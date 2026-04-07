#!/usr/bin/env python3
"""
scripts/import_mlit.py
国土交通省 国土数値情報（P35: 温泉地）→ Supabase 施設データインポートスクリプト

【データのダウンロード手順】
  1. 以下のURLにアクセスしてください:
       https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTempps-P35.html
  2. 「全国」または任意の都道府県の ZIP をダウンロードして解凍してください
  3. 解凍したフォルダに含まれる XML ファイル（例: P35-XX_XX.xml）を
     scripts/data/ ディレクトリに配置してください

【P35データについて】
  - 温泉地（草津温泉・箱根温泉 等）の所在地・名称データ
  - OSM が苦手とする地方の温泉地を補完するために使用
  - 各レコードは「温泉地エリア」を代表する1点の座標を持つ

【使い方】
  pip install -r requirements.txt

  # 単一ファイルを処理
  python import_mlit.py --file data/P35-21_22.xml

  # data/ 配下の全 XML を一括処理
  python import_mlit.py --dir data/

  # 本番実行
  python import_mlit.py --dir data/ --execute
"""

import argparse
import os
import sys
import time
from pathlib import Path
from typing import Optional

import requests
from dotenv import load_dotenv
from lxml import etree

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

BATCH_SIZE = 100

# ──────────────────────────────────────────────────────────────────────────────
# XML 名前空間
# KSJ2 形式（2015年以前）と KSJ3 形式（2016年以降）の両方に対応
# ──────────────────────────────────────────────────────────────────────────────
# P35 フィールドマッピング（年度によって若干異なるため複数パターンを試行）
# P35_001: 温泉地コード / P35_002: 都道府県名 / P35_003: 市区町村名
# P35_004: 温泉地名（年度によっては P35_002 が名前のこともある）
_FIELD_CANDIDATES = {
    # 温泉地名（最優先で試行する順）
    "name": ["P35_004", "P35_002", "P35_003"],
    # 都道府県
    "prefecture": ["P35_002", "P35_003"],
    # 市区町村
    "municipality": ["P35_003", "P35_004"],
}


# ──────────────────────────────────────────────────────────────────────────────
# GML ファイルのパース
# ──────────────────────────────────────────────────────────────────────────────
def _parse_gml_file(filepath: Path) -> list[dict]:
    """
    KSJ2/KSJ3 形式の GML (XML) ファイルをパースして
    施設レコードのリストを返す。
    """
    try:
        tree = etree.parse(str(filepath))
    except etree.XMLSyntaxError as e:
        print(f"     ⚠️  XML パースエラー: {e}")
        return []

    root = tree.getroot()

    # ルート要素から名前空間マップを取得
    nsmap = root.nsmap.copy()

    # デフォルト名前空間（None キー）がある場合は "ksj" として登録
    default_ns = nsmap.pop(None, None)
    if default_ns:
        nsmap["ksj"] = default_ns

    # GML 名前空間（なければ代表的な URI で補完）
    if "gml" not in nsmap:
        nsmap["gml"] = "http://www.opengis.net/gml/3.2"

    facilities = []

    # P35 要素を全取得（名前空間あり・なし両方に対応）
    p35_elements = (
        root.findall(".//ksj:P35", nsmap)        # 名前空間あり
        or root.findall(".//{*}P35")             # ワイルドカード（lxml 拡張）
        or root.findall(".//P35")                # 名前空間なし
    )

    for p35 in p35_elements:
        record = _parse_p35_element(p35, nsmap)
        if record:
            facilities.append(record)

    return facilities


def _get_text(element, tag: str, nsmap: dict) -> Optional[str]:
    """指定タグのテキストを取得（名前空間ありなし両対応）"""
    # 名前空間あり（デフォルト NS or ksj:）
    for prefix in ("ksj", None):
        if prefix and prefix in nsmap:
            child = element.find(f"{prefix}:{tag}", nsmap)
        else:
            child = element.find(f"{{{nsmap.get('ksj', '')}}}{tag}")
        if child is not None and child.text:
            return child.text.strip()

    # ワイルドカード検索（フォールバック）
    child = element.find(f"{{*}}{tag}")
    if child is not None and child.text:
        return child.text.strip()

    # 名前空間なし
    child = element.find(tag)
    if child is not None and child.text:
        return child.text.strip()

    return None


