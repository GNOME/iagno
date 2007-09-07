pixmapdir=$(datadir)/pixmaps/iagno
Gamesdir = $(datadir)/applications

INCLUDES =						\
	-I$(top_srcdir)/libgames-support		\
	$(WARN_CFLAGS)					\
	$(GNOME_GAMES_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"		   	\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"	\
	$(GGZMOD_INCLUDES) $(GGZ_GTK_INCLUDES) $(GGZCORE_INCLUDES)\
	$(LIBGGZ_INCLUDES) $(GGZCORE_INCLUDES) $(GGZDMOD_INCLUDES)

if GGZ_SERVER
bin_PROGRAMS = iagno iagnod
iagnod_SOURCES = server.h   \
		 server.c   

iagnod_LDFLAGS = @GGZDMOD_LDFLAGS@

iagnod_LDADD = \
	$(GNOME_GAMES_LIBS)     \
	$(INTLLIBS) 		\
	@LIB_GGZDMOD@

else
bin_PROGRAMS = iagno 
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

iagno_LDFLAGS = $(GGZMOD_LDFLAGS)

iagno_LDADD = \
	../libgames-support/libgames-support.la \
	$(GNOME_GAMES_LIBS) \
	$(INTLLIBS) \
	$(LIB_GGZMOD) \
	$(LIB_GGZ_GTK)

pixmap_DATA = \
	classic.png \
	woodtrim.png

Games_in_files = iagno.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = iagno.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = \
	AUTHORS \
	iagno-client.dsc.in \
	iagno-server.dsc.in \
        iagno.room          \
	$(pixmap_DATA)	\
	$(schema_in_files)

install-data-local:
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

@INTLTOOL_SOUNDLIST_RULE@

SUBDIRS= help

DISTCLEANFILES = $(Games_DATA) $(schema_DATA) 

if GGZ_SERVER
ggzroom_DATA = iagno.room
ggzroomdir = ${prefix}/etc/ggzd/rooms/

ggzgame_DATA = iagno-server.dsc
ggzgamedir = ${prefix}/etc/ggzd/games/
endif

