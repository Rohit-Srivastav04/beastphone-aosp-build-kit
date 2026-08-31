#!/usr/bin/env python3
"""Restore rclone gdrive config from rclone-auth.txt (OAuth token JSON)."""
import json
import os
import pathlib
import re
import subprocess
import sys

kit = pathlib.Path(os.environ.get("BEASTPHONE_KIT", os.path.expanduser("~/beastphone-build")))
auth = kit / "rclone-auth.txt"
if not auth.exists():
    print(f"Missing {auth} — copy rclone-auth.txt.example and fill OAuth token", file=sys.stderr)
    sys.exit(1)

text = auth.read_text()
m = re.search(r"\{.*\}", text, re.S)
if not m:
    print("no token json in rclone-auth.txt", file=sys.stderr)
    sys.exit(1)
token = json.loads(m.group(0))
if "access_token" not in token or "refresh_token" not in token:
    print("incomplete token", file=sys.stderr)
    sys.exit(1)

cfg = pathlib.Path.home() / ".config/rclone/rclone.conf"
cfg.parent.mkdir(parents=True, exist_ok=True)
token_line = json.dumps(token, separators=(",", ":"))
cfg.write_text(
    "[gdrive]\n"
    "type = drive\n"
    "scope = drive\n"
    f"token = {token_line}\n"
)
cfg.chmod(0o600)
print("config_written ok")
r = subprocess.run(["rclone", "about", "gdrive:"], capture_output=True, text=True)
print(r.stdout or r.stderr)
