#!/bin/bash

# Read NAS_HOST from .env if present, else fall back to this machine.
NAS_HOST="${NAS_HOST:-$(hostname -I 2>/dev/null | cut -d' ' -f1)}"
NAS_HOST="${NAS_HOST:-localhost}"
# Project NOMAD - Automated Setup on Ugreen NAS
# Run this after all files are uploaded to /volume1/docker/project-nomad/

set -e

echo "=========================================="
echo "Project NOMAD - Ugreen NAS Setup"
echo "=========================================="
echo ""

# Navigate to project directory
cd /volume1/docker/project-nomad

echo "[1/6] Loading Docker images..."
sudo docker load < project-nomad.tar.gz && echo "  âœ“ project-nomad"
sudo docker load < mysql.tar.gz && echo "  âœ“ mysql"
sudo docker load < redis.tar.gz && echo "  âœ“ redis"
sudo docker load < ollama.tar.gz && echo "  âœ“ ollama"
sudo docker load < qdrant.tar.gz && echo "  âœ“ qdrant"
sudo docker load < kiwix.tar.gz && echo "  âœ“ kiwix"
sudo docker load < dozzle.tar.gz && echo "  âœ“ dozzle"
sudo docker load < disk-collector.tar.gz && echo "  âœ“ disk-collector"
echo ""

echo "[2/6] Verifying images loaded..."
sudo docker images | grep -E 'nomad|mysql|redis|ollama|kiwix|qdrant|dozzle|disk'
echo ""

echo "[3/6] Configuring environment..."
mv .env.ugreen .env
echo "  âœ“ .env configured"
echo ""

echo "[4/6] Starting all services..."
sudo docker-compose -f docker-compose-ugreen.yml up -d
echo "  âœ“ Services started (waiting 120 seconds for startup...)"
sleep 120
echo ""

echo "[5/6] Checking service status..."
sudo docker-compose ps
echo ""

echo "[6/6] Health check..."
curl -s http://localhost:8080/api/health && echo "" || echo "  âš  Warning: Health check endpoint not responding yet"
echo ""

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Services available at:"
echo "  â€¢ Admin Dashboard:   http://${NAS_HOST}:8080"
echo "  â€¢ Kiwix Library:     http://${NAS_HOST}:8090"
echo "  â€¢ Dozzle Logs:       http://${NAS_HOST}:9999"
echo "  â€¢ Ollama API:        http://${NAS_HOST}:11434"
echo ""
echo "To view logs: sudo docker-compose logs -f"
echo "To stop all: sudo docker-compose down"
echo ""

