#include <config.h>
#include <gnome.h>
#include <dirent.h>

#include "properties.h"
#include "gnothello.h"
#include "othello.h"

static GtkWidget *propbox = NULL;

extern GtkWidget *window;
extern GtkWidget *time_display;
extern guint black_computer_level;
extern guint white_computer_level;
extern guint computer_speed;
extern gint timer_valid;
extern guint black_computer_id;
extern guint white_computer_id;
extern gchar tile_set[255];
extern gchar tile_set_tmp[255];
extern gint8 pixmaps[8][8];
extern gint animate;
extern gint animate_stagger;
extern gint flip_pixmaps_id;
extern gint flip_final;
extern gint grid;

guint t_black_computer_level;
guint t_white_computer_level;
gint t_animate;
gint t_quick_moves;
gint t_animate_stagger;
gint t_flip_final;
gint t_grid;

int mapped = 0;

void load_properties ()
{
	black_computer_level = gnome_config_get_int
		("/iagno/Preferences/blacklevel=0");
	white_computer_level = gnome_config_get_int
		("/iagno/Preferences/whitelevel=0");
	strncpy (tile_set, gnome_config_get_string
			("/iagno/Preferences/tileset=classic.png"), 255);
	animate = gnome_config_get_int ("/iagno/Preferences/animate=2");
	animate_stagger = gnome_config_get_int
		("/iagno/Preferences/animstagger=0");
	grid = gnome_config_get_int
		("/iagno/Preferences/grid=0");
	if (gnome_config_get_int ("/iagno/Preferences/quickmoves=0"))
		computer_speed = COMPUTER_MOVE_DELAY / 2;
	else
		computer_speed = COMPUTER_MOVE_DELAY;
	flip_final = gnome_config_get_int
		("/iagno/Preferences/flipfinal=1");
	
	switch (animate) {
		case 0:
			flip_pixmaps_id = gtk_timeout_add (100, flip_pixmaps,
					NULL);
			break;
		case 1:
			flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY *
					8, flip_pixmaps, NULL);
			break;
		case 2: flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY,
					flip_pixmaps, NULL);
			break;
	}
}

void reset_properties ()
{
	t_black_computer_level = black_computer_level = gnome_config_get_int
		("/iagno/Preferences/blacklevel=0");
	t_white_computer_level = white_computer_level = gnome_config_get_int
		("/iagno/Preferences/whitelevel=0");
        strncpy (tile_set_tmp, tile_set, 255);
	t_animate = animate;
	t_quick_moves = gnome_config_get_int
		("/iagno/Preferences/quickmoves");
	t_animate_stagger = animate_stagger;
	t_grid = grid;
	t_flip_final = flip_final;
}

void black_computer_level_select (GtkWidget *widget, gpointer data)
{
	if (((guint) data != t_black_computer_level) &&
		       (GTK_TOGGLE_BUTTON (widget)->active)) {
		t_black_computer_level = (guint) data;
		if (mapped)
			gnome_property_box_changed (GNOME_PROPERTY_BOX
					(propbox));
	}
}

void white_computer_level_select (GtkWidget *widget, gpointer data)
{
	if (((guint) data != t_white_computer_level) &&
		       (GTK_TOGGLE_BUTTON (widget)->active)) {
		t_white_computer_level = (guint) data;
		if (mapped)
			gnome_property_box_changed (GNOME_PROPERTY_BOX
					(propbox));
	}
}

void quick_moves_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_quick_moves = 1;
	else
		t_quick_moves = 0;

	gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
}

void flip_final_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_flip_final = 1;
	else
		t_flip_final = 0;

	gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
}

void animate_stagger_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_animate_stagger = 1;
	else
		t_animate_stagger = 0;
	
	gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
}

void grid_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_grid = 1;
	else
		t_grid = 0;
	
	gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
}

void animate_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active) {
		t_animate = (gint) data;
		gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
	}
}

