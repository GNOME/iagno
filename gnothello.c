/*
 * gnothello.c - Main GUI part of iagno
 * written by Ian Peters <itp@gnu.org>
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
#include <libgnomeui/gnome-window-icon.h>
#include <gdk/gdkkeysyms.h>

#include <sys/time.h>
#include <string.h>

#include "gnothello.h"
#include "othello.h"
#include "properties.h"
#include "network.h"

GnomeAppBar *appbar;
GtkWidget *window;
GtkWidget *drawing_area;
GtkWidget *tile_dialog;
GtkWidget *black_score;
GtkWidget *white_score;
GtkWidget *time_display;

GdkPixmap *buffer_pixmap = NULL;
GdkPixmap *tiles_pixmap = NULL;
GdkPixmap *tiles_mask = NULL;

gint flip_pixmaps_id = 0;
gint statusbar_id;
guint whose_turn = BLACK_TURN;
guint game_in_progress = 0;
guint black_computer_level;
guint white_computer_level;
guint black_computer_id = 0;
guint white_computer_id = 0;
guint computer_speed = COMPUTER_MOVE_DELAY;
gint animate;
gint animate_stagger;
gint grid = 0;
guint tiles_to_flip = 0;

gint64 milliseconds_total = 0;
gint64 milliseconds_current_start = 0;

gint timer_valid = 0;

gint bcount;
gint wcount;

gint8 pixmaps[8][8] = {{0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0}};

gint8 board[8][8] = {{0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0}};

MoveHistory game[61];

gint8 move_count = 0;

extern guint flip_final_id;

int session_flag = 0;
int session_xpos = -1;
int session_ypos = -1;
int session_position = 0;

gchar tile_set[255];
gchar tile_set_tmp[255];

GdkGC *gridGC[2] = { 0 };

static const struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &session_xpos, 0, NULL, NULL},
  {NULL, 'y', POPT_ARG_INT, &session_ypos, 0, NULL, NULL},
#ifdef HAVE_ORBIT
  {"ior", '\0', POPT_ARG_STRING, &ior, 0, N_("IOR of remote Iagno server"),
   N_("IOR")},
#endif
  {NULL, '\0', 0, NULL, 0}
};

GnomeUIInfo game_menu[] = {
        GNOMEUIINFO_MENU_NEW_GAME_ITEM(new_game_cb, NULL),

	GNOMEUIINFO_SEPARATOR,

	GNOMEUIINFO_MENU_UNDO_MOVE_ITEM(undo_move_cb, NULL),
	
	GNOMEUIINFO_SEPARATOR,

        GNOMEUIINFO_MENU_EXIT_ITEM(quit_game_cb, NULL),

	GNOMEUIINFO_END
};

/*
GnomeUIInfo black_level_radio_list[] = {
	{ GNOME_APP_UI_ITEM, N_("_Disabled"),
	  N_("Disable the computer player"),
	  black_level_cb, 0, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level _One"),
	  N_("Enable the level 1 computer player"),
	  black_level_cb, (gpointer) 1, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0,
	  0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level _Two"),
	  N_("Enable the level 2 computer player"),
	  black_level_cb, (gpointer) 2, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0,
	  0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level Th_ree"),
	  N_("Enable the level 3 computer player"),
	  black_level_cb, (gpointer) 3, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0,
	  0, NULL },

	GNOMEUIINFO_END
};

GnomeUIInfo white_level_radio_list[] = {
	{ GNOME_APP_UI_ITEM, N_("_Disabled"),
	  N_("Disable the computer player"),
	  white_level_cb, (gpointer) 0, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level _One"),
	  N_("Enable the level 1 computer player"),
	  white_level_cb, (gpointer) 1, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level _Two"),
	  N_("Enable the level 2 computer player"),
	  white_level_cb, (gpointer) 2, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

	{ GNOME_APP_UI_ITEM, N_("Level Th_ree"),
	  N_("Enable the level 3 computer player"),
	  white_level_cb, (gpointer) 3, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo black_level_menu[] = {
	GNOMEUIINFO_RADIOLIST(black_level_radio_list),
	GNOMEUIINFO_END
};

GnomeUIInfo white_level_menu[] = {
	GNOMEUIINFO_RADIOLIST(white_level_radio_list),
	GNOMEUIINFO_END
};

GnomeUIInfo comp_menu[] = {
};
*/

