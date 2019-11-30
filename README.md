# proxmox-lxc-hass
The following is for creating our Home Assistant installation, network and configuring appliances.

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


## About LXC Home Assistant Installation
This page is about installing Proxmox LXC's and configuring appliances for your Home Assistant network. Software tools like Hassio, deCONZ, Phoscon and stuff.

Again we build our LXC's on Unbuntu 18.04. Proxmox itself ships with a set of basic templates and to download a prebuilt OS distribution use the graphical interface `typhoon-01` > `local` > `content` > `templates` and select and download the following templates:
*  `ubuntu-18.04-standard`.

## 1.00 Unprivileged LXC Containers and file permissions
With unprivileged LXC containers you will have issues with UIDs (user id) and GIDs (group id) permissions with bind mounted shared data. All of the UIDs and GIDs are mapped to a different number range than on the host machine, usually root (uid 0) became uid 100000, 1 will be 100001 and so on.

However you will soon realise that every file and directory will be mapped to "nobody" (uid 65534). This isn't acceptable for host mounted shared data resources. For shared data you want to access the directory with the same - unprivileged - uid as it's using on other LXC machines.

The fix is to change the UID and GID mapping. So in our build we will create a new users/groups:

*  user `media` (uid 1605) and group `medialab` (gid 65605) accessible to unprivileged LXC containers (i.e Jellyfin, NZBGet, Deluge, Sonarr, Radarr, LazyLibrarian, Flexget);
*  user `storm` (uid 1606) and group `homelab` (gid 65606) accessible to unprivileged LXC containers (i.e Syncthing, Nextcloud, Unifi, Home Assistant, CCTV etc);
*  user `typhoon` (uid 1607) and group `privatelab` (gid 65606) accessible to unprivileged LXC containers (i.e all things private).

For our Home Assistant network we use user `storm` (uid 1606) and group `homelab` (gid 65606).

Also because Synology new Group ID's are in ranges above 65536, outside of Proxmox ID map range, we must pass through our Medialab (gid 65605), Homelab (gid 65606) and Privatelab (gid 65607) Group GID's mapped 1:1.

This is achieved in three parts during the course of creating your new media LXC's.

### 1.01 Unprivileged container mapping - homelab
To change a container mapping we change the container UID and GID in the file `/etc/pve/lxc/container-id.conf` after you create a new container. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:
```
# User media | Group homelab
echo -e "lxc.idmap: u 0 100000 1606
lxc.idmap: g 0 100000 100
lxc.idmap: u 1606 1606 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1607 101607 63929
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e homelab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/container-id.conf
```
### 1.02 Allow a LXC to perform mapping on the Proxmox host - homelab
Next we have to allow the LXC to actually do the mapping on the host. Since LXC creates the container using root, we have to allow root to use these new uids in the container.

To achieve this we need to **add** lines to `/etc/subuid` (users) and `/etc/subgid` (groups). So we need to define two ranges: one where the system IDs (i.e root uid 0) of the container can be mapped to an arbitrary range on the host for security reasons, and another where Synology GIDs above 65536 of the container can be mapped to the same GIDs on the host. That's why we have the following lines in the /etc/subuid and /etc/subgid files.

Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following (NOTE: Only needs to be performed ONCE on each host (i.e typhoon-01/02/03)):

```
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1606:1' /etc/subuid || echo 'root:1606:1' >> /etc/subuid
```

The above code adds a ID map range from 65604 > 65704 on the container to the same range on the host. Next ID maps gid100 (default linux users group) and uid1606 (username storm) on the container to the same range on the host.


### 1.03 Create a newuser `storm` in a LXC
We need to create a `media` user in all media LXC's which require shared data (NFS NAS shares). After logging into the LXC container type the following:

(A) To create a user without a Home folder
```
groupadd -g 65606 homelab &&
useradd -u 1606 -g homelab -M storm
```
(B) To create a user with a Home folder
```
groupadd -g 65606 homelab &&
useradd -u 1606 -g homelab -m storm
```
Note: We do not need to create a new user group because `users` is a default linux group with GID value 100.

