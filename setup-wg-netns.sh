#!/bin/bash

# Setup script for wg-netns with Transmission
# This script creates the WireGuard configuration and starts the namespace

set -e

echo "=== Transmission WireGuard Setup with wg-netns ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables from .env file
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Please copy .env.example to .env and configure your WireGuard settings"
    exit 1
fi

echo "Loading configuration from .env..."
set -a
source .env
set +a

# Validate required variables
if [ -z "$WIREGUARD_PRIVATE_KEY" ] || [ -z "$WIREGUARD_PUBLIC_KEY" ] || [ -z "$WIREGUARD_ADDRESS" ] || [ -z "$WIREGUARD_ENDPOINT" ]; then
    echo "Error: Missing required WireGuard configuration in .env"
    echo "Required variables: WIREGUARD_PRIVATE_KEY, WIREGUARD_PUBLIC_KEY, WIREGUARD_ADDRESS, WIREGUARD_ENDPOINT"
    exit 1
fi

# Create wireguard configuration directory if it doesn't exist
mkdir -p /etc/wireguard

# Create wg-netns configuration file
echo "Creating /etc/wireguard/transmission-vpn.json..."

# Build DNS server array
DNS_ARRAY="[]"
if [ -n "$WIREGUARD_DNS" ]; then
    # Convert comma-separated DNS to JSON array
    DNS_ARRAY="[\"$(echo "$WIREGUARD_DNS" | sed 's/,/","/g')\"]"
fi

# Build preshared-key field
PRESHARED_KEY_FIELD=""
if [ -n "$WIREGUARD_PRESHARED_KEY" ]; then
    PRESHARED_KEY_FIELD=",\"preshared-key\": \"$WIREGUARD_PRESHARED_KEY\""
fi

# Build optional interface fields
LISTEN_PORT_FIELD=""
if [ -n "$WIREGUARD_LISTEN_PORT" ]; then
    LISTEN_PORT_FIELD=",\"listen-port\": $WIREGUARD_LISTEN_PORT"
fi

MTU_FIELD=""
if [ -n "$WIREGUARD_MTU" ]; then
    MTU_FIELD=",\"mtu\": $WIREGUARD_MTU"
fi

cat > /etc/wireguard/transmission-vpn.json <<EOF
{
  "name": "transmission-vpn",
  "managed": true,
  "dns-server": $DNS_ARRAY,
  "interfaces": [
    {
      "name": "wg0",
      "address": ["$WIREGUARD_ADDRESS"],
      "private-key": "$WIREGUARD_PRIVATE_KEY"$LISTEN_PORT_FIELD$MTU_FIELD,
      "peers": [
        {
          "public-key": "$WIREGUARD_PUBLIC_KEY"$PRESHARED_KEY_FIELD,
          "endpoint": "$WIREGUARD_ENDPOINT",
          "persistent-keepalive": 25,
          "allowed-ips": ["0.0.0.0/0", "::/0"]
        }
      ]
    }
  ]
}
EOF

echo "Configuration created successfully!"
echo

# Check if wg-netns is installed
if ! command -v wg-netns &> /dev/null; then
    echo "Warning: wg-netns command not found"
    echo "Please install wg-netns first:"
    echo "  curl -o ~/.local/bin/wg-netns https://raw.githubusercontent.com/dadevel/wg-netns/main/wgnetns/main.py"
    echo "  chmod +x ~/.local/bin/wg-netns"
    echo "  sudo ln -s ~/.local/bin/wg-netns /usr/local/bin/wg-netns"
    exit 1
fi

echo "Starting WireGuard namespace..."
wg-netns up transmission-vpn

echo
echo "=== Verifying VPN connection ==="
ip netns exec transmission-vpn wg show

echo
echo "=== Checking external IP ==="
ip netns exec transmission-vpn curl -s https://ipinfo.io | head -10

echo
echo "=== Setup Complete ==="
echo
echo "WireGuard namespace 'transmission-vpn' is now running!"
echo
echo "Next steps:"
echo "  1. Start Transmission with Podman:"
echo "     podman-compose up -d"
echo "  or:"
echo "     ./podman-run.sh"
echo
echo "  2. Setup port forwarding (in another terminal):"
echo "     sudo ./extras/netns-publish.sh 9091 transmission-vpn 127.0.0.1:9091"
echo
echo "To stop the namespace:"
echo "  sudo wg-netns down transmission-vpn"
