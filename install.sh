#!/bin/sh

prefix=/usr/local

echo "--------------------------------------"
echo
echo "Installing digitalocean"
echo
echo "Edit configuration settings in $prefix/etc/digitalocean.conf"

install -m 700 digitalocean $prefix/etc/rc.d
install -m 700 digitalocean.sh $prefix/sbin

if [ ! -f $prefix/etc/digitalocean.conf ] ; then
	install -m 644 digitalocean.conf $prefix/etc
else
	if [ ! -z "`diff digitalocean.conf $prefix/etc/digitalocean.conf`" ] ; then
		install -m 644 digitalocean.conf $prefix/etc/digitalocean.conf.sample
		echo "Review default settings in $prefix/etc/digitalocean.conf.sample"
	fi
fi

if [ -z "`grep 'digitalocean_enable=' /etc/rc.conf`" ] ; then
	echo
	echo "To enable, add this to /etc/rc.conf"
	echo
	echo '	digitalocean_enable="YES"'
fi

echo
echo "--------------------------------------"
