#!/usr/bin/env python3
"""Cross-language research summarizer CLI.

This tool reads web research results (JSON or CSV), analyzes each source via
OpenAI Chat Completions, performs cross-source comparisons, and writes a
bilingual Markdown report.
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import time
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List

from openai import OpenAI, OpenAIError


MODEL_NAME = "gpt-4.1"
RATE_LIMIT_DELAY = 1.0
MAX_RETRIES = 2

logger = logging.getLogger(__name__)
client = OpenAI()


@dataclass
class AnalysisResult:
    record: Dict[str, Any]
    short_summary_en: str
    short_summary_ja: str
    quality_score: int
    evidence_type: str
    notes: str
    key_points: List[str]
    potential_bias: str

    @classmethod
    def fallback(cls, record: Dict[str, Any], message: str) -> "AnalysisResult":
        return cls(
            record=record,
            short_summary_en="Summary unavailable due to parsing error.",
            short_summary_ja="解析エラーのため要約を利用できません。",
            quality_score=1,
            evidence_type="tertiary",
            notes=message,
            key_points=["Insufficient data"],
            potential_bias="Unknown due to error",
        )

    def to_dict(self) -> Dict[str, Any]:
        base = dict(self.record)
        base.update(
            {
                "short_summary_en": self.short_summary_en,
                "short_summary_ja": self.short_summary_ja,
                "quality_score": self.quality_score,
                "evidence_type": self.evidence_type,
                "notes": self.notes,
                "key_points": self.key_points,
                "potential_bias": self.potential_bias,
            }
        )
        return base


def load_data(path: str, fmt: str) -> List[Dict[str, Any]]:
    if fmt not in {"json", "csv"}:
        raise ValueError("Unsupported format; choose 'json' or 'csv'.")
    try:
        if fmt == "json":
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if not isinstance(data, list):
                    raise ValueError("JSON input must be a list of objects")
                return [dict(item) for item in data]
        else:
            with open(path, newline="", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                return [dict(row) for row in reader]
    except FileNotFoundError as exc:
        logger.error("Input file not found: %s", path)
        raise SystemExit(1) from exc
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to read input: %s", exc)
        raise SystemExit(1) from exc


def call_openai_chat(system_prompt: str, user_prompt: str) -> str:
    try:
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.3,
        )
        return response.choices[0].message.content or ""
    except OpenAIError as exc:
        logger.error("OpenAI API error: %s", exc)
        raise


def analyze_source(record: Dict[str, Any]) -> AnalysisResult:
    topic = record.get("topic", "(unknown topic)")
    language = record.get("language", "")
    title = record.get("title", "")
    url = record.get("url", "")
    snippet = record.get("snippet", "")

    system_prompt = (
        "You are a multilingual research analyst. Summarize web sources concisely "
        "and return ONLY valid JSON."
    )
    user_prompt = f"""
Topic: {topic}
Language: {language}
Title: {title}
URL: {url}
Snippet: {snippet}

