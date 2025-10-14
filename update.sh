#!/bin/sh
# shellcheck disable=SC2016  # Literal single quotes in echo output

prefix=/usr/local

echo "--------------------------------------"
echo
echo "Installing digitalocean"
echo
echo "Edit configuration settings in ${prefix}/etc/digitalocean.conf"

install -d "${prefix}/etc/rc.d"
install -d "${prefix}/sbin"

install -m 0700 digitalocean "${prefix}/etc/rc.d/"
install -m 0700 digitalocean.sh "${prefix}/sbin/"

if [ ! -f "${prefix}/etc/digitalocean.conf" ]; then
	install -m 0644 digitalocean.conf "${prefix}/etc"
else
	if ! diff -q digitalocean.conf "${prefix}/etc/digitalocean.conf" >/dev/null 2>&1; then
		install -m 0644 digitalocean.conf "${prefix}/etc/digitalocean.conf.sample"
		echo "Review default settings in ${prefix}/etc/digitalocean.conf.sample"
	fi
fi

if ! grep -q 'digitalocean_enable=' /etc/rc.conf 2>/dev/null; then
	echo
	echo "To enable, add this to /etc/rc.conf"
	echo
	echo '	digitalocean_enable="YES"'
fi

echo
echo "--------------------------------------"
