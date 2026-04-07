#!/usr/bin/env python3
"""
scripts/import_osm.py
OpenStreetMap (Overpass API) → Supabase 施設データインポートスクリプト

【事前準備】
  1. Supabase ダッシュボードで以下の migration を実行してください:
       supabase/migrations/20260403000001_add_osm_fields.sql
  2. .env に SUPABASE_SERVICE_ROLE_KEY を設定してください

【使い方】
  pip install -r requirements.txt

  # まずドライランで件数を確認（DB書き込みなし）
  python import_osm.py

  # 本番実行
  python import_osm.py --execute

  # テスト用（100件だけ挿入）
  python import_osm.py --execute --limit 100
"""

import argparse
import os
import sys
import time
from typing import Optional

import requests
from dotenv import load_dotenv

# .env 読み込み（scripts/ の親ディレクトリにある）
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
BATCH_SIZE = 100  # Supabase への1バッチあたりの挿入件数

# ──────────────────────────────────────────────────────────────────────────────
# Overpass クエリ
# ──────────────────────────────────────────────────────────────────────────────
# 対象タグ:
#   amenity=public_bath   → 銭湯・公衆浴場（天然温泉含む）
#   amenity=sauna         → サウナ
#   leisure=spa           → スパ系施設
#   leisure=bathing_resort → スーパー銭湯
# out body center qt:
#   body   = タグを全取得
#   center = way の中心座標を付与（nodeはそのまま）
#   qt     = クアッドタイル順でソート（高速化）
OVERPASS_QUERY = """
[out:json][timeout:300];
area["ISO3166-1"="JP"]->.japan;
(
  node["amenity"="public_bath"](area.japan);
  way["amenity"="public_bath"](area.japan);
  node["amenity"="sauna"](area.japan);
  way["amenity"="sauna"](area.japan);
  node["leisure"="spa"](area.japan);
  way["leisure"="spa"](area.japan);
  node["leisure"="bathing_resort"](area.japan);
  way["leisure"="bathing_resort"](area.japan);
);
out body center qt;
"""

# ──────────────────────────────────────────────────────────────────────────────
# OSM タグ → 施設タイプ変換
# ──────────────────────────────────────────────────────────────────────────────
_ONSEN_KEYWORDS = ("温泉", "おんせん", "onsen", "Onsen", "湯", "の湯", "乃湯")
_SUPERSENTO_KEYWORDS = ("スーパー銭湯", "スパ銭", "スパ", "天然温泉スパ")


def _determine_type(tags: dict) -> str:
    amenity = tags.get("amenity", "")
    leisure = tags.get("leisure", "")
    name = tags.get("name", "") or ""

    # サウナ
    if amenity == "sauna" or tags.get("sauna") == "yes":
        return "sauna"

    # スーパー銭湯
    if leisure == "bathing_resort":
        return "supersento"
    if leisure == "spa" and any(k in name for k in _SUPERSENTO_KEYWORDS):
        return "supersento"

    # 温泉（OSMタグまたは施設名に温泉ワードを含む）
    if (
        tags.get("hot_spring") == "yes"
        or tags.get("onsen") == "yes"
        or tags.get("bathing") == "hot_spring"
        or any(k in name for k in _ONSEN_KEYWORDS)
    ):
        return "onsen"

    # spa でスーパー銭湯判定外ならスーパー銭湯扱い
    if leisure == "spa":
        return "supersento"

    # デフォルト：銭湯
    return "public_bath"


# ──────────────────────────────────────────────────────────────────────────────
# OSM タグ → 住所文字列
# ──────────────────────────────────────────────────────────────────────────────
_ADDR_KEYS = (
    "addr:full",          # 一体型住所（日本ではこちらが多い）
    "addr:province",      # 都道府県
    "addr:city",          # 市区町村
    "addr:suburb",        # 丁目・大字
    "addr:quarter",       # 小字
    "addr:street",        # 通り名
    "addr:housenumber",   # 番地
)


def _extract_address(tags: dict) -> str:
    if tags.get("addr:full"):
        return tags["addr:full"]
    return "".join(tags[k] for k in _ADDR_KEYS[1:] if tags.get(k))


# ──────────────────────────────────────────────────────────────────────────────
# OSM タグ → アメニティ（設備情報）
# ──────────────────────────────────────────────────────────────────────────────
def _extract_amenities(tags: dict) -> dict:
    desc = tags.get("description", "") or ""
    return {
        "sauna": tags.get("sauna") == "yes",
        "outdoor_bath": "露天" in desc or tags.get("outdoor_seating") == "yes",
        "parking": "parking" in tags or tags.get("amenity:parking") is not None,
        "tattoo_friendly": tags.get("tattoo") == "allowed",
        "natural_hot_spring": (
            tags.get("hot_spring") == "yes" or tags.get("onsen") == "yes"
        ),
    }


