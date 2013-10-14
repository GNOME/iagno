bin_PROGRAMS = iagno
check_PROGRAMS = test-iagno

iagno_SOURCES = \
	config.vapi \
	computer-player.vala \
	game.vala \
	game-view.vala \
	iagno.vala \
	player.vala

iagno_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/iagno\" \
	-DSOUND_DIRECTORY=\"$(datadir)/iagno/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(IAGNO_CFLAGS)

iagno_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg libcanberra \
	--pkg libcanberra-gtk \
	--target-glib 2.36

iagno_LDADD = $(IAGNO_LIBS)

test_iagno_SOURCES = \
	test-iagno.vala \
	computer-player.vala \
	game.vala \
	player.vala

test_iagno_CFLAGS = $(IAGNO_CFLAGS)

test_iagno_LDADD = $(IAGNO_LIBS)

check-local: $(check_PROGRAMS)
	$(GTESTER) --keep-going --verbose $(check_PROGRAMS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
