pixmapdir=$(datadir)/pixmaps/gnothello
Gamesdir = $(datadir)/apps/Games
appicondir=$(datadir)/pixmaps

INCLUDES = 			\
	-DHAVE_ORBIT \
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR)

bin_PROGRAMS = gnothello

CORBA_SRCS = gnothello-game-common.c gnothello-game-skels.c gnothello-game-stubs.c gnothello-game.h
gnothello_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	network.h	\
	$(CORBA_SRCS) \
	othello.c \
	othello.h

CLEANFILES = $(CORBA_SRCS)

BUILT_SOURCES = $(CORBA_SRCS)

$(CORBA_SRCS): $(top_srcdir)/idl/gnothello-game.idl $(ORBIT_IDL)
	$(ORBIT_IDL) $<

gnothello_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEGNORBA_LIBS)	\
	$(INTLLIBS)

pixmap_DATA = \
	classic.png \
	metal.png \
	metal2.png \
	woodtrim.png

appicon_DATA = gnothello.png

Games_DATA = gnothello.desktop

EXTRA_DIST = AUTHORS \
             gnothello.desktop 	\
             $(pixmap_DATA)	\
	     $(appicon_DATA)

install-data-local:
	-chgrp games $(bindir)/gnothello && chmod 2111 $(bindir)/gnothello
