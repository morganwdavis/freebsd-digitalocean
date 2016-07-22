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
- Replaces networking configurations in /etc/rc.conf with just one `digitalocean_enable="YES"` setting.
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
2. Add `digitalocean_enable="YES"` to /etc/rc.conf
3. If needed, edit /usr/local/etc/digitalocean.conf (self-documenting)
4. Test it by entering `service digitalocean start`  
	(Note: this builds configuration files but *does not change any active network settings*)
5. Sanity-check the `hostname`, `network`, and `routing` files in /etc/rc.conf.d
6. Optional: If you configured the `droplet_user` (typically *freebsd*), check its home directory for .ssh/authorized_keys
7. If all looks good, you can restart the droplet

## Zero downtime network updates

It is possible to reconfigure the FreeBSD instance while running without needing to reboot. To restart networking and routing, enter these commands:

```
service digitalocean restart

/etc/rc.d/netif restart && /etc/rd.d/routing restart
```

## Why I made this
DigitalOcean's FreeBSD base images do not support ZFS. To get it, you have to [perform your own standard FreeBSD installation](https://github.com/fxlv/docs/blob/master/freebsd/freebsd-with-zfs-digitalocean.md) which is not difficult, and usually preferrable. You end up with a ZFS-enabled FreeBSD system, installed just as you want it, with nothing weird added to it.

You could manually configure your new stock FreeBSD droplet by putting the required networking statements in /etc/rc.conf. But that removes the benefits of being able to deploy properly configured droplet clones that have correct, non-conflicting settings.

I didn't want to use the method DigitalOcean implements for auto-configuration. Extra packages of networking support tools and the special *freebsd* user account increase attack surfaces. Those packages will require updates at some point. They take up disk space, create persistent processes in memory, and steal CPU cycles.

Even if I didn't need ZFS (e.g., on one of the smaller memory droplets), I'd still want to make the droplet as pristine as possible while keeping the auto-configuration benefits. This shell script-based solution does the trick.
