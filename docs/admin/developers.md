# For developers

Everything below is under `MeowyCore.Admin` and loads after MeowyCore is ready. Wrap your code in `MeowyCore.OnReady(function() … end)` if your addon might load first.

## Permissions

Use CAMI (or `MeowyCore.Perm`) as you would with any admin mod. Your privileges show up in the Ranks tab.

```lua
CAMI.RegisterPrivilege({ Name = "myaddon.spawnboss", MinAccess = "superadmin" })
CAMI.PlayerHasAccess(ply, "myaddon.spawnboss", function(ok) end)
```

## Commands

Register in a **shared** file so the menu can show it:

```lua
MeowyCore.Admin.RegisterCommand({
    name = "heal", aliases = { "h" }, category = "players", minAccess = "admin",
    args = {
        { name = "targets", type = "players" },
        { name = "amount", type = "number", min = 1, max = 1000, optional = true, default = 100 },
    },
    run = function(ctx)   -- server only
        for _, p in ipairs(ctx.args.targets) do p:SetHealth(ctx.args.amount) end
        return { key = "notice.heal", vars = { targets = MeowyCore.Admin.NameList(ctx.args.targets) } }
    end,
})
```

- Argument types: `player`, `players` (selectors and immunity handled for you), `steamid` (online or offline), `rank`, `duration` (seconds), `number`, `string` (one word), `text` (rest of the line).
- `run` returns nothing, a notice `{ key, vars }` (sent to the [notice audience](./settings)), or `false, errorKey, vars` to tell only the actor.
- The permission is `meowycore.admin.cmd.<name>`; `minAccess` is its default.
- Phrases go in `MeowyCore.Lang.Register("admin", "en", { ["notice.heal"] = "{actor} healed {targets}.", ["cmd.heal.help"] = "…" })`.

## Offline targets

`MeowyCore.Admin.FetchCanTarget(actor, steamid, function(ok, errKey) end)` applies the immunity rules to a SteamID whether or not the player is online. Use it for anything that acts on a SteamID.

## Events

| Hook | Arguments |
|---|---|
| `MeowyCore.Admin.Ready` | |
| `MeowyCore.Admin.CommandRun` | actor, commandName, args |
| `MeowyCore.Admin.Banned` | steamid, seconds, reason, actor |
| `MeowyCore.Admin.Unbanned` | steamid, actor |
| `MeowyCore.Admin.RankChanged` | steamid, rankName, expires |
| `MeowyCore.Admin.RanksUpdated` | |
| `MeowyCore.Admin.Warned` | steamid, warningId, reason, actor, activeCount |
| `MeowyCore.Admin.WarningThreshold` | steamid, count, rule, actor |
| `MeowyCore.Admin.ReportCreated` | report |
| `MeowyCore.Admin.ReportClaimed` | report, actor |
| `MeowyCore.Admin.ReportClosed` | report, actor, note |
| `MeowyCore.Admin.Imported` | sourceId, plan |

Server-side unless noted. `actor` is `NULL` for the server console.

## Importers

Add a source for `madmin import`:

```lua
MeowyCore.Admin.RegisterImporter({
    id = "myadmin", label = "My Admin",
    detect = function() return sql.TableExists("myadmin_users") end,
    read = function(callback)
        callback({
            ranks = { { name = "mod", inherits = "user", granted = { "meowycore.admin.cmd.kick" } } },
            users = { { steamid = "STEAM_0:1:1", rank = "mod", name = "Bob" } },
            bans  = { { steamid = "STEAM_0:1:2", reason = "cheating", admin = "Alice", created = 1700000000, expires = 0 } },
            notes = { "Anything that couldn't be carried over" },
        })
    end,
})
```

Dry runs, idempotency and applying are handled for you.