void apply_changes ()
{
	guint i, j;
	
	if ((black_computer_level != t_black_computer_level) ||
			(white_computer_level != t_white_computer_level)) {
		gtk_clock_stop (GTK_CLOCK (time_display));
		gtk_widget_set_sensitive (time_display, FALSE);
		gtk_clock_set_seconds (GTK_CLOCK (time_display), 0);
		timer_valid = 0;
	}

	black_computer_level = t_black_computer_level;
	white_computer_level = t_white_computer_level;
	
	if (black_computer_id) {
		gtk_timeout_remove (black_computer_id);
		black_computer_id = 0;
	}
	
	if (white_computer_id) {
		gtk_timeout_remove (white_computer_id);
		white_computer_id = 0;
	}
	
	if (t_quick_moves)
		computer_speed = COMPUTER_MOVE_DELAY / 2;
	else
		computer_speed = COMPUTER_MOVE_DELAY;
	
	if (strcmp (tile_set, tile_set_tmp)) {
		strncpy (tile_set, tile_set_tmp, 255);
		load_pixmaps ();
	    set_bg_color();
		for (i = 0; i < 8; i++)
			for (j = 0; j < 8; j++)
				if (pixmaps [i][j] >= BLACK_TURN &&
						pixmaps[i][j] <= WHITE_TURN)
					gui_draw_pixmap_buffer (pixmaps[i][j], i, j);
				else
					gui_draw_pixmap_buffer (0, i, j);
		gui_draw_grid();
	}
	
	animate = t_animate;
	
	if (flip_pixmaps_id) {
		gtk_timeout_remove (flip_pixmaps_id);
		flip_pixmaps_id = 0;
	}
	
	switch (animate) {
		case 0:
			flip_pixmaps_id = gtk_timeout_add (100, flip_pixmaps,
					NULL);
			break;
		case 1:
			flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY *
					8, flip_pixmaps, NULL);
			break;
		case 2: flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY,
					flip_pixmaps, NULL);
			break;
	}
	
	animate_stagger = t_animate_stagger;

	flip_final = t_flip_final;

	if (grid!=t_grid) {
			grid = t_grid;
			gui_draw_grid();
	}

	check_computer_players ();
}

void save_properties ()
{
	gnome_config_set_int ("/iagno/Preferences/blacklevel",
			black_computer_level);
	gnome_config_set_int ("/iagno/Preferences/whitelevel",
			white_computer_level);
	gnome_config_set_int ("/iagno/Preferences/quickmoves",
			t_quick_moves);
	gnome_config_set_string ("/iagno/Preferences/tileset",
			tile_set_tmp);
	gnome_config_set_int ("/iagno/Preferences/animate", animate);
	gnome_config_set_int ("/iagno/Preferences/animstagger",
			animate_stagger);
	gnome_config_set_int ("/iagno/Preferences/grid",
			grid);
	gnome_config_set_int ("/iagno/Preferences/flipfinal", flip_final);
	
	gnome_config_sync ();
}

void apply_cb (GtkWidget *widget, gpointer data)
{
	apply_changes();
	
	save_properties ();
}

void destroy_cb (GtkWidget *widget, gpointer data)
{
	mapped = 0;
}

void set_selection(GtkWidget *widget, gpointer data)
{
	if (strcmp ((gchar *)data, tile_set_tmp)) {
		gnome_property_box_changed (GNOME_PROPERTY_BOX (propbox));
	        strncpy(tile_set_tmp, data, 255);
	}
}

void free_str(GtkWidget *widget, void *data)
{
        free(data);
}

void fill_menu(GtkWidget *menu)
{
        struct dirent *e;
        char *dname = gnome_unconditional_pixmap_file("iagno");
        DIR *dir;
        int itemno = 0;

        dir = opendir(dname);

        if(!dir)
                return;

        while((e = readdir(dir)) != NULL) {
                GtkWidget *item;
                char *s = strdup(e->d_name);
                if(!strstr(e->d_name, ".png")) {
                        free(s);
                        continue;
                }

                item = gtk_menu_item_new_with_label(s);
                gtk_widget_show(item);
                gtk_menu_append(GTK_MENU(menu), item);
                gtk_signal_connect(GTK_OBJECT(item), "activate",
				(GtkSignalFunc)set_selection, s);
                gtk_signal_connect(GTK_OBJECT(item), "destroy",
				(GtkSignalFunc)free_str, s);

                if (!strcmp(tile_set, s)) {
                        gtk_menu_set_active(GTK_MENU(menu), itemno);
                }

                itemno++;
        }
        closedir(dir);
}

void
dialog_help_callback (GnomePropertyBox *box, gint page_num)
{
  GnomeHelpMenuEntry settings_entry = { "iagno", "settings.html" };
  GnomeHelpMenuEntry animation_entry = { "iagno", "animations.html" };

  switch (page_num) {
  case 0:
    gnome_help_display (0, &settings_entry);
    break;
  case 1:
    gnome_help_display (0, &animation_entry);
    break;
  default:
    break;
  }
}

