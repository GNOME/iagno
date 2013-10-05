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

desktopdir = $(datadir)/applications
desktop_in_files = iagno.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

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
	$(desktop_in_files) \
	$(gsettings_in_file) \
	$(man_MANS)

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
