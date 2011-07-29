SUBDIRS =

if BUILD_HELP
SUBDIRS += help
endif

NULL =

bin_PROGRAMS = iagno

iagno_SOURCES = \
	gnothello.c \
	gnothello.h \
	othello.c \
	othello.h \
	properties.c \
	properties.h \
	$(NULL)

iagno_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

iagno_CFLAGS = \
	$(GTK_CFLAGS) \
	$(AM_CFLAGS)

iagno_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS) \
	$(INTLLIBS)

if HAVE_GNOME
iagno_CFLAGS += $(GNOME_CFLAGS)
iagno_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
iagno_CFLAGS += $(RSVG_CFLAGS)
iagno_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
iagno_CFLAGS += $(GHTREAD_CFLAGS)
iagno_LDADD += $(GTHREAD_LIBS)
endif

pixmapdir = $(pkgdatadir)/iagno/pixmaps
pixmap_DATA = \
	classic.png \
	woodtrim.png \
	small.png

Gamesdir = $(datadir)/applications
Games_in_files = iagno.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)

gsettings_in_file = org.gnome.iagno.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = iagno.6

EXTRA_DIST = \
	AUTHORS \
	$(pixmap_DATA)	\
	$(gsettings_in_file) \
	$(man_MANS)

CLEANFILES = \
	$(NULL)

DISTCLEANFILES = $(Games_DATA) $(gsettings_in_file)

@INTLTOOL_DESKTOP_RULE@
@INTLTOOL_SOUNDLIST_RULE@

-include $(top_srcdir)/git.mk
