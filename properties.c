/* -*- mode:C; indent-tabs-mode:t; tab-width:8; c-basic-offset:8; -*- */

/*
 * Properties.c - Properties and preferences part of iagno
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * For more details see the file COPYING.
 */

#include <config.h>
#include <gnome.h>
#include <string.h>
#include <dirent.h>
#include <gconf/gconf-client.h>
#include <games-gconf.h>
#include <games-clock.h>
#include <games-frame.h>

#include "properties.h"
#include "gnothello.h"
#include "othello.h"

#define KEY_TILESET "/apps/iagno/tileset"
#define KEY_BLACK_LEVEL "/apps/iagno/black_level"
#define KEY_WHITE_LEVEL "/apps/iagno/white_level"
#define KEY_QUICK_MOVES "/apps/iagno/quick_moves"
#define KEY_ANIMATE "/apps/iagno/animate"
#define KEY_ANIMATE_STAGGER "/apps/iagno/animate_stagger"
#define KEY_SHOW_GRID "/apps/iagno/show_grid"
#define KEY_FLIP_FINAL_RESULTS "/apps/iagno/flip_final_results"

static GtkWidget *propbox = NULL;

extern GtkWidget *window;
extern GtkWidget *time_display;
extern guint black_computer_level;
extern guint white_computer_level;
extern guint computer_speed;
extern gint timer_valid;
extern guint black_computer_id;
extern guint white_computer_id;
extern gchar *tile_set;
extern gchar *tile_set_tmp;
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

static void apply_changes (void);

/*
 * FIXME:
 * 	This was only a quick port to gconf.
 *	It doesn't abide by the HIG.
 */

static gint clamp_int (gint input, gint low, gint high)
{
        if (input < low)
                input = low;
        if (input > high)
                input = high;

        return input;
}

void 
load_properties (void)
{
	GConfClient *client;
	GError      *error = NULL;

	client = gconf_client_get_default ();
	if (!games_gconf_sanity_check_string (client, KEY_TILESET)) {
		exit(1);
	}
	black_computer_level = gconf_client_get_int (client, KEY_BLACK_LEVEL, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
        black_computer_level = clamp_int (black_computer_level, 0, 3);
	
	white_computer_level = gconf_client_get_int (client, KEY_WHITE_LEVEL, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
        white_computer_level = clamp_int (white_computer_level, 0, 3);
	
	if (gconf_client_get_bool (client, KEY_QUICK_MOVES, &error))
		computer_speed = COMPUTER_MOVE_DELAY / 2;
	else
		computer_speed = COMPUTER_MOVE_DELAY;

	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}

	if (tile_set)
		g_free (tile_set);

	tile_set = gconf_client_get_string (client, KEY_TILESET, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
	if (tile_set == NULL)
		tile_set = g_strdup ("classic.png");
	
	animate = gconf_client_get_int (client, KEY_ANIMATE, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
        animate = clamp_int (animate, 0, 2);

	animate_stagger = gconf_client_get_bool (client, KEY_ANIMATE_STAGGER, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}

	grid = gconf_client_get_bool (client, KEY_SHOW_GRID, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}

	flip_final = gconf_client_get_bool (client, KEY_FLIP_FINAL_RESULTS, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}

	switch (animate) {
	case 0:
		flip_pixmaps_id = g_timeout_add (100, flip_pixmaps, &error);
		break;
	case 1:
		flip_pixmaps_id = g_timeout_add (PIXMAP_FLIP_DELAY * 8, flip_pixmaps, NULL);
		break;
	default:
	case 2:
		flip_pixmaps_id = g_timeout_add (PIXMAP_FLIP_DELAY, flip_pixmaps, NULL);
		break;
	}

	g_object_unref (client);
}

static void
reset_properties (void)
{
	GConfClient *client;
	GError      *error = NULL;

	client = gconf_client_get_default ();

	black_computer_level =
		gconf_client_get_int (client, KEY_BLACK_LEVEL, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
        t_black_computer_level = black_computer_level
		= clamp_int (black_computer_level, 0, 3);

	white_computer_level =
		gconf_client_get_int (client, KEY_WHITE_LEVEL, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
        t_white_computer_level = white_computer_level
		= clamp_int (white_computer_level, 0, 3);
	
	t_quick_moves = gconf_client_get_bool (client, KEY_QUICK_MOVES, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}

	if (tile_set_tmp)
		g_free (tile_set_tmp);

	tile_set_tmp = gconf_client_get_string (client, KEY_TILESET, &error);
	if (error) {
		g_warning (G_STRLOC ": gconf error: %s\n", error->message);
		g_error_free (error);
		error = NULL;
	}
	if (tile_set_tmp == NULL)
		tile_set_tmp = g_strdup("classic.png");
	
	t_animate         = animate;
	t_animate_stagger = animate_stagger;
	t_grid            = grid;
	t_flip_final      = flip_final;

	g_object_unref (client);
}

static void 
black_computer_level_select (GtkWidget *widget, gpointer data)
{
	if (((guint) data != t_black_computer_level) 
	    && (GTK_TOGGLE_BUTTON (widget)->active)) {
		t_black_computer_level = (guint) data;
		apply_changes ();
	}
}

static void 
white_computer_level_select (GtkWidget *widget, gpointer data)
{
	if (((guint) data != t_white_computer_level)
	    && (GTK_TOGGLE_BUTTON (widget)->active)) {
		t_white_computer_level = (guint) data;
		apply_changes ();
	}
}

static void 
quick_moves_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_quick_moves = 1;
	else
		t_quick_moves = 0;
	apply_changes ();
}

static void 
flip_final_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_flip_final = 1;
	else
		t_flip_final = 0;
	apply_changes ();	
}

static void
animate_stagger_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_animate_stagger = 1;
	else
		t_animate_stagger = 0;
	apply_changes ();	
}

static void
grid_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active)
		t_grid = 1;
	else
		t_grid = 0;
	apply_changes ();
}

