#!/bin/bash
# ============================================
# 🚀 High-End Auto Installer: Windows 11 on Docker + Cloudflare Tunnel
#    (7GB RAM | 4 Cores | 24/7 Keep-Alive)
# ============================================

set -e

echo "=== 🔧 Checking Root Access ==="
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Script ini butuh akses root. Jalankan dengan: sudo bash script.sh"
  exit 1
fi

echo "=== ⚙️ Checking KVM Support ==="
if [ -e /dev/kvm ]; then
  echo "✅ KVM found! High Performance Mode Enabled."
else
  echo "⚠️ WARNING: /dev/kvm not found! Windows might be slow."
  echo "   Make sure Virtualization is enabled in BIOS/Cloud Panel."
  sleep 3
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker.io docker-compose-plugin -y 2>/dev/null || apt install docker-compose -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja dockercom ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== 🧾 Membuat file windows.yml (High-End Config) ==="
# Setting RAM to 7GB and Cores to 4 as requested
cat > windows.yml <<'EOF'
version: "3.9"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "7G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
      - "3389:3389/tcp"
      - "3389:3389/udp"
    volumes:
      - /tmp/windows-storage:/storage
    restart: always
    stop_grace_period: 2m
EOF

echo
echo "=== ✅ File windows.yml berhasil dibuat ==="

echo
echo "=== 🚀 Menjalankan Windows 11 container ==="
docker compose -f windows.yml up -d 2>/dev/null || docker-compose -f windows.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses web & RDP ==="
# Kill old tunnels if any
pkill cloudflared || true

nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &

echo "⏳ Waiting for Cloudflare tunnels to generate links (10 seconds)..."
sleep 10

CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_web.log | head -n 1)
CF_RDP=$(grep -o "tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*" /var/log/cloudflared_rdp.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Instalasi Selesai (High-End Configuration)"
echo
if [ -n "$CF_WEB" ]; then
  echo "🌍 Web Console (Browser Link):"
  echo "    ${CF_WEB}"
else
  echo "⚠️ Web Link not found yet. Check logs later."
fi

if [ -n "$CF_RDP" ]; then
  echo
  echo "🖥️  RDP Address (Use in Remote Desktop App):"
  echo "    ${CF_RDP}"
else
  echo "⚠️ RDP Link not found yet. Check logs later."
fi

echo
echo "🔑 Username: MASTER"
echo "🔒 Password: admin@123"
echo "=============================================="

# ==========================================
# 🛑 ANTI-DISCONNECT / KEEP-ALIVE LOOP
# ==========================================
echo
echo "🚀 Starting 24/7 Keep-Alive System..."
echo "⚠️  DO NOT CLOSE THIS TERMINAL. Minimize it."
echo

while true; do
    # 1. Print Timestamp & Status
    echo "[$(date)] ✅ System Active | Windows RAM: 7GB | Status: $(docker inspect -f '{{.State.Status}}' windows 2>/dev/null || echo 'Stopped')"
    
    # 2. Check Tunnel Health
    if ! pgrep -x "cloudflared" > /dev/null; then
        echo "[$(date)] ⚠️ Tunnel died! Restarting..."
        nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
        nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &
    fi

    # 3. Network Activity (Ping Google)
    curl -s --head https://www.google.com > /dev/null

    # 4. Wait 5 minutes
    sleep 300
done