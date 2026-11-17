"""Write a CLIProxyAPI config from the example, filling key placeholders from key files.

Usage: python3 scripts/write-config.py <example.yaml> <destination> <host> [key-dir]
Keys are read from <key-dir>/client-<n>.key (default ~/.config/cliproxyapi) and never printed.
"""
import pathlib
import re
import sys


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    src, dst, host = sys.argv[1:4]
    if host not in ("", "127.0.0.1"):
        print('host must be "" or "127.0.0.1"', file=sys.stderr)
        return 2
    key_dir = pathlib.Path(sys.argv[4] if len(sys.argv) == 5 else pathlib.Path.home() / ".config/cliproxyapi")
    text = pathlib.Path(src).read_text()
    for n in re.findall(r"<client-(\d+)-key>", text):
        key_file = key_dir / f"client-{n}.key"
        if not key_file.is_file():
            print(f"missing key file: {key_file}", file=sys.stderr)
            return 1
        key = key_file.read_text().strip()
        if not re.fullmatch(r"[0-9a-f]{32,}", key):
            print(f"key file is not a hex key: {key_file}", file=sys.stderr)
            return 1
        text = text.replace(f"<client-{n}-key>", key)
    text = re.sub(r'^(  host: )".*?"', rf'\1"{host}"', text, count=1, flags=re.M)
    out = pathlib.Path(dst)
    out.write_text(text)
    out.chmod(0o600)
    print(f"wrote {out} (host={host or 'all interfaces'}, keys from {key_dir})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
