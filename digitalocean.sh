#!/bin/sh
# shellcheck disable=SC2312  # Piped commands intentionally use exit status of last command
# shellcheck disable=SC2154  # Variables sourced from config file
# shellcheck disable=SC2086  # api_item must expand unquoted (contains command with args)

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

if [ -f "${conf}" ]; then
	# shellcheck source=/dev/null
	# shellcheck disable=SC2034  # Variables used throughout script
	. "${conf}"
else
	echo "$0: unable to load configuration file: ${conf}" >&2
	exit 1
fi

# Verify required variables from config
: "${hostname_conf?Error: 'hostname_conf' not set in ${conf}}"
: "${network_conf?Error: 'network_conf' not set in ${conf}}"
: "${routing_conf?Error: 'routing_conf' not set in ${conf}}"
: "${pub_if?Error: 'pub_if' not set in ${conf}}"
: "${pvt_if?Error: 'pvt_if' not set in ${conf}}"
: "${api_item?Error: 'api_item' not set in ${conf}}"

#
# update hostid; needed for deploying from snapshots
#

hostid=$(kenv -q smbios.system.uuid)
if [ -e /etc/hostid ]; then
	echo "current hostID = $(cat /etc/hostid)"
fi
echo "new hostID = $hostid"
echo "$hostid" > /etc/hostid

#
# resize the disk (enables droplet resizing)
#

if [ "$auto_resize" = "1" ]; then
	/sbin/gpart recover vtbd0
	/sbin/gpart resize -i3 vtbd0

	if [ -e /dev/gpt/disk0 ]; then
		/sbin/zpool online -e zroot gpt/disk0
	else
		/sbin/growfs -y /dev/gpt/rootfs
	fi
fi

#
# Update hosts file
#

update_hosts() {
	if [ -n "${hosts_file}" ]; then
		host_addr="$1"
		host_name="$2"

		if [ ! -e "${hosts_file}" ]; then
			touch "${hosts_file}" || return 1
		fi

		if grep -q "${host_name}" "${hosts_file}"; then
			sed -r -i '' "/${host_name}/s/^[0-9a-f\.:]+/${host_addr}/" "${hosts_file}"
		else
			echo "${host_addr}	${host_name}" >> "${hosts_file}"
		fi
	fi
}

#
# Set hostname
#

echo "# digitalocean hostname configuration" > "${hostname_conf}"

hostname=$(${api_item}/hostname)
echo "Configuring DigitalOcean droplet for ${hostname}"
echo "hostname=\"${hostname}\"" >> "${hostname_conf}"

#
# Set networking
#

echo "# digitalocean network configuration" > "${network_conf}"

for i in $(${api_item}/interfaces); do
	case "$i" in
	"public"*)
		net_if="${pub_if}"
		addr_name="DO_PUB_IPV"
		;;
	"private"*)
		net_if="${pvt_if}"
		addr_name="DO_PVT_IPV"
		;;
	*)
		net_if=""
	esac

	if [ -n "${net_if}" ]; then
		for n in 4 6; do
			ip=$(${api_item}/interfaces/"${i}"0/ipv"${n}"/address 2>/dev/null)
			if [ -n "${ip}" ]; then
				if [ "${n}" = "4" ]; then
					mask=$(${api_item}/interfaces/"${i}"0/ipv4/netmask)
					echo "ifconfig_${net_if}=\"inet ${ip} netmask ${mask}\"" >> "${network_conf}"
				else
					cidr=$(${api_item}/interfaces/"${i}"0/ipv6/cidr)
					echo "ifconfig_${net_if}_ipv6=\"inet6 ${ip}/${cidr}\"" >> "${network_conf}"
				fi
				update_hosts "${ip}" "${addr_name}${n}"
			fi
		done
	fi
done

#
# Support floating IP by adding anchor IP
#

for n in 4 6; do
	fip_active=$(${api_item}/floating_ip/ipv"${n}"/active 2>/dev/null)
	if [ "${fip_active}" = "true" ]; then
		fip=$(${api_item}/floating_ip/ipv"${n}"/ip_address)
		aip=$(${api_item}/interfaces/public/0/anchor_ipv"${n}"/address)
		v=""
		if [ "${n}" = "6" ]; then
			v="${n}"
		fi
		echo "floating_ipv${n}=\"${fip}\"" >> "${network_conf}"
		update_hosts "${fip}" "DO_FLOATING_IPV${n}"
		echo "ifconfig_${pub_if}_alias0=\"inet${v} ${aip}/16\"" >> "${network_conf}"
		update_hosts "${aip}" "DO_ANCHOR_IPV${n}"
	fi
done

#
# Set routing
#

echo "# digitalocean routing configuration" > "${routing_conf}"
for n in 4 6; do
	gateway=$(${api_item}/interfaces/public/0/ipv"${n}"/gateway 2>/dev/null)
	if [ -n "${gateway}" ]; then
		if [ "${n}" = "4" ]; then
			echo "defaultrouter=\"${gateway}\"" >> "${routing_conf}"
		else
			echo "ipv6_defaultrouter=\"${gateway}\"" >> "${routing_conf}"
		fi
		update_hosts "${gateway}" "DO_GW_IPV${n}"
	fi
done

#
# Set nameservers
#

if [ "${use_do_dns}" = "1" ]; then
	${api_item}/dns/nameservers | sed 's/^/nameserver /' | /sbin/resolvconf -a "${pub_if}"
fi

#
# Merge public keys with droplet_user's authorized keys (if user exists)
#

if [ -n "${droplet_user}" ]; then
	du=$(eval echo "~${droplet_user}")
	if [ -d "${du}" ]; then
		ssh_dir="${du}/.ssh"
		auth_keys="${ssh_dir}/authorized_keys"

		# Create .ssh directory if it doesn't exist
		if [ ! -d "${ssh_dir}" ]; then
			if ! mkdir -m 700 "${ssh_dir}"; then
				echo "Failed to create ${ssh_dir}" >&2
				exit 1
			fi
			if ! chown "${droplet_user}" "${ssh_dir}"; then
				echo "Failed to chown ${ssh_dir}" >&2
				exit 1
			fi
		fi

		# Fetch and merge public keys
		me=$(basename -- "$0")
		do_keys_tmp=$(mktemp -t "${me}") || exit 1

		if ! ${api_item}/public-keys > "${do_keys_tmp}"; then
			rm "${do_keys_tmp}"
			exit 1
		fi

		# Append existing authorized_keys if present
		if [ -f "${auth_keys}" ]; then
			cat "${auth_keys}" >> "${do_keys_tmp}"
		fi

		# Write unique sorted keys and set permissions
		sort -u "${do_keys_tmp}" > "${auth_keys}"
		rm "${do_keys_tmp}"

		if ! chown "${droplet_user}" "${auth_keys}"; then
			echo "Failed to chown ${auth_keys}" >&2
			exit 1
		fi
		if ! chmod 600 "${auth_keys}"; then
			echo "Failed to chmod ${auth_keys}" >&2
			exit 1
		fi
	fi
fi

#
# Run commands provided via 'user-data'
#

userdata=$(${api_item}/user-data)

if [ -n "${userdata}" ]; then
	userscript=$(mktemp -t userdata) || exit 1
	echo "${userdata}" > "${userscript}"
	if ! /bin/sh "${userscript}"; then
		echo "Warning: user-data script failed" >&2
	fi
	rm "${userscript}"
fi
