#!/bin/bash
# On-demand full check: tests the server and the provider, then always sends
# the report to ntfy and to the run summary.

VNC=103.49.131.249
PANEL=my.thepowerhost.in

port() { timeout 5 bash -c "</dev/tcp/$1/$2" 2>/dev/null; }
mark() { [ "$1" = 1 ] && echo "✅" || echo "❌"; }

# Retry RDP like the scheduled check, so a blip doesn't read as down.
rdp=0
for attempt in 1 2 3; do
  port "$HOST" 3389 && { rdp=1; break; }
  sleep 10
done
port "$HOST" 80 && web=1 || web=0
port "$PANEL" 443 && panel=1 || panel=0
port "$VNC" 5901 && vnc=1 || vnc=0

# Same test from a few other countries via check-host.net.
world=""
id=$(curl -s -m 15 -H "Accept: application/json" \
  "https://check-host.net/check-tcp?host=$HOST:3389&max_nodes=3" |
  python3 -I -c "import sys,json;print(json.load(sys.stdin)['request_id'])" 2>/dev/null)
if [ -n "$id" ]; then
  sleep 20
  world=$(curl -s -m 15 -H "Accept: application/json" "https://check-host.net/check-result/$id" |
    python3 -I -c '
import sys, json
out = []
for node, r in json.load(sys.stdin).items():
    place = node.split(".")[0].upper()
    ok = bool(r) and isinstance(r[0], dict) and "time" in r[0]
    out.append(f"{place} {chr(0x2705) if ok else chr(0x274C)}")
print("  ".join(out))
' 2>/dev/null)
fi

if [ $rdp = 1 ]; then
  title="Server UP"; prio=default; tag=white_check_mark
  verdict="RDP is reachable. If Windows App hangs on 'Configuring remote PC', clear stuck sessions via the VNC console (query session / logoff <ID>) or Reboot. If someone gets kicked out, two people share one Windows account."
elif [ $panel = 0 ] && [ $vnc = 0 ]; then
  title="PROVIDER OUTAGE"; prio=high; tag=rotating_light
  verdict="Server, client panel and VNC console are all down. Nothing to fix on your side; contact The Power Host via thepowerhost.in. Usually back in minutes."
elif [ $web = 0 ]; then
  title="SERVER DOWN"; prio=high; tag=rotating_light
  verdict="Provider is fine but the server answers nothing. Open the VNC console from the client area: updating -> wait; frozen/black -> Reboot."
else
  title="RDP BLOCKED"; prio=high; tag=warning
  verdict="Server is on (web answers) but RDP doesn't. Check Windows Firewall / Remote Desktop settings via the VNC console."
fi

body="RDP $(mark $rdp)  Web $(mark $web)  Panel $(mark $panel)  VNC $(mark $vnc)"
[ -n "$world" ] && body="$body
Other countries: $world"
body="$body

$verdict"

curl -s -m 10 -H "Title: $title (check now)" -H "Priority: $prio" -H "Tags: $tag" \
  -d "$body" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null

{ echo "## $title"; echo; echo "$body"; } >> "$GITHUB_STEP_SUMMARY"
echo "Result: $title"
