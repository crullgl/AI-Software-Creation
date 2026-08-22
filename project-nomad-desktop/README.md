# Project NOMAD — a second, GPU-accelerated instance on a Windows PC

Run a **second [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad)** on a desktop with a GPU, while your existing NAS instance keeps running **completely untouched**. The desktop copy borrows the NAS's library — hundreds of gigabytes of ZIM archives and offline maps — **read-only over SMB**, so there is no duplication and no risk to the original.

Why bother: a NAS serves files well but is a poor place to run a local LLM. Moving the app and Ollama onto a machine with a GPU made the AI assistant roughly **4.5× faster** in testing, while the terabyte of content stayed exactly where it was.

Built and verified on Windows 11 + Docker Desktop (WSL2) against a UGREEN DXP4800 Pro, 2026-08-22.

---

## The one rule

**The NAS instance is never modified.** Not stopped, updated or reconfigured. Its Docker socket is never exposed to the desktop, so there is no mechanism to touch it even by accident.

The two instances share exactly one thing — the *content* — and only ever read-only. That is enforced at the mount layer, and worth verifying yourself after setup:

```bash
docker exec nomadpc_nas_library sh -c "touch /data/_w"
# touch: /data/_w: Read-only file system
```

### What must stay local, and why

| Piece | Where | Why it cannot be shared |
|---|---|---|
| MySQL | local disk | **Two MySQL servers on one datadir destroy it.** InnoDB assumes exclusive ownership, and your NAS instance has those files open. MySQL over SMB is unsupported anyway — CIFS provides neither real file locking nor honest `fsync`. |
| Redis | local disk | same reasoning |
| App storage | local disk | this instance's own state |
| Ollama models | local disk | large, and wanted on fast storage |
| **ZIM archives** | **NAS, read-only** | the whole point — no duplication |
| **Maps** | **NAS, read-only** | same |

---

## Requirements

- Windows 10/11 with **Docker Desktop** (WSL2 backend)
- An **NVIDIA GPU** if you want accelerated AI — verify with:
  `docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi`
- An existing Project NOMAD whose storage folder is reachable over SMB
- ~30 GB free disk for images and models (the library stays on the NAS)

---

## Setup

**1. Clone and configure**

```powershell
git clone <this-repo> D:\nomad-pc
cd D:\nomad-pc
copy .env.example .env
```

Edit `.env`: generate three random secrets, and set your NAS host, share and login. **Do not reuse your NAS instance's passwords** — the two should share no credentials. On Windows you can instead run `setup_env.ps1`, which generates the secrets, prompts for the NAS login, verifies it, and ACL-locks the file to your account.

**2. Start it**

```powershell
docker compose up -d
```

**3. Check**

```powershell
docker compose ps
docker exec nomadpc_nas_library sh -c "ls /data/*.zim | wc -l"   # your archive count
```

| Service | URL |
|---|---|
| NOMAD | http://localhost:8080 |
| Information Library (Kiwix) | http://localhost:8090 |
| Direct NAS library | http://localhost:8091 |
| Logs (Dozzle) | http://localhost:9998 |
| Ollama | http://localhost:11434 |

**4. Attach the NAS library to NOMAD's own Kiwix**

NOMAD installs and manages its own Information Library, pointed at a local folder. To make it serve the NAS archives too:

```powershell
.\attach_nas_library.ps1
```

Re-run this after any **Rescan Library** or reinstall — those rewrite `kiwix-library.xml` and drop the NAS entries.

**5. Optional — copy your map pins across**

```powershell
.\copy_markers.ps1
```

Reads `/api/maps/markers` from the NAS over HTTP and POSTs them locally. The NAS is only read.

---

## Choosing a model: measure, don't guess

Benchmarked on an RTX 3060 Laptop (6 GB), identical prompt:

| Model | tokens/sec | Placement |
|---|---|---|
| **gemma4:e2b-it-qat** | **113.1** | **100% GPU** (1.6 GB resident) |
| llama3.1:8b-text-q4_K_M | 25.3 | 25% CPU / 75% GPU |
| qwen3:4b-q8_0 | 21.6 | 18% CPU / 82% GPU |

**VRAM is the entire constraint.** A model that doesn't fit spills onto the CPU and runs about four times slower — and it will not tell you. Always check the placement column:

```powershell
docker exec nomad_ollama ollama ps
```

`benchmark.ps1` runs this comparison on your own hardware.

---

## Traps worth knowing (each cost real debugging time)

**NOMAD hardcodes its Docker network name** as `project-nomad_default`. Compose derives network names from the folder, so `name: project-nomad` is pinned at the top of `docker-compose.yml`. Without it, every in-app install fails with `network project-nomad_default not found`.

**Never use "Edit App" on the Information Library.** The form shows `/opt/project-nomad/storage/zim` — a Linux path from the NAS build. On create NOMAD translates it to the real host folder; on **Save & Recreate** it passes it through literally, that path doesn't exist in the Docker VM, and Kiwix restart-loops with `Failed to load the XML library file`. This is a NOMAD bug on Windows.

**NOMAD's installer needs a writable zim folder** — it downloads a starter Wikipedia. Mounting the NAS read-only there fails with `EROFS: read-only file system`. Hence: local writable folder for the app, NAS mounted beside it at `/data/nas`.

**The Kiwix image runs as uid 1001** but NOMAD creates the library XML as root, so `kiwix-manage` must run with `docker exec -u 0` or it fails with `Cannot write the library`.

**Do not delete the `nas_library` container on 8091.** It looks redundant next to 8090, but it holds the CIFS volume mounted — which is what keeps the NAS path live for NOMAD's own Kiwix.

**Leave "Resource Limits" blank in Edit App.** The form suggests defaults of 1024 MB / 1 CPU, but no limit is actually applied — containers read `unlimited`. Filling those boxes in *imposes* a cap that didn't exist.

**Docker's memory lives in `%USERPROFILE%\.wslconfig`,** not Docker Desktop's UI, because it runs on WSL2. WSL2 defaults to about half your RAM. A sample config is in `wslconfig.example`. **Do not set `networkingMode=mirrored`** — it prevents the Docker engine from starting.

**Windows symlinks need admin or Developer Mode.** Without them you cannot simply link the NAS into the app's storage folder, which is why each container is wired individually here.

---

## Security notes

- `.env` is gitignored and holds both this instance's generated secrets and your NAS login. **Never commit it.**
- The NAS share is mounted `ro` with `file_mode=0444` — read-only at the CIFS layer, not merely by convention.
- The upstream NOMAD compose ships some secrets in plain text. This setup generates its own instead.
- Check your own NOMAD install for credentials committed to markdown or compose files. Mine had the NAS password in two setup documents.

---

## Licence and credit

Project NOMAD is by [Crosstalk Solutions](https://github.com/Crosstalk-Solutions/project-nomad). This repo is only a deployment recipe — configuration and helper scripts for running a second instance on Windows against an existing NAS library. All credit for NOMAD itself goes upstream.
