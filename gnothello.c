/*
 * gnothello.c - Main GUI part of gnothello
 * written by Ian Peters <ipeters@acm.org>
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
#include <gdk/gdkkeysyms.h>

#include <sys/time.h>
#include <string.h>
#include <dirent.h>

#include "gnothello.h"
#include "othello.h"
#include "network.h"

GtkWidget *window;
GtkWidget *drawing_area;
GtkWidget *statusbar;
GtkWidget *tile_dialog;
GtkWidget *black_score;
GtkWidget *white_score;
GtkWidget *time_display;

GdkPixmap *buffer_pixmap = NULL;
GdkPixmap *tiles_pixmap = NULL;
GdkPixmap *tiles_mask = NULL;

gint flip_pixmaps_id = 0;
//gint check_computer_players_id;
gint statusbar_id;
guint whose_turn = BLACK_TURN;
guint game_in_progress = 0;
guint black_computer_level;
guint white_computer_level;
guint black_computer_id;
guint white_computer_id;
guint computer_speed = COMPUTER_MOVE_DELAY;
gint animate;
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

static const struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &session_xpos, 0, NULL, NULL},
  {NULL, 'y', POPT_ARG_INT, &session_ypos, 0, NULL, NULL},
#ifdef HAVE_ORBIT
  {"ior", '\0', POPT_ARG_STRING, &ior, 0, N_("IOR of remote Gnothello server"),
   N_("IOR")},
#endif
  {NULL, '\0', 0, NULL, 0}
};

GnomeUIInfo game_menu[] = {
	{ GNOME_APP_UI_ITEM, N_("_New"), "Start a new game", new_game_cb, NULL, NULL, GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_NEW, 'n', GDK_CONTROL_MASK, NULL },
	{ GNOME_APP_UI_ITEM, N_("_Undo"), "Undo last move", undo_move_cb, NULL, NULL, GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_UNDO, 'z', GDK_CONTROL_MASK, NULL },
	{ GNOME_APP_UI_ITEM, N_("E_xit"), "Exit Gnothello", quit_game_cb, NULL, NULL, GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_EXIT, 'q', GDK_CONTROL_MASK, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo black_level_radio_list[] = {
	{ GNOME_APP_UI_ITEM, N_("_Disabled"), NULL, black_level_cb, "0", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level _One"), NULL, black_level_cb, "1", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level _Two"), NULL, black_level_cb, "2", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level Th_ree"), NULL, black_level_cb, "3", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo white_level_radio_list[] = {
	{ GNOME_APP_UI_ITEM, N_("_Disabled"), NULL, white_level_cb, "0", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level _One"), NULL, white_level_cb, "1", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level _Two"), NULL, white_level_cb, "2", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("Level Th_ree"), NULL, white_level_cb, "3", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
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
	{ GNOME_APP_UI_SUBTREE, N_("_Dark"), NULL, black_level_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, (GdkModifierType) 0, GDK_CONTROL_MASK },
	{ GNOME_APP_UI_SUBTREE, N_("_Light"), NULL, white_level_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, (GdkModifierType) 0, GDK_CONTROL_MASK },
	GNOMEUIINFO_SEPARATOR,
	{ GNOME_APP_UI_TOGGLEITEM, N_("_Quick Moves"), "Computer makes quick moves", quick_moves_cb, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo anim_radio_list[] = {
	{ GNOME_APP_UI_ITEM, N_("_No Animation"), NULL, anim_cb, "0", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("_Some Animation"), NULL, anim_cb, "1", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_ITEM, N_("_Full Animation"), NULL, anim_cb, "2", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo anim_type_menu[] = {
	GNOMEUIINFO_RADIOLIST(anim_radio_list),
	GNOMEUIINFO_END
};

GnomeUIInfo anim_menu[] = {
	GNOMEUIINFO_RADIOLIST(anim_radio_list),
	GNOMEUIINFO_SEPARATOR,
	{ GNOME_APP_UI_TOGGLEITEM, N_("_Stagger Flips"), NULL, anim_stagger_cb, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_SEPARATOR,
	{ GNOME_APP_UI_ITEM, N_("_Load Tiles..."), NULL, load_tiles_cb, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo help_menu[] = {
	{ GNOME_APP_UI_ITEM, N_("_About Gnothello"), NULL, about_cb, NULL, NULL, GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_ABOUT, 0, 0, NULL },
	GNOMEUIINFO_END
};

GnomeUIInfo mainmenu[] = {
	{ GNOME_APP_UI_SUBTREE, N_("_Game"), NULL, game_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_SUBTREE, N_("_Computer"), NULL, comp_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_SUBTREE, N_("_Animation"), NULL, anim_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	{ GNOME_APP_UI_SUBTREE, N_("_Help"), NULL, help_menu, NULL, NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },
	GNOMEUIINFO_END
};

void quit_game_maybe(GtkWidget *widget, gint button)
{
	if(button == 0) {
		gnome_config_sync();

		gtk_timeout_remove(flip_pixmaps_id);
		gtk_timeout_remove(black_computer_id);
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

	gtk_timeout_remove(flip_final_id);

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
}

void black_level_cb(GtkWidget *widget, gpointer data)
{
	int tmp;

	tmp = atoi((gchar *)data);

	gnome_config_set_int("/gnothello/Preferences/blacklevel", tmp);
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

	gnome_config_set_int("/gnothello/Preferences/whitelevel", tmp);
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

void anim_cb(GtkWidget *widget, gpointer data)
{
	gint tmp;

	tmp = atoi((gchar *)data);
	gnome_config_set_int("/gnothello/Preferences/animate", tmp);
	gnome_config_sync();

	if(flip_pixmaps_id)
		gtk_timeout_remove(flip_pixmaps_id);

	switch(tmp) {
		case 0:
			flip_pixmaps_id = gtk_timeout_add(100, flip_pixmaps, NULL);
			animate = 0;
			break;
		case 1:
			flip_pixmaps_id = gtk_timeout_add(PIXMAP_FLIP_DELAY * 8, flip_pixmaps, NULL);
			animate = 1;
			break;
		case 2:
			flip_pixmaps_id = gtk_timeout_add(PIXMAP_FLIP_DELAY, flip_pixmaps, NULL);
			animate = 2;
			break;
	}
}

void about_cb(GtkWidget *widget, gpointer data)
{
	GtkWidget *about;

	const gchar *authors[] = {"Ian Peters", NULL};

	about = gnome_about_new(_("Gnothello"), GNOTHELLO_VERSION, "(C) 1998 Ian Peters", (const char **)authors, _("Send comments and bug reports to: ipeters@acm.org\nTiles under the General Public License."), NULL);
	gtk_window_set_modal(GTK_WINDOW(about), TRUE);

	gtk_widget_show(about);
}

void comp_black_cb(GtkWidget *widget, gpointer data)
{
	if(GTK_CHECK_MENU_ITEM(widget)->active) {
		gnome_config_set_bool("/gnothello/Preferences/compblack", TRUE);
	} else {
		gnome_config_set_bool("/gnothello/Preferences/compblack", FALSE);
	}
	gnome_config_sync();
}

void comp_white_cb(GtkWidget *widget, gpointer data)
{
	if(GTK_CHECK_MENU_ITEM(widget)->active) {
		gnome_config_set_bool("/gnothello/Preferences/compwhite", TRUE);
	} else {
		gnome_config_set_bool("/gnothello/Preferences/compwhite", FALSE);
	}
	gnome_config_sync();
}

void quick_moves_cb(GtkWidget *widget, gpointer data)
{
	if(GTK_CHECK_MENU_ITEM(widget)->active) {
		gnome_config_set_bool("/gnothello/Preferences/quickmoves", TRUE);
		computer_speed = COMPUTER_MOVE_DELAY / 2;
	} else {
		gnome_config_set_bool("/gnothello/Preferences/quickmoves", FALSE);
		computer_speed = COMPUTER_MOVE_DELAY;
	}
	gnome_config_sync();
}

void anim_stagger_cb(GtkWidget *widget, gpointer data)
{
	if(GTK_CHECK_MENU_ITEM(widget)->active) {
		gnome_config_set_int("/gnothello/Preferences/animstagger", 1);
	} else {
		gnome_config_set_int("/gnothello/Preferences/animstagger", 0);
	}
	gnome_config_sync();
}

void load_tiles_cb(GtkWidget *widget, gpointer data)
{
	GtkWidget *menu, *options_menu, *frame, *hbox, *label;

	if (tile_dialog)
		return;

	strncpy(tile_set_tmp, tile_set, 255);

	tile_dialog = gnome_dialog_new(_("Load Tile Set"), GNOME_STOCK_BUTTON_OK, GNOME_STOCK_BUTTON_CANCEL, NULL);
	gtk_signal_connect(GTK_OBJECT(tile_dialog), "delete_event", (GtkSignalFunc)cancel, NULL);

	options_menu = gtk_option_menu_new();
	menu = gtk_menu_new();
	fill_menu(menu);
	gtk_widget_show(options_menu);
	gtk_option_menu_set_menu(GTK_OPTION_MENU(options_menu), menu);

	frame = gtk_frame_new(_("Tile Set"));
/*	gtk_container_border_width(GTK_CONTAINER(frame), 5); */

	hbox = gtk_hbox_new(FALSE, FALSE);
	gtk_container_border_width(GTK_CONTAINER(hbox), GNOME_PAD_SMALL);
	gtk_widget_show(hbox);

	label = gtk_label_new(_("Select Tile Set: "));
	gtk_widget_show(label);

	gtk_box_pack_start_defaults(GTK_BOX(hbox), label);
	gtk_box_pack_start_defaults(GTK_BOX(hbox), options_menu);

	gtk_container_add(GTK_CONTAINER(frame), hbox);
	gtk_widget_show(frame);

	gtk_box_pack_start_defaults(GTK_BOX(GNOME_DIALOG(tile_dialog)->vbox), frame);

	gnome_dialog_button_connect(GNOME_DIALOG(tile_dialog), 0, GTK_SIGNAL_FUNC(load_tiles_callback), NULL);
	gnome_dialog_button_connect(GNOME_DIALOG(tile_dialog), 1, GTK_SIGNAL_FUNC(cancel), (gpointer)1);

	gtk_widget_show (tile_dialog);
}

