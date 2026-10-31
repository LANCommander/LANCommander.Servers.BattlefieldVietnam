# Battlefield Vietnam Server (Docker)

This repository provides a Dockerized **Battlefield Vietnam** dedicated server. It runs DICE's official 1.21 Linux dedicated server (`bfv_linded`), downloaded on first start from the [LinuxGSM](https://linuxgsm.com/servers/bfvserver/) mirror. That package includes the community security patch and the official WW2 mod, and needs no retail game files.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Downloads and installs the 1.21 Linux dedicated server automatically (pinned and verified by SHA256)
- The server's name, port, player limit, password, game mode and map rotation are environment variables, written into the server's `.con` files
- LAN-only by default (`game.serverInternet 0`), so the server answers LAN browser broadcasts and doesn't register with GameSpy/ASE
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  battlefieldvietnam:
    image: lancommander/battlefieldvietnam:latest
    container_name: battlefieldvietnam

    ports:
      - "15567:15567/udp"
      - "22000:22000/udp"

    volumes:
      - ./config:/config

    environment:
      BFV_SERVER_NAME: "My Battlefield Vietnam Server"
      BFV_MAX_PLAYERS: "32"
      BFV_MAPS: "Hue,Khe_Sahn,Ia_Drang,Operation_Hastings"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP.

---

## Server Files

On first start, `BFV_SERVER_URL` (`bfv_linded-v1.21-20041207_patch-linuxgsm.tar.xz`, 141 MB) is downloaded, checked against `BFV_SERVER_SHA256` and extracted into `config/Server/`. It is reinstalled when `BFV_SERVER_URL` changes. To use your own copy, put a server folder with `bfv_linded.dynamic` in `config/Server/`, or point `BFV_SERVER_URL` at a `.tar.xz`, `.tar.gz` or `.zip` of one (and clear or update `BFV_SERVER_SHA256`).

Clients must run 1.21. The server reads lower-case file names only, so third-party mods and maps must be lower-cased (`fixinstall.sh` in the server folder does this).

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Linux dedicated server (bfv_linded.dynamic, mods/bfvietnam/ ...), installed automatically
    ├── Overlay/           # Your files, layered on top of Server/ (mods/bfvietnam/settings/ and logs/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `mods/<BFV_MOD>/settings/<BFV_CONFIG>` on every start. Settings left empty are not touched, so you can set them in the file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `BFV_SERVER_NAME` | `game.serverName` (at most 30 characters; longer names are cut off) | `Battlefield Vietnam Server` |
| `BFV_PORT` | `game.serverPort` (game port) | `15567` |
| `BFV_INTERNET` | `game.serverInternet`: `true` announces the server to GameSpy/ASE; `false` is LAN only | `false` |
| `BFV_MAX_PLAYERS` | `game.serverMaxPlayers` (up to 64) | `32` |
| `BFV_PASSWORD` | `game.serverPassword` | |
| `BFV_GAME_MODE` | `game.serverGamePlayMode`, and the mode for `BFV_MAPS`: `GPM_CQ` (Conquest) or `GPM_COOP` (Co-op with bots) | `GPM_CQ` |
| `BFV_MAPS` | Map rotation, comma- or space-separated (e.g. `Hue,Khe_Sahn`). Replaces `settings/maplist.con`; empty keeps the existing file | |
| `BFV_MOD` | Mod folder under `mods/` (`+game`) | `bfvietnam` |
| `BFV_CONFIG` | Server settings file in `mods/<mod>/settings/` (`+config`); created if missing | `serversettings.con` |
| `BFV_STATUS_MONITOR` | Show the text status monitor in `docker logs`. Needs `tty: true`, or it spins a CPU core | `false` |
| `BFV_SERVER_URL` | Server package to install | LinuxGSM 1.21 package |
| `BFV_SERVER_SHA256` | Expected SHA256 of `BFV_SERVER_URL` (empty skips the check) | hash of the default package |
| `START_EXE` | Launcher | `/usr/local/bin/bfv-server` |
| `START_ARGS` | Appended to the server command line | |

Rules like time/score limits, rounds, friendly fire, team ratios and bot skill are `game.server*` lines in the same settings file. Voting rules are in `settings/adminsettings.con`.

Retail maps: `Defense_of_Con_Thien`, `Fall_of_Saigon`, `Ho_Chi_Minh_Trail`, `Ho_Chi_Minh_Trail_alt`, `Hue`, `Hue_alt`, `Ia_Drang`, `Khe_Sahn`, `Landing_Zone_Albany`, `Lang_Vei`, `Operation_Cedar_Falls`, `Operation_Flaming_Dart`, `Operation_Game_Warden`, `Operation_Hastings`, `Operation_Irving`, `Quang_Tri`, `Quang_Tri_alt`, `Saigon68`. The stock `maplist.con` also has the WW2 mod maps (`Invasion_of_the_Philippines`, `Iwo_Jima`, `Wake`) commented out as `game.addLevel <map> GPM_CQ bfv_ww2mod` lines; clients need the WW2 mod to play them.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/battlefieldvietnam:local .
```

---

## License

Battlefield Vietnam and its dedicated server are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
