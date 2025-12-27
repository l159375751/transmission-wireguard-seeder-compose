#!/bin/bash

# Quick run script for testing Transmission with custom image
# For production use, use podman-run.sh or podman-compose.yml

# Build custom image if it doesn't exist
if ! podman images | grep -q "localhost/transmission-wg"; then
    echo "Building custom transmission-wg image..."
    podman build -t transmission-wg:latest .
fi

sudo podman run --rm --name transmission \
  --network ns:/run/netns/transmission-vpn \
  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
  -v transmission-data:/data \
  -v /home/user/test/transmission-wireguard-seeder-compose/downloads:/downloads \
  -v /home/user/test/transmission-wireguard-seeder-compose/watch:/watch \
  localhost/transmission-wg:latest


# Detached mode version (commented out)
#sudo podman run -d --name transmission \
#  --network ns:/run/netns/transmission-vpn \
#  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
#  -v transmission-data:/data \
#  -v /home/user/test/transmission-wireguard-seeder-compose/downloads:/downloads \
#  -v /home/user/test/transmission-wireguard-seeder-compose/watch:/watch \
#  --restart unless-stopped \
#  localhost/transmission-wg:latest
