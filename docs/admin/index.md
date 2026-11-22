# Meowy Admin

Meowy Admin is an admin mod with the staff toolkit built in: ranks, bans, warnings, reports and sits share one menu, one database and one permission system.

## Requirements

- Garry's Mod server (dedicated or listen), any gamemode. DarkRP extras (like fines) switch on automatically.
- **MeowyCore**, the free library Meowy Admin runs on: [github.com/catualus/meowycore](https://github.com/catualus/meowycore).
- Optional: MySQL with [MySQLOO](https://github.com/FredyH/MySQLOO) if you run several servers that should share ranks and bans.

## Install

1. Download MeowyCore and put the `meowycore` folder in `garrysmod/addons/`.
2. Put the `meowycore_admin` folder from your GmodStore download in `garrysmod/addons/`.
3. Remove or disable your old admin mod (ULX, SAM, sAdmin…). Two admin mods fight over ranks. Before removing it, see [Importing](./importing) to bring your ranks and bans over.
4. Restart the server.

## Icons for players

Add the **MeowyCore Content** Workshop item to your server's Workshop collection and set its ID:

```
meowycore_workshop <workshop id>
```

Without it, the icons are sent through the server download, which needs FastDL on most servers.

## Make yourself the owner

Owners pass every check and can't be targeted by other staff. On a **listen server** the host is always the owner. On a **dedicated server**, run this in the server console (not in game):

```
meowycore_config admin owners ["STEAM_0:1:12345678"]
```

Several owners: `["STEAM_0:1:111","STEAM_0:0:222"]`. Then give yourself the top rank in game, or from the console:

```
madmin setrank STEAM_0:1:12345678 superadmin
```

## Open the menu

- Chat: `!menu`
- Console: `madmin_menu` (bind it, for example `bind F6 madmin_menu`)

Players can contact staff with `!report` (or `bind F7 madmin_report`).

## Use MySQL (optional)

Create `garrysmod/data/meowycore/database.json`:

```json
{ "driver": "mysqloo", "host": "127.0.0.1", "port": 3306,
  "user": "gmod", "password": "secret", "database": "gmod" }
```

Install the MySQLOO module for your server's platform, then restart. Without both, Meowy Admin uses the server's built-in SQLite. Every server pointing at the same database shares ranks, player ranks and bans; bans from other servers apply within `banRefreshSeconds` (60 s by default).

## Where to go next

- [Commands](./commands): every command, its arguments and who can use it
- [Ranks and permissions](./ranks): immunity, inheritance and permission editing
- [Warnings](./warnings) and [Reports and sits](./reports): the built-in staff modules
- [Settings](./settings): every option
