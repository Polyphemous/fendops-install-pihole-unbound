# Create project structure
mkdir -p ~/pihole/{pihole,dnsmasq,unbound}
cd ~/pihole

# Create docker-compose.yml
cat > docker-compose.yml << EOF
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
      WEBPASSWORD: "$PIHOLE_PW"
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

# Create unbound config
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

# Download root hints
curl -o unbound/root.hints https://www.internic.net/domain/named.root

# Create dnsmasq config
cat > dnsmasq/02-lan-access.conf << 'EOF'
listen-address=0.0.0.0
bind-interfaces
domain-needed
bogus-priv
EOF

# Pre-load Pi-hole config to allow remote clients
cat > pihole/setupVars.conf << 'EOF'
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=0.0.0.0
DNSMASQ_LISTENING=all
PIHOLE_DNS_1=unbound#53
PIHOLE_DNS_2=
QUERY_LOGGING=true
INSTALL_WEB=true
WEBPASSWORD=$PIHOLE_PW
REV_SERVER=false
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
BLOCKING_ENABLED=true
DNS_ALLOW_EXTERNAL=true
EOF

# Start containers
docker compose up -d

docker exec -it pihole pihole setpassword