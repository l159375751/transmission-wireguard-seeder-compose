FROM python:3.14-alpine3.23

# Install Transmission, network tools, and WireGuard utilities
RUN apk add --no-cache \
    transmission-daemon \
    transmission-remote \
    tcpdump \
    wireguard-tools \
    curl \
    iputils \
    bind-tools

# Create necessary directories
RUN mkdir -p /downloads /data /watch

# Set working directory
WORKDIR /data

# Expose Transmission ports
# 9091: Web UI
# 51413: BitTorrent peer port (TCP/UDP)
EXPOSE 9091 51413 51413/udp

# Run Transmission daemon in foreground
CMD ["transmission-daemon", "--foreground", "--config-dir", "/data"]
