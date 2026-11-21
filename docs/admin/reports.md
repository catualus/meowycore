# Reports and sits

Players report people or problems; staff work through a shared queue and can pull everyone into a sit.

## For players

- `!report` (or `!calladmin`, or a key bound to `madmin_report`) opens the form: what it's about (a player, something else, a bug), which player, and what happened.
- `!myreports` shows their open reports, who's handling them, and a chat thread with that staff member.
- When a report is closed they see the staff member's note and can rate the help from 1 to 5.

Limits: one report per 60 seconds and 3 open reports per player (both adjustable).

## For staff

Staff with `meowycore.admin.reports.handle` get:

- a notification and sound for every new report, a reminder when reports have waited 10 minutes, and a "reports waiting" message when they join;
- the open count at the top of the screen and on the menu's **Reports** tab.

In the Reports tab:

| Filter | Shows |
|---|---|
| Open | Unclaimed reports |
| Mine | Reports you're handling |
| Active | Open and claimed |
| Closed | History, searchable, with notes and ratings |

On a report:

- **Claim**: it's yours. Only one staff member can claim a report. By default you're teleported to the reporter (`!return` takes you back).
- **Reply**: message the reporter; their replies show up live.
- **Release**: back to the queue.
- **Close**: with an optional note the reporter sees.
- **Go to / Bring** the reporter (needs the goto / bring permissions).

Rules:

- You can't claim or close reports you filed or that are about you.
- A claimed report can only be handled by its claimer, or by someone with `meowycore.admin.reports.override`.
- If the claimer leaves, or the server restarts, the report goes back to the queue.

## Sits

**Start sit** brings the reporter (and the reported player, if online) to you. It needs the bring permission and skips anyone who outranks you. If the map has a **sit spot**, you all go there instead. **End sit**, or closing the report, sends everyone back to where they were.

Set a sit spot per map by standing there and typing `!setsitspot` (`!clearsitspot` removes it).

## Settings

**Settings → Reports & sits** or `meowycore_config reports <key> <value>`:

| Key | Default | Meaning |
|---|---|---|
| `cooldown` | 60 | Seconds between reports from one player |
| `maxOpen` | 3 | Unresolved reports per player |
| `staleMinutes` | 10 | Remind staff about reports waiting this long (0 = off) |
| `retentionDays` | 30 | Days to keep closed reports |
| `ratings` | true | Ask reporters to rate the help |
| `gotoOnClaim` | true | Teleport to the reporter when claiming |
