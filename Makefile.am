scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/gnothello
Gamesdir = $(datadir)/apps/Games
appicondir=$(datadir)/pixmaps

INCLUDES = 			\
	-DHAVE_ORBIT \
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR) -I.

bin_PROGRAMS = reversi

CORBA_SRCS = gnothello-game-common.c gnothello-game-skels.c gnothello-game-stubs.c gnothello-game.h
reversi_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	network.h	\
	$(CORBA_SRCS) \
	othello.c \
	othello.h

$(srcdir)/network.c $(srcdir)/network.h: $(CORBA_SRCS)

CLEANFILES = $(CORBA_SRCS)

BUILT_SOURCES = $(CORBA_SRCS)

$(CORBA_SRCS): $(top_srcdir)/idl/gnothello-game.idl $(ORBIT_IDL)
	$(ORBIT_IDL) $<

reversi_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEGNORBA_LIBS)	\
	$(INTLLIBS)

pixmap_DATA = \
	blend.png \
	classic.png \
	flipblend.png \
	metal.png \
	metal2.png \
	shrink.png \
	woodtrim.png

appicon_DATA = gnothello.png

Games_DATA = gnothello.desktop

EXTRA_DIST = AUTHORS \
             gnothello.desktop 	\
	     gnothello.soundlist \
             $(pixmap_DATA)	\
	     $(appicon_DATA)

install-data-local:
	-$(mkinstalldirs) $(scoredir)
	touch $(scoredir)/gnothello.w1.scores
	touch $(scoredir)/gnothello.w2.scores
	touch $(scoredir)/gnothello.w3.scores
	touch $(scoredir)/gnothello.b1.scores
	touch $(scoredir)/gnothello.b2.scores
	touch $(scoredir)/gnothello.b3.scores
	-chown games.games $(scoredir)/gnothello.w1.scores
	-chown games.games $(scoredir)/gnothello.w2.scores
	-chown games.games $(scoredir)/gnothello.w3.scores
	-chown games.games $(scoredir)/gnothello.b1.scores
	-chown games.games $(scoredir)/gnothello.b2.scores
	-chown games.games $(scoredir)/gnothello.b3.scores
	-chmod 664 $(scoredir)/gnothello.w1.scores
	-chmod 664 $(scoredir)/gnothello.w2.scores
	-chmod 664 $(scoredir)/gnothello.w3.scores
	-chmod 664 $(scoredir)/gnothello.b1.scores
	-chmod 664 $(scoredir)/gnothello.b2.scores
	-chmod 664 $(scoredir)/gnothello.b3.scores
	-chgrp games $(bindir)/gnothello && chmod 2111 $(bindir)/gnothello

soundlistdir = $(sysconfdir)/sound/events
soundlist_DATA = gnothello.soundlist