void load_tiles_callback(GtkWidget *widget, void *data)
{
	gint i, j;

	cancel(0,0);
	strncpy(tile_set, tile_set_tmp, 255);
	gnome_config_set_string("/gnothello/Preferences/tileset", tile_set);
	load_pixmaps();
	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			if(pixmaps[i][j] >= BLACK_TURN && pixmaps[i][j] <= WHITE_TURN)
				gui_draw_pixmap(pixmaps[i][j], i, j);
			else
				gui_draw_pixmap(0, i, j);
		}
}

void fill_menu(GtkWidget *menu)
{
	struct dirent *e;
	char *dname = gnome_unconditional_pixmap_file("gnothello");
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
		gtk_signal_connect(GTK_OBJECT(item), "activate", (GtkSignalFunc)set_selection, s);
		gtk_signal_connect(GTK_OBJECT(item), "destroy", (GtkSignalFunc)free_str, s);

		if (!strcmp(tile_set, s)) {
			gtk_menu_set_active(GTK_MENU(menu), itemno);
		}

		itemno++;
	}
	closedir(dir);
}

void free_str(GtkWidget *widget, void *data)
{
	free(data);
}

void set_selection(GtkWidget *widget, void *data)
{
	strncpy(tile_set_tmp, data, 255);
}

