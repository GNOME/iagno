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

#include <sys/time.h>
#include <string.h>

#include "gnothello.h"
#include "othello.h"
#include "network.h"

GtkWidget *window;
GtkWidget *drawing_area;
GtkWidget *statusbar;

GdkPixmap *buffer_pixmap = NULL;
GdkPixmap *tiles_pixmap = NULL;
GdkPixmap *tiles_mask = NULL;

gint flip_pixmaps_id = 0;
gint check_valid_moves_id;
gint check_computer_players_id;
gint statusbar_id;
guint whose_turn = BLACK_TURN;
guint new_game = 1;
guint black_computer_level;
guint white_computer_level;
guint black_computer_id;
guint white_computer_id;
guint computer_speed = COMPUTER_MOVE_DELAY;

gint pixmaps[8][8] = {{0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0},
		      {0,0,0,0,0,0,0,0}};

gint board[8][8] = {{0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0},
		    {0,0,0,0,0,0,0,0}};

extern guint flip_final_id;
extern guint black_computer_busy;
extern guint white_computer_busy;

int session_flag = 0;
int session_xpos = 0;
int session_ypos = 0;
int session_position = 0;

static struct argp_option options[] =
{
	{NULL, 'x', N_("X"),   OPTION_HIDDEN, NULL, 1},
	{NULL, 'y', N_("Y"),   OPTION_HIDDEN, NULL, 1},
#ifdef HAVE_ORBIT
	{"ior",'i', N_("IOR"), 0,             N_("IOR of remote Gnothello server"), 1 },
#endif
	{NULL, 0, NULL, 0, NULL, 0}
};

static error_t parse_args(int key, char *arg, struct argp_state *state);
static struct argp parser =
{
	options, parse_args, NULL, NULL, NULL, NULL, NULL
};

GnomeUIInfo file_menu[] = {
	{ GNOME_APP_UI_ITEM, N_("_New"), NULL, new_game_cb, NULL, NULL,
	  GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_NEW, 'n', GDK_CONTROL_MASK },
	{ GNOME_APP_UI_ITEM, N_("_Quit"), NULL, quit_game_cb, NULL, NULL,
	  GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_EXIT, 'q', GDK_CONTROL_MASK },
	GNOMEUIINFO_END
};

