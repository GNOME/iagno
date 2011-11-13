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

-include $(top_srcdir)/git.mk
