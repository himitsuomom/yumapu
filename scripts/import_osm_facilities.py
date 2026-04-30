#!/usr/bin/env python3
"""
import_osm_facilities.py
=========================
OpenStreetMap (Overpass API) から日本全国の温泉・銭湯・サウナデータを取得して
Supabase にインポートするスクリプト。

【使い方】
  1. 必要パッケージをインストール:
       pip install requests supabase python-dotenv

  2. 環境変数を設定（.env ファイルか直接環境変数）:
       SUPABASE_URL=https://xxxx.supabase.co
       SUPABASE_SERVICE_ROLE_KEY=eyJ...  ← Service Role Key を使う（管理操作のため）

  3. 実行:
       python scripts/import_osm_facilities.py

  4. 段階実行（施設タイプ別）:
       python scripts/import_osm_facilities.py --type onsen
       python scripts/import_osm_facilities.py --type public_bath
       python scripts/import_osm_facilities.py --type sauna

【注意】
  - Overpass API は無料サービスです。大量リクエストは避けてください。
  - 一度実行済みの施設は osm_id で重複スキップされます（UPSERT）。
  - 初回実行時間は約 5〜10 分（日本全国 5,000〜8,000 件程度）です。
"""

import os
import sys
import json
import time
import logging
import argparse
from typing import Optional
from datetime import datetime

import requests

# ─────────────────────────────────────────────────────────────────────────────
# Nominatim 逆ジオコーディング
# ─────────────────────────────────────────────────────────────────────────────
NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
NOMINATIM_USER_AGENT = "yumapu-import/1.0 (himitsuomom; educational use)"
NOMINATIM_RATE_LIMIT = 1.1  # 秒（Nominatim 利用規約: 1 req/sec 以下）

_geocode_cache: dict[tuple, Optional[str]] = {}
_last_nominatim_call = 0.0


def reverse_geocode(lat: float, lng: float) -> Optional[str]:
    """
    Nominatim 逆ジオコーディングで緯度経度→日本語住所を返す。
    Nominatim 利用規約に従い 1 req/sec 以下に制限する。
    """
    global _last_nominatim_call

    # 小数点4桁で丸めてキャッシュ（~11m 精度、同エリアの重複リクエストを避ける）
    cache_key = (round(lat, 4), round(lng, 4))
    if cache_key in _geocode_cache:
        return _geocode_cache[cache_key]

    # レート制限
    elapsed = time.time() - _last_nominatim_call
    if elapsed < NOMINATIM_RATE_LIMIT:
        time.sleep(NOMINATIM_RATE_LIMIT - elapsed)

    try:
        resp = requests.get(
            NOMINATIM_URL,
            params={
                "format": "json",
                "lat": lat,
                "lon": lng,
                "accept-language": "ja",
                "zoom": 18,
            },
            headers={"User-Agent": NOMINATIM_USER_AGENT},
            timeout=10,
        )
        _last_nominatim_call = time.time()
        resp.raise_for_status()
        data = resp.json()

        addr = data.get("address", {})
        parts = []
        # 日本の Nominatim では都道府県は province フィールド
        pref = addr.get("province") or addr.get("state") or addr.get("prefecture")
        if pref:
            parts.append(pref)
        city = addr.get("city") or addr.get("town") or addr.get("village")
        if city:
            parts.append(city)
        suburb = addr.get("suburb") or addr.get("quarter") or addr.get("neighbourhood")
        if suburb:
            parts.append(suburb)
        if addr.get("road"):
            parts.append(addr["road"])
        if addr.get("house_number"):
            parts.append(addr["house_number"])

        result = "".join(parts) if parts else None
        _geocode_cache[cache_key] = result
        return result

    except Exception as e:
        logger.debug(f"Nominatim エラー ({lat},{lng}): {e}")
        _last_nominatim_call = time.time()
        _geocode_cache[cache_key] = None
        return None

