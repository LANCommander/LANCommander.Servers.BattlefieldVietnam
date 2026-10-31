# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - BFV_SERVER_URL is the official 1.21 Linux dedicated server (bfv_linded) with the community
#     security patch and the WW2 mod, as packaged by LinuxGSM and mirrored as this repo's
#     server-1.21 release. It is installed into /config/Server on first start and verified
#     against BFV_SERVER_SHA256 (empty = no check)
#   - Server rules live in mods/<BFV_MOD>/settings/<BFV_CONFIG>; the BFV_* settings below are
#     written into it on every start (empty settings are left alone). BFV_MAPS, when set,
#     replaces settings/maplist.con
#   - The text status monitor busy-loops without a terminal, so it is off unless
#     BFV_STATUS_MONITOR=true (then also set `tty: true`)
# ----------------------------
ENV BFV_SERVER_URL="https://github.com/LANCommander/LANCommander.Servers.BattlefieldVietnam/releases/download/server-1.21/bfv_linded-v1.21-20041207_patch-linuxgsm.tar.xz" \
    BFV_SERVER_SHA256="12c5ac805dc6690f615d7187d6e7c67379a201d73e74ad1cd79818efc43414f9" \
    BFV_MOD="bfvietnam" \
    BFV_CONFIG="serversettings.con" \
    BFV_PORT="15567" \
    BFV_INTERNET="false" \
    BFV_SERVER_NAME="Battlefield Vietnam Server" \
    BFV_MAX_PLAYERS="32" \
    BFV_PASSWORD="" \
    BFV_GAME_MODE="GPM_CQ" \
    BFV_MAPS="" \
    BFV_STATUS_MONITOR="false" \
    START_EXE="/usr/local/bin/bfv-server" \
    START_ARGS=""

# bfv_linded is a 32-bit binary built against libstdc++5 and ncurses 5
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++5:i386 \
        libncurses5:i386 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/bfv-server /usr/local/bin/bfv-server
RUN chmod +x /usr/local/bin/bfv-server

COPY Hooks/ "${BASE_HOOKS}/"

# 15567/udp: game (BFV_PORT)
# 22000/udp: LAN browser broadcasts and GameSpy LAN queries
# 23000/udp: GameSpy queries (BFV_INTERNET=true only)
# 15690/udp: ASE queries (BFV_INTERNET=true only)
EXPOSE 15567/udp 22000/udp 23000/udp 15690/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