void show_properties_dialog ()
{
	GtkWidget *hbox;
	GtkWidget *label;
	GtkWidget *label2;
	GtkWidget *table;
	GtkWidget *button;
	GtkWidget *frame;
	GtkWidget *vbox;
	GtkWidget *option_menu;
	GtkWidget *menu;
	
	if (propbox)
		return;
	
	reset_properties ();
	
	propbox = gnome_property_box_new ();
	gnome_dialog_set_parent (GNOME_DIALOG (propbox), GTK_WINDOW (window));
	gtk_signal_connect (GTK_OBJECT (propbox), "destroy", GTK_SIGNAL_FUNC
			(gtk_widget_destroyed), &propbox);
	
	label = gtk_label_new (_("Players"));
	gtk_widget_show (label);
	
	table = gtk_table_new (2, 2, FALSE);
	gtk_container_border_width (GTK_CONTAINER (table), GNOME_PAD);
	gtk_table_set_row_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_table_set_col_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_widget_show (table);
	
	button = gtk_check_button_new_with_label (_("Quick Moves"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			(computer_speed == COMPUTER_MOVE_DELAY / 2));
	gtk_signal_connect (GTK_OBJECT (button), "toggled", GTK_SIGNAL_FUNC
			(quick_moves_select), NULL);
	gtk_widget_show (button);
	
	gtk_table_attach (GTK_TABLE (table), button, 0, 2, 1, 2,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	
	frame = gtk_frame_new (_("Dark"));
	gtk_widget_show (frame);
	
	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_border_width (GTK_CONTAINER (vbox), GNOME_PAD);
	gtk_widget_show (vbox);
	
	button = gtk_radio_button_new_with_label (NULL, _("Human"));
	if (black_computer_level == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 0);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level one"));
	if (black_computer_level == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 1);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level two"));
	if (black_computer_level == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 2);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level three"));
	if (black_computer_level == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 3);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	gtk_container_add (GTK_CONTAINER (frame), vbox);

	gtk_table_attach (GTK_TABLE (table), frame, 0, 1, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	
	frame = gtk_frame_new (_("Light"));
	gtk_widget_show (frame);
	
	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_border_width (GTK_CONTAINER (vbox), GNOME_PAD);
	gtk_widget_show (vbox);
	
	button = gtk_radio_button_new_with_label (NULL, _("Human"));
	if (white_computer_level == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 0);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level one"));
	if (white_computer_level == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 1);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level two"));
	if (white_computer_level == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 2);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Level three"));
	if (white_computer_level == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 3);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	gtk_container_add (GTK_CONTAINER (frame), vbox);

	gtk_table_attach (GTK_TABLE (table), frame, 1, 2, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	
	gnome_property_box_append_page (GNOME_PROPERTY_BOX (propbox), table,
			label);
	
	label = gtk_label_new (_("Animation"));
	gtk_widget_show (label);
	
	table = gtk_table_new (1, 2, FALSE);
	gtk_container_border_width (GTK_CONTAINER (table), GNOME_PAD);
	gtk_table_set_row_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_table_set_col_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_widget_show (table);
	
	frame = gtk_frame_new (NULL);
	gtk_widget_show (frame);
	
	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_border_width (GTK_CONTAINER (vbox), GNOME_PAD);
	gtk_widget_show (vbox);
	
	button = gtk_radio_button_new_with_label (NULL, _("None"));
	if (animate == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 0);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Partial"));
	if (animate == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 1);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_group
			(GTK_RADIO_BUTTON (button)), _("Complete"));
	if (animate == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 2);
	gtk_widget_show (button);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	gtk_container_add (GTK_CONTAINER (frame), vbox);

	gtk_table_attach (GTK_TABLE (table), frame, 0, 1, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	
	vbox = gtk_vbox_new (TRUE, GNOME_PAD);
	gtk_widget_show (vbox);
	
	button = gtk_check_button_new_with_label (_("Stagger flips"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_animate_stagger);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_stagger_select), NULL);
	gtk_widget_show (button);
	
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_check_button_new_with_label (_("Show grid"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_grid);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (grid_select), NULL);
	gtk_widget_show (button);
	
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_check_button_new_with_label (_("Flip final results"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_flip_final);
	gtk_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (flip_final_select), NULL);
	gtk_widget_show (button);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	hbox = gtk_hbox_new (FALSE, GNOME_PAD);
	gtk_widget_show (hbox);
	
	label2 = gtk_label_new (_("Tile set:"));
	gtk_widget_show (label2);
	
	gtk_box_pack_start (GTK_BOX (hbox), label2, FALSE, FALSE, 0);
	
	option_menu = gtk_option_menu_new ();
	menu = gtk_menu_new ();
	fill_menu (menu);
	gtk_option_menu_set_menu (GTK_OPTION_MENU (option_menu), menu);
	gtk_widget_show (option_menu);
	
	gtk_box_pack_start (GTK_BOX (hbox), option_menu, TRUE, TRUE, 0);
	
	gtk_box_pack_start (GTK_BOX (vbox), hbox, FALSE, FALSE, 0);
	
	gtk_table_attach (GTK_TABLE (table), vbox, 1, 2, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	
	gnome_property_box_append_page (GNOME_PROPERTY_BOX (propbox), table,
			label);
	
	gtk_signal_connect (GTK_OBJECT (propbox), "apply", GTK_SIGNAL_FUNC
			(apply_cb), NULL);
	gtk_signal_connect (GTK_OBJECT (propbox), "destroy", GTK_SIGNAL_FUNC
			(destroy_cb), NULL);
  gtk_signal_connect (GTK_OBJECT (propbox), "help",
                      GTK_SIGNAL_FUNC (dialog_help_callback), NULL);
	
	gtk_widget_show (propbox);
	mapped = 1;
}