static void
animate_select (GtkWidget *widget, gpointer data)
{
	if (GTK_TOGGLE_BUTTON (widget)->active) {
		t_animate = (gint) data;
	}
	apply_changes ();	
}

static void
save_properties (void)
{
	GConfClient *client;

	client = gconf_client_get_default ();

	gconf_client_set_int (client, KEY_BLACK_LEVEL,
			      black_computer_level, NULL);
	gconf_client_set_int (client, KEY_WHITE_LEVEL,
			      white_computer_level, NULL);

	gconf_client_set_bool (client, KEY_QUICK_MOVES,
			       t_quick_moves, NULL);

	gconf_client_set_string (client, KEY_TILESET,
				 tile_set_tmp, NULL);

	gconf_client_set_int (client, KEY_ANIMATE,
			      animate, NULL);

	gconf_client_set_bool (client, KEY_ANIMATE_STAGGER,
			       animate_stagger, NULL);
	gconf_client_set_bool (client, KEY_SHOW_GRID,
			       grid, NULL);
	gconf_client_set_bool (client, KEY_FLIP_FINAL_RESULTS,
			       flip_final, NULL);
}

static void
apply_changes (void)
{
	guint i, j;
	
	if ((black_computer_level != t_black_computer_level) ||
			(white_computer_level != t_white_computer_level)) {
		games_clock_stop (GAMES_CLOCK (time_display));
		gtk_widget_set_sensitive (time_display, FALSE);
		games_clock_set_seconds (GAMES_CLOCK (time_display), 0);
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
		g_free (tile_set);
		tile_set = g_strdup (tile_set_tmp);
		load_pixmaps ();
		set_bg_color ();
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
			flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY * 8,
							   flip_pixmaps, NULL);
			break;
		case 2: flip_pixmaps_id = gtk_timeout_add (PIXMAP_FLIP_DELAY,
							   flip_pixmaps, NULL);
			break;
	}
	
	animate_stagger = t_animate_stagger;

	flip_final = t_flip_final;

	if (grid != t_grid) {
			grid = t_grid;
			gui_draw_grid ();
	}

	check_computer_players ();

	save_properties ();
}

