---
sidebar_label: Docker
---

# Battlefield Vietnam Docker Container

This Docker container runs a Battlefield Vietnam dedicated server. It is built on the base image and runs DICE's official 1.21 Linux dedicated server, `bfv_linded`, which it downloads on first start. No retail game files are needed.

## Quick Start

```yaml
services:
  battlefieldvietnam:
    image: lancommander/battlefieldvietnam:latest
    container_name: battlefieldvietnam

    ports:
      - 15567:15567/udp
      - 22000:22000/udp

    volumes:
      - "/data/Servers/Battlefield Vietnam/Conquest:/config"

    environment:
      BFV_SERVER_NAME: "My Battlefield Vietnam Server"
      BFV_MAPS: "Hue,Khe_Sahn,Ia_Drang"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

## How It Starts

1. `PostInitialization/20-InstallBattlefieldVietnam.ps1` checks for `Server/bfv_linded.dynamic`. If it's missing, or `BFV_SERVER_URL` differs from the URL in `Server/.bfv-server-url`, the hook downloads the package, verifies `BFV_SERVER_SHA256`, extracts it into `Server/` and remounts the overlay.
2. `PostInitialization/30-ConfigureBattlefieldVietnam.ps1` writes the non-empty `BFV_*` settings into `mods/<BFV_MOD>/settings/<BFV_CONFIG>` (creating it, since the package has no `serversettings.con`), and `BFV_MAPS` into `settings/maplist.con`. It edits through `Merged/`, so the files land in `Overlay/`.
3. `START_EXE` (`/usr/local/bin/bfv-server`) runs `bfv_linded.dynamic +restart 1 +dedicated 1 +game bfvietnam +config serversettings.con +statusMonitor 0` from `Merged/`.

With the status monitor off, `docker logs` ends at the `Starting:` line. The server's own log is `mods/bfvietnam/logs/bflog_<hostname>.log` in `Overlay/`.

## Server Package

The default `BFV_SERVER_URL` is the `server-1.21` release of this repo: LinuxGSM's package of the 1.21 Linux server, `bfv_linded-v1.21-20041207_patch-linuxgsm.tar.xz` (also at `https://linuxgsm.download/BattlefieldVietnam/`). It contains:

- `bfv_linded.dynamic` (with the community security patch described in `README-PATCH.txt`) and `bfv_linded.static`
- `mods/bfvietnam/` (server-side archives and maps) and `mods/bfv_ww2mod/` (the official WW2 mod)
- PunkBuster (`pb/`), `fixinstall.sh` and DICE's readmes

## Configuration Options

### Ports

- **15567/udp**: Game (`BFV_PORT`)
- **22000/udp**: LAN browser broadcasts and GameSpy LAN queries (`\status\`)
- **23000/udp**: GameSpy queries, only with `BFV_INTERNET=true`
- **15690/udp**: ASE queries, only with `BFV_INTERNET=true`

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### serversettings.con and maplist.con

`Overlay/mods/bfvietnam/settings/serversettings.con` is yours to edit; any `game.server*` setting works there (`game.serverGameTime`, `game.serverTicketRatio`, `game.serverSoldierFriendlyFire`, `game.serverCoopAiSkill` ...). Only the lines that have a non-empty `BFV_*` variable are rewritten on start. The server also reads `settings/serverautoexec.con` (console commands run at startup) and `settings/banlist.con`.

Each `maplist.con` line is `game.addLevel <Map> <GameMode> <mod>`. The maps ship Conquest (`GPM_CQ`) and Co-op (`GPM_COOP`, with bots) layers. The server rewrites `maplist.con` itself while it runs, so `game.setCurrentLevel` tracks the current map.

### Hooks

| Hook | When |
|------|------|
| `PreInstallBattlefieldVietnam` / `PostInstallBattlefieldVietnam` | Around the server install check/download |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **Server name is the container hostname and settings are ignored**: `+config` is relative to `mods/<mod>/settings/`. A full path such as `mods/bfvietnam/settings/serversettings.con` makes the server look in `settings/mods/...`, fail silently and use defaults. `BFV_CONFIG` takes just the file name.
- **High CPU use (a whole core)**: the text status monitor busy-loops when there is no terminal. Leave `BFV_STATUS_MONITOR=false`, or set it to `true` with `tty: true` in compose.
- **Custom maps or mods not found**: the server lower-cases every file name before opening it. Run `fixinstall.sh` in the mod folder, or lower-case the names yourself.
- **Server not in the LAN browser**: the browser finds servers by UDP broadcast on port 22000, so the container needs its own LAN address (macvlan/ipvlan) or host networking. Clients can join by IP through port mapping.
- **Server not in the internet browser**: `BFV_INTERNET` is `false` by default. The GameSpy master servers are gone, so internet mode needs a GameSpy replacement on the clients and the server.
- **`SHA256 mismatch`**: the download doesn't match `BFV_SERVER_SHA256`. Set it to the new hash (or empty) only if you trust the new file.
- **Clients can't join**: server and clients must both be 1.21 with the same mods.
