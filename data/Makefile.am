SUBDIRS = icons

uidir = $(datadir)/iagno
ui_DATA = iagno.ui

themedir = $(datadir)/iagno/themes
theme_DATA = \
	sun_and_star.svg \
	black_and_white.svg

soundsdir = $(datadir)/iagno/sounds
sounds_DATA = \
	flip-piece.ogg \
	gameover.ogg

desktopdir = $(datadir)/applications
desktop_in_files = iagno.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = iagno.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

gsettings_SCHEMAS = org.gnome.iagno.gschema.xml
@GSETTINGS_RULES@

man_MANS = iagno.6

EXTRA_DIST = \
	$(ui_DATA) \
	$(theme_DATA) \
	$(sounds_DATA) \
	$(appdata_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