Return a JSON object with keys: short_summary_en (2-3 English sentences),
short_summary_ja (2-3 Japanese sentences), quality_score (integer 1-5),
evidence_type (primary|secondary|tertiary), notes (English rationale),
key_points (3-7 English bullet points as strings), potential_bias (short English note).
"""

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            content = call_openai_chat(system_prompt, user_prompt)
            parsed = json.loads(content)
            return AnalysisResult(
                record=record,
                short_summary_en=str(parsed.get("short_summary_en", "")),
                short_summary_ja=str(parsed.get("short_summary_ja", "")),
                quality_score=int(parsed.get("quality_score", 1)),
                evidence_type=str(parsed.get("evidence_type", "tertiary")),
                notes=str(parsed.get("notes", "")),
                key_points=[str(p) for p in parsed.get("key_points", [])][:7],
                potential_bias=str(parsed.get("potential_bias", "")),
            )
        except (json.JSONDecodeError, TypeError) as exc:
            logger.warning("JSON parse error (attempt %s): %s", attempt, exc)
            user_prompt += "\nReturn ONLY JSON."
            if attempt >= MAX_RETRIES:
                return AnalysisResult.fallback(record, f"Parse failure: {exc}")
        except OpenAIError as exc:
            logger.error("OpenAI API error during analysis: %s", exc)
            if attempt >= MAX_RETRIES:
                return AnalysisResult.fallback(record, f"API failure: {exc}")
        finally:
            time.sleep(RATE_LIMIT_DELAY)
    return AnalysisResult.fallback(record, "Unknown error")


def analyze_all(records: List[Dict[str, Any]]) -> List[AnalysisResult]:
    analyses: List[AnalysisResult] = []
    for record in records:
        try:
            analysis = analyze_source(record)
            analyses.append(analysis)
        except Exception as exc:  # noqa: BLE001
            logger.error("Unexpected error analyzing record: %s", exc)
            analyses.append(AnalysisResult.fallback(record, f"Unexpected error: {exc}"))
    return analyses


def summarize_sources_for_prompt(analyses: List[AnalysisResult]) -> str:
    lines = []
    for a in analyses:
        title = a.record.get("title", "")
        lang = a.record.get("language", "")
        url = a.record.get("url", "")
        lines.append(
            f"- [{lang}] {title} ({url}) | score={a.quality_score} | key_points={'; '.join(a.key_points)}"
        )
    return "\n".join(lines)


def compare_sources(analyses: List[AnalysisResult]) -> Dict[str, Any]:
    if not analyses:
        return {
            "global_summary_en": "No analyses available.",
            "global_summary_ja": "分析結果がありません。",
            "agreements": [],
            "disagreements": [],
            "recommendations_en": [],
            "recommendations_ja": [],
            "top_overall": [],
            "top_by_language": {},
        }

    sorted_by_quality = sorted(analyses, key=lambda a: a.quality_score, reverse=True)
    top_overall = sorted_by_quality[:3]

    top_by_language: Dict[str, List[AnalysisResult]] = {}
    for analysis in sorted_by_quality:
        lang = analysis.record.get("language", "")
        lang_list = top_by_language.setdefault(lang, [])
        if len(lang_list) < 2:
            lang_list.append(analysis)

    summary_text = summarize_sources_for_prompt(analyses)
    system_prompt = (
        "You are a cross-language research synthesizer. Compare findings across sources "
        "and return structured JSON only."
    )
    user_prompt = f"""
Sources:
{summary_text}

