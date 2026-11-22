# Settings

Change settings in the menu's **Settings** tab (needs `meowycore.config`), or from the console:

```
meowycore_config <namespace> <key>            shows the value
meowycore_config <namespace> <key> <value>    sets it
```

Tables are JSON: `meowycore_config admin owners ["STEAM_0:1:123"]`. Settings are saved in `data/meowycore/config/<namespace>.json` and apply immediately unless noted.

## admin

| Key | Default | Meaning |
|---|---|---|
| `chatPrefix` | `!` | Chat command prefix (1–2 characters) |
| `adminChatPrefix` | `@` | Chat messages starting with this go to the staff. Empty turns it off (`!asay` still works) |
| `hideCommandChat` | true | Hide the chat line of a command; only the result notice shows |
| `noticeAudience` | `all` | Who sees action notices: `all`, `staff` (has `meowycore.admin.seenotices`) or `none` |
| `allowEqualImmunity` | false | Staff may act on players with the same immunity |
| `owners` | `[]` | SteamIDs with full access. **Server console only** |
| `banFamilySharing` | true | Kick family-shared copies of a banned account |
| `historyDays` | 30 | Days to keep command history |
| `banRefreshSeconds` | 60 | How often bans are re-read from the database (for MySQL networks) |
| `moduleWarnings` | true | [Warnings](./warnings) module. Applies after a map change |
| `moduleReports` | true | [Reports and sits](./reports) module. Applies after a map change |

Turning a module off keeps its data; it only stops loading.

## Modules

- [warnings](./warnings#settings)
- [reports](./reports#settings)

## MeowyCore console variables

Set these in `server.cfg` or the server console.

| Variable | Default | Meaning |
|---|---|---|
| `meowycore_update_check` | 1 | Check the public `versions.json` on GitHub and tell admins when an update is out. No data is sent. `0` turns it off |
| `meowycore_workshop` | (empty) | Workshop ID of the **MeowyCore Content** addon. When set, players get the icons through Workshop and nothing goes through FastDL (recommended) |
| `meowycore_fastdl` | 1 | Without a Workshop ID: send the icons through the server download. With `sv_allowdownload 0` they must also be on your FastDL host |