# ──────────────────────────────────────────────────────────────────────────────
# OSM 要素 → Facility レコード変換
# ──────────────────────────────────────────────────────────────────────────────
def _to_facility(element: dict) -> Optional[dict]:
    tags = element.get("tags", {})

    # 名前が取れないものはスキップ
    name = tags.get("name") or tags.get("name:ja")
    if not name:
        return None

    # 座標取得：node は直接、way は center キー
    if element["type"] == "node":
        lat = element.get("lat")
        lng = element.get("lon")
    elif element["type"] == "way":
        center = element.get("center", {})
        lat = center.get("lat")
        lng = center.get("lon")
    else:
        return None  # relation は今回対象外

    if lat is None or lng is None:
        return None

    # 日本国内の緯度経度チェック（離島・南鳥島・南大東島含む）
    if not (24.0 <= lat <= 46.0 and 122.0 <= lng <= 154.0):
        return None

    return {
        "name": name,
        "type": _determine_type(tags),
        "price": 0,              # OSM には価格情報なし → デフォルト0
        "rating": 0.0,           # OSM には評価情報なし → デフォルト0
        "review_count": 0,
        "is_open": True,         # リアルタイム営業状況は Google Places API で補完
        "address": _extract_address(tags),
        "phone": tags.get("phone") or tags.get("contact:phone") or "",
        "hours": tags.get("opening_hours") or "",
        "holiday": "",
        "latitude": lat,
        "longitude": lng,
        "amenities": _extract_amenities(tags),
        "data_source": "osm",
        "osm_id": f"{element['type']}/{element['id']}",
    }


# ──────────────────────────────────────────────────────────────────────────────
# Overpass API からデータ取得
# ──────────────────────────────────────────────────────────────────────────────
def _fetch_overpass() -> list:
    print("🌐 Overpass API に問い合わせ中...")
    print("   ※ 日本全国のデータ取得は 1〜3 分かかります。")

    for attempt in range(3):
        try:
            resp = requests.post(
                OVERPASS_URL,
                data={"data": OVERPASS_QUERY},
                timeout=370,
            )
            resp.raise_for_status()
            elements = resp.json().get("elements", [])
            print(f"✅ {len(elements):,} 件の OSM 要素を取得しました")
            return elements

        except requests.exceptions.Timeout:
            wait = 30
            print(f"⚠️  タイムアウト（試行 {attempt + 1}/3）... {wait}秒後に再試行")
            time.sleep(wait)

        except requests.exceptions.HTTPError as e:
            print(f"❌ HTTP エラー: {e}")
            if attempt == 2:
                raise
            time.sleep(10)

        except Exception as e:
            print(f"❌ 予期しないエラー: {e}")
            if attempt == 2:
                raise
            time.sleep(10)

    return []


# ──────────────────────────────────────────────────────────────────────────────
# Supabase REST API 経由でバッチ upsert
# ──────────────────────────────────────────────────────────────────────────────
def _upsert_batch(batch: list) -> tuple[int, int]:
    """
    osm_id を競合キーとして upsert する。
    再実行しても同じレコードが重複しない。
    """
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
# メイン
# ──────────────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(description="OSM → Supabase 施設インポート")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="実際に DB へ書き込む（省略時はドライラン）",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="挿入件数の上限（テスト用。省略時は全件）",
    )
    args = parser.parse_args()
    dry_run = not args.execute

    # ─── 設定チェック ───────────────────────────────────────────────────────
    print("=" * 62)
    print("  Yu Map — OSM 施設データインポート")
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

    # ─── 1. Overpass からデータ取得 ─────────────────────────────────────────
    elements = _fetch_overpass()
    if not elements:
        sys.exit("❌ データ取得に失敗しました")

    # ─── 2. 変換 ────────────────────────────────────────────────────────────
    print("\n🔄 変換中...")
    facilities: list[dict] = []
    skipped = 0
    for el in elements:
        f = _to_facility(el)
        if f:
            facilities.append(f)
        else:
            skipped += 1

    if args.limit > 0:
        facilities = facilities[: args.limit]
        print(f"   ※ --limit {args.limit} 件に制限しています")

    print(f"   変換成功 : {len(facilities):>6,} 件")
    print(f"   スキップ : {skipped:>6,} 件（名前なし・座標なし等）")

    # ─── 3. タイプ別内訳 ─────────────────────────────────────────────────────
    _LABEL = {
        "public_bath": "銭湯",
        "onsen": "温泉",
        "sauna": "サウナ",
        "supersento": "スーパー銭湯",
    }
    counts: dict[str, int] = {}
    for f in facilities:
        counts[f["type"]] = counts.get(f["type"], 0) + 1

    print("\n📊 タイプ別内訳:")
    for t, n in sorted(counts.items()):
        print(f"   {_LABEL.get(t, t):<14} {n:>6,} 件")

    # ─── 4. ドライランなら終了 ───────────────────────────────────────────────
    if dry_run:
        print(f"\n✅ ドライラン完了（合計 {len(facilities):,} 件を書き込む予定）")
        print("   --execute を付けて実行すると DB に書き込まれます")
        return

    # ─── 5. Supabase へバッチ upsert ─────────────────────────────────────────
    print(f"\n💾 Supabase へ書き込み中 (バッチサイズ: {BATCH_SIZE}件)...")
    total_ok = 0
    total_err = 0
    total_batches = (len(facilities) + BATCH_SIZE - 1) // BATCH_SIZE

    for i in range(0, len(facilities), BATCH_SIZE):
        batch = facilities[i : i + BATCH_SIZE]
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
        time.sleep(0.3)  # Supabase レートリミット対策

    # ─── 6. 結果 ─────────────────────────────────────────────────────────────
    print(f"\n{'=' * 62}")
    print(f"  完了: {total_ok:,} 件 挿入/更新  /  {total_err:,} 件 エラー")
    if total_err > 0:
        print("  ※ エラーの主な原因: migration 未実行 / RLS 設定 / 型不一致")
        print("     supabase/migrations/20260403000001_add_osm_fields.sql を")
        print("     Supabase SQL エディタで実行してください")
    print(f"{'=' * 62}")


if __name__ == "__main__":
    main()