static void
close_cb (GtkWidget *widget, gint arg1, gpointer data)
{
	gtk_widget_hide (widget);

/*	if (arg1 == GTK_RESPONSE_REJECT)
		return;

	apply_changes ();
	
	save_properties (); */
}

static void
destroy_cb (GtkWidget *widget, gpointer data)
{

}

void
set_selection (GtkWidget *widget, gpointer data)
{
	if (strcmp ((gchar *)data, tile_set_tmp) != 0) {
		g_free (tile_set_tmp);
		tile_set_tmp = g_strdup (data);
	}
	apply_changes ();
}

void
free_str (GtkWidget *widget, void *data)
{
        g_free(data);
}

void
fill_menu (GtkWidget *menu)
{
        struct dirent *e;
        char *dname = NULL;
        DIR *dir;
        int itemno = 0;

	dname = gnome_program_locate_file (NULL,
			GNOME_FILE_DOMAIN_APP_PIXMAP,  "iagno", FALSE, NULL);
        dir = opendir(dname);

        if(!dir)
                return;

        while((e = readdir(dir)) != NULL) {
                GtkWidget *item;
                char *s = g_strdup(e->d_name);
                if(strstr(e->d_name, ".png") == 0) {
                        g_free(s);
                        continue;
                }

                item = gtk_menu_item_new_with_label(s);
                gtk_widget_show(item);
                gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);

		if (strcmp(tile_set, s) == 0) {
			gtk_menu_set_active(GTK_MENU(menu), itemno);
		}

                g_signal_connect(GTK_OBJECT(item), "activate",
				(GtkSignalFunc)set_selection, s);
                g_signal_connect(GTK_OBJECT(item), "destroy",
				(GtkSignalFunc)free_str, s);

                itemno++;
        }
        closedir(dir);
	g_free (dname);
}

