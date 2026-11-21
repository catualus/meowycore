# MeowyCore

MeowyCore is the free (MIT) library every Meowy addon runs on. Server owners only need to install it; this page is for developers who want to build on it.

## Install

Put the `meowycore` folder in `garrysmod/addons/`. Addons that use it wait for it with:

```lua
MeowyCore.OnReady(function()
    -- MeowyCore is loaded
end)
```

## What's in it

| Module | What it does |
|---|---|
| `MeowyCore.Class` | Classes with typed, validated fields and inheritance |
| `MeowyCore.Net` | Declared net messages: typed fields, validation, rate limits and permission checks, one guarded receiver |
| `MeowyCore.Config` | Validated settings saved to `data/meowycore/config/`, synced to clients when marked `shared`, with an in-game editor |
| `MeowyCore.Data` | SQLite or MySQL (MySQLOO) with the same async API, `?` binding and per-addon migrations |
| `MeowyCore.Perm` | Permissions through CAMI |
| `MeowyCore.Lang` | Phrases with `{placeholders}` and per-language tables |
| `MeowyCore.UI` | The flat dark UI kit: frames, buttons, inputs, lists, toasts, dialogs, anti-aliased shapes, icons |
| `MeowyCore.Updates` | Opt-out update check against the public `versions.json` |

## A net message in three lines

```lua
local Hello = MeowyCore.Net.Define("myaddon_hello", {
    to = "server", fields = { { "text", "string", max = 64 } }, rate = { burst = 3, refill = 1 },
})
if SERVER then Hello:Receive(function(ply, msg) print(ply, msg.text) end) end
-- client: Hello:Send({ text = "hi" })
```

Payloads are validated on both sides before your handler runs; malformed or rate-limited messages never reach it.

## Source

[github.com/catualus/meowycore](https://github.com/catualus/meowycore). Every file starts with a comment describing its API.
