#!/usr/bin/env bash
# check-proxy.sh - check a CLIProxyAPI server from any client.
# Usage: PROXY_URL=http://<server>:8317 PROXY_KEY=<client-key> ./scripts/check-proxy.sh
# Checks: /healthz answers, /v1/models rejects a missing key, accepts PROXY_KEY.
# Exit 0 when every check passes, 1 when one fails, 2 on usage error.
# The key is never printed.
set -u

url="${PROXY_URL:-http://127.0.0.1:8317}"
url="${url%/}"
key="${PROXY_KEY:-}"
timeout="${PROXY_TIMEOUT:-5}"
[ -n "$key" ] || { echo "usage: PROXY_URL=<url> PROXY_KEY=<client-key> $0" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 2; }

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

code() { # code <path> [header]
  if [ -n "${2:-}" ]; then
    curl -s -o /dev/null -w '%{http_code}' -m "$timeout" -H "$2" "$url$1"
  else
    curl -s -o /dev/null -w '%{http_code}' -m "$timeout" "$url$1"
  fi
}

health="$(code /healthz)"
if [ "$health" = 200 ]; then pass "healthz: 200"
elif [ "$health" = 000 ]; then fail "healthz: no connection to $url (service down, wrong host/port, or firewall)"
else fail "healthz: HTTP $health"; fi

anon="$(code /v1/models)"
case "$anon" in
  401|403) pass "missing key rejected: HTTP $anon" ;;
  200) fail "missing key accepted: set access.api-keys before sharing this server" ;;
  *) fail "missing key check: HTTP $anon" ;;
esac

body="$(curl -s -m "$timeout" -w '\n%{http_code}' -H "Authorization: Bearer $key" "$url/v1/models")"
status="${body##*$'\n'}"
models="$(printf '%s' "${body%$'\n'*}" | grep -o '"id"[[:space:]]*:' | wc -l | tr -d ' ')"
if [ "$status" = 200 ]; then
  if [ "$models" -gt 0 ]; then pass "models with key: $models listed"
  else fail "models with key: list is empty (log in an account on the server; see docs section 6)"; fi
else
  fail "models with key: HTTP $status (check the key in access.api-keys)"
fi

[ "$fails" -eq 0 ] && { echo "ALL CHECKS PASSED ($url)"; exit 0; }
echo "$fails check(s) failed ($url)"
exit 1