/*
GnomeUIInfo settings_computer_submenu[] = {
        GNOMEUIINFO_SUBTREE_HINT(N_("_Dark"),
				 N_("Configure the dark computer player"),
				 black_level_menu),
        GNOMEUIINFO_SUBTREE_HINT(N_("_Light"), 
				 N_("Configure the light computer player"),
				 white_level_menu),

	GNOMEUIINFO_SEPARATOR,

	GNOMEUIINFO_TOGGLEITEM(N_("_Quick moves"),
			       N_("Turn on quick computer moves"),
			       quick_moves_cb, NULL),
	GNOMEUIINFO_END
};
*/

GnomeUIInfo settings_menu[] = {
	GNOMEUIINFO_MENU_PREFERENCES_ITEM (properties_cb, NULL),
        GNOMEUIINFO_END
};

GnomeUIInfo help_menu[] = {
        GNOMEUIINFO_HELP("iagno"),
	GNOMEUIINFO_MENU_ABOUT_ITEM(about_cb, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo mainmenu[] = {
        GNOMEUIINFO_MENU_GAME_TREE(game_menu),
        GNOMEUIINFO_MENU_SETTINGS_TREE(settings_menu),
        GNOMEUIINFO_MENU_HELP_TREE(help_menu),
	GNOMEUIINFO_END
};

void quit_game_maybe(GtkWidget *widget, gint button)
{
	if(button == 0) {
		if (flip_pixmaps_id)
			gtk_timeout_remove(flip_pixmaps_id);
		if (black_computer_id)
			gtk_timeout_remove(black_computer_id);
		if (white_computer_id)
			gtk_timeout_remove(white_computer_id);

		if(buffer_pixmap)
			gdk_pixmap_unref(buffer_pixmap);
		if(tiles_pixmap)
			gdk_pixmap_unref(tiles_pixmap);
		if(tiles_mask)
			gdk_pixmap_unref(tiles_mask);

		gtk_main_quit();
	}
}

void quit_game_cb(GtkWidget *widget, gpointer data)
{
	GtkWidget *box;

	if(game_in_progress) {
		box = gnome_message_box_new(_("Do you really want to quit?"), GNOME_MESSAGE_BOX_QUESTION, GNOME_STOCK_BUTTON_YES, GNOME_STOCK_BUTTON_NO, NULL);
		gnome_dialog_set_parent(GNOME_DIALOG(box), GTK_WINDOW(window));
		gnome_dialog_set_default(GNOME_DIALOG(box), 0);
		gtk_window_set_modal(GTK_WINDOW(box), TRUE);
		gtk_signal_connect(GTK_OBJECT(box), "clicked", (GtkSignalFunc)quit_game_maybe, NULL);
		gtk_widget_show(box);
	} else {
		quit_game_maybe(NULL, 0);
	}
}

void new_game_maybe(GtkWidget *widget, int button)
{
	if (button == 0) {
		network_new();
		init_new_game();
	}
}

void new_game_cb(GtkWidget *widget, gpointer data)
{
	GtkWidget *box;

	if(game_in_progress) {
		box = gnome_message_box_new(_("Do you really want to end this game?"), GNOME_MESSAGE_BOX_QUESTION, GNOME_STOCK_BUTTON_YES, GNOME_STOCK_BUTTON_NO, NULL);
		gnome_dialog_set_parent(GNOME_DIALOG(box), GTK_WINDOW(window));
		gnome_dialog_set_default(GNOME_DIALOG(box), 0);
		gtk_window_set_modal(GTK_WINDOW(box), TRUE);
		gtk_signal_connect(GTK_OBJECT(box), "clicked", (GtkSignalFunc)new_game_maybe, NULL);
		gtk_widget_show(box);
	} else {
		network_new();
		init_new_game();
	}
}

void undo_move_cb(GtkWidget *widget, gpointer data)
{
	gint8 which_computer;
	gint i, j;

	if((black_computer_level && white_computer_level) || !move_count)
		return;

	if (flip_final_id) {
		gtk_timeout_remove(flip_final_id);
		flip_final_id = 0;
	}

	game_in_progress = 1;

	if(black_computer_level || white_computer_level) {
		if(black_computer_level)
			which_computer = BLACK_TURN;
		else
			which_computer = WHITE_TURN;
		move_count--;
		while(game[move_count].me == which_computer && move_count > 0) {
			pixmaps[game[move_count].x][game[move_count].y] = 100;
			move_count--;
		}
		pixmaps[game[move_count].x][game[move_count].y] = 100;
		memcpy(board, game[move_count].board, sizeof(gint8) * 8 * 8);
	} else {
		move_count--;
		memcpy(board, game[move_count].board, sizeof(gint8) * 8 * 8);
		pixmaps[game[move_count].x][game[move_count].y] = 100;
	}

	whose_turn = game[move_count].me;

	if(whose_turn == WHITE_TURN)
		gui_message(_("Light's move"));
	else
		gui_message(_("Dark's move"));

	wcount = 0;
	bcount = 0;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			if(board[i][j] == WHITE_TURN)
				wcount++;
			if(board[i][j] == BLACK_TURN)
				bcount++;
		}

	gui_status();

	if(timer_valid) {
		gtk_clock_stop(GTK_CLOCK(time_display));
		gtk_widget_set_sensitive(time_display, FALSE);
		gtk_clock_set_seconds(GTK_CLOCK(time_display), 0);
		timer_valid = 0;
	}

	tiles_to_flip = 1;

	check_computer_players ();
}

void black_level_cb(GtkWidget *widget, gpointer data)
{
        int tmp;

        tmp = atoi((gchar *)data);

        gnome_config_set_int("/iagno/Preferences/blacklevel", tmp);
        gnome_config_sync();

        black_computer_level = tmp;

        if(game_in_progress) {
                gtk_clock_stop(GTK_CLOCK(time_display));
                gtk_widget_set_sensitive(time_display, FALSE);
                gtk_clock_set_seconds(GTK_CLOCK(time_display), 0);
                timer_valid = 0;
        }

        check_computer_players();
}

void white_level_cb(GtkWidget *widget, gpointer data)
{
        int tmp;

        tmp = atoi((gchar *)data);

        gnome_config_set_int("/iagno/Preferences/whitelevel", tmp);
        gnome_config_sync();

        white_computer_level = tmp;

        if(game_in_progress) {
                gtk_clock_stop(GTK_CLOCK(time_display));
                gtk_widget_set_sensitive(time_display, FALSE);
                gtk_clock_set_seconds(GTK_CLOCK(time_display), 0);
                timer_valid = 0;
        }

        check_computer_players();
}

void about_cb(GtkWidget *widget, gpointer data)
{
	static GtkWidget *about;

	const gchar *authors[] = {"Ian Peters", NULL};
	
	if (about != NULL) {
		gdk_window_raise (about->window);
		gdk_window_show (about->window);
		return;
	}

	about = gnome_about_new(_("Iagno"), VERSION, _("(C) 1998 Ian Peters"),
			(const char **)authors, _("Send comments and bug reports to: itp@gnu.org\nTiles under the General Public License."), NULL);
	gtk_signal_connect (GTK_OBJECT (about), "destroy", GTK_SIGNAL_FUNC
			(gtk_widget_destroyed), &about);
	gnome_dialog_set_parent(GNOME_DIALOG(about), GTK_WINDOW(window));

	gtk_widget_show(about);
}

void properties_cb (GtkWidget *widget, gpointer data)
{
	show_properties_dialog ();
}

gint expose_event(GtkWidget *widget, GdkEventExpose *event)
{
	gdk_draw_pixmap(widget->window, widget->style->fg_gc[GTK_WIDGET_STATE(widget)], buffer_pixmap, event->area.x, event->area.y, event->area.x, event->area.y, event->area.width, event->area.height);

	return(FALSE);
}

gint configure_event(GtkWidget *widget, GdkEventConfigure *event)
{
	guint i, j;

	if (gridGC[0] != 0) {
		gdk_draw_rectangle(buffer_pixmap,gridGC[0],1,0,0,BOARDWIDTH,BOARDHEIGHT);
		for(i = 0; i < 8; i++)
			for(j = 0; j < 8; j++)
				gui_draw_pixmap_buffer(pixmaps[i][j], i, j);
		gui_draw_grid();
	}
	
	return(TRUE);
}

gint button_press_event(GtkWidget *widget, GdkEventButton *event)
{
	guint x, y;

	if (!network_allow ())
		return (TRUE);
	
	if((whose_turn == WHITE_TURN) && white_computer_level)
		return (TRUE);

	if((whose_turn == BLACK_TURN) && black_computer_level)
		return(TRUE);

	if(event->button == 1) {
		x = event->x / (TILEWIDTH+GRIDWIDTH);
		y = event->y / (TILEHEIGHT+GRIDWIDTH);
		if(is_valid_move(x, y, whose_turn))
			game_move(x, y, whose_turn);
	}

	return(TRUE);
}

void gui_draw_pixmap(gint which, gint x, gint y)
{
	gdk_draw_pixmap(drawing_area->window, gridGC[0], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * (TILEWIDTH+GRIDWIDTH), y * (TILEHEIGHT+GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
	gdk_draw_pixmap(buffer_pixmap, gridGC[0], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * (TILEWIDTH+GRIDWIDTH), y * (TILEHEIGHT+GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
}

void gui_draw_pixmap_buffer(gint which, gint x, gint y)
{
	gdk_draw_pixmap(buffer_pixmap, gridGC[0], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * (TILEWIDTH+GRIDWIDTH), y * (TILEHEIGHT+GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
}

void gui_draw_grid()
{
	int i;
	GdkGC *gridcolor;
        
	for(i = 1; i < 8; i++) {
		gdk_draw_line(buffer_pixmap, gridGC[grid],
					  i*BOARDWIDTH/8-1, 0, i*BOARDWIDTH/8-1, BOARDHEIGHT);
		gdk_draw_line(buffer_pixmap, gridGC[grid],
					  0, i*BOARDHEIGHT/8-1, BOARDWIDTH, i*BOARDHEIGHT/8-1);
	}
	
	gdk_draw_pixmap(drawing_area->window, gridGC[0], buffer_pixmap, 0, 0, 0, 0, BOARDWIDTH, BOARDHEIGHT);
}

void load_pixmaps()
{
	char *tmp;
	char *fname;
	GdkImlibImage *image;
	GdkVisual *visual;

	tmp = g_strconcat("iagno/", tile_set, NULL);
	fname = gnome_unconditional_pixmap_file(tmp);
	g_free(tmp);

	if(!g_file_exists(fname)) {
		g_print(_("Could not find \'%s\' pixmap file for Iagno\n"), fname);
		exit(1);
	}

	image = gdk_imlib_load_image(fname);
	visual = gdk_imlib_get_visual();
	if(visual->type != GDK_VISUAL_TRUE_COLOR) {
		gdk_imlib_set_render_type(RT_PLAIN_PALETTE);
	}
	gdk_imlib_render(image, image->rgb_width, image->rgb_height);
	tiles_pixmap = gdk_imlib_move_image(image);
	tiles_mask = gdk_imlib_move_mask(image);

	gdk_imlib_destroy_image(image);
	g_free(fname);
}

gint flip_pixmaps(gpointer data)
{
	guint i, j;
	guint flipped_tiles = 0;

	if(!tiles_to_flip)
		return(TRUE);
	
	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			if(pixmaps[i][j] == 100) {
				pixmaps[i][j] = 101;
				gui_draw_pixmap(0, i, j);
				flipped_tiles = 1;
			} else if(pixmaps[i][j] < board[i][j]) {
				if(animate == 0) {
					if(pixmaps[i][j] == BLACK_TURN)
						pixmaps[i][j] = board[i][j];
					else
						pixmaps[i][j]++;
				} else if(animate == 1) {
					if(pixmaps[i][j] < 1)
						pixmaps[i][j] += 2;
					else if(pixmaps[i][j] >= 1 && pixmaps[i][j] < 8)
						pixmaps[i][j] = 8;
					else if(pixmaps[i][j] >= 8 && pixmaps[i][j] < 16)
						pixmaps[i][j] = 16;
					else if(pixmaps[i][j] >= 16 && pixmaps[i][j] < 23)
						pixmaps[i][j] = 23;
					else if(pixmaps[i][j] >= 23 && pixmaps[i][j] < 31)
						pixmaps[i][j] = 31;
					else if(pixmaps[i][j] > 31)
						pixmaps[i][j] = 31;
				} else if(animate == 2)
					pixmaps[i][j]++;
				if(pixmaps[i][j] > 0)
					gui_draw_pixmap(pixmaps[i][j], i, j);
				flipped_tiles = 1;
			} else if(pixmaps[i][j] > board[i][j] && pixmaps[i][j] != 101) {
				if(animate == 0) {
					if(pixmaps[i][j] == WHITE_TURN)
						pixmaps[i][j] = board[i][j];
					else
						pixmaps[i][j]--;
				} else if(animate == 1) {
					if(pixmaps[i][j] > 31)
						pixmaps[i][j] -= 2;
					else if(pixmaps[i][j] <= 31 && pixmaps[i][j] > 23)
						pixmaps[i][j] = 23;
					else if(pixmaps[i][j] <= 23 && pixmaps[i][j] > 16)
						pixmaps[i][j] = 16;
					else if(pixmaps[i][j] <= 16 && pixmaps[i][j] > 8)
						pixmaps[i][j] = 8;
					else if(pixmaps[i][j] <= 8 && pixmaps[i][j] > 1)
						pixmaps[i][j] = 1;
					else if(pixmaps[i][j] < 1)
						pixmaps[i][j] = 1;
				} else if(animate == 2)
					pixmaps[i][j]--;
				if(pixmaps[i][j] < 32)
					gui_draw_pixmap(pixmaps[i][j], i, j);
				flipped_tiles = 1;
			}
		}

	if(!flipped_tiles)
		tiles_to_flip = 0;

	return(TRUE);
}

void init_new_game()
{
	guint i, j;

	if (flip_final_id) {
		gtk_timeout_remove(flip_final_id);
		flip_final_id = 0;
	}

	if (black_computer_id) {
		gtk_timeout_remove(black_computer_id);
		black_computer_id = 0;
	}

	if (white_computer_id) {
		gtk_timeout_remove(white_computer_id);
		white_computer_id = 0;
	}

	game_in_progress = 1;
	move_count = 0;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			board[i][j] = 0;
	board[3][3] = WHITE_TURN;
	board[3][4] = BLACK_TURN;
	board[4][3] = BLACK_TURN;
	board[4][4] = WHITE_TURN;

	bcount = 2;
	wcount = 2;

	gui_status();

	memcpy(pixmaps, board, sizeof(gint8) * 8 * 8);
	memcpy(game[0].board, board, sizeof(gint8) * 8 * 8);

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			gui_draw_pixmap_buffer(pixmaps[i][j], i, j);

        gui_draw_grid();

	whose_turn = BLACK_TURN;
	gui_message(_("Dark's move"));

	gtk_clock_stop(GTK_CLOCK(time_display));
	gtk_clock_set_seconds(GTK_CLOCK(time_display), 0);

	if(black_computer_level ^ white_computer_level) {
		if(!black_computer_level)
			gtk_clock_start(GTK_CLOCK(time_display));
		gtk_widget_set_sensitive(time_display, TRUE);
		timer_valid = 1;
	} else {
		gtk_widget_set_sensitive(time_display, FALSE);
		timer_valid = 0;
	}

	check_computer_players();
}

void create_window()
{
	GtkWidget *table;
	GtkWidget *sep;

	window = gnome_app_new("iagno", _("Iagno"));

	gtk_widget_realize(window);
	gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gtk_signal_connect(GTK_OBJECT(window), "delete_event", GTK_SIGNAL_FUNC(quit_game_cb), NULL);

	gnome_app_create_menus(GNOME_APP(window), mainmenu);

	gtk_widget_push_visual (gdk_imlib_get_visual ());
	gtk_widget_push_colormap (gdk_imlib_get_colormap ());

	drawing_area = gtk_drawing_area_new();

	gtk_widget_pop_colormap ();
	gtk_widget_pop_visual ();

	gnome_app_set_contents(GNOME_APP(window), drawing_area);

	gtk_drawing_area_size(GTK_DRAWING_AREA(drawing_area), BOARDWIDTH, BOARDHEIGHT);
	gtk_signal_connect(GTK_OBJECT(drawing_area), "expose_event", GTK_SIGNAL_FUNC(expose_event), NULL);
	gtk_signal_connect(GTK_OBJECT(window), "configure_event", GTK_SIGNAL_FUNC(configure_event), NULL);
	gtk_signal_connect(GTK_OBJECT(drawing_area), "button_press_event", GTK_SIGNAL_FUNC(button_press_event), NULL);
	gtk_widget_set_events(drawing_area, GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK);
	gtk_widget_show(drawing_area);

	appbar = GNOME_APPBAR (gnome_appbar_new(FALSE, TRUE, FALSE));
	gnome_app_set_statusbar(GNOME_APP(window), GTK_WIDGET (appbar));
	gnome_app_install_menu_hints(GNOME_APP (window), mainmenu);

	table = gtk_table_new(1, 8, FALSE);

	black_score = gtk_label_new(_("Dark:"));
	gtk_widget_show(black_score);

	gtk_table_attach(GTK_TABLE(table), black_score, 1, 2, 0, 1, 0, 0, 3, 1);

	black_score = gtk_label_new("00");
	gtk_widget_show(black_score);

	gtk_table_attach(GTK_TABLE(table), black_score, 2, 3, 0, 1, 0, 0, 3, 1);

	sep = gtk_vseparator_new();
	gtk_widget_show(sep);

	gtk_table_attach(GTK_TABLE(table), sep, 3, 4, 0, 1, 0, GTK_FILL, 3, 3);

	white_score = gtk_label_new(_("Light:"));
	gtk_widget_show(white_score);

	gtk_table_attach(GTK_TABLE(table), white_score, 4, 5, 0, 1, 0, 0, 3, 1);

	white_score = gtk_label_new("00");
	gtk_widget_show(white_score);

	gtk_table_attach(GTK_TABLE(table), white_score, 5, 6, 0, 1, 0, 0, 3, 1);

	sep = gtk_vseparator_new();
	gtk_widget_show(sep);

	gtk_table_attach(GTK_TABLE(table), sep, 6, 7, 0, 1, 0, GTK_FILL, 3, 3);

	time_display = gtk_clock_new(GTK_CLOCK_INCREASING);
	gtk_widget_set_sensitive(time_display, FALSE);
	gtk_widget_show(time_display);

	gtk_table_attach(GTK_TABLE(table), time_display, 7, 8, 0, 1, 0, 0, 3, 1);

	gtk_widget_show(table);

	gtk_box_pack_start(GTK_BOX(appbar), table, FALSE, TRUE, 0);

	gnome_appbar_set_status(GNOME_APPBAR (appbar),
				_("Welcome to Iagno!"));
}

void gui_status()
{
	gchar message[3];

	sprintf(message, _("%.2d"), bcount);
	gtk_label_set(GTK_LABEL(black_score), message);
	sprintf(message, _("%.2d"), wcount);
	gtk_label_set(GTK_LABEL(white_score), message);
}

void gui_message(gchar *message)
{
	gnome_appbar_pop(GNOME_APPBAR (appbar));
        gnome_appbar_push(GNOME_APPBAR (appbar), message);
}

guint check_computer_players()
{
	if(black_computer_level && whose_turn == BLACK_TURN)
		switch(black_computer_level) {
			case 1:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) BLACK_TURN);
			break;
			case 2:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) BLACK_TURN);
			break;
			case 3:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) BLACK_TURN);
			break;
		}

	if(white_computer_level && whose_turn == WHITE_TURN)
		switch(white_computer_level) {
			case 1:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) WHITE_TURN);
			break;
			case 2:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) WHITE_TURN);
			break;
			case 3:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) WHITE_TURN);
			break;
		}

	return(TRUE);
}

