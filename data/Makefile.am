SUBDIRS = icons

uidir = $(datadir)/iagno
ui_DATA = \
	iagno-menus.ui \
	iagno.ui

imagedir = $(datadir)/iagno/images
image_DATA = \
	dark.svg \
	light.svg \
	mark.svg

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

appstream_in_files = iagno.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@
@INTLTOOL_XML_RULE@

gsettings_SCHEMAS = org.gnome.iagno.gschema.xml
@GSETTINGS_RULES@

man_MANS = iagno.6

EXTRA_DIST = \
	$(ui_DATA) \
	$(image_DATA) \
	$(theme_DATA) \
	$(sounds_DATA) \
	$(appstream_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
