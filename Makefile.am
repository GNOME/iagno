SUBDIRS= help

NULL =

pixmapdir=$(datadir)/gnome-games/iagno/pixmaps
Gamesdir = $(datadir)/applications

INCLUDES =						\
	-I$(top_srcdir)		\
	$(WARN_CFLAGS)					\
	-DDATADIR=\""$(datadir)"\"		   	\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"	\
	$(GGZ_GTK_INCLUDES) $(GGZMOD_INCLUDES) $(GGZCORE_INCLUDES) \
	$(LIBGGZ_INCLUDES) $(GGZCORE_INCLUDES) $(GGZDMOD_INCLUDES) \
	$(GNOME_GAMES_CFLAGS)

bin_PROGRAMS = iagno
ggzexecmod_PROGRAMS =

if GGZ_SERVER
ggzexecmod_PROGRAMS += iagnod
iagnod_SOURCES = server.h   \
		 server.c   

iagnod_LDADD = \
	$(GNOME_GAMES_LIBS)     \
	$(INTLLIBS) 		\
	$(LIB_GGZDMOD)
endif

if GGZ_CLIENT
GGZ_FILES =	ggz-network.h \
		ggz-network.c \
		$(NULL)
endif

iagno_SOURCES = \
	gnothello.c \
	gnothello.h \
	othello.c \
	othello.h \
	properties.c \
	properties.h \
	$(GGZ_FILES)

iagno_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GNOME_GAMES_LIBS) \
	$(INTLLIBS) \
	$(LIB_GGZMOD) \
	$(LIB_GGZ_GTK)

pixmap_DATA = \
	classic.png \
	woodtrim.png

Games_in_files = iagno.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = iagno.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)


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
	$(schema_in_files)

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
