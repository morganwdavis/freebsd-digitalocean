# freebsd-digitalocean

Lightweight, zero-dependency, self-configuration for FreeBSD droplets on DigitalOcean

## Features

-   Allows you to run a FreeBSD droplet that auto-configures itself at boot time.
-   No dependency on extra packages or ports -- it's just a simple shell script.
-   Automatically sets up:
    -   IPv4 and IPv6 public and private network addressing and routing
    -   Reserved IP anchor addresses
    -   Hostname and DNS servers
    -   _freebsd_ user's authorized public keys
    -   Executes user-data scripts for automation
-   Replaces networking configurations in /etc/rc.conf with just one `digitalocean_enable="YES"` setting.
-   Completely configurable.

## Preparation

> _WARNING: Any custom networking scripts you may have created in /etc/rc.conf.d will be replaced. Backup if needed._

Droplets built from DigitalOcean's base FreeBSD images have extra packages and scripts that will no longer be required for auto configuration. They should be disabled first to avoid conflicts. When you're confident your cleaned-up droplet is working properly with this solution, you can remove the preinstalled stuff you do not need:

Unnecessary packages:

-   curl
-   dmidecode
-   e2fsprogs
-   gettext-runtime
-   gpart (is in base, no clue why DO installs it from pkg)
-   indexinfo
-   jq
-   libffi
-   libiconv
-   libnghttp2
-   oniguruma
-   python27
-   lots of py27-\* packages
-   readline
-   rsync
-   sudo (doas is much more elegant and safer)

Unnecessary users:

-   freebsd

Settings in /etc/rc.conf that can/should be removed:

-   hostname
-   cloudinit_enable
-   digitaloceanpre
-   digitalocean
-   all ifconfig and route-related lines
-   basically everything from the comment `DigitalOcean Dynamic Configuration lines and the immediate line below it, are removed each boot.` until the end of the file

Extraneous files and directories:

-   /usr/local/etc/rc.d/cloud\* (cloudconfig, cloudfinal, cloudinit, cloudinitlocal)
-   /usr/local/etc/rc.d/digitalocean\* (digitalocean, digitaloceanpre)

## Installation and Testing

1. As root, run `./update.sh` which installs the necessary files:

    ```sh
    install -m 700 digitalocean /usr/local/etc/rc.d
    install -m 644 digitalocean.conf /usr/local/etc
    install -m 700 digitalocean.sh /usr/local/sbin
    ```

2. Add `digitalocean_enable="YES"` to /etc/rc.conf

3. If needed, edit /usr/local/etc/digitalocean.conf (self-documenting)

4. Test it by entering `service digitalocean start`
   (Note: this builds configuration files but _does not change any active network settings_)

5. Sanity-check the `hostname`, `network`, and `routing` files in /etc/rc.conf.d

6. Optional: If you configured the `droplet_user` (typically _freebsd_), check its home directory for .ssh/authorized_keys

7. If all looks good, you can restart the droplet

**Hint:** By default, sshd is configured to disallow root login, even with ssh-keys; so it is necessary to add a normal user for SSH access. It is highly recommended to continue disabling SSH root login and use a non-root user with sudo privileges for better security.

## Zero Downtime Network Updates

It is possible to reconfigure the FreeBSD instance while running without needing to reboot. To restart networking and routing, enter these commands:

```sh
service digitalocean restart
service netif restart && service routing restart
```

## Dynamically Updated Hosts Files

Setting the config option `hosts_file` to point to a file (such as /etc/hosts) will cause special `DO_*` entries found in that file to be updated with their corresponding IP addresses. Example:

```
0.0.0.0         public-ip       DO_PUB_IPV4
0.0.0.0         private-ip      DO_PVT_IPV4
0.0.0.0         anchor-ip       DO_ANCHOR_IPV4
0.0.0.0         reserved-ip     DO_RESERVED_IPV4
0.0.0.0         floating-ip     DO_FLOATING_IPV4
0.0.0.0         gateway-ip      DO_GW_IPV4
```

The script searches for a line with a `DO_*` entry, such as `DO_PUB_IPV4`, and replaces the first column address with the corresponding metadata address value. This creates an alias for services that listen on an address by referring to its symbolic `DO_` name. The `DO_*` symbols are required exactly as shown for matching purposes. Optionally, any other symbolic names may be included on the line, such as the `*-ip` examples above. In the case of the /etc/hosts file, this would allow a service to bind to the address associated with `anchor-ip`, provided the service permits host names.

