pixmapdir=$(datadir)/pixmaps/gnothello
Gamesdir = $(datadir)/apps/Games

INCLUDES = 			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR) $(ORBIT_CFLAGS)

bin_PROGRAMS = gnothello

CORBA_SRCS = game-common.c game-skels.c game-stubs.c game.h
gnothello_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	$(CORBA_SRCS) \
	othello.c \
	othello.h

BUILT_SOURCES = $(CORBA_SRCS)

$(CORBA_SRCS): game.idl
	orbit-idl $<

gnothello_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEUI_LIBS)	\
	$(ORBIT_LIBS) \
	$(INTLLIBS)

pixmap_DATA = tiles.png

Games_DATA = gnothello.desktop

EXTRA_DIST = AUTHORS \
	     game.idl \
             gnothello.desktop \
             $(pixmap_DATA)

install-data-local:
	-chgrp games $(bindir)/gnothello && chmod 2111 $(bindir)/gnothello
