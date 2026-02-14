# Heartbeat Checklist

Run these checks every 30 minutes during active hours:

## 1. Check for blocked workers

```bash
cd /home/yakob/yakthang && ./check-workers.sh --blocked
```

- If any blocked workers, report what's blocking them
- Suggest unblocking actions or respawn strategy

## 2. Check in-progress workers

```bash
cd /home/yakob/yakthang && ./check-workers.sh --wip
```

- Flag any tasks stuck in wip for >2 hours
- Review progress and suggest interventions if needed

## 3. Check task tree

```bash
cd /home/yakob/yakthang && yx ls
```

- Any high-priority unassigned tasks?
- Any tasks ready to spawn workers for?

## Response

If nothing needs attention, reply **HEARTBEAT_OK**.

If something needs attention, report it concisely and suggest actions.
