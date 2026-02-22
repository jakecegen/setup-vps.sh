#!/bin/bash

# ========== WARNA ==========
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║   🔧 Setup VPS Gateway untuk RDP      ║"
echo "║   📱 Akses RDP dari HP tanpa Tailscale ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ========== CEK ROOT ==========
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Jalankan sebagai root!${NC}"
  echo -e "${YELLOW}   Ketik: sudo bash setup-vps.sh${NC}"
  exit 1
fi

# ========== DETEKSI IP PUBLIK VPS ==========
echo -e "${YELLOW}🌐 [1/6] Mendeteksi IP Publik VPS...${NC}"
VPS_PUBLIC_IP=$(curl -s ifconfig.me)

if [ -z "$VPS_PUBLIC_IP" ]; then
  VPS_PUBLIC_IP=$(curl -s api.ipify.org)
fi

if [ -z "$VPS_PUBLIC_IP" ]; then
  VPS_PUBLIC_IP=$(curl -s icanhazip.com)
fi

if [ -z "$VPS_PUBLIC_IP" ]; then
  echo -e "${RED}❌ Gagal mendeteksi IP Publik!${NC}"
  read -p "Masukkan IP Publik VPS manual: " VPS_PUBLIC_IP
fi

echo -e "${GREEN}✅ IP Publik VPS: $VPS_PUBLIC_IP${NC}"
echo ""

# ========== INSTALL TAILSCALE ==========
echo -e "${YELLOW}📦 [2/6] Installing Tailscale...${NC}"

if command -v tailscale &> /dev/null; then
  echo -e "${GREEN}✅ Tailscale sudah terinstall${NC}"
else
  curl -fsSL https://tailscale.com/install.sh | sh
  echo -e "${GREEN}✅ Tailscale berhasil diinstall${NC}"
fi
echo ""

# ========== KONEK TAILSCALE VIA AUTH KEY ==========
echo -e "${YELLOW}🔗 [3/6] Menghubungkan Tailscale...${NC}"
echo ""
read -p "  Masukkan Auth Key: " AUTHKEY
echo ""

tailscale up --authkey=$AUTHKEY --hostname=vps-gateway

sleep 3

VPS_TAILSCALE_IP=$(tailscale ip -4)

if [ -z "$VPS_TAILSCALE_IP" ]; then
  echo -e "${RED}❌ Gagal konek Tailscale! Cek Auth Key kamu${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Tailscale Connected! IP: $VPS_TAILSCALE_IP${NC}"
echo ""

# ========== CEK PERANGKAT ==========
echo -e "${YELLOW}📋 [4/6] Perangkat di jaringan Tailscale:${NC}"
echo ""
tailscale status
echo ""

# ========== AUTO DETECT IP RDP ==========
echo -e "${YELLOW}🖥️ [5/6] Mencari GitHub RDP...${NC}"
echo ""

RDP_IP=$(tailscale status | grep "github-rdp" | awk '{print $1}')

if [ -z "$RDP_IP" ]; then
  echo -e "${RED}⚠️  GitHub RDP tidak terdeteksi otomatis${NC}"
  echo ""
  tailscale status
  echo ""
  read -p "  Masukkan IP Tailscale GitHub RDP (100.x.x.x): " RDP_IP
else
  echo -e "${GREEN}✅ GitHub RDP ditemukan: $RDP_IP${NC}"
  echo ""
  read -p "  Gunakan IP ini? (y/n): " confirm
  if [ "$confirm" != "y" ]; then
    read -p "  Masukkan IP Tailscale GitHub RDP manual: " RDP_IP
  fi
fi

echo ""

# ========== SET PORT ==========
read -p "  Port untuk akses dari HP (default 9999): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-9999}
echo ""

# ========== SETUP PORT FORWARD ==========
echo -e "${YELLOW}📦 [6/6] Menyiapkan Port Forward...${NC}"
apt update -y > /dev/null 2>&1
apt install socat -y > /dev/null 2>&1
echo -e "${GREEN}✅ Socat terinstall${NC}"

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf 2>/dev/null
sysctl -p > /dev/null 2>&1
echo -e "${GREEN}✅ IP Forward aktif${NC}"

if command -v ufw &> /dev/null; then
  ufw allow $CUSTOM_PORT/tcp > /dev/null 2>&1
fi
iptables -A INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null
echo -e "${GREEN}✅ Firewall port $CUSTOM_PORT dibuka${NC}"
echo ""

# ========== TAMPILKAN HASIL ==========
clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║            ✅ SETUP SELESAI!                      ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "  🌐 IP Publik VPS     : $VPS_PUBLIC_IP"
echo "  📍 IP Tailscale VPS  : $VPS_TAILSCALE_IP"
echo "  🖥️  IP Tailscale RDP  : $RDP_IP"
echo "  🔌 Port Forward      : $CUSTOM_PORT"
echo "║                                                  ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "  📱 CARA KONEK DARI HP:"
echo "  ════════════════════════════════════"
echo ""
echo "  1. Buka aplikasi RD Client di HP"
echo "  2. Klik (+) → Add PC"
echo "  3. Isi seperti ini:"
echo ""
echo -e "  ┌─────────────────────────────────────┐"
echo -e "  │                                     │"
echo -e "  │  PC Name : ${CYAN}$VPS_PUBLIC_IP:$CUSTOM_PORT${GREEN}  │"
echo -e "  │  User    : ${CYAN}runneradmin${GREEN}               │"
echo -e "  │  Pass    : ${CYAN}winaryo321${GREEN}                │"
echo -e "  │                                     │"
echo -e "  └─────────────────────────────────────┘"
echo ""
echo "  4. Klik Connect ✅"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ========== SIMPAN INFO KE FILE ==========
cat > /root/rdp-info.txt << EOF
========================================
  RDP CONNECTION INFO
========================================
  
  Konek dari HP:
  PC Name : $VPS_PUBLIC_IP:$CUSTOM_PORT
  User    : runneradmin
  Pass    : winaryo321

  IP Publik VPS    : $VPS_PUBLIC_IP
  IP Tailscale VPS : $VPS_TAILSCALE_IP
  IP Tailscale RDP : $RDP_IP
  Port             : $CUSTOM_PORT

========================================
EOF

echo -e "${YELLOW}💾 Info disimpan di /root/rdp-info.txt${NC}"
echo -e "${YELLOW}   Ketik: cat /root/rdp-info.txt${NC}"
echo ""
echo -e "${RED}══════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  JANGAN TUTUP TERMINAL INI!${NC}"
echo -e "${RED}   Port forward berjalan di bawah...${NC}"
echo -e "${RED}   Tekan Ctrl+C untuk menghentikan${NC}"
echo -e "${RED}══════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}🚀 Port Forward aktif: $VPS_PUBLIC_IP:$CUSTOM_PORT → $RDP_IP:3389${NC}"
echo ""

# ========== JALANKAN PORT FORWARD ==========
socat TCP-LISTEN:$CUSTOM_PORT,fork,reuseaddr TCP:$RDP_IP:3389
