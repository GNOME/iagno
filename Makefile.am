scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/iagno
Gamesdir = $(datadir)/gnome/apps/Games
appicondir=$(datadir)/pixmaps

INCLUDES = 			\
	-DHAVE_ORBIT \
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR) -I.

bin_PROGRAMS = iagno

CORBA_SRCS = gnothello-game-common.c gnothello-game-skels.c gnothello-game-stubs.c gnothello-game.h
iagno_SOURCES = \
	gnothello.c \
	gnothello.h \
	network.c   \
	network.h	\
	$(CORBA_SRCS) \
	othello.c \
	othello.h \
	properties.c \
	properties.h

$(srcdir)/network.c $(srcdir)/network.h: $(CORBA_SRCS)

CLEANFILES = $(CORBA_SRCS)

BUILT_SOURCES = $(CORBA_SRCS)

$(CORBA_SRCS): built_corba_srcs

built_corba_srcs: $(top_srcdir)/idl/gnothello-game.idl $(ORBIT_IDL)
	$(ORBIT_IDL) $<
	touch built_corba_srcs

iagno_LDADD = \
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

CLEAN_FILES=built_corba_srcs
