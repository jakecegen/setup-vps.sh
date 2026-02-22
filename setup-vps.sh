#!/bin/bash

echo "╔═══════════════════════════════════════╗"
echo "║   🔧 Setup VPS sebagai RDP Gateway    ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ========== WARNA ==========
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ========== CEK ROOT ==========
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Jalankan sebagai root! (sudo bash setup-vps.sh)${NC}"
  exit 1
fi

# ========== INSTALL TAILSCALE ==========
echo -e "${YELLOW}📦 [1/5] Installing Tailscale...${NC}"
curl -fsSL https://tailscale.com/install.sh | sh
echo -e "${GREEN}✅ Tailscale terinstall${NC}"
echo ""

# ========== KONEK TAILSCALE ==========
echo -e "${YELLOW}🔗 [2/5] Menghubungkan Tailscale...${NC}"
echo "Pilih cara konek:"
echo "  1) Login manual (buka link di browser)"
echo "  2) Pakai Auth Key"
read -p "Pilihan (1/2): " choice

if [ "$choice" == "2" ]; then
  read -p "Masukkan Auth Key: " authkey
  tailscale up --authkey=$authkey --hostname=vps-gateway
else
  tailscale up --hostname=vps-gateway
fi

sleep 3

VPS_TAILSCALE_IP=$(tailscale ip -4)
echo -e "${GREEN}✅ Tailscale connected! IP: $VPS_TAILSCALE_IP${NC}"
echo ""

# ========== CEK STATUS ==========
echo -e "${YELLOW}📋 [3/5] Mengecek perangkat di jaringan Tailscale...${NC}"
tailscale status
echo ""

# ========== INPUT IP RDP ==========
echo -e "${YELLOW}🖥️ [4/5] Setup Port Forward...${NC}"
read -p "Masukkan IP Tailscale GitHub RDP (100.x.x.x): " RDP_IP
read -p "Port untuk akses dari HP (default: 9999): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-9999}

# ========== INSTALL SOCAT ==========
echo -e "${YELLOW}📦 Installing socat...${NC}"
apt update -y && apt install socat -y

# ========== AKTIFKAN IP FORWARD ==========
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# ========== BUKA FIREWALL ==========
echo -e "${YELLOW}🔥 Membuka firewall port $CUSTOM_PORT...${NC}"

# UFW (jika ada)
if command -v ufw &> /dev/null; then
  ufw allow $CUSTOM_PORT/tcp
  echo -e "${GREEN}✅ UFW: Port $CUSTOM_PORT dibuka${NC}"
fi

# iptables
iptables -A INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT
echo -e "${GREEN}✅ iptables: Port $CUSTOM_PORT dibuka${NC}"
echo ""

# ========== DAPATKAN IP PUBLIK =PS ==========
VPS_PUBLIC_IP=$(curl -s ifconfig.me)

# ========== TAMPILKAN INFO ==========
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║          ✅ SETUP SELESAI!                 ║"
echo "╠═══════════════════════════════════════════╣"
echo "║                                           ║"
echo "  📍 IP Publik VPS    : $VPS_PUBLIC_IP"
echo "  📍 IP Tailscale VPS : $VPS_TAILSCALE_IP"
echo "  📍 IP Tailscale RDP : $RDP_IP"
echo "  🔌 Port             : $CUSTOM_PORT"
echo "║                                           ║"
echo "╠═══════════════════════════════════════════╣"
echo "║                                           ║"
echo "  📱 CARA KONEK DARI HP:"
echo "  ─────────────────────"
echo "  Buka RD Client / Microsoft Remote Desktop"
echo ""
echo "  PC Name  : $VPS_PUBLIC_IP:$CUSTOM_PORT"
echo "  Username : runneradmin"
echo "  Password : (yang kamu set di GitHub Actions)"
echo "║                                           ║"
echo "╚═══════════════════════════════════════════╝"

# ========== JALANKAN PORT FORWARD ==========
echo ""
echo -e "${YELLOW}🚀 Menjalankan Port Forward...${NC}"
echo -e "${YELLOW}   $VPS_PUBLIC_IP:$CUSTOM_PORT → $RDP_IP:3389${NC}"
echo ""
echo -e "${RED}⚠️  JANGAN TUTUP TERMINAL INI!${NC}"
echo -e "${RED}   Port forward akan berhenti jika terminal ditutup.${NC}"
echo ""
echo -e "${GREEN}Tekan Ctrl+C untuk menghentikan.${NC}"
echo ""

# Jalankan socat (port forward)
socat TCP-LISTEN:$CUSTOM_PORT,fork,reuseaddr TCP:$RDP_IP:3389
