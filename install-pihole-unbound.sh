#!/bin/bash

# ------------------------------------------------------------
# Title: Pi-hole + Unbound Auto Installer
# Author: Matt [Polyphemous]
# License: MIT
# Created: May 2025
#
# Description:
#   Installs and configures Pi-hole with Unbound in Docker.
#
# AI Usage:
#   Script logic and automation refined with help from OpenAI's ChatGPT.
# ------------------------------------------------------------

# -----------------------------
# Require sudo/root
# -----------------------------
if [[ $EUID -ne 0 ]]; then
  echo "[❌] This installer must be run as root. Use: sudo $0"
  exit 1
fi

# -----------------------------
# Install curl if missing
# -----------------------------
if ! command -v curl &>/dev/null; then
  echo "[📦] Installing curl..."
  apt update && apt install -y curl
fi

# -----------------------------
# Install Docker if missing
# -----------------------------
if ! command -v docker &>/dev/null; then
  echo "[📦] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# -----------------------------
# Create directories
# -----------------------------
mkdir -p ~/pihole/{pihole,dnsmasq,unbound}
cd ~/pihole || exit 1

# -----------------------------
# docker-compose.yml
# -----------------------------
cat > docker-compose.yml << 'EOF'
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    environment:
      TZ: "America/New_York"
      DNSMASQ_LISTENING: "all"
      PIHOLE_DNS_1: "unbound#53"
      PIHOLE_DNS_2: ""
    volumes:
      - ./pihole:/etc/pihole
      - ./dnsmasq:/etc/dnsmasq.d
    restart: unless-stopped
    networks:
      - dns_network
    cap_add:
      - NET_ADMIN
    depends_on:
      - unbound

  unbound:
    container_name: unbound
    image: klutchell/unbound:latest
    volumes:
      - ./unbound:/opt/unbound/etc/unbound/custom
    restart: unless-stopped
    networks:
      - dns_network

networks:
  dns_network:
    driver: bridge
EOF

# -----------------------------
# Unbound config
# -----------------------------
cat > unbound/custom.conf << 'EOF'
server:
  verbosity: 1
  interface: 0.0.0.0
  port: 53
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  do-ip6: no
  harden-glue: yes
  harden-dnssec-stripped: yes
  use-caps-for-id: no
  edns-buffer-size: 1472
  prefetch: yes
  num-threads: 1
  so-rcvbuf: 1m
  access-control: 0.0.0.0/0 allow
  root-hints: "/opt/unbound/etc/unbound/custom/root.hints"
EOF

# -----------------------------
# Download root hints
# -----------------------------
curl -sS -o unbound/root.hints https://www.internic.net/domain/named.root

# -----------------------------
# dnsmasq config
# -----------------------------
cat > dnsmasq/02-lan-access.conf << 'EOF'
listen-address=0.0.0.0
bind-interfaces
domain-needed
bogus-priv
EOF

# -----------------------------
# SetupVars for initial config
# -----------------------------
cat > pihole/setupVars.conf << 'EOF'
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=0.0.0.0
DNSMASQ_LISTENING=all
PIHOLE_DNS_1=unbound#53
PIHOLE_DNS_2=
QUERY_LOGGING=true
INSTALL_WEB=true
REV_SERVER=false
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
BLOCKING_ENABLED=true
DNS_ALLOW_EXTERNAL=true
EOF

# -----------------------------
# Start containers
# -----------------------------
docker compose up -d

# -----------------------------
# Final notes
# -----------------------------
echo
echo "[✅] Pi-hole + Unbound installed and running!"
echo "[ℹ️] Visit the web interface at: http://<your-ip>/admin"
echo

# -----------------------------
# Prompt for password
# -----------------------------
echo "[🔐] Set your Pi-hole admin password now:"
docker exec -it pihole pihole setpassword