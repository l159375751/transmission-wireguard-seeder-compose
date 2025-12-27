# Transmission WireGuard Seeder

Secure BitTorrent seeding setup using [Transmission](https://transmissionbt.com/) with WireGuard VPN via [wg-netns](https://github.com/dadevel/wg-netns). All Transmission traffic is routed through the VPN using Linux network namespaces for true kernel-level isolation.

## Features

- [Transmission](https://transmissionbt.com/) BitTorrent client with web UI
- WireGuard VPN using [wg-netns](https://github.com/dadevel/wg-netns) (lightweight Python script)
- All torrent traffic routed through VPN with guaranteed no-leak isolation
- Podman container integration (native network namespace support)
- Minimal resource overhead - no VPN container needed
- Systemd service support for auto-start on boot
- Port forwarding support (if supported by your VPN provider)

## Why wg-netns instead of Gluetun?

**wg-netns** creates a Linux network namespace on the host with a WireGuard interface. Podman containers can attach directly to this namespace, inheriting the VPN connection. This approach:

- ✅ Lightweight - single Python script vs full container
- ✅ True isolation - kernel-level network namespace
- ✅ No container overhead - VPN runs on host
- ✅ Works perfectly with Podman's native namespace support
- ✅ Maximum performance and minimal resource usage

## Prerequisites

- Linux host (network namespaces are a Linux kernel feature)
- Podman installed (Docker doesn't support network namespaces well)
- Python 3.7 or newer
- `iproute2` package (provides `ip` command)
- `wireguard-tools` package (provides `wg` command)
- WireGuard VPN credentials from your VPN provider
- Root/sudo access (required for creating network namespaces)

### Install Prerequisites

**Debian/Ubuntu:**
```bash
sudo apt install podman python3 python3-toml iproute2 wireguard-tools curl
```

**Fedora:**
```bash
sudo dnf install podman python3 iproute wireguard-tools curl
```

**Arch Linux:**
```bash
sudo pacman -S podman python iproute2 wireguard-tools
```

## Quick Start

### 1. Install wg-netns

```bash
curl -o ~/.local/bin/wg-netns https://raw.githubusercontent.com/dadevel/wg-netns/main/wgnetns/main.py
chmod +x ~/.local/bin/wg-netns
sudo ln -s ~/.local/bin/wg-netns /usr/local/bin/wg-netns
```

### 2. Configure WireGuard Credentials

Copy the example environment file and fill in your WireGuard credentials:

```bash
cp .env.example .env
nano .env
```

Edit `.env` with your VPN provider's WireGuard configuration:

```bash
# Required fields
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_PUBLIC_KEY=your_server_public_key_here
WIREGUARD_ADDRESS=10.0.0.2/32
WIREGUARD_ENDPOINT=vpn.example.com:51820

# Optional fields
WIREGUARD_PRESHARED_KEY=
WIREGUARD_DNS=
TZ=UTC
PUID=1000
PGID=1000
DOWNLOADS_PATH=/path/to/downloads
WATCH_PATH=/path/to/watch
```

### 3. Setup WireGuard Namespace

Run the setup script to create the WireGuard configuration and start the namespace:

```bash
sudo ./setup-wg-netns.sh
```

This script will:
- Create `/etc/wireguard/transmission-vpn.json` from your `.env` file
- Start the `transmission-vpn` network namespace
- Verify the VPN connection

### 4. Start Transmission

**Option A: Using Podman Compose**

```bash
podman-compose up -d
```

**Option B: Using Standalone Script**

```bash
./podman-run.sh
```

### 5. Setup Port Forwarding (Access Web UI)

Since Transmission is running inside a network namespace, you need to forward ports to access the web UI:

```bash
sudo socat TCP-LISTEN:9091,fork,reuseaddr EXEC:'ip netns exec transmission-vpn socat STDIO TCP:127.0.0.1:9091'
```

Keep this running in a separate terminal, or run it in the background.

### 6. Access Transmission Web UI

Navigate to: **http://localhost:9091**

Default credentials:
- Username: `admin` (can be changed in settings)
- Password: Check `/config/settings.json` in the container

## Usage

### Verifying VPN Connection

Check that Transmission is using the VPN:

```bash
# Check Transmission's external IP (should be your VPN IP)
podman exec transmission curl -s https://ipinfo.io

# Check WireGuard status
sudo ip netns exec transmission-vpn wg show

# Check namespace routing
sudo ip netns exec transmission-vpn ip route
```

### Managing the Namespace

**Check if namespace is running:**
```bash
sudo ip netns list
```

**Stop the namespace:**
```bash
sudo wg-netns down transmission-vpn
```

**Restart the namespace:**
```bash
sudo wg-netns down transmission-vpn
sudo wg-netns up transmission-vpn
```

### Managing Transmission Container

**View logs:**
```bash
podman logs -f transmission
```

**Stop container:**
```bash
podman stop transmission
```

**Start container:**
```bash
podman start transmission
```

**Remove container:**
```bash
podman rm transmission
```

**Restart container:**
```bash
podman restart transmission
```

### Adding Torrents

You can add torrents in three ways:

1. **Web UI:** Upload .torrent files or add magnet links through http://localhost:9091
2. **Watch folder:** Place .torrent files in the `watch` directory (configured via `WATCH_PATH`)
3. **API/RPC:** Use Transmission's RPC API

### Download Location

Downloaded files will be saved to the directory specified by `DOWNLOADS_PATH` in your `.env` file.

## Systemd Service (Auto-start on Boot)

### Setup wg-netns as a systemd service

**1. Download the systemd service file:**
```bash
sudo curl -o /etc/systemd/system/wg-netns@.service \
  https://raw.githubusercontent.com/dadevel/wg-netns/main/extras/wg-netns@.service
```

**2. Enable and start the service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now wg-netns@transmission-vpn.service
```

**3. Check status:**
```bash
sudo systemctl status wg-netns@transmission-vpn.service
```

### Setup Transmission as a systemd user service

Create `~/.config/systemd/user/transmission.service`:

```ini
[Unit]
Description=Transmission BitTorrent Client in WireGuard Namespace
After=wg-netns@transmission-vpn.service
Requires=wg-netns@transmission-vpn.service

[Service]
Type=simple
ExecStart=/usr/bin/podman run --rm --name transmission \
  --network ns:/run/netns/transmission-vpn \
  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
  -v transmission-config:/config \
  -v /path/to/downloads:/downloads \
  -v /path/to/watch:/watch \
  docker.io/linuxserver/transmission:latest
ExecStop=/usr/bin/podman stop transmission
Restart=on-failure

[Install]
WantedBy=default.target
```

**Enable and start:**
```bash
systemctl --user daemon-reload
systemctl --user enable --now transmission.service
```

## Port Forwarding (VPN Provider Feature)

If your VPN provider supports port forwarding, configure it in the wg-netns configuration.

Edit `/etc/wireguard/transmission-vpn.json` and add a `post-up` hook:

```json
{
  "name": "transmission-vpn",
  "managed": true,
  "post-up": "echo 'Port forwarding setup here'",
  "interfaces": [
    ...
  ]
}
```

Refer to your VPN provider's documentation for specific port forwarding setup instructions.

## Troubleshooting

### Namespace not found

```bash
Error: WireGuard namespace 'transmission-vpn' not found
```

**Solution:** Start the namespace first:
```bash
sudo wg-netns up transmission-vpn
```

### VPN not connecting

**Check logs:**
```bash
sudo journalctl -u wg-netns@transmission-vpn.service -f
```

**Verify configuration:**
```bash
sudo cat /etc/wireguard/transmission-vpn.json
```

**Test connection manually:**
```bash
sudo ip netns exec transmission-vpn ping 1.1.1.1
sudo ip netns exec transmission-vpn curl https://ipinfo.io
```

### Cannot access Transmission Web UI

**Ensure port forwarding is running:**
```bash
sudo socat TCP-LISTEN:9091,fork,reuseaddr EXEC:'ip netns exec transmission-vpn socat STDIO TCP:127.0.0.1:9091'
```

**Check if Transmission is running:**
```bash
podman ps | grep transmission
```

**Check Transmission logs:**
```bash
podman logs transmission
```

### DNS not working inside namespace

**Check DNS configuration:**
```bash
sudo ip netns exec transmission-vpn cat /etc/resolv.conf
```

**Set DNS manually in `/etc/wireguard/transmission-vpn.json`:**
```json
{
  "dns-server": ["1.1.1.1", "8.8.8.8"],
  ...
}
```

### Slow download speeds

- Check VPN server load/location (try different endpoint)
- Verify your VPN provider doesn't throttle P2P traffic
- Enable port forwarding if supported by your VPN provider
- Check if Transmission peer port is open (default 51413)

## Architecture

This setup uses a lightweight architecture:

1. **wg-netns** (Python script on host)
   - Creates Linux network namespace `transmission-vpn`
   - Establishes WireGuard VPN connection in that namespace
   - All traffic in namespace is routed through VPN

2. **Transmission** (Podman container)
   - Attaches to `transmission-vpn` namespace via `--network ns:/run/netns/transmission-vpn`
   - Inherits the namespace's VPN network stack
   - All traffic automatically goes through VPN
   - True kernel-level isolation prevents leaks

**Namespace location:** `/run/netns/transmission-vpn`

## Security Notes

- Never commit your `.env` file with real credentials to git
- The `.gitignore` file already excludes `.env` files
- Use strong passwords for Transmission web UI
- Regularly update: `podman pull docker.io/linuxserver/transmission:latest`
- Monitor VPN connection status regularly
- wg-netns provides true network isolation - no traffic can leak outside the namespace

## Configuration Files

- **`.env`** - Your WireGuard credentials (not committed to git)
- **`.env.example`** - Template for environment variables
- **`/etc/wireguard/transmission-vpn.json`** - Generated wg-netns configuration
- **`transmission-vpn.json`** - Template with variable placeholders
- **`podman-compose.yml`** - Podman Compose configuration
- **`setup-wg-netns.sh`** - Setup script to generate config and start namespace
- **`podman-run.sh`** - Standalone podman run script

## Advanced: Manual Configuration

If you prefer to manually create the wg-netns configuration instead of using the setup script:

**Create `/etc/wireguard/transmission-vpn.json`:**

```json
{
  "name": "transmission-vpn",
  "managed": true,
  "dns-server": ["1.1.1.1"],
  "interfaces": [
    {
      "name": "wg0",
      "address": ["10.x.x.x/32"],
      "private-key": "YOUR_PRIVATE_KEY",
      "peers": [
        {
          "public-key": "VPN_SERVER_PUBLIC_KEY",
          "endpoint": "vpn.example.com:51820",
          "persistent-keepalive": 25,
          "allowed-ips": ["0.0.0.0/0", "::/0"]
        }
      ]
    }
  ]
}
```

**Start namespace:**
```bash
sudo wg-netns up transmission-vpn
```

## Uninstall

**1. Stop and remove Transmission:**
```bash
podman stop transmission
podman rm transmission
podman volume rm transmission-config
```

**2. Stop the namespace:**
```bash
sudo wg-netns down transmission-vpn
```

**3. Disable systemd services (if configured):**
```bash
sudo systemctl disable --now wg-netns@transmission-vpn.service
systemctl --user disable --now transmission.service
```

**4. Remove configuration:**
```bash
sudo rm /etc/wireguard/transmission-vpn.json
sudo rm /etc/systemd/system/wg-netns@.service
```

## Resources

- [wg-netns GitHub](https://github.com/dadevel/wg-netns)
- [wg-netns README](./wg-netns-README.md) (included in this repo)
- [WireGuard Network Namespaces](https://www.wireguard.com/netns/)
- [Transmission](https://transmissionbt.com/)
- [LinuxServer.io Transmission Image](https://github.com/linuxserver/docker-transmission)
- [Podman Documentation](https://docs.podman.io/)

## Credits

- [wg-netns](https://github.com/dadevel/wg-netns) by dadevel
- [Transmission](https://transmissionbt.com/)
- [LinuxServer.io](https://www.linuxserver.io/) for the Transmission Podman image

## License

This is a configuration repository. Refer to individual component licenses:
- [wg-netns](https://github.com/dadevel/wg-netns) - MIT License
- [Transmission](https://transmissionbt.com/) - GPL
- [LinuxServer.io Transmission](https://github.com/linuxserver/docker-transmission)
