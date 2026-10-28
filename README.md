# docker_aime — All.net/AimeDB server for Initial D THE ARCADE

A self-contained **Docker Compose** stack that runs the [ARTEMiS](https://gitea.tendokyu.moe/Dniel97/artemis)
All.net emulator — **including the AimeDB card server** — so a private
Initial D THE ARCADE cabinet (Season 3 / SDGT 3.00.00) can keep profiles, save
progress and use networked features.

One command brings up the whole stack: ARTEMiS (`app`) plus MariaDB (`db`) and
memcached (`memcached`). ARTEMiS is cloned at a pinned commit **during the image
build**, so there is nothing to check out by hand.

## Quick start

```bash
git clone https://github.com/azlekayn/docker_aime.git
cd docker_aime
cp .env.example .env
$EDITOR .env          # set IDAC_HOSTNAME (required); AIMEDB_KEY is preset

docker compose up -d --build
```

`IDAC_HOSTNAME` must be an address the **cabinets** can reach — the LAN IP of
the Docker host, e.g. `192.168.1.10`. **Do not use `127.0.0.1`** (the game
rejects loopback). If the host sits behind NAT, forward the ports below.

Point the game client at it (from
[`idac-toolkit`](https://github.com/azlekayn)):

```bash
idac connect 192.168.1.10
```

or edit by hand: `segatools.ini` → `[dns] default=192.168.1.10` and
`XeLanConfig.ini` → `TENTATIVE_LAN_SERVER_FIND_TYPE,1,` /
`TENTATIVE_LAN_SERVER_IP,192.168.1.10,`.

## What's in here

| Path | Purpose |
|---|---|
| `docker-compose.yml` | The stack: `app` (ARTEMiS), `db` (MariaDB), `memcached` |
| `Dockerfile` | Builds the ARTEMiS image; clones upstream at a pinned commit and applies `patches/` |
| `.env.example` | Copy to `.env`; set the client-facing hostname + AimeDB key |
| `config/core.yaml` | ARTEMiS core config (DB/memcached hosts wired to the stack) |
| `config/idac.yaml` | Initial D THE ARCADE title config (matching/echo ports) |
| `patches/*.patch` | Overlay fixes applied during the build (see below) |
| `setup.sh` | Optional: create `.env` and inject hostname/key into the YAMLs |

## Ports

| Port | Service |
|---|---|
| `80` | ALL.net / title HTTP |
| `8443` | Billing (HTTPS) |
| `22345` | **AimeDB** (card read/register) |
| `8080` | Web management UI (profiles, rankings) |
| `20000-20003` | IDAC online-battle matching + echo + P2P |

## AimeDB key

SEGA's AiMeDB uses a **fixed 16-byte ASCII key that is the same across games:
`Copyright(C)SEGA`** (AES-128-ECB). It is preset in `.env.example`. The server
exits immediately (`!!!KEY NOT SET!!!`) if the key is empty, and without the
correct key every AimeDB packet fails (the cab shows *"Aime is not available"*).

## Web management UI

The ARTEMiS frontend is enabled on `:8080`. Browse to `http://<server>:8080/`,
create an account/card via **Gate**, then log in. The `idac` branch ships:

* Profile (and JSON export): `/game/idac/profile`
* Time-trial ranking: `/game/idac/ranking/time-trial`
* Team ranking: `/game/idac/ranking/team`

## Overlay patches

Applied automatically during the image build, **idempotently**:

* **`idac-index.patch`** (`titles/idac/index.py`)
  * advertises **this** server's hostname instead of the hardcoded
    `http://sega-initiald.net/<ver>/` — otherwise the cab's `GameServer` auth
    fails and it drops to offline (`IsWanAvailable: NG`);
  * widens the Season-3 version range to `200–339` so **SDGT 3.00.00 (v300)**
    maps to the Season-3 handlers (upstream stops at `239`, so v300 was rejected
    as `Unhandled v300 request`).
* **`aimedb.patch`** (`core/aimedb.py`)
  * accepts a hex/`0x`-prefixed AimeDB key as well as a plain ASCII key;
  * logs the raw received packet at `debug` (handy when diagnosing the key).

To track a different upstream build, set `ARTEMIS_REPO` / `ARTEMIS_BRANCH` /
`ARTEMIS_COMMIT` in `.env` and rebuild:

```bash
docker compose build --no-cache && docker compose up -d
```

## Configuration model

ARTEMiS reads environment overrides as `CFG_<module>_<path>` with the module and
keys in **lowercase** (e.g. `CFG_core_server_hostname`,
`CFG_core_aimedb_key`, `CFG_idac_server_matching_host`). Compose sets these, so
editing `.env` and re-running `docker compose up -d` is enough for hostname/key
changes. The bundled `config/*.yaml` provide the title-specific defaults.

## Troubleshooting

* **Game can't reach the server** — check `IDAC_HOSTNAME` is a non-loopback
  address clients can reach and the ports are open.
* **`Unhandled command in AimeDB`** — `AIMEDB_KEY` is missing/wrong.
* **Data not loading / memcached errors** — memcached must be reachable as
  `ma.memcached` (already wired).
* **Logs** — `docker compose logs -f app`, or the `aime-logs` volume
  (`/app/logs/{allnet,aimedb,idac,core}.log` inside the container).
* **Podman** — use fully-qualified image names (podman enforces short-name
  resolution), e.g. `docker.io/library/memcached`.

## Credits & license

ARTEMiS is by the ARTEMiS contributors (see upstream) and is distributed under
the **WTFPL v2** (`LICENSE.txt` upstream). This repository only adds packaging
(Dockerfile/compose/patches) on top of it and is released under the same terms.
Initial D THE ARCADE is a trademark of SEGA; this project is unaffiliated with
SEGA and is intended for private, personal use only.
