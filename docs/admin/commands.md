# Commands

Every command works three ways:

- **Chat:** `!kick bob spamming` (the prefix is a [setting](./settings))
- **Console:** `madmin kick bob spamming`
- **Menu:** the Commands tab builds the command for you

Arguments in `<angle brackets>` are required, `[square brackets]` optional. Put arguments with spaces in "double quotes".

## Choosing players

| You type | Means |
|---|---|
| `bob` | The player whose name contains "bob" (must match only one) |
| `STEAM_0:1:123` or `7656119…` | That SteamID or SteamID64 |
| `^` | Yourself |
| `@` | The player you're looking at |
| `*` | Everyone |
| `#admin` | Everyone with that rank |
| `!^`, `!#admin` | Everyone *except* those |

You can only act on players with lower **immunity** than yours ([Ranks](./ranks)).

## Durations

`30` (minutes), `45s`, `10m`, `2h`, `1d`, `1w`, `1mo`, `1y`, or combined like `1h30m`. `0`, `perm` or `permanent` mean forever. The longest timed duration is 10 years.

## Reference

**Default access** is the lowest base rank that has the command out of the box. Change it per rank in the Ranks tab. Each command's permission is `meowycore.admin.cmd.<name>`.

### Punishments

| Command | Usage | Default access | Does |
|---|---|---|---|
| kick (k) | `!kick <target> [reason]` | admin | Kick a player |
| ban (b) | `!ban <target> <duration> [reason]` | admin | Ban an online player |
| banid | `!banid <steamid> <duration> [reason]` | admin | Ban a SteamID, online or not |
| unban | `!unban <steamid>` | admin | Lift a ban. You must outrank whoever issued it |
| mute / unmute | `!mute <targets> [duration]` | admin | Block text chat |
| gag / ungag | `!gag <targets> [duration]` | admin | Block voice chat |
| warn | `!warn <player> <reason>` | admin | Warn a player ([Warnings](./warnings)) |
| unwarn | `!unwarn <id> [reason]` | admin | Remove a warning by number |
| clearwarns | `!clearwarns <player> [reason]` | superadmin | Remove all active warnings |

### Players

| Command | Usage | Default access | Does |
|---|---|---|---|
| slay (kill) | `!slay [targets]` | admin | Kill |
| respawn | `!respawn [targets]` | admin | Respawn |
| freeze / unfreeze | `!freeze [targets]` | admin | Freeze in place |
| jail / unjail | `!jail <targets> [duration]` | admin | Keep players in place: no leaving, noclip, spawning or vehicles. Survives reconnecting |
| god / ungod | `!god [targets]` | admin | Invulnerability |
| cloak / uncloak | `!cloak [targets]` | admin | Invisibility |
| noclip | `!noclip [targets]` | admin | Toggle noclip |
| strip | `!strip [targets]` | admin | Remove weapons |
| hp | `!hp <targets> <amount>` | admin | Set health |
| armor | `!armor <targets> <amount>` | admin | Set armor |

With no target, these act on yourself.

### Teleporting

| Command | Usage | Default access | Does |
|---|---|---|---|
| goto (tp) | `!goto <target>` | admin | Go to a player |
| bring | `!bring <targets>` | admin | Bring players to you |
| send | `!send <targets> <destination>` | admin | Send players to another player |
| return | `!return [targets]` | admin | Undo the last teleport |

### Ranks and server

| Command | Usage | Default access | Does |
|---|---|---|---|
| setrank (adduser, setgroup) | `!setrank <player> <rank> [duration] [expireto]` | superadmin | Set a rank, optionally timed; drops to `expireto` (default `user`) afterwards |
| map | `!map <map> [gamemode]` | superadmin | Change map |
| cleanup (cleanmap) | `!cleanup` | admin | Remove everything players spawned |
| import | `!import <source> [apply]` | owners only | [Import](./importing) from another admin mod |
| setsitspot / clearsitspot | `!setsitspot` | superadmin | Set or clear this map's [sit spot](./reports#sits) |

### Everyone

| Command | Usage | Does |
|---|---|---|
| menu (admin) | `!menu` | Open the admin menu (needs `meowycore.admin.menu`) |
| help (commands) | `!help` | List the commands you can use |
| who | `!who` | List players and ranks |
| playtime (pt) | `!playtime [target]` | Total playtime |
| warnings (mywarnings, warns) | `!warnings [player]` | Your warnings (staff: anyone's) |
| report (calladmin) | `!report` | [Contact staff](./reports) |
| myreports | `!myreports` | Your open reports and their replies |
