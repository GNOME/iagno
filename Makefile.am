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
	othello.c \
	othello.h

gnothello_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEUI_LIBS)	\
	$(INTLLIBS)

pixmap_DATA = tiles.png

Games_DATA = gnothello.desktop

EXTRA_DIST = AUTHORS \
             gnothello.desktop \
             $(pixmap_DATA)

install-data-local:
	-chgrp games $(bindir)/gnothello && chmod 2111 $(bindir)/gnothello
