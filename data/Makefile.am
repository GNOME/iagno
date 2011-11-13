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
	$(pixmap_DATA)	\
	$(gsettings_in_file) \
	$(man_MANS)

DISTCLEANFILES = $(Games_DATA) $(gsettings_SCHEMAS)

@INTLTOOL_DESKTOP_RULE@
@INTLTOOL_SOUNDLIST_RULE@

-include $(top_srcdir)/git.mk