Your own scripts can also lookup these metadata addresses easily by using getent(1):

```sh
anchor_ip=$(getent hosts anchor-ip | cut -f1 -d' ')
```

(Use `_IPV6` suffixed symbols for IPv6 addresses.)

> Note: The term "floating IP" has been deprecated and replaced by DigitalOcean's new name "reserved IP". Support for the new name is now provided here and both will have the same IP address.

## User-Data Support

This script supports DigitalOcean's user-data feature, which allows you to provide a shell script that runs automatically. The best value of the user-data script on DigitalOcean droplets as a shell script often lies in defining common variables (such as network resource addresses, API endpoints, configuration URLs) alongside unique identifiers or values specific to each droplet to give the droplet a sense of identity and context within your infrastructure. For example, you could structure your user-data shell scripts to clearly separate shared configuration from instance-unique information, leveraging DigitalOcean metadata queries to build smart, context-aware droplet provisioning.

### Benefits and Use Cases

-   Centralizes and simplifies droplet setup by hosting operational logic on an external server.
-   Allows easy updates to droplet configuration and software without recreating droplets.
-   Ideal for FreeBSD droplets without cloud-init support.
-   Enables automated installation and configuration of packages on first boot.
-   Supports setting up configuration management tools (Ansible, Puppet, Chef).
-   Automates deployment of applications, services, firewall rules, and one-time initialization tasks.

### How to Use User-Data

When creating a droplet, you can provide user-data in a couple of ways:

**Via the DigitalOcean Control Panel:**

1. On the Droplet creation page, click **+ Advanced Options**
2. Check the box next to **Add Initialization scripts**
3. Paste your shell script in the text box

**Via the DigitalOcean API:**

-   Use the `user_data` field in your Droplet creation POST request

### Important Notes

-   User-data scripts are executed as the **root** user
-   Scripts run **after** network configuration is complete
-   Since this runs on every boot, the script or user-data should be idempotent (safe to run multiple times without adverse effect).
-   **User-data on DigitalOcean droplets is immutable after creation.**

### Example User-Data Script

```sh
#!/bin/sh

set -e

# Export unique droplet ID from metadata
export UNIQUE_DROPLET_ID=$(fetch -q -o - http://169.254.169.254/metadata/v1/id)

# Define external script URL and local bootstrap script path
EXTERNAL_SCRIPT_URL="https://example.com/current-bootstrap.sh"
BOOTSTRAP_SCRIPT="/tmp/bootstrap.sh"

# Fetch the external bootstrap script, run it, and clean up
/usr/bin/fetch -q -o "$BOOTSTRAP_SCRIPT" "$EXTERNAL_SCRIPT_URL"
/bin/chmod +x "$BOOTSTRAP_SCRIPT"
/bin/sh "$BOOTSTRAP_SCRIPT"
/bin/rm -f "$BOOTSTRAP_SCRIPT"
```

### How It Works

1. The droplet user-data script exports a unique droplet ID fetched from the DigitalOcean metadata service.
2. It fetches the latest external bootstrap script using `fetch` from a stable URL you control.
3. The fetched script is made executable and then run to configure or update the droplet.

This approach keeps user-data minimal, uses dynamic external scripts for flexibility, and leverages the metadata API for unique droplet identity.

## Why I Made This

I didn't want to use DigitalOcean's implementation for auto-configuration. Extra packages of networking support tools and the special _freebsd_ user account increase attack surfaces. Those packages will require updates at some point. They take up disk space, create persistent processes in memory, and steal CPU cycles. This shell script-based solution does the trick.

## Updates

-   October 2025: Modernized shell scripts with proper quoting, error handling, shellcheck compliance, and much cleanup. Added user-data support.
-   August 12, 2016: Added support for dynamically updated host file entries.
-   August 3, 2016: DigitalOcean now offers FreeBSD base images with ZFS support! Removed references for [performing your own standard memory-based FreeBSD installation](https://github.com/fxlv/docs/blob/master/freebsd/freebsd-with-zfs-digitalocean.md) in order to run bsdinstall so you can enable ZFS on the root filesystem.
-   July 28, 2016: This project was mentioned on [episode 152 of the BSD Now show](https://youtu.be/vcQPHHGnTwo?t=1h7m).