void
show_properties_dialog (void)
{
	GtkWidget *notebook;
	GtkWidget *hbox;
	GtkWidget *label;
	GtkWidget *label2;
	GtkWidget *table;
	GtkWidget *button;
	GtkWidget *frame;
	GtkWidget *vbox, *vbox2;
	GtkWidget *option_menu;
	GtkWidget *menu;

	if (propbox)
	{
                gtk_window_present (GTK_WINDOW (propbox));
                return;
	}

	reset_properties ();
	
	propbox = gtk_dialog_new_with_buttons (NULL,
			GTK_WINDOW (window),
			0,
			GTK_STOCK_CLOSE, GTK_RESPONSE_CLOSE, NULL);
        gtk_window_set_title (GTK_WINDOW(propbox), _("Iagno Preferences"));
        
        gtk_dialog_set_has_separator (GTK_DIALOG (propbox), FALSE);
	notebook = gtk_notebook_new ();
	gtk_container_add (GTK_CONTAINER (GTK_DIALOG (propbox)->vbox),
                           notebook);

	label = gtk_label_new (_("Players"));

	vbox = gtk_vbox_new (FALSE, 0);
	gtk_notebook_append_page (GTK_NOTEBOOK (notebook),
                                  vbox, label);
        
        table = gtk_table_new (1, 2, FALSE);
        gtk_container_set_border_width (GTK_CONTAINER (table), 0);
        gtk_box_pack_start (GTK_BOX (vbox), table, FALSE, FALSE, 0);

	vbox2 = gtk_vbox_new (FALSE, FALSE);
	gtk_container_set_border_width (GTK_CONTAINER (vbox2), 12);
        gtk_box_pack_start (GTK_BOX (vbox), vbox2, FALSE, FALSE, 0);

	button = gtk_check_button_new_with_label (_("Use quick moves"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
                                      (computer_speed == COMPUTER_MOVE_DELAY / 2));
	g_signal_connect (GTK_OBJECT (button), "toggled", GTK_SIGNAL_FUNC
                          (quick_moves_select), NULL);
	
	gtk_box_pack_start (GTK_BOX (vbox2), button, FALSE, FALSE, 0);
        

	frame = games_frame_new (_("Dark"));
        gtk_table_attach_defaults (GTK_TABLE (table), frame, 0, 1, 0, 1);

	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), GNOME_PAD);

	button = gtk_radio_button_new_with_label (NULL, _("Human"));
	if (black_computer_level == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 0);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Level one"));
	if (black_computer_level == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 1);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Level two"));
	if (black_computer_level == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 2);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Level three"));
	if (black_computer_level == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (black_computer_level_select),
			(gpointer) 3);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	gtk_container_add (GTK_CONTAINER (frame), vbox);

	frame = games_frame_new (_("Light"));
        gtk_table_attach_defaults (GTK_TABLE (table), frame, 1, 2, 0, 1);
	
	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), GNOME_PAD);
	
	button = gtk_radio_button_new_with_label (NULL, _("Human"));
	if (white_computer_level == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 0);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Level one"));
	if (white_computer_level == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
                          GTK_SIGNAL_FUNC (white_computer_level_select),
                          (gpointer) 1);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Level two"));
	if (white_computer_level == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
                          GTK_SIGNAL_FUNC (white_computer_level_select),
                          (gpointer) 2);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
                                                  (GTK_RADIO_BUTTON (button)),
                                                  _("Level three"));
	if (white_computer_level == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (white_computer_level_select),
			(gpointer) 3);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	gtk_container_add (GTK_CONTAINER (frame), vbox);


        label = gtk_label_new (_("Appearance"));

	table = gtk_table_new (1, 2, FALSE);
	gtk_container_set_border_width (GTK_CONTAINER (table), 0);
	
	frame = games_frame_new (_("Animation"));
	
	vbox = gtk_vbox_new (FALSE, 6);
	
	button = gtk_radio_button_new_with_label (NULL, _("None"));
	if (animate == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 0);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Partial"));
	if (animate == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 1);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	button = gtk_radio_button_new_with_label (gtk_radio_button_get_group
			(GTK_RADIO_BUTTON (button)), _("Complete"));
	if (animate == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_select), (gpointer) 2);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	gtk_container_add (GTK_CONTAINER (frame), vbox);
	gtk_table_attach_defaults (GTK_TABLE (table), frame, 0, 1, 0, 1);
	
        frame = games_frame_new (_("Options"));
	vbox = gtk_vbox_new (FALSE, 6);
	gtk_container_add (GTK_CONTAINER (frame), vbox);
	button = gtk_check_button_new_with_label (_("Stagger flips"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_animate_stagger);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (animate_stagger_select), NULL);
	
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_check_button_new_with_label (_("Show grid"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_grid);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (grid_select), NULL);
	
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_check_button_new_with_label (_("Flip final results"));
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
			t_flip_final);
	g_signal_connect (GTK_OBJECT (button), "toggled",
			GTK_SIGNAL_FUNC (flip_final_select), NULL);

	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	hbox = gtk_hbox_new (FALSE, GNOME_PAD);
	
	label2 = gtk_label_new (_("Tile set:"));
	
	gtk_box_pack_start (GTK_BOX (hbox), label2, FALSE, FALSE, 0);
	
	option_menu = gtk_option_menu_new ();
	menu = gtk_menu_new ();
	fill_menu (menu);
	gtk_option_menu_set_menu (GTK_OPTION_MENU (option_menu), menu);
	
	gtk_box_pack_start (GTK_BOX (hbox), option_menu, TRUE, TRUE, 0);
	
	gtk_box_pack_start (GTK_BOX (vbox), hbox, FALSE, FALSE, 0);
	
	gtk_table_attach_defaults (GTK_TABLE (table), frame, 1, 2, 0, 1);

	gtk_notebook_append_page (GTK_NOTEBOOK (notebook), table,
                                  label);
        
	g_signal_connect (GTK_OBJECT (propbox), "response", GTK_SIGNAL_FUNC
			(close_cb), NULL);
	g_signal_connect (GTK_OBJECT (propbox), "destroy", GTK_SIGNAL_FUNC
			(destroy_cb), NULL);
	g_signal_connect (GTK_OBJECT (propbox), "close", GTK_SIGNAL_FUNC
			(destroy_cb), NULL);

	gtk_widget_show_all (propbox);
}
