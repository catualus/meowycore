# FAQ and troubleshooting

### Nothing happens / "Meowy Admin" isn't in the console on startup

MeowyCore is missing. The server console says so 5 seconds after start. Install it from [GitHub](https://github.com/catualus/meowycore).

### I can't open the menu

You need a rank with `meowycore.admin.menu` (admins by default). On a new dedicated server, set yourself as [owner](./#make-yourself-the-owner) from the server console first.

### `meowycore_config admin owners` says it can only be set from the console

That's on purpose: owners have full access, so only the server console (RCON, the panel's console, or the server window) can set them.

### Players see "The server is still starting up"

For up to 90 seconds after a restart, joins wait until the ban list has loaded, so banned players can't slip in. If it lasts longer, the database is unreachable: check `data/meowycore/database.json` and the server console. After 90 seconds players are let in anyway and the console logs an error.

### Another addon's admin checks don't work

Make sure only one admin mod is installed. Meowy Admin answers CAMI, so addons using CAMI or `IsAdmin()`/`IsSuperAdmin()` work. Addons that check ULX directly (`ULib.ucl`) need ULX.

### Can I use Meowy Admin across several servers?

Yes. Point them all at the same MySQL database ([setup](./#use-mysql-optional)). Ranks, player ranks, bans, warnings and reports are shared.

### Does it phone home?

Only the optional update check, which downloads a public file from GitHub and sends nothing. Turn it off with `meowycore_update_check 0`.
