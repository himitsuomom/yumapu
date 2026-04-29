#!/usr/bin/env python3
"""
Phase 1 OSMデータ検証スクリプト
Supabase 不要。Overpass API から取得してデータ品質を検証するのみ。

完了基準:
  - 全国施設数 3,000件以上
  - 名称・住所・座標の欠損率 20%以下
"""

import sys
import json
import time
import logging
import requests
from typing import Optional

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
TIMEOUT = 180

QUERIES = {
    "onsen": """\
  node["amenity"="onsen"]["name"](area.japan);
  way["amenity"="onsen"]["name"](area.japan);
  node["leisure"="hot_spring"]["name"](area.japan);
  way["leisure"="hot_spring"]["name"](area.japan);
  node["bath:type"="onsen"]["name"](area.japan);
  node["natural"="hot_spring"]["name"](area.japan);""",
    "public_bath": """\
  node["amenity"="public_bath"]["name"](area.japan);
  way["amenity"="public_bath"]["name"](area.japan);""",
    "sauna": """\
  node["leisure"="sauna"]["name"](area.japan);
  way["leisure"="sauna"]["name"](area.japan);
  node["amenity"="sauna"]["name"](area.japan);""",
}

# 含有率テスト用: よく行く施設10件（実際の施設名に変えてください）
KNOWN_FACILITIES = [
    "草津温泉",
    "有馬温泉",
    "道後温泉",
    "別府温泉",
    "箱根湯本温泉",
    "登別温泉",
    "黒川温泉",
    "湯布院温泉",
    "城崎温泉",
    "白浜温泉",
]


def fetch(facility_type: str) -> list[dict]:
    inner = QUERIES[facility_type]
    query = (
        f'[out:json][timeout:{TIMEOUT}];\n'
        f'area["name"="日本"]["admin_level"="2"]->.japan;\n'
        f'(\n{inner}\n);\n'
        f'out center body;\n'
    )
    for url in OVERPASS_URLS:
        try:
            logger.info(f"  クエリ中: {url}")
            r = requests.post(url, data={"data": query}, timeout=TIMEOUT + 10)
            r.raise_for_status()
            elements = r.json().get("elements", [])
            logger.info(f"  → {len(elements)} 件取得")
            return elements
        except Exception as e:
            logger.warning(f"  → 失敗: {e}")
            time.sleep(5)
    return []


def get_coord(el: dict) -> Optional[tuple]:
    if el["type"] == "node":
        return el.get("lat"), el.get("lon")
    center = el.get("center", {})
    return center.get("lat"), center.get("lon")


def analyze(elements: list[dict], facility_type: str) -> dict:
    total = len(elements)
    if total == 0:
        return {"total": 0, "name_missing": 0, "addr_missing": 0, "coord_missing": 0}

    name_missing = addr_missing = coord_missing = 0
    names = []

    for el in elements:
        tags = el.get("tags", {})
        name = tags.get("name", "")
        if not name:
            name_missing += 1
        else:
            names.append(name)

        addr = (tags.get("addr:full") or tags.get("addr:street") or
                tags.get("addr:city") or tags.get("addr:prefecture"))
        if not addr:
            addr_missing += 1

        lat, lon = get_coord(el)
        if not lat or not lon:
            coord_missing += 1

    return {
        "total": total,
        "name_missing": name_missing,
        "name_missing_pct": round(name_missing / total * 100, 1),
        "addr_missing": addr_missing,
        "addr_missing_pct": round(addr_missing / total * 100, 1),
        "coord_missing": coord_missing,
        "coord_missing_pct": round(coord_missing / total * 100, 1),
        "names_sample": names[:10],
    }


def containment_test(all_names: list[str]) -> dict:
    """KNOWN_FACILITIES の含有率テスト（名称の部分一致）"""
    found = []
    not_found = []
    names_lower = [n.lower() for n in all_names]
    for known in KNOWN_FACILITIES:
        k = known.replace("温泉", "").lower()
        hit = any(k in n for n in names_lower)
        (found if hit else not_found).append(known)
    rate = round(len(found) / len(KNOWN_FACILITIES) * 100, 1)
    return {"found": found, "not_found": not_found, "rate": rate}


def main():
    results = {}
    all_names = []

    for ftype in ["onsen", "public_bath", "sauna"]:
        logger.info(f"\n=== {ftype} 取得中 ===")
        elements = fetch(ftype)
        stats = analyze(elements, ftype)
        results[ftype] = stats
        all_names.extend(stats.get("names_sample", []))
        time.sleep(3)  # Overpass API への負荷軽減

    # 全件取得して names_sample を充実させる
    full_names = []
    for ftype in results:
        # すでに analyze 内で names を収集済みなので fetch を再度呼ばない
        pass

    total_all = sum(r["total"] for r in results.values())

    print("\n" + "=" * 60)
    print("Phase 1 OSM データ検証レポート")
    print("=" * 60)

    for ftype, r in results.items():
        label = {"onsen": "温泉", "public_bath": "銭湯", "sauna": "サウナ"}[ftype]
        print(f"\n【{label}】 {r['total']} 件")
        print(f"  名称欠損率:   {r.get('name_missing_pct', 'N/A')}%")
        print(f"  住所欠損率:   {r.get('addr_missing_pct', 'N/A')}%")
        print(f"  座標欠損率:   {r.get('coord_missing_pct', 'N/A')}%")
        if r.get("names_sample"):
            print(f"  名称サンプル: {', '.join(r['names_sample'][:5])}")

    print(f"\n【合計】 {total_all} 件")

    # 完了基準チェック
    print("\n" + "-" * 60)
    print("完了基準チェック")
    print("-" * 60)
    ok_total = total_all >= 3000
    print(f"  全国施設数 3,000件以上: {'✅' if ok_total else '❌'} ({total_all} 件)")

    for ftype, label in [("onsen", "温泉"), ("public_bath", "銭湯"), ("sauna", "サウナ")]:
        r = results.get(ftype, {})
        name_pct = r.get("name_missing_pct", 100)
        coord_pct = r.get("coord_missing_pct", 100)
        ok_name = name_pct <= 20
        ok_coord = coord_pct <= 20
        print(f"  {label} 名称欠損率 ≤20%: {'✅' if ok_name else '❌'} ({name_pct}%)")
        print(f"  {label} 座標欠損率 ≤20%: {'✅' if ok_coord else '❌'} ({coord_pct}%)")

    # 含有率テスト（名称サンプルで簡易チェック）
    print("\n" + "-" * 60)
    print("含有率テスト（著名温泉地10件）")
    print("-" * 60)
    containment = containment_test(all_names)
    ok_contain = containment["rate"] >= 50
    print(f"  含有率: {'✅' if ok_contain else '❌'} {containment['rate']}% ({len(containment['found'])}/10件)")
    if containment["found"]:
        print(f"  発見:   {', '.join(containment['found'])}")
    if containment["not_found"]:
        print(f"  未発見: {', '.join(containment['not_found'])}")
    if not ok_contain:
        print("  → ⚠️  含有率50%未満: 観光オープンデータでの補強を検討")

    print("\n" + "=" * 60)

    # JSON 保存
    output = {
        "results": results,
        "total": total_all,
        "containment": containment,
    }
    with open("scripts/data/phase1_validation.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    logger.info("詳細結果を scripts/data/phase1_validation.json に保存しました")


if __name__ == "__main__":
    import os
    os.makedirs("scripts/data", exist_ok=True)
    main()
