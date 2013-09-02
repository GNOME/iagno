SUBDIRS = icons

uidir = $(datadir)/iagno
ui_DATA = iagno.ui

themedir = $(datadir)/iagno/themes
theme_DATA = \
	sun_and_star.svg \
	black_and_white.svg \
	blend.png \
	flipblend.png \
	metal.png \
	metal2.png \
	shrink.png \
	sunmoon.png

soundsdir = $(datadir)/iagno/sounds
sounds_DATA = \
	flip-piece.ogg \
	gameover.ogg

Gamesdir = $(datadir)/applications
Games_in_files = iagno.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)

appdatadir = $(datadir)/appdata
appdata_files = iagno.appdata.xml

gsettings_in_file = org.gnome.iagno.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = iagno.6

EXTRA_DIST = \
	$(ui_DATA) \
	$(theme_DATA) \
	$(sounds_DATA) \
	$(appdata_files) \
	$(gsettings_in_file) \
	$(man_MANS)

CLEANFILES = $(Games_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(Games_DATA) $(gsettings_SCHEMAS)

@INTLTOOL_DESKTOP_RULE@

-include $(top_srcdir)/git.mk
