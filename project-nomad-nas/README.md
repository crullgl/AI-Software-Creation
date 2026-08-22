# Project NOMAD on a UGREEN NAS

The Docker configuration for running [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad) on a UGREEN NAS (tested on a DXP4800 Pro). This is the **NAS-side** half; [`../project-nomad-desktop`](../project-nomad-desktop) is a second, GPU-accelerated instance that borrows this one's library read-only.

## Files

| File | What it is |
|---|---|
| `docker-compose-ugreen.yml` | The UGREEN variant. Named volumes, `ollama` for local AI, and a `disk-collector` that scans `/volume1` and `/volume2` (UGREEN's volume paths). **All secrets come from `.env`.** |
| `docker-compose.yaml` | The generic variant, using bind mounts under `./storage`. |
| `setup-ugreen.sh` | Loads the exported images and brings the stack up over SSH. |
| `.env.example` | Every variable both compose files need. |

## Setup

```bash
cp .env.example .env      # then fill in - generate each password fresh
docker compose -f docker-compose-ugreen.yml up -d
```

Then browse to `http://YOUR_NAS_IP:8080`.

| Service | Port |
|---|---|
| NOMAD Command Center | 8080 |
| Kiwix (the library) | 8090 |
| Dozzle (live logs) | 9999 |
| Ollama | 11434 |
| Qdrant | 6333 / 6334 |
| MySQL | 3306 |

## What is deliberately not in this repo

**The exported container images** (`*.tar.gz`, about 4.05 GB — ollama alone is 3.2 GB). They exceed GitHub's file limits, and they are simply saved copies of public upstream images. `docker compose pull` fetches the same thing. They only exist on the NAS because the original migration moved them onto a machine that had no internet at the time.

**`.env` and `.env.ugreen`** — the live secrets.

**`MIGRATION_STATUS.md` and `UPLOAD_GUIDE.md`** — the original setup notes. They contain the NAS username and password in clear text, which is exactly why they are not here.

## A security note worth reading

Upstream's `docker-compose.yaml` ships with `APP_KEY` and the database passwords **written directly into the file**. The copy here has them replaced with `${VAR}` references, matching what `docker-compose-ugreen.yml` already does properly.

If you are running the upstream file unmodified, your database passwords are sitting in plain text in your compose file — and on your NAS share, where anything with read access to that folder can see them. Move them to `.env`, and check your own setup notes for credentials pasted in while getting things working. Mine had them.

## Credit

Project NOMAD is by [Crosstalk Solutions](https://github.com/Crosstalk-Solutions/project-nomad). This folder is only deployment configuration for running it on UGREEN hardware.
