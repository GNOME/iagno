scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/iagno
Gamesdir = $(datadir)/applications
appicondir=$(datadir)/pixmaps

INCLUDES =						\
	-I$(top_srcdir)/libgames-support		\
	$(WARN_CFLAGS)					\
	$(GNOME_GAMES_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"		   \
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"	\
	-DG_DISABLE_DEPRECATED -DGDK_DISABLE_DEPRECATED \
	-DGTK_DISABLE_DEPRECATED -DGNOME_DISABLE_DEPRECATED

bin_PROGRAMS = iagno

iagno_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	network.h	\
	othello.c \
	othello.h \
	properties.c \
	properties.h

iagno_LDADD = \
	$(GNOME_GAMES_LIBS) \
	../libgames-support/libgames-support.la \
	$(INTLLIBS)

pixmap_DATA = \
	blend.png \
	classic.png \
	flipblend.png \
	metal.png \
	metal2.png \
	shrink.png \
	woodtrim.png

appicon_DATA = iagno.png

Games_in_files = iagno.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schemadir   = $(sysconfdir)/gconf/schemas
schema_in_files = iagno.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = AUTHORS \
             iagno.desktop.in 	\
	     iagno.soundlist.in \
             $(pixmap_DATA)	\
	     $(appicon_DATA)	\
	     $(schema_DATA)

install-data-local:
	GCONF_CONFIG_SOURCE=$(GCONF_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(srcdir)/$(schema_DATA)
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	touch $(DESTDIR)$(scoredir)/iagno.w1.scores
	touch $(DESTDIR)$(scoredir)/iagno.w2.scores
	touch $(DESTDIR)$(scoredir)/iagno.w3.scores
	touch $(DESTDIR)$(scoredir)/iagno.b1.scores
	touch $(DESTDIR)$(scoredir)/iagno.b2.scores
	touch $(DESTDIR)$(scoredir)/iagno.b3.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.w1.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.w2.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.w3.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.b1.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.b2.scores
	-chown games.games $(DESTDIR)$(scoredir)/iagno.b3.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.w1.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.w2.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.w3.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.b1.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.b2.scores
	-chmod 664 $(DESTDIR)$(scoredir)/iagno.b3.scores
	-chgrp games $(DESTDIR)$(bindir)/iagno && chmod 2111 $(DESTDIR)$(bindir)/iagno

soundlistdir = $(sysconfdir)/sound/events
soundlist_in_files = iagno.soundlist.in
soundlist_DATA = $(soundlist_in_files:.soundlist.in=.soundlist)
@INTLTOOL_SOUNDLIST_RULE@

SUBDIRS=sounds help

