#!/bin/bash

# Transmission with WireGuard via wg-netns - Podman Standalone Script
# This script starts Transmission attached to the wg-netns namespace

set -e

echo "=== Starting Transmission with wg-netns ==="
echo

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source .env
    set +a
else
    echo "Warning: .env file not found. Using default values."
fi

# Set defaults
TZ=${TZ:-UTC}
PUID=${PUID:-1000}
PGID=${PGID:-1000}
DOWNLOADS_PATH=${DOWNLOADS_PATH:-./downloads}
WATCH_PATH=${WATCH_PATH:-./watch}

# Check if namespace exists
if ! sudo ip netns list | grep -q "transmission-vpn"; then
    echo "Error: WireGuard namespace 'transmission-vpn' not found"
    echo
    echo "Please run the setup script first:"
    echo "  sudo ./setup-wg-netns.sh"
    echo
    echo "Or manually start the namespace:"
    echo "  sudo wg-netns up transmission-vpn"
    exit 1
fi

# Create required directories
mkdir -p "$DOWNLOADS_PATH"
mkdir -p "$WATCH_PATH"

# Create podman volume if it doesn't exist
podman volume create transmission-config 2>/dev/null || true

echo "Building custom Transmission image..."
podman build -t transmission-wg:latest .

echo
echo "Starting Transmission container attached to wg-netns namespace..."
echo

podman run -d \
    --name transmission \
    --network ns:/run/netns/transmission-vpn \
    -e PUID="$PUID" \
    -e PGID="$PGID" \
    -e TZ="$TZ" \
    -v transmission-data:/data \
    -v "$(realpath "$DOWNLOADS_PATH")":/downloads \
    -v "$(realpath "$WATCH_PATH")":/watch \
    --restart unless-stopped \
    localhost/transmission-wg:latest

echo
echo "========================================"
echo "Transmission started successfully!"
echo "========================================"
echo
echo "Container is running in the wg-netns namespace 'transmission-vpn'"
echo
echo "To verify VPN connection:"
echo "  podman exec transmission curl -s https://ipinfo.io"
echo
echo "To access Transmission Web UI, you need to set up port forwarding:"
echo "  In another terminal, run:"
echo "  sudo socat TCP-LISTEN:9091,fork,reuseaddr EXEC:'ip netns exec transmission-vpn socat STDIO TCP:127.0.0.1:9091'"
echo
echo "Then access: http://localhost:9091"
echo
echo "To view logs:"
echo "  podman logs -f transmission"
echo
echo "To stop Transmission:"
echo "  podman stop transmission"
echo
echo "To remove Transmission:"
echo "  podman rm transmission"
echo "========================================"
