scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/iagno
Gamesdir = $(datadir)/gnome/apps/Games
appicondir=$(datadir)/pixmaps

INCLUDES = 	$(GNOME_GAMES_CFLAGS)		\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	 -I. 

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

Games_DATA = iagno.desktop

EXTRA_DIST = AUTHORS \
             iagno.desktop 	\
	     iagno.soundlist \
             $(pixmap_DATA)	\
	     $(appicon_DATA)

install-data-local:
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
soundlist_DATA = iagno.soundlist

SUBDIRS=sounds help