# ─────────────────────────────────────────────────────────────────────────────
# ロギング設定
# ─────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# 定数
# ─────────────────────────────────────────────────────────────────────────────
# Overpass API のミラーリスト（順に試みる）
OVERPASS_URLS = [
    "https://lz4.overpass-api.de/api/interpreter",
    "https://z.overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]
OVERPASS_TIMEOUT = 180  # 秒
OVERPASS_MAX_RETRIES = 3
OVERPASS_RETRY_WAIT = 60  # 秒

SUPABASE_BATCH_SIZE = 100  # 一度にUPSERTするレコード数

# ─────────────────────────────────────────────────────────────────────────────
# OSM クエリ定義（inner_filters のみ定義、日本エリア指定は fetch_overpass で付与）
# ─────────────────────────────────────────────────────────────────────────────
# タイプ別の検索フィルター（area.japan バインドを使う）
OVERPASS_INNER_FILTERS = {
    "onsen": """\
  node["amenity"="onsen"]["name"](area.japan);
  way["amenity"="onsen"]["name"](area.japan);
  node["leisure"="hot_spring"]["name"](area.japan);
  way["leisure"="hot_spring"]["name"](area.japan);
  node["bath:type"="onsen"]["name"](area.japan);
  way["bath:type"="onsen"]["name"](area.japan);
  node["natural"="hot_spring"]["name"](area.japan);
  node["amenity"="spa"]["bath:type"="onsen"]["name"](area.japan);""",
    "public_bath": """\
  node["amenity"="public_bath"]["name"](area.japan);
  way["amenity"="public_bath"]["name"](area.japan);
  node["amenity"="bath"]["name"](area.japan);
  way["amenity"="bath"]["name"](area.japan);""",
    "sauna": """\
  node["leisure"="sauna"]["name"](area.japan);
  way["leisure"="sauna"]["name"](area.japan);
  node["amenity"="sauna"]["name"](area.japan);
  way["amenity"="sauna"]["name"](area.japan);""",
}


# ─────────────────────────────────────────────────────────────────────────────
# 都道府県名 → ID のマッピング（Supabase prefectures テーブル対応）
# ─────────────────────────────────────────────────────────────────────────────
PREFECTURE_MAP = {
    "北海道": "北海道",
    "青森県": "青森県", "岩手県": "岩手県", "宮城県": "宮城県",
    "秋田県": "秋田県", "山形県": "山形県", "福島県": "福島県",
    "茨城県": "茨城県", "栃木県": "栃木県", "群馬県": "群馬県",
    "埼玉県": "埼玉県", "千葉県": "千葉県", "東京都": "東京都",
    "神奈川県": "神奈川県", "新潟県": "新潟県", "富山県": "富山県",
    "石川県": "石川県", "福井県": "福井県", "山梨県": "山梨県",
    "長野県": "長野県", "岐阜県": "岐阜県", "静岡県": "静岡県",
    "愛知県": "愛知県", "三重県": "三重県", "滋賀県": "滋賀県",
    "京都府": "京都府", "大阪府": "大阪府", "兵庫県": "兵庫県",
    "奈良県": "奈良県", "和歌山県": "和歌山県", "鳥取県": "鳥取県",
    "島根県": "島根県", "岡山県": "岡山県", "広島県": "広島県",
    "山口県": "山口県", "徳島県": "徳島県", "香川県": "香川県",
    "愛媛県": "愛媛県", "高知県": "高知県", "福岡県": "福岡県",
    "佐賀県": "佐賀県", "長崎県": "長崎県", "熊本県": "熊本県",
    "大分県": "大分県", "宮崎県": "宮崎県", "鹿児島県": "鹿児島県",
    "沖縄県": "沖縄県",
}


# ─────────────────────────────────────────────────────────────────────────────
# Overpass API 呼び出し
# ─────────────────────────────────────────────────────────────────────────────
def fetch_overpass(facility_type: str) -> list[dict]:
    """Overpass API からOSMデータを取得する。"""
    # 日本エリア指定 + 施設タイプ別フィルターを組み合わせた完全クエリ
    inner_filters = OVERPASS_INNER_FILTERS[facility_type]
    full_query = (
        f'[out:json][timeout:{OVERPASS_TIMEOUT}];\n'
        f'area["name"="日本"]["admin_level"="2"]->.japan;\n'
        f'(\n'
        f'{inner_filters}\n'
        f');\n'
        f'out center body;\n'  # out center で way の中心座標も取得
    )

    logger.info(f"Overpass クエリ実行中: type={facility_type}")

    for url in OVERPASS_URLS:
        for attempt in range(1, OVERPASS_MAX_RETRIES + 1):
            try:
                logger.info(f"  → {url} (試行 {attempt}/{OVERPASS_MAX_RETRIES})")
                resp = requests.post(
                    url,
                    data={"data": full_query},
                    timeout=OVERPASS_TIMEOUT + 10,
                )
                resp.raise_for_status()
                data = resp.json()
                elements = data.get("elements", [])
                logger.info(f"  → {len(elements)} 件取得")
                return elements
            except requests.exceptions.HTTPError as e:
                status = getattr(e.response, "status_code", None)
                if status == 429:
                    logger.warning(f"  → レート制限。{OVERPASS_RETRY_WAIT}秒後にリトライ...")
                    time.sleep(OVERPASS_RETRY_WAIT)
                else:
                    logger.warning(f"  → HTTP エラー {status}。次のミラーへ。")
                    break  # 次の URL を試す
            except requests.exceptions.Timeout:
                logger.warning(f"  → タイムアウト (試行 {attempt})")
                if attempt == OVERPASS_MAX_RETRIES:
                    break  # 次の URL を試す
                time.sleep(10)
            except Exception as e:
                logger.warning(f"  → エラー: {e}。次のミラーへ。")
                break  # 次の URL を試す

    raise RuntimeError(f"全ての Overpass ミラーで失敗しました（type={facility_type}）")



# ─────────────────────────────────────────────────────────────────────────────
# OSM → Supabase レコード変換
# ─────────────────────────────────────────────────────────────────────────────
def osm_element_to_record(element: dict, facility_type: str, use_geocode: bool = False) -> Optional[dict]:
    """OSM エレメントを Supabase facilities レコードに変換する。"""
    tags = element.get("tags", {})

    # 名前がない施設はスキップ（品質確保）
    name = tags.get("name") or tags.get("name:ja")
    if not name:
        return None

    # 座標取得（node は直接、way は center を使う）
    lat = element.get("lat")
    lng = element.get("lon")
    if lat is None or lng is None:
        # way の場合は center を使う（Overpass の out center オプション）
        center = element.get("center", {})
        lat = center.get("lat")
        lng = center.get("lon")
    if lat is None or lng is None:
        return None

    # OSM ID（重複防止）
    osm_id = f"{element['type'][0]}{element['id']}"  # n12345 / w12345

    # 住所の組み立て（OSM タグ優先、なければ Nominatim 逆ジオコーディング）
    address = _build_address(tags)
    if address is None and use_geocode:
        address = reverse_geocode(lat, lng)

    # 電話番号（先頭の "+" や "-" も含む）
    phone = (
        tags.get("phone")
        or tags.get("contact:phone")
        or tags.get("telephone")
    )
    if phone:
        # 電話番号を正規化（スペース・ハイフン統一）
        phone = phone.split(";")[0].strip()[:20]  # DB varchar(20) 制限

    # ウェブサイト
    website = (
        tags.get("website")
        or tags.get("contact:website")
        or tags.get("url")
    )

    # 営業時間（OSM opening_hours 形式）
    opening_hours = tags.get("opening_hours")

    # 入浴料金（fee タグから推定）
    price = _parse_price(tags)

    # データ品質スコア（情報量で判定）
    quality_score = _calc_quality_score(tags)

    # type フィールド（Flutter モデル互換）
    type_code = facility_type  # 'onsen', 'public_bath', 'sauna'

    record = {
        "name": name[:255],
        "name_kana": None,
        "latitude": lat,
        "longitude": lng,
        "address": address,
        "phone": phone,
        "website": website[:500] if website else None,
        "osm_id": osm_id,
        "type": type_code,
        "hours": opening_hours,
        "price": price,
        "data_source": "osm",
        "data_quality_score": quality_score,
        "is_open": True,
    }

    return record


def _build_address(tags: dict) -> Optional[str]:
    """OSM タグから住所文字列を組み立てる。"""
    # 完全な住所タグがあればそれを使う
    if tags.get("addr:full"):
        return tags["addr:full"]

    parts = []
    if tags.get("addr:province"):
        parts.append(tags["addr:province"])
    if tags.get("addr:city"):
        parts.append(tags["addr:city"])
    if tags.get("addr:district"):
        parts.append(tags["addr:district"])
    if tags.get("addr:street"):
        parts.append(tags["addr:street"])
    if tags.get("addr:housenumber"):
        parts.append(tags["addr:housenumber"])

    if parts:
        return "".join(parts)

    # 都道府県タグだけでも保存
    if tags.get("addr:prefecture"):
        return tags["addr:prefecture"]

    return None


def _parse_price(tags: dict) -> Optional[int]:
    """OSM タグから入浴料金を推定する（円）。"""
    fee = tags.get("fee")
    if fee == "no":
        return 0  # 無料
    charge = tags.get("charge") or tags.get("fee:amount")
    if charge:
        try:
            # "500 JPY" や "500円" などから数値抽出
            import re
            match = re.search(r"\d+", charge)
            if match:
                return int(match.group())
        except Exception:
            pass
    return None


def _calc_quality_score(tags: dict) -> int:
    """OSM タグの充実度からデータ品質スコアを計算する（1〜5）。"""
    score = 2  # OSM ベースラインは 2
    if tags.get("phone") or tags.get("contact:phone"):
        score += 1
    if tags.get("website") or tags.get("contact:website"):
        score += 1
    if tags.get("opening_hours"):
        score += 1
    return min(score, 5)


# ─────────────────────────────────────────────────────────────────────────────
# Supabase へのアップサート
# ─────────────────────────────────────────────────────────────────────────────
def upsert_to_supabase(records: list[dict], supabase_url: str, service_key: str) -> tuple[int, int]:
    """
    Supabase に施設レコードを UPSERT する。
    PostgREST の geography 型解決エラー (42704) を回避するため、
    直接テーブルに POST するのではなく batch_upsert_osm_facilities RPC を使用する。

    Returns:
        (inserted_count, skipped_count) のタプル
    """
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }

    rpc_url = f"{supabase_url}/rest/v1/rpc/batch_upsert_osm_facilities"
    inserted = 0
    skipped = 0

    # バッチ処理（Supabase の POST に上限があるため分割）
    for i in range(0, len(records), SUPABASE_BATCH_SIZE):
        batch = records[i : i + SUPABASE_BATCH_SIZE]
        logger.info(f"  → バッチ {i//SUPABASE_BATCH_SIZE + 1}: {len(batch)} 件をアップサート中...")

        try:
            resp = requests.post(
                rpc_url,
                headers=headers,
                json={"records": batch},
                timeout=60,
            )
            resp.raise_for_status()
            result = resp.json()
            batch_inserted = result.get("inserted", 0)
            batch_skipped = result.get("skipped", 0)
            inserted += batch_inserted
            skipped += batch_skipped
            logger.info(f"    ✓ 挿入/更新: {batch_inserted} 件, スキップ: {batch_skipped} 件")
        except requests.exceptions.HTTPError as e:
            logger.error(f"    ✗ HTTP エラー: {e.response.status_code} - {e.response.text[:200]}")
        except Exception as e:
            logger.error(f"    予期しないエラー: {e}")

        # Supabase レート制限対策（バッチ間に短い待機）
        time.sleep(0.3)

    return inserted, skipped


