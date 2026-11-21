# MeowyCore

A free, open-source foundation library for Garry's Mod addons, focused on DarkRP and roleplay servers. It provides:

- **Loading:** files load in the right realm, with `AddCSLuaFile` handled for you.
- **Networking:** typed, rate-limited and permission-checked.
- **Permissions:** built on CAMI.
- **Storage:** SQLite by default, with optional MySQLOO, and versioned migrations.
- **Config:** schema-driven, editable in game.
- **UI:** a themeable, scale-aware panel kit.
- **Identity:** character-aware, with adapters for popular character systems.

It runs on stock Garry's Mod with no binary modules. It's used by the Meowy addons on GmodStore, and any developer is welcome to build on it.

> Status: early development. The API is not stable yet.

## Install

Drop the `meowycore` folder into `garrysmod/addons/`.

## Licence

[MIT](LICENSE)
