# CAMP LAN — SHANKPIT with no uplink

The cloud being down is not an outage for a LAN game; it is the normal condition. This is the house
version: a Raspberry Pi Zero W is the network, the camp host is the identity node and the game server,
and nothing on either box needs the internet.

```
        phones / laptops                       THE HOST (Windows or Linux box)
        192.168.42.10-150                      ┌───────────────────────────────────────┐
              │                                │  iduna      :8080  (guest accounts,    │
              │  Wi-Fi "SHANKPIT_CAMP_LAN"     │                      JWKS, SSO)        │
              ▼                                │  wotan      :8081  (static stats site) │
        ┌──────────────────┐   usb0 cable      │  shank_server :6969/udp (the GAME)     │
        │  Pi Zero W / 2W  │◄─────────────────►│  shank_lobby (the client, native)      │
        │  .42.1  AP+DHCP  │   192.168.43.1/24 └───────────────────────────────────────┘
        │  .43.1  DNS      │
        └──────────────────┘
```

## What runs where, and why

| Piece | Runs | Where the file is |
| --- | --- | --- |
| Access point, DHCP, DNS | Pi Zero | `sudo-queue/98-shankpit-camp-lan-pi.sh` |
| IDUNA (identity) | host, container **or** `go run .` | `docker-compose.camp.yml`, `IDUNA/ops/docker/iduna.Dockerfile` |
| WOTAN (static site) | host, container | `docker-compose.camp.yml` |
| The game | host, **native binary** | `SHANKPIT/apps/server`, `SHANKPIT/bin/shank_lobby` |

The game is deliberately not containerised. `shank_server` already owns its own UDP loop on port 6969
(`--port N` overrides), and on a box that is already running it a container adds a hop and a volume
mapping and buys nothing. The compose stack is only the two things that benefit from being isolated:
identity and the static site.

## The database is SQLite, not MySQL

IDUNA opens MySQL only when `MYSQL_DSN` is set; with it unset it opens `SQLITE_PATH`
(`IDUNA/main.go`, `modernc.org/sqlite`, pure Go). So the camp stack has **no database container** — the
whole identity database is one file on the `iduna_data` volume. That is the correct size for a camp:
`docker run --rm -v shankpit_camp_iduna_data:/data iduna:camp ...` is the backup.

## Bring it up

```bash
# 1. On the Pi (once per card, needs root):
sudo ./sudo-queue/98-shankpit-camp-lan-pi.sh
#    DRY_RUN=1 to see every change without writing it.

# 2. On the host, with the USB cable in:
CAMP_HOST=192.168.43.10 ./camp-deploy.sh
```

`camp-deploy.sh` builds `iduna:camp` locally (nothing is pulled or pushed), deploys with
`docker stack deploy` when swarm is active and `docker compose up -d` otherwise, runs the idempotent
schema bootstrap against the same volume, and prints the verification curls.

## The names

The Pi's dnsmasq answers `iduna.local`, `wotan.local` and the `okemily.com` platform names with the
host's USB address, so clients need no `/etc/hosts` edits, and everything not on the LAN resolves to
the host too — failing fast beats hanging on a dead uplink with 30 people waiting.

## Honest gaps, named

- **Nothing here has been run on the hardware.** There is no Docker daemon and no Pi on the box these
  files were written on. `bash -n` and a YAML parse prove the syntax, not the evening.
- **The Pi Zero W has one radio.** AP + USB gadget is fine; AP + Wi-Fi uplink at the same time is not
  available on the single-antenna part. The Zero 2 W is the part to buy if that ever matters.
- **WPA2-PSK with a camp password** (`campvibesonly` by default, `CAMP_PSK` overrides). This is a
  LAN in the woods, not a threat model.
- **No captive portal and no internet.** Phones will say "no internet connection" when they join. That
  is true, and the apps still work — they only need the host.
- **Swarm bind mounts need absolute paths.** `WOTAN_DIR=/abs/path/WOTAN` when deploying with
  `docker stack deploy`; the relative default is compose-only.