GnomeUIInfo black_level_radio_list[] = {
	GNOMEUIINFO_ITEM_DATA(N_("_Disabled"), NULL, black_level_cb, "0", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _One"), NULL, black_level_cb, "1", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _Two"), NULL, black_level_cb, "2", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _Three"), NULL, black_level_cb, "3", NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo white_level_radio_list[] = {
	GNOMEUIINFO_ITEM_DATA(N_("_Disabled"), NULL, white_level_cb, "0", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _One"), NULL, white_level_cb, "1", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _Two"), NULL, white_level_cb, "2", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("Level _Three"), NULL, white_level_cb, "3", NULL),
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
	GNOMEUIINFO_SUBTREE(N_("_Black"), black_level_menu),
	GNOMEUIINFO_SUBTREE(N_("_White"), white_level_menu),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_TOGGLEITEM(N_("_Quick Moves"), NULL, quick_moves_cb, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo anim_radio_list[] = {
	GNOMEUIINFO_ITEM_DATA(N_("_No Animation"), NULL, anim_cb, "0", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("_Some Animation"), NULL, anim_cb, "1", NULL),
	GNOMEUIINFO_ITEM_DATA(N_("_Full Animation"), NULL, anim_cb, "2", NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo anim_menu[] = {
	GNOMEUIINFO_RADIOLIST(anim_radio_list),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_TOGGLEITEM(N_("_Stagger Flips"), NULL, anim_stagger_cb, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo help_menu[] = {
	GNOMEUIINFO_ITEM_STOCK(N_("_About..."), NULL, about_cb, "Menu_About"),
	GNOMEUIINFO_END
};

GnomeUIInfo mainmenu[] = {
	GNOMEUIINFO_SUBTREE(N_("_Game"), file_menu),
	GNOMEUIINFO_SUBTREE(N_("_Computer"), comp_menu),
	GNOMEUIINFO_SUBTREE(N_("_Animation"), anim_menu),
	GNOMEUIINFO_JUSTIFY_RIGHT,
	GNOMEUIINFO_SUBTREE(N_("_Help"), help_menu),
	GNOMEUIINFO_END
};

static error_t parse_args(int key, char *arg, struct argp_state *state)
{
	switch(key) {
		case 'x':
			session_flag |= 1;
			session_xpos = atoi(arg);
			break;
		case 'y':
			session_flag |= 2;
			session_ypos = atoi(arg);
			break;
#ifdef HAVE_ORBIT
	        case 'i':
			ior = arg;
			break;
#endif
		case ARGP_KEY_SUCCESS:
			if(session_flag == 3) session_position = 1;
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}

	return 0;
}

void quit_game_cb(GtkWidget *widget, gpointer data)
{
	gnome_config_sync();

	gtk_timeout_remove(flip_pixmaps_id);
	gtk_timeout_remove(black_computer_id);
	gtk_timeout_remove(white_computer_id);
	gtk_timeout_remove(check_valid_moves_id);
	gtk_timeout_remove(check_computer_players_id);

	if(buffer_pixmap)
		gdk_pixmap_unref(buffer_pixmap);
	if(tiles_pixmap)
		gdk_pixmap_unref(tiles_pixmap);
	if(tiles_mask)
		gdk_pixmap_unref(tiles_mask);

	gtk_main_quit();
}

void new_game_cb(GtkWidget *widget, gpointer data)
{
	network_new ();
	init_new_game();
}

void black_level_cb(GtkWidget *widget, gpointer data)
{
	int tmp;

	tmp = atoi((gchar *)data);

	gnome_config_set_int("/gnothello/Preferences/blacklevel", tmp);
	gnome_config_sync();

	black_computer_level = tmp;
}

void white_level_cb(GtkWidget *widget, gpointer data)
{
	int tmp;

	tmp = atoi((gchar *)data);

	gnome_config_set_int("/gnothello/Preferences/whitelevel", tmp);
	gnome_config_sync();

	white_computer_level = tmp;
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
			break;
		case 1:
			flip_pixmaps_id = gtk_timeout_add(PIXMAP_FLIP_DELAY * 8, flip_pixmaps, NULL);
			break;
		case 2:
			flip_pixmaps_id = gtk_timeout_add(PIXMAP_FLIP_DELAY, flip_pixmaps, NULL);
			break;
	}
}

void about_cb(GtkWidget *widget, gpointer data)
{
	GtkWidget *about;

	const gchar *authors[] = {"Ian Peters", NULL};

	about = gnome_about_new(_("Gnome Othello"), GNOTHELLO_VERSION, "(C) 1998 Ian Peters", (const char **)authors, _("Send comments and bug reports to: ipeters@acm.org\nTiles under the General Public License."), NULL);

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

	tmp = g_copy_strings("gnothello/", PIXMAP_NAME, NULL);
	fname = gnome_unconditional_pixmap_file(tmp);
	g_free(tmp);

	if(!g_file_exists(fname)) {
		g_print(N_("Could not find \'%s\' pixmap file for Gnothello\n"), fname);
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
	gint animate;

	animate = gnome_config_get_int("/gnothello/Preferences/animate=2");

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			if(pixmaps[i][j] == 100) {
				pixmaps[i][j] = 101;
				gui_draw_pixmap(0, i, j);
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
			}
		}
	return(TRUE);
}

void init_new_game()
{
	guint i, j;

	gtk_timeout_remove(flip_final_id);
	new_game = 1;
	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			board[i][j] = 0;
	board[3][3] = WHITE_TURN;
	board[3][4] = BLACK_TURN;
	board[4][3] = BLACK_TURN;
	board[4][4] = WHITE_TURN;
	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			pixmaps[i][j] = 0;
	pixmaps[3][3] = WHITE_TURN;
	pixmaps[3][4] = BLACK_TURN;
	pixmaps[4][3] = BLACK_TURN;
	pixmaps[4][4] = WHITE_TURN;
	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			gui_draw_pixmap_buffer(pixmaps[i][j], i, j);
	gdk_draw_pixmap(drawing_area->window, drawing_area->style->fg_gc[GTK_WIDGET_STATE(drawing_area)], buffer_pixmap, 0, 0, 0, 0, BOARDWIDTH, BOARDHEIGHT);
	whose_turn = BLACK_TURN;
	black_computer_busy = 0;
	white_computer_busy = 0;
	gui_message(N_("  Black's turn..."));
}

void create_window()
{
	window = gnome_app_new("gnothello", N_("Gnome Othello"));

	gtk_widget_realize(window);
	gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gtk_signal_connect(GTK_OBJECT(window), "delete_event", GTK_SIGNAL_FUNC(quit_game_cb), NULL);
}

void create_menus()
{
	gnome_app_create_menus(GNOME_APP(window), mainmenu);

	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(comp_menu[3].widget), gnome_config_get_bool("/gnothello/Preferences/quickmoves=FALSE"));
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(anim_menu[2].widget), gnome_config_get_int("/gnothello/Preferences/animstagger=0"));
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(anim_radio_list[gnome_config_get_int("/gnothello/Preferences/animate=2")].widget), TRUE);
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(black_level_radio_list[gnome_config_get_int("/gnothello/Preferences/blacklevel=0")].widget), TRUE);
	gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(white_level_radio_list[gnome_config_get_int("/gnothello/Preferences/whitelevel=0")].widget), TRUE);
}

