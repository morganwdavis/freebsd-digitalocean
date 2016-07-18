#!/bin/sh

# digitalocean.sh
#
# Creates system configuration files based on droplet metadata.
#
# Author: Morgan Davis (https://github.com/morganwdavis)
# Version: 1.0
# Current version and docs: https://github.com/morganwdavis/freebsd-digitalocean
#
# !!! WARNING !!! WARNING !!! WARNING !!!
#
# Overwrites files in /etc/rc.conf.d specified in the local configuration file

# Local configuration file
conf="/usr/local/etc/digitalocean.conf"

if [ -f $conf ] ; then
    . $conf
else
    echo "$0: unable to load configuration file: $conf"
    exit 1
fi

#
# Set hostname
#

echo "# digitalocean hostname configuration" > $hostname_conf

hostname=`$api_item/hostname`
echo "Configuring DigitalOcean droplet for $hostname"
echo "hostname=\"$hostname\"" >> $hostname_conf

#
# Set networking
#

echo "# digitalocean network configuration" > $network_conf

for i in `$api_item/interfaces` ; do
    case "$i" in
	"public"*)
	    net_if=$pub_if
	    ;;
	"private"*)
	    net_if=$pvt_if
	    ;;
	*)
	    net_if=""
    esac
    
    if [ ! -z $net_if ] ; then
	for n in 4 6 ; do
	    ip=`$api_item/interfaces/${i}0/ipv${n}/address 2>/dev/null`
	    if [ ! -z "$ip" ] ; then
		if [ $n = "4" ] ; then
		    mask=`$api_item/interfaces/${i}0/ipv4/netmask`
		    echo "ifconfig_${net_if}=\"inet $ip netmask $mask\"" >> $network_conf
		else
		    cidr=`$api_item/interfaces/${i}0/ipv6/cidr`
		    echo "ifconfig_${net_if}_ipv6=\"inet6 ${ip}/${cidr}\"" >> $network_conf
		fi
	    fi
	done
    fi
done

#
# Support floating IP by adding anchor IP
#

for n in 4 6 ; do
    fip_active=`$api_item/floating_ip/ipv${n}/active 2>/dev/null`
    if [ "$fip_active" = "true" ] ; then
	fip=`$api_item/floating_ip/ipv${n}/ip_address`
	aip=`$api_item/interfaces/public/0/anchor_ipv${n}/address`
	v=""
	if [ $n = "6" ] ; then
	    v=$n
	fi
	echo "floating_ipv${n}=\"$fip\"" >> $network_conf
	echo "ifconfig_${pub_if}_alias0=\"inet${v} ${aip}/16\"" >> $network_conf
    fi
done

#
# Set routing
#

echo "# digitalocean routing configuration" > $routing_conf
for n in 4 6; do
    gateway=`$api_item/interfaces/public/0/ipv${n}/gateway 2>/dev/null`
    if [ ! -z $gateway ] ; then
	if [ $n = "4" ] ; then
	    echo "defaultrouter=\"$gateway\"" >> $routing_conf
	else
	    echo "ipv6_defaultrouter=\"$gateway\"" >> $routing_conf
	fi
    fi
done

#
# Set nameservers
#

if [ $use_do_dns -ne 0 ] ; then
    `$api_item/dns/nameservers` | /sbin/resolvconf -a $pub_if
fi

#
# Merge public keys with droplet_user's authorized keys (if user exists)
#

eval du=~$droplet_user
if [ -d "$du" ] ; then
    ssh_dir="${du}/.ssh"
    if [ ! -d "$ssh_dir" ] ; then
	(mkdir -m 700 $ssh_dir && chown $droplet_user $ssh_dir) || exit 1
    fi
    me=`basename $0`
    do_keys_tmp=`mktemp -t $me` || exit 1
    $api_item/public-keys > $do_keys_tmp || (rm $do_keys_tmp && exit 1)
    auth_keys="${ssh_dir}/.authorized_keys"
    cat $auth_keys >> $do_keys_tmp 2>/dev/null
    sort -u $do_keys_tmp > $auth_keys
    rm $do_keys_tmp
    chown $droplet_user $auth_keys && chmod 600 $auth_keys
fi