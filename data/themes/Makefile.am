themes_keydir = $(datadir)/iagno/themes/key
themes_key_in_files = \
	adwaita.theme.in \
	classic.theme.in \
	high_contrast.theme.in \
	sun_and_star.theme.in
themes_key_DATA = $(themes_key_in_files:.theme.in=.theme)

%.theme: %.theme.in $(INTLTOOL_MERGE) $(wildcard $(top_srcdir)/po/*.po)
	$(AM_V_GEN) LC_ALL=C $(INTLTOOL_MERGE) -d -u -c $(top_builddir)/po/.intltool-merge-cache $(top_srcdir)/po $< $@

EXTRA_DIST = $(themes_key_in_files)

CLEANFILES = $(themes_key_DATA)

-include $(top_srcdir)/git.mk
