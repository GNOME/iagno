pixmapdir=$(datadir)/pixmaps/gnothello
Gamesdir = $(datadir)/apps/Games

INCLUDES = 			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR)

bin_PROGRAMS = gnothello

gnothello_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	game-common.c \
	game-skels.c \
	game-stubs.c \
	othello.c \
	game.h \
	othello.h

game-common.c game-skels.c game-stubs.c game.h: game.idl
	orbit-idl game.idl
	
gnothello_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEUI_LIBS)	\
	$(INTLLIBS)

pixmap_DATA = tiles.png

Games_DATA = gnothello.desktop

EXTRA_DIST = AUTHORS \
	     game.idl \
             gnothello.desktop \
             $(pixmap_DATA)

install-data-local:
	-chgrp games $(bindir)/gnothello && chmod 2111 $(bindir)/gnothello
