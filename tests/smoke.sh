#!/usr/bin/env bash
# Smoke-тест запущенного стенда: проверяет требования тестового задания
set -uo pipefail

HOST="${TARGET_HOST:-localhost}"
HEALTH_PATH="${HEALTH_PATH:-/healthz}"
fail=0

check() {
  # $1 — название проверки, $2 — ожидаемый код, $3 — фактический
  if [ "$2" = "$3" ]; then
    echo "OK   $1: $3"
  else
    echo "FAIL $1: ожидалось $2, получено $3"
    fail=1
  fi
}

code=$(curl -s -o /dev/null -w '%{http_code}' "http://$HOST/")
check "редирект HTTP -> HTTPS" 301 "$code"

code=$(curl -sk -o /dev/null -w '%{http_code}' "https://$HOST$HEALTH_PATH")
check "health через nginx" 200 "$code"

# Тело 11 МБ при лимите 10 МБ
code=$(head -c 11000000 /dev/zero | curl -sk -o /dev/null -w '%{http_code}' -X POST --data-binary @- "https://$HOST/")
check "лимит тела запроса" 413 "$code"

# 100 запросов в 20 потоков: при лимите 10 r/s часть должна отклоняться
codes=$(seq 1 100 | xargs -P 20 -I{} curl -sk -o /dev/null -w '%{http_code}\n' "https://$HOST/" | sort | uniq -c)
echo "$codes"
if echo "$codes" | grep -qE ' (429|503)$'; then
  echo "OK   rate limiting срабатывает"
else
  echo "FAIL rate limiting: нет ответов 429/503"
  fail=1
fi

exit "$fail"
