# freebsd-digitalocean
Lightweight, zero-dependency, self-configuration for FreeBSD droplets on DigitalOcean

## Features
- Allows you to run a FreeBSD droplet that auto-configures itself at boot time.
- No depedency on extra packages or ports -- it's just a simple shell script.
- Replaces all your /etc/rc.conf networking configurations with just one `digitalocean="YES"` setting.
- Supports IPv4 and IPv6 public and private network addressing and routing.
- Supports Floating IPs by automatically adding the corresponding private anchor IPs for you.
- Automatically sets the hostname.
- Automatically sets the *freeebsd* user's authorized public keys.
- Automatically adds the droplets DNS nameservers.
- Completely configurable.

## Installation
- Copy digitalocean to /usr/local/etc/rc.d
- Copy digitalocean.conf to /usr/local/etc
- Copy digitalocean.sh to /usr/local/sbin
- Add `digitalocean="YES"` to /etc/rc.conf
- Edit /usr/local/etc/digitalocean.conf if needed (self-documenting)

## Testing
- After installation, test it by entering `service digitalocean start`
- This builds configuration files but does not change any network settings
- If no errors, check the `hostname`, `network`, and `routing` files in /etc/rc.conf.d
- If you configured a `droplet_user` (typically *freebsd*), check its home directory for .ssh/authorized_keys
- If all looks good, you can restart the droplet

## Activation
- Restart the droplet
- The digitalocean service rebuilds the configuration files from the droplet's current metadata.
- FreeBSD then continues with the normal network initialization.

## Why I made this
As of the time of this writing, DigitalOcean's FreeBSD base images do not support ZFS. In order to get that feature, you need to roll your own FreeBSD installation on DigitalOcean, which is not difficult if you follow these handy steps (see https://github.com/fxlv/docs/blob/master/freebsd/freebsd-with-zfs-digitalocean.md).

In addition to gaining ZFS, you also get a completely stock, pristine FreeBSD system with nothing weird added to it. No extra packages, no extra users, and no mysterious files or directories added by the fine folks at DigitalOcean. Awesome as they are, we really don't want them adding junk to our droplets. Of course, this also means the droplet requires the old-school network configurations in /etc/rc.conf, just like we had to do back in the day when our beards weren't so gray. But the downside of that means every new droplets you create from snapshot images boot up with some hard-coded, conflicting network settings, and that's bad.

To get a droplet to determine its own configuration from the DigitalOcean assigned metadata, there's a nitfy API you can call upon to grab all the key settings. That's what this script does, without all the junk. Since it uses current metadata at boot time, it means you can shutdown a droplet, change its settings in the DigitalOcean dashboard, such as moving a Floating IP, and power it on for a perfect startup. It uses that new configuration from metadata without having to edit or change anything inside the FreeBSD instance, and that's good.
