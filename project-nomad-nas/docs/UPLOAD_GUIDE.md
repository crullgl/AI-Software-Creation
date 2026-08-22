<!--
  SANITISED COPY. The original of this file lives on the NAS and contains
  the real NAS username and password in clear text - which is exactly why
  it is not published as-is. Credentials below are placeholders.
-->
# Project NOMAD Migration - Upload to Ugreen NAS

## Files Ready for Upload (10 files, 4.05 GB)
- âœ“ disk-collector.tar.gz (6.68 MB)
- âœ“ dozzle.tar.gz (16.94 MB)
- âœ“ kiwix.tar.gz (25.05 MB)
- âœ“ mysql.tar.gz (221.98 MB)
- âœ“ ollama.tar.gz (3168.21 MB) â† **LARGEST**
- âœ“ project-nomad.tar.gz (528.19 MB)
- âœ“ qdrant.tar.gz (68.39 MB)
- âœ“ redis.tar.gz (16.42 MB)
- âœ“ docker-compose-ugreen.yml (config)
- âœ“ .env.ugreen (config)

## Upload Method: Ugreen File Manager UI (Easiest & Most Reliable)

### Step 1: Access Ugreen Web UI
1. Open browser: **http://YOUR_NAS_IP:8000**
2. Login with credentials:
   - Username: `YOUR_NAS_USERNAME`
   - Password: `YOUR_NAS_PASSWORD`

### Step 2: Create Target Directory
1. Navigate to "File Manager"
2. Go to `/volume1/`
3. Create new folder: `docker`
4. Inside docker, create: `project-nomad`
5. Full path should be: `/volume1/docker/project-nomad/`

### Step 3: Upload Files via Web UI
1. Open `/volume1/docker/project-nomad/`
2. Click "Upload" button
3. Select all 10 files from `C:\Users\YOU\nomad-migration\`
4. **Upload order (upload largest first to detect issues early):**
   - ollama.tar.gz (3.2 GB) - Wait for completion
   - project-nomad.tar.gz (528 MB)
   - mysql.tar.gz (222 MB)
   - qdrant.tar.gz (68 MB)
   - dozzle.tar.gz (17 MB)
   - kiwix.tar.gz (25 MB)
   - redis.tar.gz (16 MB)
   - disk-collector.tar.gz (7 MB)
   - docker-compose-ugreen.yml
   - .env.ugreen
5. Monitor upload progress in web UI
6. **Total upload time: 10-30 minutes** (depends on network speed)

### Step 4: Verify All Files Uploaded
In Ugreen File Manager, check `/volume1/docker/project-nomad/`:
```
âœ“ disk-collector.tar.gz
âœ“ dozzle.tar.gz
âœ“ kiwix.tar.gz
âœ“ mysql.tar.gz
âœ“ ollama.tar.gz
âœ“ project-nomad.tar.gz
âœ“ qdrant.tar.gz
âœ“ redis.tar.gz
âœ“ docker-compose-ugreen.yml
âœ“ .env.ugreen
```

## Next: Load Images & Start Services (SSH)

Once all files are verified on Ugreen, use the SSH script below:

### SSH into Ugreen
```powershell
ssh YOUR_NAS_USERNAME@YOUR_NAS_IP -p 22
# Password: YOUR_NAS_PASSWORD
```

### Run This Command to Load & Start Everything
```bash
cd /volume1/docker/project-nomad && \
sudo docker load < project-nomad.tar.gz && echo "âœ“ project-nomad loaded" && \
sudo docker load < mysql.tar.gz && echo "âœ“ mysql loaded" && \
sudo docker load < redis.tar.gz && echo "âœ“ redis loaded" && \
sudo docker load < ollama.tar.gz && echo "âœ“ ollama loaded" && \
sudo docker load < qdrant.tar.gz && echo "âœ“ qdrant loaded" && \
sudo docker load < kiwix.tar.gz && echo "âœ“ kiwix loaded" && \
sudo docker load < dozzle.tar.gz && echo "âœ“ dozzle loaded" && \
sudo docker load < disk-collector.tar.gz && echo "âœ“ disk-collector loaded" && \
echo "All images loaded!" && \
sudo docker images | grep -E 'nomad|mysql|redis|ollama|kiwix|qdrant|dozzle' && \
mv .env.ugreen .env && \
sudo docker-compose -f docker-compose-ugreen.yml up -d && \
echo "Services starting..." && \
sleep 120 && \
sudo docker-compose ps && \
curl http://localhost:8080/api/health && \
echo "âœ“ All services running!"
```

## Access Services After Migration

Once services are running:
- **Admin Dashboard**: http://YOUR_NAS_IP:8080
- **Kiwix Library**: http://YOUR_NAS_IP:8090
- **Dozzle Logs**: http://YOUR_NAS_IP:9999
- **Ollama API**: http://YOUR_NAS_IP:11434

## Troubleshooting

### If upload fails:
1. Check Ugreen web UI for error messages
2. Try uploading files one at a time
3. Verify available space: `/volume2` has 7.0 TB free

### If docker load fails:
1. Check disk space: `df -h`
2. Check Docker daemon: `sudo systemctl status docker`
3. Check logs: `sudo docker-compose logs`

### If services won't start:
1. Verify images loaded: `sudo docker images`
2. Check .env file: `cat .env`
3. Check ports available: `sudo netstat -tulpn | grep LISTEN`
4. View logs: `sudo docker-compose logs -f`

## Important Notes
- **Data folder** (500+ GB) can be added later if needed
- **Backup your .env file** after first successful startup
- All services were tested on Windows PC and working
- SSH connection to Ugreen verified (Docker 26.1.0 confirmed)