void cancel(GtkWidget *widget, void *data)
{
	gtk_widget_destroy(tile_dialog);
	tile_dialog = NULL;
}

gint expose_event(GtkWidget *widget, GdkEventExpose *event)
{
        gdk_draw_pixmap(widget->window, widget->style->fg_gc[GTK_WIDGET_STATE(widget)], buffer_pixmap, event->area.x, event->area.y, event->area.x, event->area.y, event->area.width, event->area.height);

        return(FALSE);
}

gint configure_event(GtkWidget *widget, GdkEventConfigure *event)
{
        guint i, j;

        if(buffer_pixmap)
                gdk_pixmap_unref(buffer_pixmap);
        buffer_pixmap = gdk_pixmap_new(widget->window, widget->allocation.width, widget->allocation.height, -1);

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			gui_draw_pixmap_buffer(pixmaps[i][j], i, j);

        return(TRUE);
}

gint button_press_event(GtkWidget *widget, GdkEventButton *event)
{
	guint x, y;

	if (!network_allow ())
		return (TRUE);
	
	if(whose_turn == WHITE_TURN)
		if(gnome_config_get_int("/gnothello/Preferences/whitelevel=0"))
			return(TRUE);

	if(whose_turn == BLACK_TURN)
		if(gnome_config_get_int("/gnothello/Preferences/blacklevel=0"))
			return(TRUE);

	if(event->button == 1) {
		x = event->x / TILEWIDTH;
		y = event->y / TILEHEIGHT;
		if(is_valid_move(x, y, whose_turn))
			game_move(x, y, whose_turn);
	}

	return(TRUE);
}

