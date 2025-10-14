RUNFILES=	digitalocean digitalocean.sh update.sh
DOCFILES=	README.md digitalocean.conf
DESTDIR=	/usr/local/dtl/droplet/freebsd-digitalocean
FILESOWN=	root
FILESGRP=	operator
RUNMODE=	0550
DOCMODE=	0640

install: runfiles docfiles

docfiles: $(DOCFILES)
	install -o $(FILESOWN) -g $(FILESGRP) -m $(DOCMODE) $(DOCFILES) $(DESTDIR)

runfiles: $(RUNFILES)
	install -o $(FILESOWN) -g $(FILESGRP) -m $(RUNMODE) $(RUNFILES) $(DESTDIR)

