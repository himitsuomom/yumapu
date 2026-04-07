#!/usr/bin/env python3
"""
OSMデータを on_conflict なしの純粋INSERTで投入する。
テーブルが空の初回インポート用。
"""
import os, sys, time, requests
from dotenv import load_dotenv

# import_osm の変換ロジックを再利用
sys.path.insert(0, os.path.dirname(__file__))
from import_osm import _fetch_overpass, _to_facility

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
BATCH_SIZE = 200

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ SUPABASE_URL または SUPABASE_SERVICE_ROLE_KEY が未設定")
    sys.exit(1)

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}


def insert_batch(batch: list) -> tuple[int, int]:
    """on_conflict なしの純粋INSERT"""
    resp = requests.post(
        f"{SUPABASE_URL}/rest/v1/facilities",
        headers=HEADERS,
        json=batch,
        timeout=60,
    )
    if resp.status_code in (200, 201):
        return len(batch), 0
    else:
        print(f"\n     HTTP {resp.status_code}: {resp.text[:300]}")
        return 0, len(batch)


def main():
    print("=" * 60)
    print("  Yu Map — OSM インポート（初回・on_conflict なし）")
    print("=" * 60)

    print("\n🌐 Overpass API に問い合わせ中...")
    elements = _fetch_overpass()
    print(f"✅ {len(elements)} 件の OSM 要素を取得")

    print("\n🔄 変換中...")
    records = [r for e in elements if (r := _to_facility(e)) is not None]
    skipped = len(elements) - len(records)
    print(f"   変換成功: {len(records):>5} 件")
    print(f"   スキップ: {skipped:>5} 件（名前なし・座標なし等）")

    # タイプ別
    from collections import Counter
    type_map = {"onsen": "温泉", "public_bath": "銭湯", "sauna": "サウナ"}
    counts = Counter(r["type"] for r in records)
    print("\n📊 タイプ別内訳:")
    for k, label in type_map.items():
        if counts[k]:
            print(f"   {label:<12} {counts[k]:>5} 件")

    total = len(records)
    batches = [records[i:i+BATCH_SIZE] for i in range(0, total, BATCH_SIZE)]
    print(f"\n💾 Supabase へ書き込み中 (バッチサイズ: {BATCH_SIZE}件, 計{len(batches)}バッチ)...")

    ok_total, err_total = 0, 0
    for i, batch in enumerate(batches, 1):
        print(f"  [{i:>4}/{len(batches)}] {len(batch)} 件...", end="", flush=True)
        ok, err = insert_batch(batch)
        ok_total += ok
        err_total += err
        if ok:
            print(f" ✅ ({ok} 件成功)")
        else:
            print(f" ❌ ({err} 件失敗)")
        time.sleep(0.1)

    print("\n" + "=" * 60)
    print(f"  完了: {ok_total} 件 挿入  /  {err_total} 件 エラー")
    print("=" * 60)


if __name__ == "__main__":
    main()
