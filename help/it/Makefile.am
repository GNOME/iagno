iagno_helpdir = $(datadir)/gnome/help/iagno/it

figs = \
	ANIMATION.png \
	BLOCK.png \
	FIRST.png \
	PLAYER.png \
	START.png

iagno_help_DATA = 	\
	iagno.sgml		\
	index.html		\
	topic.dat

EXTRA_DIST = $(iagno_help_DATA) $(figs)

all: index.html

# No-op if db2html failed
index.html: iagno/index.html
	-cd $(srcdir) && cp iagno/index.html index.html

iagno/index.html: iagno.sgml
	-cd $(srcdir) && db2html iagno.sgml

dist-hook:
	-mkdir $(distdir)/iagno
	-mkdir $(distdir)/iagno/stylesheet-images
	cp $(srcdir)/iagno/*.html $(distdir)/iagno
	cp -R $(srcdir)/iagno/stylesheet-images/*.gif $(distdir)/iagno/stylesheet-images
	cp $(srcdir)/iagno/*.css $(distdir)/iagno

# No-op if db2html failed
install-data-local: index.html
	-$(mkinstalldirs) $(DESTDIR)$(iagno_helpdir)
	files=`echo $(srcdir)/iagno/*.html $(srcdir)/iagno/*.css $(srcdir)/*.png`; \
	if test "$$files" != '$(srcdir)/iagno/*.html $(srcdir)/iagno/*.css $(srcdir)/*.png'; then \
	  for file in $$files; do \
	    basefile=`echo $$file | sed -e 's,^.*/,,'`; \
	    $(INSTALL_DATA) $$file $(DESTDIR)$(iagno_helpdir)/$$basefile; \
	  done; \
	fi
	-$(mkinstalldirs) $(DESTDIR)$(iagno_helpdir)/stylesheet-images
	files=`echo $(srcdir)/iagno/stylesheet-images/*.gif`; \
	if test "$$files" != '$(srcdir)/iagno/stylesheet-images/*.gif'; then \
	  for file in $$files; do \
	    basefile=`echo $$file | sed -e 's,^.*/,,'`; \
	    $(INSTALL_DATA) $$file $(DESTDIR)$(iagno_helpdir)/stylesheet-images/$$basefile; \
	  done; \
	fi

iagno.ps: iagno.sgml
	db2ps $<

iagno.rtf: iagno.sgml
	db2rtf $<
