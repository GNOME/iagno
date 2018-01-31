themes_keydir = $(datadir)/iagno/themes/key
themes_key_in_files = \
	adwaita.theme.desktop.in \
	classic.theme.desktop.in \
	high_contrast.theme.desktop.in \
	sun_and_star.theme.desktop.in
themes_key_DATA = $(themes_key_in_files:.theme.desktop.in=.theme)

$(themes_key_DATA): %.theme: %.theme.desktop.in $(wildcard $(top_srcdir)/po/*po)
	$(AM_V_GEN)$(MSGFMT) --desktop --keyword=Name --template $< -d $(top_srcdir)/po -o $@

EXTRA_DIST = $(themes_key_in_files)

CLEANFILES = $(themes_key_DATA)

-include $(top_srcdir)/git.mk