Provide JSON with keys:
- global_summary_en (concise English synthesis)
- global_summary_ja (concise Japanese synthesis)
- agreements (list of main agreements)
- disagreements (list of main conflicts or gaps)
- recommendations_en (list of actionable recommendations in English)
- recommendations_ja (list of actionable recommendations in Japanese)
"""

    comparison: Dict[str, Any]
    try:
        content = call_openai_chat(system_prompt, user_prompt)
        comparison = json.loads(content)
    except Exception as exc:  # noqa: BLE001
        logger.error("Comparison synthesis failed: %s", exc)
        comparison = {
            "global_summary_en": "Synthesis unavailable due to error.",
            "global_summary_ja": "エラーのため統合要約を利用できません。",
            "agreements": [],
            "disagreements": [],
            "recommendations_en": [],
            "recommendations_ja": [],
        }

    comparison["top_overall"] = [a.to_dict() for a in top_overall]
    comparison["top_by_language"] = {
        lang: [a.to_dict() for a in entries] for lang, entries in top_by_language.items()
    }
    return comparison


def generate_markdown_report(
    topic: str, records: List[Dict[str, Any]], analyses: List[AnalysisResult], comparison: Dict[str, Any]
) -> str:
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    languages = sorted({rec.get("language", "") for rec in records if rec.get("language")})

    lines: List[str] = []
    lines.append(f"# Research Summary for: {topic}")
    lines.append("")
    lines.append(f"- Generated at: {now}")
    lines.append(f"- Sources analyzed: {len(records)}")
    lines.append(f"- Languages: {', '.join(languages)}")
    lines.append("")

    lines.append("## Global Summary (English)")
    lines.append(comparison.get("global_summary_en", ""))
    lines.append("")

    lines.append("## グローバル要約（日本語）")
    lines.append(comparison.get("global_summary_ja", ""))
    lines.append("")

    lines.append("## Best Sources")
    for entry in comparison.get("top_overall", []):
        lines.append(
            f"- {entry.get('title', '')} [{entry.get('language', '')}] (score: {entry.get('quality_score', '')}) - {entry.get('url', '')}"
        )
    lines.append("")

    lines.append("## Per-Source Details")
    for analysis in analyses:
        rec = analysis.record
        lines.append(f"### {rec.get('title', '(no title)')} [{rec.get('language', '')}]")
        lines.append(f"- URL: {rec.get('url', '')}")
        lines.append(f"- Rank: {rec.get('rank', '')}")
        lines.append(f"- Quality Score: {analysis.quality_score}")
        lines.append(f"- Evidence Type: {analysis.evidence_type}")
        lines.append(f"- Potential Bias: {analysis.potential_bias}")
        lines.append("- Key Points:")
        for point in analysis.key_points:
            lines.append(f"  - {point}")
        lines.append(f"- Short Summary (EN): {analysis.short_summary_en}")
        lines.append(f"- Short Summary (JA): {analysis.short_summary_ja}")
        lines.append(f"- Notes: {analysis.notes}")
        lines.append("")

    lines.append("## Cross-Source Comparison")
    lines.append("### Agreements")
    for agreement in comparison.get("agreements", []):
        lines.append(f"- {agreement}")
    if not comparison.get("agreements"):
        lines.append("- None identified.")
    lines.append("")

    lines.append("### Disagreements / Conflicting Claims")
    for disagreement in comparison.get("disagreements", []):
        lines.append(f"- {disagreement}")
    if not comparison.get("disagreements"):
        lines.append("- None identified.")
    lines.append("")

    lines.append("## Actionable Recommendations / 推奨アクション")
    lines.append("### English")
    for rec_en in comparison.get("recommendations_en", []):
        lines.append(f"- {rec_en}")
    if not comparison.get("recommendations_en"):
        lines.append("- No recommendations available.")
    lines.append("")

    lines.append("### 日本語")
    for rec_ja in comparison.get("recommendations_ja", []):
        lines.append(f"- {rec_ja}")
    if not comparison.get("recommendations_ja"):
        lines.append("- 推奨事項がありません。")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    parser = argparse.ArgumentParser(description="Summarize cross-language web research results.")
    parser.add_argument("--input", required=True, help="Path to JSON or CSV input file from n8n.")
    parser.add_argument("--format", required=True, choices=["json", "csv"], help="Input format.")
    parser.add_argument("--output", required=True, help="Path to output Markdown report.")
    args = parser.parse_args()

    if not os.getenv("OPENAI_API_KEY"):
        logger.error("OPENAI_API_KEY environment variable is not set.")
        raise SystemExit(1)

    records = load_data(args.input, args.format)
    if not records:
        logger.error("No records found in input.")
        raise SystemExit(1)

    topic = records[0].get("topic", "(unknown topic)")
    logger.info("Starting analysis for topic: %s", topic)
    logger.info("Total records: %d", len(records))

    analyses = analyze_all(records)
    comparison = compare_sources(analyses)

    report = generate_markdown_report(topic, records, analyses, comparison)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(report)

    logger.info("Report written to %s", args.output)


if __name__ == "__main__":
    main()

"""
README
------
Dependencies: openai>=1.0.0 (install via `pip install openai`).

Example usage:
python research_summary.py --input results.json --format json --output report.md
python research_summary.py --input results.csv --format csv --output report.md
"""
