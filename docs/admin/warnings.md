# Warnings

Warnings are a record of rule breaks that add up to automatic punishments.

## Giving warnings

- `!warn bob RDM` (works on offline players by SteamID too)
- Menu: right-click a player → Warn, or the **Warnings** tab → Warn player. Common reasons are one click away.

The player sees a popup they must acknowledge (or a notification, see settings). Online staff get a notification.

Rules:

- You can't warn yourself or anyone with equal or higher immunity.
- One staff member can warn the same player at most 3 times per 10 minutes (adjustable).

## Automatic punishments

In **Warnings → Rules** you set what happens when a player reaches a number of *active* warnings:

| Action | Value |
|---|---|
| Kick | — |
| Ban | minutes (0 = permanent) |
| Mute chat / Gag voice | minutes |
| Fine (DarkRP) | money |

Default: kick at 3, 1-hour ban at 5, permanent ban at 10. Each rule fires once, when the count reaches it.

## Expiry and removal

- Warnings stop counting after **30 days** (`expiryDays`, 0 = never) but stay on record.
- `!unwarn <id>` removes one warning, `!clearwarns <player>` removes all. Removal is recorded (who, when, why) and doesn't undo punishments that already happened.
- Staff can remove their own warnings; removing others' needs `meowycore.admin.warnings.removeothers`. Nobody can remove warnings on their own record.

## Seeing warnings

- Players: `!warnings` shows their own.
- Staff with `meowycore.admin.warnings.view`: `!warnings bob`, the Warnings tab (search, show removed), and the warning count on each player's page.

## Settings

All under **Settings → Warnings** or `meowycore_config warnings <key> <value>`:

| Key | Default | Meaning |
|---|---|---|
| `expiryDays` | 30 | Days until a warning stops counting (0 = never) |
| `notifyStaff` | true | Tell online staff about new warnings |
| `targetPopup` | true | Warned players must click "I understand" |
| `perTargetLimit` | 3 | Warnings one staff member can give one player per window (0 = no limit) |
| `perTargetWindow` | 600 | That window, in seconds |
| `reasons`, `thresholds` | | Edited in Warnings → Rules |
