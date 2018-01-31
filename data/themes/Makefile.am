themes_keydir = $(datadir)/iagno/themes/key
themes_key_in_files = \
	adwaita.desktop.in \
	classic.desktop.in \
	high_contrast.desktop.in \
	sun_and_star.desktop.in
themes_key_DATA = $(themes_key_in_files:.desktop.in=.desktop)

%.desktop: %.desktop.in
	$(AM_V_GEN)$(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

EXTRA_DIST = $(themes_key_in_files)

CLEANFILES = $(themes_key_DATA)

-include $(top_srcdir)/git.mk
