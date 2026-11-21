#!/bin/bash
# Web mining service entrypoint.
# Runs the RSS pipeline for the configured countries + date window.
# Runs once then exits (use Railway cron or the automine service for scheduling).
#
# Required env:
#   MINING_COUNTRIES    — comma-separated, e.g. "Nigeria,Ghana,Kenya"
#   MINING_OUTPUT_DIR   — where to write .txt articles (default: /data/web_news_rss)
#
# Optional:
#   MINING_START_YEAR / MINING_START_DATE — time window (default: current year)
#   MINING_END_YEAR   / MINING_END_DATE
#   MINING_MAX_URLS_PER_COUNTRY  — cap per country (default: 500)
#   MINING_BATCH_SIZE            — pipeline batch size (default: 100)
#   MINING_FEEDS_PATH            — path to feeds.json (default: ml/web_data_mining/config/feeds.json)
#   MINING_GOOGLE_DAILY_SLICE    — "1" to enable Google News daily slicing
#   TAVILY_API_KEY               — if set, enables --tavily-enrich
#   SEARXNG_URL                  — if set, used as self-hosted search backend

set -euo pipefail

COUNTRIES="${MINING_COUNTRIES:?Set MINING_COUNTRIES, e.g. Nigeria,Ghana,Kenya}"
OUTPUT_DIR="${MINING_OUTPUT_DIR:-/data/web_news_rss}"
MAX_URLS="${MINING_MAX_URLS_PER_COUNTRY:-500}"
BATCH_SIZE="${MINING_BATCH_SIZE:-100}"

# Default to current year if no window specified
CURRENT_YEAR=$(date +%Y)
START_YEAR="${MINING_START_YEAR:-$CURRENT_YEAR}"
END_YEAR="${MINING_END_YEAR:-$CURRENT_YEAR}"

echo "=== Web Mining Service ==="
echo "Countries: $COUNTRIES"
echo "Window:    $START_YEAR – $END_YEAR"
echo "Output:    $OUTPUT_DIR"
echo "=========================="

mkdir -p "$OUTPUT_DIR"

ARGS=(
    "--countries" "$COUNTRIES"
    "--start-year" "$START_YEAR"
    "--end-year" "$END_YEAR"
    "--max-urls-per-country" "$MAX_URLS"
    "--batch-size" "$BATCH_SIZE"
    "--output-dir" "$OUTPUT_DIR"
)

if [ -n "${MINING_FEEDS_PATH:-}" ]; then
    ARGS+=("--feeds" "$MINING_FEEDS_PATH")
fi

if [ "${MINING_GOOGLE_DAILY_SLICE:-0}" = "1" ]; then
    ARGS+=("--google-news-daily-slice")
fi

if [ -n "${MINING_START_DATE:-}" ] && [ -n "${MINING_END_DATE:-}" ]; then
    # Date-based window overrides year-based
    ARGS=()
    ARGS+=("--countries" "$COUNTRIES")
    ARGS+=("--start-date" "$MINING_START_DATE")
    ARGS+=("--end-date" "$MINING_END_DATE")
    ARGS+=("--max-urls-per-country" "$MAX_URLS")
    ARGS+=("--batch-size" "$BATCH_SIZE")
    ARGS+=("--output-dir" "$OUTPUT_DIR")
    if [ -n "${MINING_FEEDS_PATH:-}" ]; then ARGS+=("--feeds" "$MINING_FEEDS_PATH"); fi
    if [ "${MINING_GOOGLE_DAILY_SLICE:-0}" = "1" ]; then ARGS+=("--google-news-daily-slice"); fi
fi

if [ -n "${TAVILY_API_KEY:-}" ]; then
    echo "✓ Tavily enrichment enabled"
    ARGS+=("--tavily-enrich")
fi

exec python -m ml.web_data_mining.run_pipeline "${ARGS[@]}"
