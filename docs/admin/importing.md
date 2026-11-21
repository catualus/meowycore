# Importing from another admin mod

Meowy Admin can bring over ranks, player ranks and bans from the mod you're replacing. It reads that mod's **saved data** only; you can remove the mod's code first, as long as its data files or database tables are still on the server.

## Supported

| Source | Reads | Command |
|---|---|---|
| ULX / ULib | `data/ulib/groups.txt`, `users.txt`, bans from `ulib_bans` (or `data/ulib/bans.txt`) | `madmin import ulx` |
| SAM, sAdmin, xAdmin 2, lyn | | Coming in an update |

## How to import

1. Install Meowy Admin and make yourself the [owner](./#make-yourself-the-owner). Only owners and the server console can import.
2. **Dry run:** in the server console, run

   ```
   madmin import ulx
   ```

   Nothing changes. You see how many ranks, player ranks and bans would be added, the new ranks, and anything that can't be carried over.
3. **Import:**

   ```
   madmin import ulx apply
   ```

4. Open the **Ranks** tab and check each new rank's immunity (see below).

Running it again is safe: ranks that exist get only missing permissions, players already on the rank are skipped, and SteamIDs that are already banned are skipped. Expired bans are never imported.

## What carries over from ULX

| ULX | Meowy Admin |
|---|---|
| Groups and `inherit_from` | Ranks with the same parent. Names with characters other than letters, digits and `_` get `_` instead (`co-owner` → `co_owner`) |
| `ulx <command>` permissions | The matching Meowy Admin command permission |
| Other permissions (from CAMI addons) | Kept as they are |
| Users and their group | Player ranks |
| Bans (reason, banning admin's name, expiry) | Bans |

Not carried over, and listed in the dry run:

- **Target restrictions** like `!%admin`. Meowy Admin uses immunity instead. New ranks get an immunity 5 above their parent, so set them how you want in the Ranks tab.
- **Personal allow/deny lists** on single players. Give those players a rank instead.
- ULX commands Meowy Admin doesn't have.
