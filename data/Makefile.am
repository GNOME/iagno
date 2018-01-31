SUBDIRS = \
	icons \
	themes

dist_noinst_DATA = \
	iagno-screens.ui \
	iagno-themes.ui \
	iagno-menus.ui \
	iagno.ui \
	iagno.css

themedir = $(datadir)/iagno/themes/svg
theme_DATA = \
	high_contrast.svg \
	sun_and_star.svg \
	black_and_white.svg

soundsdir = $(datadir)/iagno/sounds
sounds_DATA = \
	flip-piece.ogg \
	gameover.ogg

desktopdir = $(datadir)/applications
desktop_in_files = iagno.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
$(desktop_DATA): $(desktop_in_files)
	$(AM_V_GEN)$(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

appstream_in_files = iagno.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
$(appstream_XML): $(appstream_in_files)
	$(AM_V_GEN)$(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@

gsettings_SCHEMAS = org.gnome.iagno.gschema.xml
@GSETTINGS_RULES@

man_MANS = iagno.6

EXTRA_DIST = \
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
