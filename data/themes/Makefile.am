themes_keydir = $(datadir)/iagno/themes/key
themes_key_in_files = \
	adwaita.theme.in \
	classic.theme.in \
	high_contrast.theme.in \
	sun_and_star.theme.in
themes_key_DATA = $(themes_key_in_files:.theme.in=.theme)

%.theme: %.theme.in
	$(AM_V_GEN)$(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

EXTRA_DIST = $(themes_key_in_files)

CLEANFILES = $(themes_key_DATA)

-include $(top_srcdir)/git.mk
