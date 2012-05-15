# Makefile for Spk.
#

PACKAGE="spk"
PREFIX?=/usr
LINGUAS?=

all: help

# i18n

pot:
	xgettext -o po/$(PACKAGE).pot -L Shell --package-name="Spk" \
		./spk ./spk-rm

msgmerge:
	@for l in $(LINGUAS); do \
		echo -n "Updating $$l po file."; \
		msgmerge -U po/$$l.po po/$(PACKAGE).pot; \
	done;

msgfmt:
	@for l in $(LINGUAS); do \
		echo "Compiling $$l mo file..."; \
		mkdir -p po/mo/$$l/LC_MESSAGES; \
		msgfmt -o po/mo/$$l/LC_MESSAGES/$(PACKAGE).mo po/$$l.po; \
	done;

# Install

install-msg: msgfmt
	install -m 0755 -d $(DESTDIR)$(PREFIX)/share/locale
	cp -a po/mo/* $(DESTDIR)$(PREFIX)/share/locale

install-lib:
	install -m 0755 -d $(DESTDIR)$(PREFIX)/lib/slitaz
	install -m 0755 lib/libspk.sh $(DESTDIR)$(PREFIX)/lib/slitaz

install: install-lib
	install -m 0755 -d $(DESTDIR)$(PREFIX)/bin
	install -m 0755 -d $(DESTDIR)$(PREFIX)/sbin
	install -m 0755 -d $(DESTDIR)$(PREFIX)/share/doc/spk
	install -m 0755 spk $(DESTDIR)$(PREFIX)/bin
	install -m 0755 spk-ls $(DESTDIR)$(PREFIX)/bin
	install -m 0755 spk-rm $(DESTDIR)$(PREFIX)/sbin

# Clean source

clean:
	rm -rf po/mo
	rm -f po/*~

