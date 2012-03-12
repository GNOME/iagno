bin_PROGRAMS = iagno

iagno_SOURCES = \
	config.vapi \
	computer-player.vala \
	game.vala \
	game-view.vala \
	iagno.vala

iagno_CFLAGS = \
	-I$(top_srcdir)/libgames-support \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/iagno\" \
	-DSOUND_DIRECTORY=\"$(datadir)/iagno/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(RSVG_CFLAGS) \
	$(CANBERRA_GTK_CFLAGS)

iagno_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg libcanberra \
	--pkg libcanberra-gtk \
	--vapidir $(top_srcdir)/libgames-support \
	--pkg GnomeGamesSupport-1.0

iagno_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS) \
	$(RSVG_LIBS) \
	$(CANBERRA_GTK_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
