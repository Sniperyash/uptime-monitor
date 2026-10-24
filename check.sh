#!/bin/bash
# Checks HOST:PORT and pushes to ntfy when it goes down, every REMIND_SECS
# while down, and when it recovers. State is kept in state.txt.

STATE=state.txt
now=$(date +%s)

check() { timeout 5 bash -c "</dev/tcp/$1/$2" 2>/dev/null; }
fmt() { local s=$1; printf '%dh %dm' $((s / 3600)) $((s % 3600 / 60)); }
notify() {
  curl -s -m 10 -H "Title: RDP server - $1 (cloud check)" -H "Priority: $3" -H "Tags: $4" \
    -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null
}

# Retry twice before calling it down, to ignore brief network blips.
cur=DOWN
for attempt in 1 2 3; do
  if check "$HOST" "$PORT"; then cur=UP; break; fi
  sleep 15
done

prev=UP; since=$now; last_notify=0
[ -f "$STATE" ] && read -r prev since last_notify < "$STATE"

if [ "$cur" = DOWN ]; then
  if check "$PANEL" 443; then
    why="Provider panel is up, so the problem is the server itself (Windows/updates/firewall). Try Reboot in the client area."
  else
    why="Provider panel is also down, so it is a The Power Host network outage. Contact their support."
  fi
  if [ "$prev" != DOWN ]; then
    since=$now; last_notify=$now
    notify "DOWN" "$why" high rotating_light
  elif [ $((now - last_notify)) -ge "$REMIND_SECS" ]; then
    last_notify=$now
    notify "still DOWN for $(fmt $((now - since)))" "$why" high rotating_light
  fi
else
  if [ "$prev" = DOWN ]; then
    notify "Back UP" "RDP is reachable again after $(fmt $((now - since))) down." default white_check_mark
  fi
  since=$now; last_notify=0
fi

echo "Result: $cur"
echo "$cur $since $last_notify" > "$STATE"
