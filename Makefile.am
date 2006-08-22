pixmapdir=$(datadir)/pixmaps/iagno
Gamesdir = $(datadir)/applications
icondir=$(datadir)/icons/hicolor/48x48/apps/
svgicondir = $(datadir)/icons/hicolor/scalable/apps/

INCLUDES =						\
	-I$(top_srcdir)/libgames-support		\
	$(WARN_CFLAGS)					\
	$(GNOME_GAMES_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"		   \
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"

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
	../libgames-support/libgames-support.la \
	$(GNOME_GAMES_LIBS) \
	$(AVAHI_LIBS) \
	$(BONJOUR_LIBS) \
	$(HOWL_LIBS) \
	$(INTLLIBS)

pixmap_DATA = \
	classic.png \
	woodtrim.png

icon_DATA = gnome-iagno.png
svgicon_DATA = gnome-iagno.svg

Games_in_files = iagno.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = iagno.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = AUTHORS \
	iagno.desktop.in 	\
	iagno.soundlist.in \
	$(pixmap_DATA)	\
	$(icon_DATA)	\
	$(svgicon_DATA) \
	$(schema_in_files)

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/iagno/$(schema_DATA)
endif

soundlistdir = $(sysconfdir)/sound/events
soundlist_in_files = iagno.soundlist.in
soundlist_DATA = $(soundlist_in_files:.soundlist.in=.soundlist)
@INTLTOOL_SOUNDLIST_RULE@

SUBDIRS=sounds help

DISTCLEANFILES = $(Games_DATA) $(schema_DATA) $(soundlist_DATA)