## 2.00 Home Assistant (Hassio) LXC - Ubuntu 18.04
Here we create a Home Assistant ( also known as Hass.io, HA) which is a home automation that puts local control and privacy first. Read about it [here](https://www.home-assistant.io/).

### 2.01 Create a Ubuntu 18.04 LXC for Hassio - Ubuntu 18.04
Now using the web interface `Datacenter` > `Create CT` and fill out the details as shown below (whats not shown below leave as default):

| Create: LXC Container | Value |
| :---  | :---: |
| **General**
| Node | `typhoon-01` |
| CT ID |`131`|
| Hostname |`hassio`|
| Unprivileged container | `☑` |
| Resource Pool | Leave Blank
| Password | Enter your pasword
| Password | Enter your pasword
| SSH Public key | Add one if you want to
| **Template**
| Storage | `local` |
| Template |`ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz`|
| **Root Disk**
| Storage |`typhoon-share`|
| Disk Size |`20 GiB`|
| **CPU**
| Cores |`1`|
| CPU limit | Leave Blank
| CPU Units | `1024`
| **Memory**
| Memory (MiB) |`2048`|
| Swap (MiB) |`256`|
| **Network**
| Name | `eth0`
| Mac Address | `auto`
| Bridge | `vmbr0`
| VLAN Tag | `110`
| Rate limit (MN/s) | Leave Default (unlimited)
| Firewall | `☑`
| IPv4 | `☑  Static`
| IPv4/CIDR |`192.168.110.131/24`|
| Gateway (IPv4) |`192.168.110.5`|
| IPv6 | Leave Blank
| IPv4/CIDR | Leave Blank |
| Gateway (IPv6) | Leave Blank |
| **DNS**
| DNS domain | Leave Default (use host settings)
| DNS servers | Leave Default (use host settings)
| **Confirm**
| Start after Created | `☑`

And Click `Finish` to create your Hassio LXC. The above will create the Hassio LXC without any of the required local Mount Points to the host.

If you prefer you can simply use Proxmox CLI `typhoon-01` > `>_ Shell` and type the following to achieve the same thing PLUS it will automatically add the required Mount Points (note, have your root password ready for Hassio LXC):

**Script (A):** Including LXC Mount Points
```
pct create 131 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname hassio --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=110,firewall=1,gw=192.168.110.5,ip=192.168.110.131/24,type=veth --ostype ubuntu --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=1 --password --mp0 /mnt/pve/cyclone-01-backup,mp=/mnt/backup --mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

**Script (B):** Excluding LXC Mount Points:
```
pct create 131 local:vztmpl/ubuntu-18.04-standard_18.04.1-1_amd64.tar.gz --arch amd64 --cores 1 --hostname hassio --cpulimit 1 --cpuunits 1024 --memory 2048 --net0 name=eth0,bridge=vmbr0,tag=110,firewall=1,gw=192.168.110.5,ip=192.168.110.131/24,type=veth --ostype ubuntu --rootfs typhoon-share:20 --swap 256 --unprivileged 1 --onboot 1 --startup order=1 --password
```

### 2.02 Setup Hassio Mount Points - Ubuntu 18.04
If you used Script (B) in Section 2.01 then you have no Moint Points.

Please note your Proxmox Hassio LXC MUST BE in the shutdown state before proceeding.

To create the Mount Points use the web interface go to Proxmox CLI Datacenter > typhoon-01 > >_ Shell and type the following:
```
pct set 131 -mp0 /mnt/pve/cyclone-01-backup,mp=/mnt/backup &&
pct set 131 -mp1 /mnt/pve/cyclone-01-public,mp=/mnt/public
```

### 2.03 Unprivileged container mapping - Ubuntu 18.04
To change the Hassio container mapping we change the container UID and GID in the file `/etc/pve/lxc/131.conf`. Simply use Proxmox CLI `typhoon-01` >  `>_ Shell` and type the following:

```
# User storm | Group homelab
echo -e "lxc.idmap: u 0 100000 1606
lxc.idmap: g 0 100000 100
lxc.idmap: u 1606 1606 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1607 101607 63929
lxc.idmap: g 101 100101 65435
# Below are our Synology NAS Group GID's (i.e homelab) in range from 65604 > 65704
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/131.conf &&
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid &&
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid &&
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid &&
grep -qxF 'root:1606:1' /etc/subuid || echo 'root:1606:1' >> /etc/subuid
```

### 2.04 Create Hassio default and user folders on your NAS - Ubuntu 18.04
To create the Syncthing default folders use the web interface go to Proxmox CLI `Datacenter` > `typhoon-01` > `>_ Shell` and type the following:
```
mkdir -m 775 -p {/mnt/pve/cyclone-01-backup/hassio} &&
chown -R 1606:65606 {/mnt/pve/cyclone-01-backup/hassio}
```

### 2.05 Create new "storm" user - Ubuntu 18.04
First start LXC 131 (hassio) with the Proxmox web interface go to `typhoon-01` > `131 (hassio)` > `START`.

Then with the Proxmox web interface go to `typhoon-01` > `131 (hassio)` > `>_ Shell` and type the following:
```
groupadd -g 65606 homelab &&
useradd -u 1606 -g homelab -m storm
```
