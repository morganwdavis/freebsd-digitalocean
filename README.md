# freebsd-digitalocean
Lightweight, zero-dependency, self-configuration for FreeBSD droplets on DigitalOcean

## Features
- Allows you to run a FreeBSD droplet that auto-configures itself at boot time.
- No dependency on extra packages or ports -- it's just a simple shell script.
- Automatically sets up:
	* IPv4 and IPv6 public and private network addressing and routing
	* Floating IP anchor addresses
	* Hostname and DNS servers
	* *freebsd* user's authorized public keys
- Replaces /etc/rc.conf networking configurations with just one `digitalocean="YES"` setting.
- Completely configurable.

## Preparation
>*WARNING: Any custom networking scripts you may have created in /etc/rc.conf.d will be replaced. Backup if needed.*

> NB: You can skip this preparation if you start with a completely vanilla FreeBSD installation, as described in **Why I made this** below.

Droplets built from DigitalOcean's base FreeBSD images have extra packages and scripts that will no longer be required for auto configuration. They should be disabled first to avoid conflicts. When you're confident your cleaned-up droplet is working properly with this solution, you can remove the preinstalled stuff you do not need:
- avahi
- bsd-cloudinit
- python
- curl
- Related settings in /etc/rc.conf and files in /usr/local/etc

Extraneous files and directories:
- /root/.cache directory
- selfcheck.json file
	*(can't remember where this is found)*
- /etc/rc.digitalocean.d directory

If you have your own ssh-enabled account, the *freebsd* user account can be removed.

## Installation and testing
1. As root, install these files manually or run the install.sh script:

	```
	install -m 700 digitalocean /usr/local/etc/rc.d
	install -m 644 digitalocean.conf /usr/local/etc
	install -m 700 digitalocean.sh /usr/local/sbin
	```
2. Add `digitalocean="YES"` to /etc/rc.conf
3. If needed, edit /usr/local/etc/digitalocean.conf (self-documenting)
4. Test it by entering `service digitalocean start`  
	(Note: this builds configuration files but *does not change any active network settings*)
5. Sanity-check the `hostname`, `network`, and `routing` files in /etc/rc.conf.d
6. Optional: If you configured the `droplet_user` (typically *freebsd*), check its home directory for .ssh/authorized_keys
7. If all looks good, you can restart the droplet

## Zero downtime network updates

It is possible to reconfigure the FreeBSD instance while running without needing to reboot. To restart networking and routing, enter these commands:

```
/usr/local/sbin/digitalocean.sh

/etc/rc.d/netif restart && /etc/rd.d/routing restart
```

## Why I made this
DigitalOcean's FreeBSD base images do not support ZFS. To get it, you have to [roll your own FreeBSD installation](https://github.com/fxlv/docs/blob/master/freebsd/freebsd-with-zfs-digitalocean.md) which is not difficult.

The upside, in addition to gaining ZFS, is having completely stock, pristine FreeBSD system with nothing weird added to it. No extra packages, no extra users, and no mysterious files or directories added by the fine folks at DigitalOcean. Awesome as they are, we really don't want anyone adding junk to our droplets.

Using this script, a vanilla FreeBSD droplet can determine its configuration from the DigitalOcean API at boot time. That means it gets the latest metadata each time it restarts without needing to edit or change anything inside the FreeBSD instance.