# ─────────────────────────────────────────────────────────────────────────────
# facility_type_id の設定（Supabase から facility_types テーブルを参照）
# ─────────────────────────────────────────────────────────────────────────────
def fetch_facility_type_ids(supabase_url: str, service_key: str) -> dict[str, str]:
    """Supabase から facility_types テーブルの code→id マッピングを取得する。"""
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }
    url = f"{supabase_url}/rest/v1/facility_types?select=id,code"
    resp = requests.get(url, headers=headers, timeout=10)
    resp.raise_for_status()
    rows = resp.json()
    return {row["code"]: row["id"] for row in rows}


def update_facility_type_ids_in_batch(
    records: list[dict], type_id_map: dict[str, str]
) -> list[dict]:
    """records の各レコードに facility_type_id を設定して返す。"""
    for record in records:
        type_code = record.get("type")
        if type_code and type_code in type_id_map:
            record["facility_type_id"] = type_id_map[type_code]
    return records


# ─────────────────────────────────────────────────────────────────────────────
# メイン処理
# ─────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="OSM から日本の温泉・銭湯・サウナデータを Supabase にインポート")
    parser.add_argument(
        "--type",
        choices=["onsen", "public_bath", "sauna", "all"],
        default="all",
        help="インポートする施設タイプ（デフォルト: all）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Supabase に書き込まず、取得件数だけ表示する",
    )
    parser.add_argument(
        "--geocode",
        action="store_true",
        help="住所タグがない施設を Nominatim 逆ジオコーディングで補完する（処理が遅くなります）",
    )
    args = parser.parse_args()

    # 環境変数から認証情報を読み込む
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))
    except ImportError:
        pass  # python-dotenv がない場合はそのまま

    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

    if not args.dry_run:
        if not supabase_url or not service_key:
            logger.error(
                "環境変数が設定されていません。\n"
                "SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を設定してください。\n"
                "例: export SUPABASE_URL=https://xxxx.supabase.co\n"
                "    export SUPABASE_SERVICE_ROLE_KEY=eyJ..."
            )
            sys.exit(1)

        # facility_types の ID マッピングを取得
        logger.info("Supabase から facility_types を取得中...")
        try:
            type_id_map = fetch_facility_type_ids(supabase_url, service_key)
            logger.info(f"  → {type_id_map}")
        except Exception as e:
            logger.error(f"facility_types 取得エラー: {e}")
            sys.exit(1)
    else:
        type_id_map = {}
        logger.info("【DRY RUN モード】Supabase への書き込みはスキップされます。")

    # インポートするタイプのリスト
    types_to_import = (
        ["onsen", "public_bath", "sauna"]
        if args.type == "all"
        else [args.type]
    )

    total_converted = 0
    total_inserted = 0
    start_time = datetime.now()

    for facility_type in types_to_import:
        logger.info(f"\n{'='*60}")
        logger.info(f"処理中: {facility_type}")
        logger.info(f"{'='*60}")

        # Overpass API からデータ取得
        try:
            elements = fetch_overpass(facility_type)
        except Exception as e:
            logger.error(f"Overpass API エラー（{facility_type}）: {e}")
            logger.info("  → このタイプをスキップして続行します")
            continue

        if not elements:
            logger.info("  → 取得データなし。スキップ。")
            continue

        # OSM → Supabase レコード変換
        if args.geocode:
            logger.info("  住所補完モード: 住所なし施設を Nominatim で逆ジオコーディングします")
        records = []
        skipped = 0
        for element in elements:
            # node と way のみ処理（relation はスキップ）
            if element.get("type") in ("node", "way"):
                rec = osm_element_to_record(element, facility_type, use_geocode=args.geocode)
                if rec:
                    records.append(rec)
                else:
                    skipped += 1

        logger.info(f"  変換: {len(records)} 件 (スキップ: {skipped} 件 — 名前なし/座標なし)")
        total_converted += len(records)

        if not records:
            continue

        if args.dry_run:
            # サンプルを表示
            logger.info("  サンプル（最初の3件）:")
            for r in records[:3]:
                logger.info(f"    {r['name']} ({r['latitude']:.4f}, {r['longitude']:.4f}) osm={r['osm_id']}")
            continue

        # facility_type_id を設定
        records = update_facility_type_ids_in_batch(records, type_id_map)

        # Supabase にアップサート
        logger.info(f"  Supabase にアップサート中 ({len(records)} 件)...")
        try:
            inserted, updated = upsert_to_supabase(records, supabase_url, service_key)
            total_inserted += inserted
            logger.info(f"  ✓ 完了: {inserted} 件追加/更新")
        except Exception as e:
            logger.error(f"  ✗ Supabase アップサートエラー: {e}")

        # タイプ間の待機（Overpass API への負荷軽減）
        if facility_type != types_to_import[-1]:
            logger.info("次のタイプ処理まで15秒待機中...")
            time.sleep(15)

    # 完了レポート
    elapsed = (datetime.now() - start_time).total_seconds()
    logger.info(f"\n{'='*60}")
    logger.info(f"インポート完了")
    logger.info(f"  変換件数: {total_converted} 件")
    if not args.dry_run:
        logger.info(f"  追加/更新: {total_inserted} 件")
    logger.info(f"  処理時間: {elapsed:.1f} 秒")
    logger.info(f"{'='*60}")


if __name__ == "__main__":
    main()