def _get_coordinates(element, nsmap: dict) -> tuple[Optional[float], Optional[float]]:
    """
    P35 要素から緯度経度を取得する。
    KSJ2/KSJ3 の複数フォーマットに対応:
      - gml:pos（"lat lng" 形式）
      - gml:coordinates（"lng,lat" 形式）
      - P35_006 / P35_007（直接数値）
    """
    gml_ns = nsmap.get("gml", "http://www.opengis.net/gml/3.2")

    # ① gml:pos → "lat lng"
    pos = (
        element.find(f"{{{gml_ns}}}pos")
        or element.find(".//{%s}pos" % gml_ns)
        or element.find(".//{*}pos")
    )
    if pos is not None and pos.text:
        parts = pos.text.strip().split()
        if len(parts) >= 2:
            try:
                return float(parts[0]), float(parts[1])
            except ValueError:
                pass

    # ② gml:coordinates → "lng,lat" または "lat,lng"（フォーマット依存）
    coords = element.find(".//{*}coordinates")
    if coords is not None and coords.text:
        parts = coords.text.strip().replace(" ", ",").split(",")
        if len(parts) >= 2:
            try:
                v0, v1 = float(parts[0]), float(parts[1])
                # 日本の緯度（24-46）と経度（122-154）で判定
                if 24.0 <= v0 <= 46.0 and 122.0 <= v1 <= 154.0:
                    return v0, v1
                elif 122.0 <= v0 <= 154.0 and 24.0 <= v1 <= 46.0:
                    return v1, v0
            except ValueError:
                pass

    # ③ P35_006（緯度）/ P35_007（経度）直接フィールド
    lat_text = _get_text(element, "P35_006", nsmap)
    lng_text = _get_text(element, "P35_007", nsmap)
    if lat_text and lng_text:
        try:
            return float(lat_text), float(lng_text)
        except ValueError:
            pass

    return None, None


def _parse_p35_element(element, nsmap: dict) -> Optional[dict]:
    """P35 要素1件を Facility レコードに変換する"""

    # 温泉地名を取得（候補フィールドを順番に試す）
    name = None
    for field in _FIELD_CANDIDATES["name"]:
        name = _get_text(element, field, nsmap)
        if name:
            break

    if not name:
        return None

    # 都道府県・市区町村
    prefecture = _get_text(element, _FIELD_CANDIDATES["prefecture"][0], nsmap) or ""
    municipality = _get_text(element, _FIELD_CANDIDATES["municipality"][0], nsmap) or ""

    # 住所を組み立て
    address_parts = [p for p in (prefecture, municipality) if p and p != name]
    address = "".join(address_parts)

    # 座標取得
    lat, lng = _get_coordinates(element, nsmap)
    if lat is None or lng is None:
        return None

    # 日本国内チェック
    if not (24.0 <= lat <= 46.0 and 122.0 <= lng <= 154.0):
        return None

    # 一意ID（都道府県+名前で生成）
    mlit_id = f"mlit/{prefecture}/{name}"

    return {
        "name": name,
        "type": "onsen",
        "price": 0,
        "rating": 0.0,
        "review_count": 0,
        "is_open": True,
        "address": address,
        "phone": "",
        "hours": "",
        "holiday": "",
        "latitude": lat,
        "longitude": lng,
        "amenities": {"natural_hot_spring": True},
        "data_source": "mlit",
        # osm_id カラムを MLIT ID として流用（NULL 許容・upsert キー）
        "osm_id": mlit_id,
    }


# ──────────────────────────────────────────────────────────────────────────────
# Supabase バッチ upsert
# ──────────────────────────────────────────────────────────────────────────────
def _upsert_batch(batch: list) -> tuple[int, int]:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    try:
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/facilities?on_conflict=osm_id",
            headers=headers,
            json=batch,
            timeout=30,
        )
        if resp.status_code in (200, 201):
            return len(batch), 0
        else:
            print(f"\n     HTTP {resp.status_code}: {resp.text[:200]}")
            return 0, len(batch)
    except Exception as e:
        print(f"\n     例外: {e}")
        return 0, len(batch)