void set_bg_color()
{
	GdkImage *tmpimage;
	GdkColor bgcolor;

	tmpimage = gdk_image_get(tiles_pixmap, 0, 0, 1, 1);
	bgcolor.pixel = gdk_image_get_pixel(tmpimage, 0, 0);
	gdk_window_set_background(drawing_area->window, &bgcolor);

	if (gridGC[0])
	  gdk_gc_destroy(gridGC[0]);
	gridGC[0] = gdk_gc_new (drawing_area->window);
	if (gridGC[1])
	  gdk_gc_destroy(gridGC[1]);
	gridGC[1] = gdk_gc_new (drawing_area->window);

	gdk_gc_copy (gridGC [0],drawing_area->style->bg_gc[0]);
	gdk_gc_copy (gridGC [1],drawing_area->style->bg_gc[0]);
	
	gdk_gc_set_background (gridGC [0],&bgcolor);
	gdk_gc_set_foreground (gridGC [0],&bgcolor);
	
	/* Create a complementary color to use for the ON state */
	bgcolor.pixel = 0xFFFFFF - bgcolor.pixel;
	gdk_gc_set_background (gridGC [1],&bgcolor);
	gdk_gc_set_foreground (gridGC [1],&bgcolor);
	
	gdk_image_destroy (tmpimage);
}

