bin_PROGRAMS = iagno
check_PROGRAMS = test-iagno

BUILT_SOURCES = iagno-resources.c

iagno_SOURCES = \
	config.vapi \
	computer-player.vala \
	game.vala \
	game-view.vala \
	themes.vala \
	iagno.vala \
	player.vala \
	$(BUILT_SOURCES)

iagno_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/iagno\" \
	-DSOUND_DIRECTORY=\"$(datadir)/iagno/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	-w \
	$(IAGNO_CFLAGS)

iagno_VALAFLAGS = \
	--pkg posix \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg libcanberra \
	--pkg libcanberra-gtk \
	--gresources=$(builddir)/iagno.gresource.xml \
	--target-glib 2.40

iagno_LDADD = $(IAGNO_LIBS)

test_iagno_SOURCES = \
	test-iagno.vala \
	computer-player.vala \
	game.vala \
	player.vala

test_iagno_VALAFLAGS = \
	--pkg gio-2.0 \
	--target-glib 2.40

test_iagno_CFLAGS = $(IAGNO_CFLAGS)

test_iagno_LDADD = $(IAGNO_LIBS)

check-local: $(check_PROGRAMS)
	$(GTESTER) --keep-going --verbose $(check_PROGRAMS)

iagno-resources.c: $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies iagno.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source iagno.gresource.xml

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

MAINTAINERCLEANFILES = iagno-resources.c

EXTRA_DIST = iagno.gresource.xml

-include $(top_srcdir)/git.mk
