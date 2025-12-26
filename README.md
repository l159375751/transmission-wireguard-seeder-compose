# Transmission WireGuard Seeder

Secure BitTorrent seeding setup using [Transmission](https://transmissionbt.com/) with WireGuard VPN integration via [Gluetun](https://github.com/qdm12/gluetun). All Transmission traffic is routed through the VPN for privacy and security.

## Features

- [Transmission](https://transmissionbt.com/) BitTorrent client with web UI
- WireGuard VPN integration using [Gluetun](https://github.com/qdm12/gluetun)
- All torrent traffic routed through VPN
- Port forwarding support (if supported by your VPN provider)
- Automatic VPN reconnection
- Health checks for VPN connectivity
- Two deployment options: Docker Compose and standalone containers

## Prerequisites

- Docker installed on your system
- Docker Compose (only for compose method)
- WireGuard VPN credentials from your VPN provider
- `/dev/net/tun` device available (most systems have this by default)

## Setup

### 1. Clone or Download This Repository

```bash
git clone <repository-url>
cd transmission-wireguard-seeder-compose
```

### 2. Configure WireGuard Credentials

Copy the example environment file and fill in your WireGuard credentials:

```bash
cp .env.example .env
```

Edit `.env` and add your WireGuard VPN configuration:

```bash
# Required fields
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_PUBLIC_KEY=your_server_public_key_here
WIREGUARD_ADDRESSES=10.0.0.2/32
WIREGUARD_ENDPOINT_IP=1.2.3.4
WIREGUARD_ENDPOINT_PORT=51820

# Optional: adjust these as needed
TZ=UTC
PUID=1000
PGID=1000
DOWNLOADS_PATH=./downloads
WATCH_PATH=./watch
```

**Note:** `WIREGUARD_ENDPOINT_IP` must be an IP address, not a domain name.

### 3. Choose Your Deployment Method

## Deployment Option 1: Docker Compose

Best for systems with Docker Compose support.

```bash
docker-compose up -d
```

To view logs:

```bash
docker-compose logs -f
```

To stop:

```bash
docker-compose down
```

## Deployment Option 2: Standalone Containers

Best for systems without Docker Compose (e.g., Synology NAS).

```bash
./docker-run.sh
```

To stop containers:

```bash
docker stop transmission gluetun
```

To remove containers:

```bash
docker rm transmission gluetun
```

## Usage

### Accessing Transmission Web UI

Once running, access the Transmission web interface at:

```
http://localhost:9091
```

Default credentials (can be changed in Transmission settings):
- Username: `admin`
- Password: Check `/config/settings.json` in the transmission container

### Adding Torrents

You can add torrents in three ways:

1. **Web UI:** Upload .torrent files or add magnet links through the web interface
2. **Watch folder:** Place .torrent files in the `watch` directory (configured via `WATCH_PATH`)
3. **API/RPC:** Use Transmission's RPC API

### Download Location

Downloaded files will be saved to the directory specified by `DOWNLOADS_PATH` (default: `./downloads`).

## Verifying VPN Connection

Check that your traffic is routed through the VPN:

```bash
# Check Gluetun logs for VPN status
docker logs gluetun

# Check your public IP (should be your VPN IP)
docker exec gluetun wget -qO- https://api.ipify.org
```

## Port Forwarding

If your VPN provider supports port forwarding, you can configure it in the Gluetun container. Refer to the [Gluetun port forwarding documentation](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/port-forwarding.md).

## Troubleshooting

### VPN not connecting

- Verify your WireGuard credentials in `.env` are correct
- Check `WIREGUARD_ENDPOINT_IP` is an IP address (not a domain)
- View Gluetun logs: `docker logs gluetun`

### Cannot access Transmission Web UI

- Ensure port 9091 is exposed on the Gluetun container (not Transmission)
- Check if the containers are running: `docker ps`
- Verify VPN is connected: `docker logs gluetun`

### Slow download speeds

- Check VPN server load/location
- Verify your VPN provider doesn't throttle P2P traffic
- Enable port forwarding if supported by your VPN provider

## Configuration

### Transmission Settings

Transmission settings can be modified by editing the settings file:

```bash
docker exec transmission vi /config/settings.json
```

After editing, restart the container:

```bash
docker restart transmission
```

### Gluetun Settings

Additional Gluetun environment variables can be added to `docker-compose.yml` or `docker-run.sh`. See the [Gluetun documentation](https://github.com/qdm12/gluetun-wiki) for all available options.

## Architecture

This setup uses two containers:

1. **Gluetun** - VPN client container
   - Establishes WireGuard VPN connection
   - Exposes ports for Transmission (9091, 51413)
   - Provides network stack for Transmission

2. **Transmission** - BitTorrent client
   - Uses Gluetun's network stack (`network_mode: service:gluetun` or `--network=container:gluetun`)
   - All traffic automatically routed through VPN
   - Web UI accessible via Gluetun's exposed ports

## Security Notes

- Never commit your `.env` file with real credentials
- Use strong passwords for Transmission web UI
- Regularly update container images: `docker-compose pull` or `docker pull <image>`
- Monitor VPN connection status regularly

## License

This is a configuration repository. Refer to individual component licenses:
- [Gluetun](https://github.com/qdm12/gluetun)
- [Transmission](https://transmissionbt.com/)
- [LinuxServer.io Transmission](https://github.com/linuxserver/docker-transmission)

## Credits

- [Gluetun](https://github.com/qdm12/gluetun) by qdm12
- [LinuxServer.io](https://www.linuxserver.io/) for the Transmission Docker image
