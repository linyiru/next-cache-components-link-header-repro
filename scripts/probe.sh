#!/usr/bin/env bash
# Requests / every 3s (the page revalidates after 2s) and counts how many
# copies of the next.config.js Link value each response carries.
# Expected: 1 on every request.
set -euo pipefail
PORT="${PORT:-3000}"
COUNT="${COUNT:-8}"
URL="http://localhost:${PORT}/"

for i in $(seq 1 "$COUNT"); do
  headers=$(curl -s -D - -o /dev/null "$URL")
  copies=$(printf '%s' "$headers" | grep -o 'rel="llms-txt"' | wc -l | tr -d ' ')
  cache=$(printf '%s' "$headers" | grep -i '^x-nextjs-cache' | tr -d '\r' || true)
  echo "request $i: llms-txt copies=$copies ${cache}"
  sleep 3
done

echo "--- Link header on the last response"
curl -s -D - -o /dev/null "$URL" | grep -i '^link' || true
