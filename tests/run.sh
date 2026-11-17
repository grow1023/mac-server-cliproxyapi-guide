#!/usr/bin/env bash
# tests/run.sh - repository checks. Exit 0 only when every check passes (fail-closed).
# Requires: bash, python3, curl. Uses shellcheck and ruby when installed.
set -u
cd "$(dirname "$0")/.." || exit 1
RC=0
ok()  { printf 'PASS[%s]\n' "$1"; }
bad() { printf 'FAIL[%s]: %s\n' "$1" "$2"; RC=1; }

# 1. Shell syntax and lint
for f in scripts/check-proxy.sh tests/run.sh gates/*.sh; do
  bash -n "$f" || bad syntax "$f"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning scripts/check-proxy.sh tests/run.sh gates/*.sh && ok shellcheck || bad shellcheck "warnings above"
else
  echo "SKIP[shellcheck]: not installed (CI installs it)"
fi
python3 -m py_compile tests/stub_server.py examples/clients/openai_client.py scripts/write-config.py && ok py_compile || bad py_compile "python syntax"

# 2. check-proxy.sh behavior against a local stub
TMP="$(mktemp -d)"; PIDS=""
cleanup() { { for p in $PIDS; do kill "$p"; done; wait; } 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
start_stub() { # start_stub <mode>; port is written to $TMP/<mode>.port
  # Run in this shell (not inside $(...)) and detach stdout, or the caller waits forever.
  python3 tests/stub_server.py "$1" "$TMP/$1.port" >/dev/null 2>&1 &
  PIDS="$PIDS $!"
  for _ in $(seq 50); do [ -s "$TMP/$1.port" ] && return 0; sleep 0.1; done
  bad stub "stub server '$1' did not start"
}
expect() { # expect <name> <rc> <needle> <url> <key>
  out="$(PROXY_URL="$4" PROXY_KEY="$5" PROXY_TIMEOUT=2 bash scripts/check-proxy.sh 2>&1)"; rc=$?
  if [ "$rc" -ne "$2" ]; then bad "check-proxy.$1" "exit $rc, expected $2: $out"; return; fi
  case "$out" in *"$3"*) ;; *) bad "check-proxy.$1" "missing '$3' in: $out"; return;; esac
  case "$out" in *"$5"*) bad "check-proxy.$1" "key printed in output"; return;; esac
  ok "check-proxy.$1"
}
KEY=test-key-not-secret
start_stub good; start_stub open; start_stub empty
p_good="$(cat "$TMP/good.port")"; p_open="$(cat "$TMP/open.port")"; p_empty="$(cat "$TMP/empty.port")"
expect good 0 "models with key: 2 listed" "http://127.0.0.1:$p_good/" "$KEY"
expect wrong-key 1 "check the key" "http://127.0.0.1:$p_good" "wrong-key-value"
expect open 1 "missing key accepted" "http://127.0.0.1:$p_open" "$KEY"
expect empty 1 "list is empty" "http://127.0.0.1:$p_empty" "$KEY"
expect down 1 "no connection" "http://127.0.0.1:9" "$KEY"
PROXY_KEY="" bash scripts/check-proxy.sh >/dev/null 2>&1; [ $? -eq 2 ] && ok check-proxy.usage || bad check-proxy.usage "missing key must exit 2"

# 3. Example configuration parses and keeps the safe defaults
python3 - <<'PY' || bad config "examples/config.server.yaml"
import json, subprocess, sys, shutil
path = "examples/config.server.yaml"
if shutil.which("ruby"):
    raw = subprocess.run(["ruby", "-ryaml", "-rjson", "-e", "puts YAML.safe_load(File.read(ARGV[0])).to_json", path],
                         capture_output=True, check=True).stdout
    cfg = json.loads(raw)
else:
    import yaml  # noqa: PLC0415 - fallback when ruby is absent
    cfg = yaml.safe_load(open(path))
assert cfg["config-version"] == 8
assert cfg["server"]["port"] == 8317
assert cfg["management"]["allow-remote"] is False
assert cfg["management"]["secret-key"] == ""
keys = cfg["access"]["api-keys"]
assert keys and all(k.startswith("<") and k.endswith(">") for k in keys), "examples must use placeholders only"
print("PASS[config]")
PY

# 3b. Agent handoff: write-config.py fills keys without printing them; CLAUDE.md and READMEs point to AGENTS.md
KD="$TMP/keys"; mkdir -p "$KD"
printf '%064d\n' 1 | tr 0 a > "$KD/client-1.key"; printf '%064d\n' 2 | tr 0 b > "$KD/client-2.key"
k1="$(tr -d '\n' < "$KD/client-1.key")"; k2="$(tr -d '\n' < "$KD/client-2.key")"
out="$(python3 scripts/write-config.py examples/config.server.yaml "$TMP/out.conf" 127.0.0.1 "$KD" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then bad write-config "exit $rc: $out"
elif case "$out" in *"$k1"*|*"$k2"*) true;; *) false;; esac; then bad write-config "key printed"
elif grep -q '<client-' "$TMP/out.conf" || ! grep -q "$k1" "$TMP/out.conf" || ! grep -q '^  host: "127.0.0.1"' "$TMP/out.conf"; then bad write-config "placeholders or host not replaced"
elif [ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$TMP/out.conf")" != 600 ]; then bad write-config "config mode is not 600"
else ok write-config; fi
python3 scripts/write-config.py examples/config.server.yaml "$TMP/x.conf" 0.0.0.0 "$KD" >/dev/null 2>&1; [ $? -eq 2 ] && ok write-config.host || bad write-config.host "public host must exit 2"
rm "$KD/client-2.key"
python3 scripts/write-config.py examples/config.server.yaml "$TMP/y.conf" "" "$KD" >/dev/null 2>&1; [ $? -eq 1 ] && [ ! -e "$TMP/y.conf" ] && ok write-config.missing || bad write-config.missing "missing key must exit 1 without writing"
[ "$(cat CLAUDE.md)" = "@AGENTS.md" ] && ok handoff.claude || bad handoff.claude "CLAUDE.md must import AGENTS.md"
for r in README*.md; do grep -q '](AGENTS.md)' "$r" && grep -q 'codex' "$r" && grep -q 'claude' "$r" || bad handoff.readme "$r lacks the agent handoff section"; done

# 4. Documentation: local links, en/ko parity, flags match upstream
python3 - <<'PY' || RC=1
import pathlib, re, sys
root = pathlib.Path(".")
docs = sorted(root.glob("README*.md")) + sorted(root.glob("docs/*.md")) + [root / "AGENTS.md"]
errors = []
for doc in docs:
    for target in re.findall(r"\]\(([^)#\s]+)(?:#[^)]*)?\)", doc.read_text()):
        if re.match(r"[a-z]+:", target):
            continue
        if not (doc.parent / target).resolve().exists():
            errors.append(f"{doc}: broken local link {target}")
en, ko = (root / "docs/guide.md").read_text(), (root / "docs/guide.ko.md").read_text()
h_en, h_ko = re.findall(r"^## ", en, re.M), re.findall(r"^## ", ko, re.M)
if len(h_en) != len(h_ko):
    errors.append(f"guide heading count differs: en={len(h_en)} ko={len(h_ko)}")
blocks = lambda t: re.findall(r"```(?:sh|toml|yaml)\n(.*?)```", t, re.S)
code = lambda line: re.split(r"\s#\s", line)[0].strip()  # drop the localized trailing comment
cmds = lambda t: {code(l) for b in blocks(t) for l in b.splitlines()
                  if code(l) and not l.lstrip().startswith("#") and not re.search(r"[<가-힣]", code(l))}
if cmds(en) != cmds(ko):
    errors.append(f"guide commands differ: only en={sorted(cmds(en)-cmds(ko))[:3]} only ko={sorted(cmds(ko)-cmds(en))[:3]}")
known = {l.strip() for l in open("tests/upstream_flags.txt") if l.strip() and not l.startswith("#")}
for doc in docs:
    for flag in re.findall(r"(?:cliproxyapi|cli-proxy-api)\s+-([a-z-]+)", doc.read_text()):
        if flag not in known:
            errors.append(f"{doc}: flag -{flag} not in tests/upstream_flags.txt")
    for flag in re.findall(r"`-([a-z]+(?:-[a-z]+)+)`", doc.read_text()):
        if flag.endswith("login") and flag not in known:
            errors.append(f"{doc}: flag -{flag} not in tests/upstream_flags.txt")
for e in errors:
    print(f"FAIL[docs]: {e}")
if errors:
    sys.exit(1)
print(f"PASS[docs]: {len(docs)} files, links, en/ko parity, upstream flags")
PY

# 5. Privacy: no machine paths, real-looking addresses or e-mail in tracked text
python3 - <<'PY' || RC=1
import pathlib, re, subprocess, sys
files = subprocess.run(["git", "ls-files"], capture_output=True).stdout.decode().split() or \
        [str(p) for p in pathlib.Path(".").rglob("*") if p.is_file() and ".git/" not in str(p)]
allowed_ips = {"127.0.0.1", "192.168.0.10", "192.0.2.0", "0.0.0.0", "224.0.0.251"}
errors = []
for name in files:
    path = pathlib.Path(name)
    if path.suffix.lower() in {".png", ".jpg", ".gif"} or not path.is_file():
        continue
    text = path.read_text(errors="replace")
    for ip in re.findall(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", text):
        if ip not in allowed_ips and not ip.startswith("0."):
            errors.append(f"{name}: unexpected IP address {ip}")
    if re.search(r"/Users/[A-Za-z0-9._-]+/|/home/[a-z0-9._-]+/", text):
        errors.append(f"{name}: machine-specific home path")
    for mail in re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", text):
        if not mail.endswith(("@example.com", "@users.noreply.github.com")):
            errors.append(f"{name}: e-mail address {mail}")
for e in errors:
    print(f"FAIL[privacy]: {e}")
if errors:
    sys.exit(1)
print(f"PASS[privacy]: {len(files)} files")
PY

[ "$RC" -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit "$RC"
