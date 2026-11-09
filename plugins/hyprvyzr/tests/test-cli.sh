#!/bin/bash
# Checks hyprvyzr's own logic in a throwaway home, against a fake Kasm API on
# 127.0.0.1. Nothing outside the temp folder changes: no keyring, no
# Hyprland, no Docker containers, no windows.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
t=$(mktemp -d); trap 'kill $srv 2>/dev/null || true; rm -rf "$t"' EXIT
export HOME=$t XDG_CONFIG_HOME=$t/config XDG_STATE_HOME=$t/state XDG_DATA_HOME=$t/data XDG_CACHE_HOME=$t/cache \
  XDG_RUNTIME_DIR=$t/run HYPRVYZR_NO_KEYRING=1
mkdir -p "$t/bin"
# Stand-ins: no windows, no compositor, no Docker images.
printf '#!/bin/sh\nexit 0\n' >"$t/bin/notify-send"
printf '#!/bin/sh\n[ "$1" = clients ] && echo "[]"; [ "$1" = activeworkspace ] && echo "{\\"id\\":1}"; exit 0\n' >"$t/bin/hyprctl"
printf '#!/bin/sh\n[ "$1" = images ] && printf "kasmweb/terminal\\t1.18.0\\nother/x\\tlatest\\n"; exit 0\n' >"$t/bin/docker"
printf '#!/bin/sh\nexec sleep 30\n' >"$t/bin/omacraft"
chmod +x "$t/bin/"*
export PATH="$t/bin:/usr/bin:/bin"
hv() { python3 -I "$here/bin/hyprvyzr" "$@"; }
pass=0; fail=0
ok() { echo "ok   $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# A fake Kasm on loopback TLS (self-signed), answering the Developer API.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$t/k.pem" -out "$t/c.pem" -days 1 -subj /CN=localhost 2>/dev/null
port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
cat >"$t/kasm.py" <<'PY'
import json, ssl, sys, http.server
calls = []
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        body = b"\x89PNG\r\n\x1a\nfake"
        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        m = self.path.rsplit("/", 1)[-1]
        if req.get("api_key") != "KEY" or req.get("api_key_secret") != "SECRET":
            res = {"error_message": "Invalid API key"}
        elif m == "get_images":
            res = {"images": [{"image_id": "img1", "friendly_name": "Kasm Chrome", "name": "kasmweb/chrome:1.19.0",
                               "description": "Chrome", "image_src": "img/thumbnails/chrome.png", "enabled": True},
                              {"image_id": "img2", "friendly_name": "Off", "enabled": False}]}
        elif m == "get_user":
            res = {"user": {"user_id": "u1", "username": req["target_user"]["username"]}}
        elif m == "request_kasm":
            res = {"kasm_id": "k1", "user_id": req["user_id"], "status": "Starting", "kasm_url": "/#/connect/kasm/k1/u1/tok"}
        elif m == "get_kasm_status":
            res = {"kasm_url": "/#/connect/kasm/k1/u1/tok2", "kasm": {"operational_status": "running"}}
        elif m == "destroy_kasm":
            res = {}; open(sys.argv[3], "a").write("destroyed\n")
        else:
            res = {"error_message": "unknown"}
        body = json.dumps(res).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
srv = http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(sys.argv[2] + "/c.pem", sys.argv[2] + "/k.pem")
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PY
python3 "$t/kasm.py" "$port" "$t" "$t/destroyed" & srv=$!
for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$port) 2>/dev/null && break; sleep 0.1; done

check "rejects http addresses" "! hv server add --name X --url http://example.com --user u </dev/null 2>/dev/null"
check "rejects a path after the host" "! hv server add --name X --url https://example.com/x --user u </dev/null 2>/dev/null"
check "refuses --insecure off this machine" "! echo '{\"api_key\":\"a\",\"api_key_secret\":\"b\"}' | hv server add --name X --url https://example.com --user u --insecure 2>/dev/null"
check "needs key and secret" "! echo '{\"api_key\":\"a\"}' | hv server add --name X --url https://example.com --user u 2>/dev/null"
echo '{"api_key":"KEY","api_key_secret":"SECRET"}' | hv server add --name "Home Lab" --url "https://localhost:$port" --user me --kind local --insecure >/dev/null
check "server saved without its key" "grep -q home-lab '$t/config/hyprvyzr/hyprvyzr.json' && ! grep -q SECRET '$t/config/hyprvyzr/hyprvyzr.json'"
check "settings are private" "[ \"\$(stat -c %a '$t/config/hyprvyzr/hyprvyzr.json')\" = 600 ] && [ \"\$(stat -c %a '$t/config/hyprvyzr')\" = 700 ]"
check "key kept in a 0600 file without a keyring" "[ \"\$(stat -c %a '$t/data/hyprvyzr/secrets.json')\" = 600 ]"
check "server test" "hv --json server test home-lab | grep -q '\"images\": 2'"
ws=$(hv --json workspaces --refresh)
check "lists the enabled workspaces only" "echo '$ws' | grep -q 'home-lab:img1' && ! echo '$ws' | grep -q 'home-lab:img2'"
check "caches the thumbnail" "ls '$t/cache/hyprvyzr/thumbs/' | grep -q chrome.png"
check "lists native images, installed ones marked" "echo '$ws' | python3 -c 'import json,sys; w={x[\"key\"]:x for x in json.load(sys.stdin)[\"workspaces\"]}; assert w[\"native:terminal\"][\"installed\"] and w[\"native:terminal\"][\"image\"].endswith(\":1.18.0\") and not w[\"native:chrome\"][\"installed\"]'"
hv --json launch home-lab:img1 >"$t/launch.json"
check "launch joins with the status call's fresh link" "grep -q 'tok2' $t/run/hyprvyzr/*.json"
check "the link file is private" "[ \"\$(stat -c %a $t/run/hyprvyzr/*.json)\" = 600 ]"
id=$(python3 -c "import json;print(json.load(open('$t/launch.json'))['id'])")
check "the session is listed" "hv --json sessions | grep -q '$id'"
hv end "$id"
check "end destroys the Kasm session" "grep -q destroyed '$t/destroyed'"
check "and forgets it" "! hv --json sessions | grep -q '$id'"
check "rejects a bad key" "! hv launch 'native:../etc' 2>/dev/null"
check "unknown server" "! hv launch nowhere:x 2>/dev/null"
echo '{"api_key":"bad","api_key_secret":"bad"}' | hv server add --name Wrong --url "https://localhost:$port" --user me --insecure >/dev/null
hv server test wrong >"$t/wrong.txt" 2>&1 || true; cat "$t/wrong.txt"
check "a wrong key says so" "grep -q 'Invalid API key' '$t/wrong.txt'"
hv server remove wrong >/dev/null
check "removing drops the key too" "! grep -q wrong '$t/data/hyprvyzr/secrets.json'"
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
