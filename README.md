# Uptime monitor

GitHub Actions checks a server's port about every 5 minutes and sends a push
notification through [ntfy](https://ntfy.sh) when it goes down, every 15 minutes
while it stays down, and when it comes back.

The server address and ntfy topic are repository secrets (`MON_HOST`, `NTFY_TOPIC`),
so they are not visible in this repo or its logs.

- Run a check now: Actions → Uptime check → Run workflow
- Pause: Actions → Uptime check → ⋯ → Disable workflow
