<!--
  SANITISED COPY. The original of this file lives on the NAS and contains
  the real NAS username and password in clear text - which is exactly why
  it is not published as-is. Credentials below are placeholders.
-->
# Project NOMAD Migration Status

**Date**: April 1, 2026  
**Status**: âœ… Ready for Upload to Ugreen NAS

---

## What's Ready

### âœ… All Files Prepared (4.05 GB)
Located in: `C:\Users\YOU\nomad-migration\`

**Docker Images (4.01 GB):**
- disk-collector.tar.gz (6.68 MB)
- dozzle.tar.gz (16.94 MB)
- kiwix.tar.gz (25.05 MB)
- mysql.tar.gz (221.98 MB)
- ollama.tar.gz (3168.21 MB) â† Largest
- project-nomad.tar.gz (528.19 MB)
- qdrant.tar.gz (68.39 MB)
- redis.tar.gz (16.42 MB)

**Configuration Files:**
- docker-compose-ugreen.yml (2.86 KB)
- .env.ugreen (633 B)

**Helper Files:**
- UPLOAD_GUIDE.md (4.06 KB) - Detailed upload instructions
- setup-ugreen.sh (2.00 KB) - Automated SSH script

---

## Next Steps

### 1ï¸âƒ£ Upload to Ugreen (10-30 minutes)
```
1. Open: http://YOUR_NAS_IP:8000
2. Login: YOUR_NAS_USERNAME / YOUR_NAS_PASSWORD
3. Create: /volume1/docker/project-nomad/
4. Upload all 10 files from C:\Users\YOU\nomad-migration\
5. Verify: All files appear in web UI
```

**See:** `UPLOAD_GUIDE.md` for detailed steps

### 2ï¸âƒ£ SSH into Ugreen & Load Images (5-10 minutes)
```powershell
ssh YOUR_NAS_USERNAME@YOUR_NAS_IP -p 22
# Password: YOUR_NAS_PASSWORD
```

Then run (or copy setup-ugreen.sh and execute):
```bash
cd /volume1/docker/project-nomad && \
bash setup-ugreen.sh
```

### 3ï¸âƒ£ Verify Services Running
Check these endpoints:
- http://YOUR_NAS_IP:8080 (Admin Dashboard)
- http://YOUR_NAS_IP:8090 (Kiwix)
- http://YOUR_NAS_IP:9999 (Dozzle Logs)
- http://YOUR_NAS_IP:11434 (Ollama API)

---

## Ugreen NAS Details

| Item | Value |
|------|-------|
| IP Address | YOUR_NAS_IP |
| SSH Username | YOUR_NAS_USERNAME |
| SSH Password | YOUR_NAS_PASSWORD |
| SSH Port | 22 |
| Docker Version | 26.1.0 âœ“ |
| Target Path | /volume1/docker/project-nomad/ |
| Available Space | /volume1: 1.5T free, /volume2: 7.0T free |

---

## What Was Tried (Previous Sessions)

âŒ SCP - timeout issues
âŒ Rsync - SSH connection refused
âŒ HTTP server (nginx) - port inaccessible
âŒ SMB mount - permission denied
âŒ Python/Node HTTP servers - not available

âœ… **Solution: Ugreen File Manager UI** - Most reliable, no special tools needed

---

## Estimated Timeline

| Step | Time | Total |
|------|------|-------|
| Upload via UI | 10-30 min | 0:10-0:30 |
| Load images (SSH) | 5-10 min | 0:15-0:40 |
| Services startup | 2 min | 0:17-0:42 |
| **Total** | | **~20-45 minutes** |

---

## Files Not Yet Transferred

**Optional - Can Add Later:**
- storage/ folder (500+ GB with ZIM files, models, databases)
- Can be transferred via SMB or direct copy if needed

---

## Important Notes

1. All services were tested and working on Windows PC
2. Ugreen SSH connection verified (docker check successful)
3. Docker daemon is running on Ugreen
4. Enough disk space available (/volume2 has 7.0 TB)
5. No additional software needed on Ugreen
6. Config files (.env) automatically created with correct settings
7. Services will start automatically after docker-compose up -d

---

## Questions?

If anything fails during upload or setup:
1. Check Ugreen web UI error messages
2. Run `df -h` to check disk space
3. Run `sudo docker images` to verify what loaded
4. Run `sudo docker-compose logs -f` to see service logs
5. Check network connectivity: `ping YOUR_NAS_IP`

---

**Ready to proceed with upload!**