static char *nstr(int n)
{
	char buf[20];
	sprintf(buf, "%d", n);
	return strdup(buf);
}

static int save_state(GnomeClient *client, gint phase, GnomeRestartStyle save_style, gint shutdown, GnomeInteractStyle interact_style, gint fast, gpointer client_data)
{
	char *argv[20];
	int i;
	gint xpos, ypos;

	gdk_window_get_origin(window->window, &xpos, &ypos);

	i = 0;
	argv[i++] = (char *)client_data;
	argv[i++] = "-x";
	argv[i++] = nstr(xpos);
	argv[i++] = "-y";
	argv[i++] = nstr(ypos);

	gnome_client_set_restart_command(client, i, argv);
	gnome_client_set_clone_command(client, 0, NULL);

	free(argv[2]);
	free(argv[4]);

	return TRUE;
}

int main(int argc, char **argv)
{
	GnomeClient *client;
	CORBA_def(CORBA_Environment ev;)
	struct timeval tv;

	gnome_score_init("iagno");

	bindtextdomain(PACKAGE, GNOMELOCALEDIR);
	textdomain(PACKAGE);

	gettimeofday(&tv, NULL);
	srand(tv.tv_usec);

#ifdef HAVE_ORBIT
	CORBA_exception_init (&ev);
	orb = gnome_CORBA_init_with_popt_table ("iagno", VERSION, &argc, argv, options, 0, NULL, GNORBA_INIT_SERVER_FUNC|GNORBA_INIT_DISABLE_COOKIES, &ev);
#else
	gnome_init_with_popt_table("iagno", VERSION, argc, argv, options, 0, NULL);
#endif
	gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/iagno.png");
	client= gnome_master_client();

	gtk_object_ref(GTK_OBJECT(client));
	gtk_object_sink(GTK_OBJECT(client));

	gtk_signal_connect(GTK_OBJECT(client), "save_yourself", GTK_SIGNAL_FUNC(save_state), argv[0]);
	gtk_signal_connect(GTK_OBJECT(client), "die", GTK_SIGNAL_FUNC(quit_game_cb), argv[0]);
	
	create_window();
	
	load_properties ();

	load_pixmaps();

	if(session_xpos >= 0 && session_ypos >= 0) {
		gtk_widget_set_uposition(window, session_xpos, session_ypos);
	}

	gtk_widget_show(window);

	buffer_pixmap = gdk_pixmap_new(drawing_area->window, BOARDWIDTH, BOARDHEIGHT, -1);

	set_bg_color();

	network_init();

	gtk_main();

	return 0;
}