# ──────────────────────────────────────────────────────────────────────────────
# ファイル収集
# ──────────────────────────────────────────────────────────────────────────────
def _collect_files(file_arg: Optional[str], dir_arg: Optional[str]) -> list[Path]:
    files: list[Path] = []

    if file_arg:
        p = Path(file_arg)
        if not p.exists():
            sys.exit(f"❌ ファイルが見つかりません: {file_arg}")
        files.append(p)

    if dir_arg:
        d = Path(dir_arg)
        if not d.is_dir():
            sys.exit(f"❌ ディレクトリが見つかりません: {dir_arg}")
        xml_files = sorted(d.glob("*.xml")) + sorted(d.glob("*.gml"))
        if not xml_files:
            sys.exit(f"❌ {dir_arg} に XML/GML ファイルが見つかりません")
        files.extend(xml_files)

    if not files:
        sys.exit(
            "❌ ファイルが指定されていません\n"
            "   --file <xmlファイル>  または  --dir <ディレクトリ>  を指定してください\n\n"
            "   【データのダウンロード先】\n"
            "   https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTempps-P35.html\n"
            "   ZIP を解凍して scripts/data/ に配置してください"
        )

    return files


# ──────────────────────────────────────────────────────────────────────────────
# メイン
# ──────────────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(
        description="国土数値情報 P35（温泉地）→ Supabase インポート"
    )
    parser.add_argument("--file", help="処理する XML/GML ファイルのパス")
    parser.add_argument("--dir", help="XML/GML ファイルが入ったディレクトリ")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="実際に DB へ書き込む（省略時はドライラン）",
    )
    args = parser.parse_args()
    dry_run = not args.execute

    # ─── 設定チェック ───────────────────────────────────────────────────────
    print("=" * 62)
    print("  Yu Map — 国土数値情報（P35温泉地）インポート")
    print("=" * 62)

    if not SUPABASE_URL:
        sys.exit("❌ SUPABASE_URL が .env に設定されていません")
    if not dry_run and not SUPABASE_SERVICE_KEY:
        sys.exit(
            "❌ SUPABASE_SERVICE_ROLE_KEY が .env に設定されていません\n"
            "   Supabase ダッシュボード → Project Settings → API → service_role"
        )

    if dry_run:
        print("⚠️  ドライランモード（DB への書き込みは行いません）")
        print("   実際に書き込む場合は --execute を付けてください")
    print()

    # ─── ファイル収集 ────────────────────────────────────────────────────────
    files = _collect_files(args.file, args.dir)
    print(f"📂 処理対象ファイル: {len(files)} 件")
    for f in files:
        print(f"   - {f.name}")
    print()

    # ─── パース ─────────────────────────────────────────────────────────────
    all_facilities: list[dict] = []
    for filepath in files:
        print(f"🔄 {filepath.name} をパース中...")
        records = _parse_gml_file(filepath)
        print(f"   → {len(records)} 件の温泉地を取得")
        all_facilities.extend(records)

    # 重複除去（同じ osm_id）
    seen: set[str] = set()
    deduped: list[dict] = []
    for f in all_facilities:
        uid = f["osm_id"]
        if uid not in seen:
            seen.add(uid)
            deduped.append(f)
    if len(deduped) < len(all_facilities):
        print(f"   ※ 重複 {len(all_facilities) - len(deduped)} 件を除外しました")

    all_facilities = deduped
    print(f"\n📊 合計: {len(all_facilities):,} 件の温泉地")

    if dry_run:
        print(f"\n✅ ドライラン完了（{len(all_facilities):,} 件を書き込む予定）")
        print("   --execute を付けて実行すると DB に書き込まれます")
        return

    # ─── Supabase へバッチ upsert ─────────────────────────────────────────
    print(f"\n💾 Supabase へ書き込み中 (バッチサイズ: {BATCH_SIZE}件)...")
    total_ok, total_err = 0, 0
    total_batches = (len(all_facilities) + BATCH_SIZE - 1) // BATCH_SIZE

    for i in range(0, len(all_facilities), BATCH_SIZE):
        batch = all_facilities[i : i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        print(
            f"  [{batch_num:>4}/{total_batches}] {len(batch)} 件...",
            end="",
            flush=True,
        )
        ok, err = _upsert_batch(batch)
        total_ok += ok
        total_err += err
        print(" ✅" if err == 0 else f" ❌ ({err} 件失敗)")
        time.sleep(0.3)

    print(f"\n{'=' * 62}")
    print(f"  完了: {total_ok:,} 件 挿入/更新  /  {total_err:,} 件 エラー")
    if total_err > 0:
        print("  ※ エラーの主な原因: migration 未実行 / RLS 設定 / 型不一致")
    print(f"{'=' * 62}")


if __name__ == "__main__":
    main()