void create_drawing_area()
{
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
}

void create_statusbar()
{
	statusbar = gtk_statusbar_new();
	gtk_widget_show(statusbar);
	statusbar_id = gtk_statusbar_get_context_id(GTK_STATUSBAR(statusbar), "gnothello");
	gnome_app_set_statusbar(GNOME_APP(window), statusbar);
	gtk_statusbar_push(GTK_STATUSBAR(statusbar), statusbar_id, _("  Welcome to Gnome Othello!"));
}

void gui_message(gchar *message)
{
	gtk_statusbar_pop(GTK_STATUSBAR(statusbar), statusbar_id);
	gtk_statusbar_push(GTK_STATUSBAR(statusbar), statusbar_id, message);
}

guint check_computer_players()
{
	if(black_computer_level && !black_computer_busy && whose_turn == BLACK_TURN)
		switch(black_computer_level) {
			case 1:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) BLACK_TURN);
				black_computer_busy = 1;
			break;
			case 2:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) BLACK_TURN);
				black_computer_busy = 1;
			break;
			case 3:
				black_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) BLACK_TURN);
				black_computer_busy = 1;
			break;
		}

	if(whose_turn == WHITE_TURN && black_computer_busy) {
		gtk_timeout_remove(black_computer_id);
		black_computer_busy = 0;
	}

	if(white_computer_level && !white_computer_busy && whose_turn == WHITE_TURN)
		switch(white_computer_level) {
			case 1:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) WHITE_TURN);
				white_computer_busy = 1;
			break;
			case 2:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_1, (gpointer) WHITE_TURN);
				white_computer_busy = 1;
			break;
			case 3:
				white_computer_id = gtk_timeout_add(computer_speed, (GtkFunction)computer_move_3, (gpointer) WHITE_TURN);
				white_computer_busy = 1;
			break;
		}

	if(whose_turn == BLACK_TURN && white_computer_busy) {
		gtk_timeout_remove(white_computer_id);
		white_computer_busy = 0;
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

	argp_program_version = GNOTHELLO_VERSION;

	bindtextdomain(PACKAGE, GNOMELOCALEDIR);
	textdomain(PACKAGE);

	gettimeofday(&tv, NULL);
	srand(tv.tv_usec);

	client = gnome_client_new_default();

	gtk_object_ref(GTK_OBJECT(client));
	gtk_object_sink(GTK_OBJECT(client));

	gtk_signal_connect(GTK_OBJECT(client), "save_yourself", GTK_SIGNAL_FUNC(save_state), argv[0]);
	gtk_signal_connect(GTK_OBJECT(client), "die", GTK_SIGNAL_FUNC(quit_game_cb), argv[0]);

#ifdef HAVE_ORBIT
	CORBA_exception_init (&ev);
	orb = gnome_CORBA_init ("gnothello", &parser, &argc, argv, 0, NULL);
#else
	gnome_init("gnothello", &parser, argc, argv, 0, NULL);
#endif
	
	create_window();
	create_menus();
	create_drawing_area();
	create_statusbar();

	load_pixmaps();

	check_valid_moves_id = gtk_timeout_add(1000, check_valid_moves, NULL);
	check_computer_players_id = gtk_timeout_add(100, (GtkFunction)check_computer_players, NULL);

	if(session_position) {
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
