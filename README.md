# proxmox-lxc-smarthome
The following is for creating our Smarter Home network and appliances.

Network Prerequisites are:
- [x] Layer 2 Network Switches
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable you to a configure DNS server(s), like a UniFi USG Gateway, so set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or os down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other Prerequisites are:
- [x] Synology NAS, or linux variant of a NAS, is fully configured as per [SYNOBUILD](https://github.com/ahuacate/synobuild#synobuild)
- [x] UniFi network is fully configured as per [UNIFIBUILD](https://github.com/ahuacate/unifibuild#unifi-build)
- [x] Proxmox node fully configured as per [PROXMOX-NODE BUILDING](https://github.com/ahuacate/proxmox-node/blob/master/README.md#proxmox-node-building)
- [x] [Conbee II](https://www.phoscon.de/en/conbee2) or [Raspbee](https://www.phoscon.de/en/raspbee) Zigbee Gateway available from Phoscon.de

Tasks to be performed are:


## About LXC Smart Home Installations
This page is about installing Proxmox LXC's and configuring appliances for your Smart Home network. Software tools like Home Assistant (Hassio), Node-RED, deCONZ, Phoscon and stuff.

Standard practice is to build our LXC's on Unbuntu 18.04. Proxmox itself ships with a set of basic templates and to download a prebuilt OS distribution use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select and download the following templates:
*  `ubuntu-18.04-standard`.

## 1.00 Unprivileged LXC Containers and file permissions
With unprivileged LXC containers you will have issues with UIDs (user id) and GIDs (group id) permissions with bind mounted shared data. All of the UIDs and GIDs are mapped to a different number range than on the host machine, usually root (uid 0) became uid 100000, 1 will be 100001 and so on.

However you will soon realise that every file and directory will be mapped to "nobody" (uid 65534). This isn't acceptable for host mounted shared data resources. For shared data you want to access the directory with the same - unprivileged - uid as it's using on other LXC machines.

The fix is to change the UID and GID mapping. So in our build we will create a new users/groups:

*  user `media` (uid 1605) and group `medialab` (gid 65605) accessible to unprivileged LXC containers (i.e Jellyfin, NZBGet, Deluge, Sonarr, Radarr, LazyLibrarian, Flexget);
*  user `storm` (uid 1606) and group `homelab` (gid 65606) accessible to unprivileged LXC containers (i.e Syncthing, Nextcloud, Unifi etc);
*  user `typhoon` (uid 1607) and group `privatelab` (gid 65606) accessible to unprivileged LXC containers (i.e all things private, Home Assistant, CCTV ).

For our Home Assistant network we use user `typhoon` (uid 1607) and group `ptivatelab` (gid 65607).

Also because Synology new Group ID's are in ranges above 65536, outside of Proxmox ID map range, we must pass through our Medialab (gid 65605), Homelab (gid 65606) and Privatelab (gid 65607) Group GID's mapped 1:1.

This is achieved in three parts during the course of creating your new media LXC's.

### 1.01 Unprivileged container mapping - privatelab
To change a container mapping we change the container UID and GID in the file `/etc/pve/lxc/container-id.conf` after you create a new container. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:
```
# User media | Group homelab
echo -e "lxc.idmap: u 0 100000 1607
lxc.idmap: g 0 100000 100
lxc.idmap: u 1607 1607 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1608 101608 63928
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e privatelab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/container-id.conf
```
### 1.02 Allow a LXC to perform mapping on the Proxmox host - privatelab
Next we have to allow the LXC to actually do the mapping on the host. Since LXC creates the container using root, we have to allow root to use these new uids in the container.

To achieve this we need to **add** lines to `/etc/subuid` (users) and `/etc/subgid` (groups). So we need to define two ranges: one where the system IDs (i.e root uid 0) of the container can be mapped to an arbitrary range on the host for security reasons, and another where Synology GIDs above 65536 of the container can be mapped to the same GIDs on the host. That's why we have the following lines in the /etc/subuid and /etc/subgid files.

Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following (NOTE: Only needs to be performed ONCE on each host (i.e typhoon-01/02/03)):

```
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1607:1' /etc/subuid || echo 'root:1607:1' >> /etc/subuid
```

The above code adds a ID map range from 65604 > 65704 on the container to the same range on the host. Next ID maps gid100 (default linux users group) and uid1607 (username typhoon) on the container to the same range on the host.


### 1.03 Create a newuser `typhoon` in a LXC
We need to create a `typhoon` user in all privatelab LXC's which require shared data (NFS NAS shares). After logging into the LXC container type the following:

(A) To create a user without a Home folder
```
groupadd -g 65607 privatelab &&
useradd -u 1607 -g privatelab -M typhoon
```
(B) To create a user with a Home folder
```
groupadd -g 65607 privatelab &&
useradd -u 1607 -g privatelab -m typhoon
```
Note: We do not need to create a new user group because `users` is a default linux group with GID value 100.

## 2.00 Home Assistant (Hassio) LXC - Ubuntu 18.04
Here we create a Home Assistant ( also known as Hass.io, HA) which is a home automation that puts local control and privacy first. Read about it [here](https://www.home-assistant.io/).

To make life easy we use the proven and dependable [whiskerz007](https://github.com/whiskerz007/proxmox_hassio_lxc) setup scripts to install Hass.io modified to install on Ubuntu 18.04 instead of Debian 10.

### 2.01 Turnkey Hassio Installation - Ubuntu 18.04
To create a new Ubuntu 18.04 LXC container on Proxmox and setup Hass.io to run inside of it, run the following in a SSH connection or the Proxmox web shell `Proxmox CLI Datacenter` > `typhoon-01` > `>_ Shell` and type the following:

```
bash -c "$(wget -qLO - https://github.com/whiskerz007/proxmox_hassio_lxc/raw/master/create_container.sh)"
```
