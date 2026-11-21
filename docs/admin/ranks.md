# Ranks and permissions

## Base ranks

Three ranks always exist and can't be deleted:

| Rank | Immunity | Notes |
|---|---|---|
| user | 0 | Everyone starts here |
| admin | 50 | `Player:IsAdmin()` is true |
| superadmin | 100 | Has every permission (`*`); `IsSuperAdmin()` is true |

## Custom ranks

Create them in the menu's **Ranks** tab. Each custom rank:

- **inherits** from another rank and gets everything that rank has. Its "access level" (user/admin/superadmin) comes from the base rank at the root of its chain, so other addons that check `IsAdmin()` see the right thing.
- has an **immunity** from 0 to 100. Staff can only act on players with *lower* immunity (equal is allowed if you turn on `allowEqualImmunity`). This applies to offline players (by SteamID) too.
- can **grant** or **deny** individual permissions. A deny wins over a grant on the same rank; otherwise the nearest rank in the chain that mentions a permission decides.
- has a label and colour, shown in the menu and to chat addons.

## Who may edit what

- You can only create, edit or delete ranks with immunity **below your own**.
- A rank you edit can't end up with anything you don't have yourself, whether through its own grants, its parent or removed denies. It also can't get a higher access level than yours.
- Deleting a rank moves its players and child ranks to its parent. You can't delete a rank whose parent is at or above your immunity.
- `!setrank` only hands out ranks below your own, including the fallback rank of a timed rank.
- Owners (see [Getting started](./#make-yourself-the-owner)) and the server console skip these limits.

## Timed ranks

```
!setrank bob vip 30d
!setrank bob moderator 7d user
```

When the time runs out, the player drops to the fallback rank (default `user`), even while online.

## CAMI

Meowy Admin is a CAMI provider: ranks are registered as CAMI usergroups and it answers `CAMI.PlayerHasAccess`. Any addon that uses CAMI (DarkRP, most GmodStore addons) shows its permissions in the Ranks tab, where you can grant or deny them per rank.

## Permission names

| Permission | Default | Lets you |
|---|---|---|
| `meowycore.admin.menu` | admin | Open the menu |
| `meowycore.admin.ranks` | superadmin | Use the Ranks tab |
| `meowycore.admin.seenotices` | admin | See staff-only action notices |
| `meowycore.admin.cmd.<command>` | per command | Use a command ([list](./commands)) |
| `meowycore.admin.warnings.view` | admin | See other players' warnings |
| `meowycore.admin.warnings.removeothers` | admin | Remove warnings issued by other staff |
| `meowycore.admin.reports.handle` | admin | See and handle reports |
| `meowycore.admin.reports.override` | superadmin | Handle reports claimed by others |
| `meowycore.config` | superadmin | Change settings |
