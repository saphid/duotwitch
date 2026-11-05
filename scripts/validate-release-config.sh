#!/bin/sh
set -eu
[ "${CONFIGURATION:-}" = Release ] || exit 0
/usr/bin/python3 - <<'PYTHON'
import os
import re
import sys
from urllib.parse import urlsplit

client = os.environ.get("TWITCH_CLIENT_ID", "").strip()
raw = os.environ.get("TWITCH_PLAYER_HOST", "").strip()
errors = []
if not re.fullmatch(r"[A-Za-z0-9]{10,}", client):
    errors.append("TWITCH_CLIENT_ID must contain the registered public Twitch client ID.")
try:
    url = urlsplit(raw)
    host = url.hostname or ""
    valid = (url.scheme == "https" and "." in host and url.port in (None, 443)
             and not url.username and not url.password and not url.query and not url.fragment
             and not host.endswith((".invalid", ".example", ".test", ".localhost"))
             and host not in ("localhost", "127.0.0.1", "player.twitch.tv")
             and "YOUR_" not in raw and not re.search(r"\s", raw))
except ValueError:
    valid = False
if not valid:
    errors.append("TWITCH_PLAYER_HOST must be your deployed HTTPS player page. In xcconfig, write https:/$()/host/path.")
for error in errors:
    print("error: " + error, file=sys.stderr)
sys.exit(1 if errors else 0)
PYTHON
