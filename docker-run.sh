#!/bin/bash

# Transmission WireGuard Seeder - Container-only Setup
# For systems without docker-compose (e.g., Synology NAS)

set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source .env
    set +a
else
    echo "Warning: .env file not found. Please create one with your WireGuard configuration."
    echo "See .env.example for reference."
    exit 1
fi

# Set defaults
TZ=${TZ:-UTC}
PUID=${PUID:-1000}
PGID=${PGID:-1000}
WIREGUARD_ENDPOINT_PORT=${WIREGUARD_ENDPOINT_PORT:-51820}
DOWNLOADS_PATH=${DOWNLOADS_PATH:-./downloads}
WATCH_PATH=${WATCH_PATH:-./watch}

# Create required directories
mkdir -p "$DOWNLOADS_PATH"
mkdir -p "$WATCH_PATH"

# Create Docker volumes if they don't exist
docker volume create gluetun-data 2>/dev/null || true
docker volume create transmission-config 2>/dev/null || true

echo "Starting Gluetun VPN container..."
docker run -d \
    --name gluetun \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun:/dev/net/tun \
    -p 9091:9091 \
    -p 51413:51413 \
    -p 51413:51413/udp \
    -e VPN_SERVICE_PROVIDER=custom \
    -e VPN_TYPE=wireguard \
    -e WIREGUARD_PRIVATE_KEY="$WIREGUARD_PRIVATE_KEY" \
    -e WIREGUARD_PUBLIC_KEY="$WIREGUARD_PUBLIC_KEY" \
    -e WIREGUARD_PRESHARED_KEY="$WIREGUARD_PRESHARED_KEY" \
    -e WIREGUARD_ADDRESSES="$WIREGUARD_ADDRESSES" \
    -e WIREGUARD_ENDPOINT_IP="$WIREGUARD_ENDPOINT_IP" \
    -e WIREGUARD_ENDPOINT_PORT="$WIREGUARD_ENDPOINT_PORT" \
    -e TZ="$TZ" \
    -v gluetun-data:/gluetun \
    --restart unless-stopped \
    qmcgaw/gluetun:latest

echo "Waiting for Gluetun to establish VPN connection..."
sleep 10

echo "Starting Transmission container (using Gluetun's network)..."
docker run -d \
    --name transmission \
    --network=container:gluetun \
    -e PUID="$PUID" \
    -e PGID="$PGID" \
    -e TZ="$TZ" \
    -e TRANSMISSION_WEB_HOME=/config/flood-for-transmission/ \
    -v transmission-config:/config \
    -v "$(realpath "$DOWNLOADS_PATH")":/downloads \
    -v "$(realpath "$WATCH_PATH")":/watch \
    --restart unless-stopped \
    linuxserver/transmission:latest

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo "Transmission Web UI: http://localhost:9091"
echo ""
echo "To check VPN status:"
echo "  docker logs gluetun"
echo ""
echo "To stop containers:"
echo "  docker stop transmission gluetun"
echo ""
echo "To remove containers:"
echo "  docker rm transmission gluetun"
echo "========================================"
