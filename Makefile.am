SUBDIRS =

if BUILD_HELP
SUBDIRS += help
endif

NULL =

bin_PROGRAMS = iagno
ggzexecmod_PROGRAMS =

if GGZ_SERVER
ggzexecmod_PROGRAMS += iagnod

iagnod_SOURCES = server.h   \
		 server.c   

iagnod_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

iagnod_CFLAGS = \
	$(GGZDMOD_INCLUDES) \
	$(AM_CFLAGS)

iagnod_LDADD = \
	$(INTLLIBS) 		\
	$(LIB_GGZDMOD)
endif

iagno_SOURCES = \
	gnothello.c \
	gnothello.h \
	othello.c \
	othello.h \
	properties.c \
	properties.h \
	$(NULL)

if GGZ_CLIENT
iagno_SOURCES += \
	ggz-network.h \
	ggz-network.c \
	$(NULL)
endif

iagno_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

iagno_CFLAGS = \
	$(GGZ_GTK_INCLUDES) $(GGZMOD_INCLUDES) $(GGZCORE_INCLUDES) \
	$(LIBGGZ_INCLUDES) $(GGZDMOD_INCLUDES) \
	$(GTK_CFLAGS) \
	$(AM_CFLAGS)

iagno_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS) \
	$(INTLLIBS) \
	$(LIB_GGZMOD) \
	$(LIB_GGZ_GTK)

if HAVE_GNOME
iagno_CFLAGS += $(GNOME_CFLAGS)
iagno_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
iagno_CFLAGS += $(RSVG_CFLAGS)
iagno_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
iagno_CFLAGS += $(GHTREAD_CFLAGS)
iagno_LDADD += $(GTHREAD_LIBS)
endif

pixmapdir = $(pkgdatadir)/iagno/pixmaps
pixmap_DATA = \
	classic.png \
	woodtrim.png

Gamesdir = $(datadir)/applications
Games_in_files = iagno.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)

schema_in_files = iagno.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif

man_MANS = iagno.6

if GGZ_SERVER
ggzroom_in_files = iagno.room.in
ggzroom_DATA = $(ggzroom_in_files:.room.in=.room)
ggzroomdir = ${ggzdconfdir}/rooms/

ggzserver_dscdir = ${ggzdconfdir}/games/
ggzserver_dsc_in_files = iagno-server.dsc.in
ggzserver_dsc_DATA = $(ggzserver_dsc_in_files:.dsc.in=.dsc)
endif # GGZ_SERVER

if GGZ_CLIENT
ggzclient_dsc_in_files = iagno-client.dsc.in
endif # GGZ_CLIENT

EXTRA_DIST = \
	AUTHORS \
	iagno-client.dsc.in \
	iagno-server.dsc.in \
        iagno.room.in \
	$(pixmap_DATA)	\
	$(schema_in_files) \
	$(man_MANS)

CLEANFILES = \
	$(ggzroom_DATA) \
	$(ggzserver_dsc_in_files:.dsc.in=.dsc) \
	$(ggzclient_dsc_in_files:.dsc.in=.dsc) \
	$(NULL)

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)

install-data-local: $(ggzclient_dsc_in_files:.dsc.in=.dsc)
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/iagno/$(schema_DATA)
endif
if GGZ_CLIENT
	$(GGZ_CONFIG) -D --install --modfile=iagno-client.dsc --force
endif
uninstall-local:
if GGZ_CLIENT
	-$(GGZ_CONFIG) -D --remove --modfile=iagno-client.dsc
endif

@INTLTOOL_DESKTOP_RULE@
@INTLTOOL_SCHEMAS_RULE@
@INTLTOOL_SOUNDLIST_RULE@
@GNOME_GAMES_GGZ_INTLTOOL_ROOM_RULE@
@GNOME_GAMES_GGZ_DSC_RULE@
