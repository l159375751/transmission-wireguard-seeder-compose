sudo podman run --rm  --name transmission \
  --network ns:/run/netns/transmission-vpn \
  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
  -v transmission-wireguard-seeder-compose_transmission-config:/config \
  -v /home/user/test/transmission-wireguard-seeder-compose/downloads:/downloads \
  -v /home/user/test/transmission-wireguard-seeder-compose/watch:/watch \
  docker.io/linuxserver/transmission:latest



#sudo podman run -d --name transmission \
#  --network ns:/run/netns/transmission-vpn \
#  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
#  -v transmission-wireguard-seeder-compose_transmission-config:/config \
#  -v /home/user/test/transmission-wireguard-seeder-compose/downloads:/downloads \
#  -v /home/user/test/transmission-wireguard-seeder-compose/watch:/watch \
#  --restart unless-stopped \
#  docker.io/linuxserver/transmission:latest
