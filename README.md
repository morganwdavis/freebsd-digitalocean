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

Droplets built from DigitalOcean's base FreeBSD images have extra packages and scripts that will no longer be required for auto configuration. They should be disabled first to avoid conflicts. When you're confident your cleaned-up droplet is working properly with this solution, you can remove the preinstalled stuff you do not need:

Unecessary packages:

- avahi
- bsd-cloudinit
- python
- curl

`pkg delete avahi bsd-cloudinit python27 curl`

Left over users:
- `rmuser -y avahi avahi-autoipd messagebus`

Settings in /etc/rc.conf
- Remove ifconfig_vtnet0="dhcp"

Extraneous files and directories:
- /root/.cache directory
- /etc/rc.digitalocean.d directory
- /etc/rc.d/digitalocean

If you have your own ssh-enabled account, the *freebsd* user account can be removed.

## Installation and testing
1. As root, run update.sh which essentially does this for you:

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

service netif restart && service routing restart
```

## Dynamically updated hosts files
Setting the config option `hosts_file` to point to a file (such as /etc/hosts) will cause special `DO_*` entries found in that file to be updated with their corresponding IP addresses.  Example:

```
0.0.0.0         public-ip		# DO_PUB_IPV4
0.0.0.0         private-ip		# DO_PVT_IPV4
0.0.0.0         anchor-ip		# DO_ANCHOR_IPV4
0.0.0.0         floating-ip		# DO_FLOATING_IPV4
0.0.0.0         gateway-ip		# DO_GW_IPV4
```

The script searches for a line with a `DO_*` entry, such as `DO_PUB_IPV4`, and replaces the first column address with the corresponding metadata address value. This creates an alias for services that listen on an address by referring to its symbolic `DO_` name. The `DO_*` symbols are required exactly as shown for matching purposes. Optionally, any other symbolic names may be included on the line, such as the `*-ip` examples above.  In the case of the /etc/hosts file, this would allow a service to bind to the address associated with `anchor-ip`, provided the service permits host names.

Your own scripts can also lookup these metadata addresses easily by using getent(1):

```
anchor_ip=`getent hosts anchor-ip | cut -f1 -d' '`
```

(Use `_IPV6` suffixed symbols for IPv6 adddresses.)


## Why I made this
I didn't want to use DigitalOcean's implementation for auto-configuration. Extra packages of networking support tools and the special *freebsd* user account increase attack surfaces. Those packages will require updates at some point. They take up disk space, create persistent processes in memory, and steal CPU cycles. This shell script-based solution does the trick.

## What's next?
I'd love to get some feedback from others running and testing this just to make sure it's solid and has all features working well. After that, I could see making this an actual FreeBSD package. That is, of course, if DigitalOcean doesn't adopt something equivalent in their upcoming base images.

## Updates
- August 12, 2016: Added support for dynamically updated host file entries.
- August 3, 2016: DigitalOcean now offers FreeBSD base images with ZFS support! Removed references for [performing your own standard memory-based FreeBSD installation](https://github.com/fxlv/docs/blob/master/freebsd/freebsd-with-zfs-digitalocean.md) in order to run bsdinstall so you can enable ZFS on the root filesystem.
- July 28, 2016: This project was mentioned on [episode 152 of the BSD Now show](https://youtu.be/vcQPHHGnTwo?t=1h7m).