void gui_draw_pixmap(gint which, gint x, gint y)
{
	gdk_draw_pixmap(drawing_area->window, drawing_area->style->fg_gc[GTK_WIDGET_STATE(drawing_area)], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * TILEWIDTH, y * TILEHEIGHT, TILEWIDTH, TILEHEIGHT);
	gdk_draw_pixmap(buffer_pixmap, drawing_area->style->fg_gc[GTK_WIDGET_STATE(drawing_area)], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * TILEWIDTH, y * TILEHEIGHT, TILEWIDTH, TILEHEIGHT);
}

void gui_draw_pixmap_buffer(gint which, gint x, gint y)
{
	gdk_draw_pixmap(buffer_pixmap, drawing_area->style->fg_gc[GTK_WIDGET_STATE(drawing_area)], tiles_pixmap, (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT, x * TILEWIDTH, y * TILEHEIGHT, TILEWIDTH, TILEHEIGHT);
}

void load_pixmaps()
{
	char *tmp;
	char *fname;
	GdkImlibImage *image;
	GdkVisual *visual;

	tmp = g_copy_strings("gnothello/", tile_set, NULL);
	fname = gnome_unconditional_pixmap_file(tmp);
	g_free(tmp);

	if(!g_file_exists(fname)) {
		g_print(_("Could not find \'%s\' pixmap file for Gnothello\n"), fname);
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

	gtk_timeout_remove(flip_final_id);

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

	gdk_draw_pixmap(drawing_area->window, drawing_area->style->fg_gc[GTK_WIDGET_STATE(drawing_area)], buffer_pixmap, 0, 0, 0, 0, BOARDWIDTH, BOARDHEIGHT);
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
	GtkWidget *vbox;
	GtkWidget *frame;
	GtkWidget *table;
	GtkWidget *sep;
	GtkWidget *appbar;

	window = gnome_app_new("gnothello", _("Gnothello"));

	gtk_widget_realize(window);
	gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gtk_signal_connect(GTK_OBJECT(window), "delete_event", GTK_SIGNAL_FUNC(quit_game_cb), NULL);

	gnome_app_create_menus(GNOME_APP(window), mainmenu);

	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(comp_menu[3].widget), gnome_config_get_bool("/gnothello/Preferences/quickmoves=FALSE"));
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(anim_menu[2].widget), gnome_config_get_int("/gnothello/Preferences/animstagger=0"));
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(anim_radio_list[gnome_config_get_int("/gnothello/Preferences/animate=2")].widget), TRUE);
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(black_level_radio_list[gnome_config_get_int("/gnothello/Preferences/blacklevel=0")].widget), TRUE);
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(white_level_radio_list[gnome_config_get_int("/gnothello/Preferences/whitelevel=0")].widget), TRUE);

	gtk_widget_push_visual (gdk_imlib_get_visual ());
	gtk_widget_push_colormap (gdk_imlib_get_colormap ());

	drawing_area = gtk_drawing_area_new();

	gtk_widget_pop_colormap ();
	gtk_widget_pop_visual ();

	gnome_app_set_contents(GNOME_APP(window), drawing_area);

	gtk_drawing_area_size(GTK_DRAWING_AREA(drawing_area), BOARDWIDTH, BOARDHEIGHT);
	gtk_signal_connect(GTK_OBJECT(drawing_area), "expose_event", GTK_SIGNAL_FUNC(expose_event), NULL);
	gtk_signal_connect(GTK_OBJECT(drawing_area), "configure_event", GTK_SIGNAL_FUNC(configure_event), NULL);
	gtk_signal_connect(GTK_OBJECT(drawing_area), "button_press_event", GTK_SIGNAL_FUNC(button_press_event), NULL);
	gtk_widget_set_events(drawing_area, GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK);
	gtk_widget_show(drawing_area);

	appbar = gnome_appbar_new(FALSE, FALSE, FALSE);

	table = gtk_table_new(1, 8, FALSE);
//	gtk_table_set_col_spacing(GTK_TABLE(table), 1, 32);
//	gtk_table_set_col_spacing(GTK_TABLE(table), 2, 32);

	statusbar = gtk_statusbar_new();
	gtk_frame_set_shadow_type(GTK_FRAME(GTK_STATUSBAR(statusbar)->frame), GTK_SHADOW_NONE);
	gtk_widget_show(statusbar);
	statusbar_id = gtk_statusbar_get_context_id(GTK_STATUSBAR(statusbar), "gnothello");

	gtk_table_attach(GTK_TABLE(table), statusbar, 0, 1, 0, 1, GTK_EXPAND | GTK_FILL, 0, 3, 1);

	black_score = gtk_label_new("Dark:");
	gtk_widget_show(black_score);

	gtk_table_attach(GTK_TABLE(table), black_score, 1, 2, 0, 1, 0, 0, 3, 1);

	black_score = gtk_label_new("00");
	gtk_widget_show(black_score);

	gtk_table_attach(GTK_TABLE(table), black_score, 2, 3, 0, 1, 0, 0, 3, 1);

	sep = gtk_vseparator_new();
	gtk_widget_show(sep);

	gtk_table_attach(GTK_TABLE(table), sep, 3, 4, 0, 1, 0, GTK_FILL, 3, 3);

	white_score = gtk_label_new("Light:");
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

	gtk_box_pack_start(GTK_BOX(appbar), table, TRUE, TRUE, 0);

	gnome_app_set_statusbar(GNOME_APP(window), appbar);

	gtk_statusbar_push(GTK_STATUSBAR(statusbar), statusbar_id, _("Welcome to Gnothello!"));
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
	gtk_statusbar_pop(GTK_STATUSBAR(statusbar), statusbar_id);
	gtk_statusbar_push(GTK_STATUSBAR(statusbar), statusbar_id, message);
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
	gdk_image_destroy(tmpimage);
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
	gint i;

	gnome_score_init("gnothello");

	bindtextdomain(PACKAGE, GNOMELOCALEDIR);
	textdomain(PACKAGE);

	gettimeofday(&tv, NULL);
	srand(tv.tv_usec);

#ifdef HAVE_ORBIT
	CORBA_exception_init (&ev);
	orb = gnome_CORBA_init_with_popt_table ("gnothello", VERSION, &argc, 
						argv, options, 0, NULL, 0, &ev);
#else
	gnome_init_with_popt_table("gnothello", VERSION, argc, argv, options, 0, NULL);
#endif

	client= gnome_master_client();

	gtk_object_ref(GTK_OBJECT(client));
	gtk_object_sink(GTK_OBJECT(client));

	gtk_signal_connect(GTK_OBJECT(client), "save_yourself", GTK_SIGNAL_FUNC(save_state), argv[0]);
	gtk_signal_connect(GTK_OBJECT(client), "die", GTK_SIGNAL_FUNC(quit_game_cb), argv[0]);
	
	create_window();

	strncpy(tile_set, gnome_config_get_string("/gnothello/preferences/tileset=classic.png"), 255);
	load_pixmaps();

	animate = gnome_config_get_int("/gnothello/Preferences/animate=2");

//	check_computer_players_id = gtk_timeout_add(100, (GtkFunction)check_computer_players, NULL);

	if(session_xpos >= 0 && session_ypos >= 0) {
		gtk_widget_set_uposition(window, session_xpos, session_ypos);
	}

	gtk_widget_show(window);

	set_bg_color();

	gdk_window_clear_area(drawing_area->window, 0, 0, BOARDWIDTH, BOARDHEIGHT);

	network_init();
	gtk_main();

	gtk_object_unref(GTK_OBJECT(client));

	return 0;
}
