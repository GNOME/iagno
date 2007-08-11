/* -*- mode:C; indent-tabs-mode:t; tab-width:8; c-basic-offset:8; -*- */

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
#include <gdk/gdkkeysyms.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include <string.h>
#include <games-stock.h>
#include <games-sound.h>
#include <games-conf.h>

#ifdef GGZ_CLIENT
#include <games-dlg-chat.h>
#include <games-dlg-players.h>
#include "ggz-network.h"
#include <ggz-embed.h>
#endif

#include "gnothello.h"
#include "othello.h"
#include "properties.h"

#define APP_NAME "iagno"
#define APP_NAME_LONG N_("Iagno")

GnomeAppBar *appbar;
GtkWidget *window;
GtkWidget *notebook;
GtkWidget *drawing_area;
GtkWidget *tile_dialog;
GtkWidget *black_score;
GtkWidget *white_score;

GdkPixmap *buffer_pixmap = NULL;
GdkPixmap *tiles_pixmap = NULL;
GdkPixmap *tiles_mask = NULL;

gint flip_pixmaps_id = 0;
gint statusbar_id;
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

guint game_in_progress;

gint8 pixmaps[8][8] = { {0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
};

gint8 board[8][8] = { {0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
,
{0, 0, 0, 0, 0, 0, 0, 0}
};
guint whose_turn;
gint8 move_count;
gint bcount;
gint wcount;

extern guint flip_final_id;
extern gint8 squares[64];

int session_flag = 0;
int session_xpos = -1;
int session_ypos = -1;
int session_position = 0;

gchar *tile_set = NULL;
gchar *tile_set_tmp = NULL;

GdkGC *gridGC[2] = { 0 };

static const GOptionEntry options[] = {
  {"x", 'x', 0, G_OPTION_ARG_INT, &session_xpos, N_("X location of window"),
   N_("X")},
  {"y", 'y', 0, G_OPTION_ARG_INT, &session_ypos, N_("Y location of window"),
   N_("Y")},
  {NULL}
};

GnomeUIInfo game_menu[] = {
  GNOMEUIINFO_MENU_NEW_GAME_ITEM (new_game_cb, NULL),

  GNOMEUIINFO_ITEM (N_("Net_work Game"), NULL, new_network_game_cb, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_UNDO_MOVE_ITEM (undo_move_cb, NULL),

  GNOMEUIINFO_ITEM (N_("_Player list"), NULL, on_player_list, NULL),

  GNOMEUIINFO_ITEM (N_("_Chat Window"), NULL, on_chat_window, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_ITEM (N_("_Leave Game"), NULL, on_network_leave, NULL),

  GNOMEUIINFO_MENU_QUIT_ITEM (quit_game_cb, NULL),

  GNOMEUIINFO_END
};

GnomeUIInfo settings_menu[] = {
  GNOMEUIINFO_MENU_PREFERENCES_ITEM (properties_cb, NULL),
  GNOMEUIINFO_END
};

GnomeUIInfo help_menu[] = {
  GNOMEUIINFO_HELP ("iagno"),
  GNOMEUIINFO_MENU_ABOUT_ITEM (about_cb, NULL),
  GNOMEUIINFO_END
};

GnomeUIInfo mainmenu[] = {
  GNOMEUIINFO_MENU_GAME_TREE (game_menu),
  GNOMEUIINFO_MENU_SETTINGS_TREE (settings_menu),
  GNOMEUIINFO_MENU_HELP_TREE (help_menu),
  GNOMEUIINFO_END
};

static void
undo_set_sensitive (gboolean state)
{
  gtk_widget_set_sensitive (game_menu[3].widget, state);
}

void
quit_game_cb (GtkWidget * widget, gpointer data)
{
  gtk_main_quit ();
}

void
new_game_cb (GtkWidget * widget, gpointer data)
{
  init_new_game ();
}

void
on_player_list (void)
{
#ifdef GGZ_CLIENT
  create_or_raise_dlg_players (GTK_WINDOW (window));
#endif
}

void
on_chat_window (void)
{
#ifdef GGZ_CLIENT
  create_or_raise_dlg_chat (GTK_WINDOW (window));
#endif
}

void
new_network_game_cb (GtkWidget * widget, gpointer data)
{
#ifdef GGZ_CLIENT
  on_network_game ();
  gtk_widget_hide (mainmenu[0].widget);
  gtk_widget_hide (mainmenu[1].widget);
#endif
}

void
on_network_leave (GObject * object, gpointer data)
{
#ifdef GGZ_CLIENT
  ggz_embed_leave_table ();
  gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), NETWORK_PAGE);
#endif
}

void
undo_move_cb (GtkWidget * widget, gpointer data)
{
  gint8 which_computer, xy;

  if ((black_computer_level && white_computer_level) || move_count == 4)
    return;
   
  /* Cancel any pending AI operations */
  if (black_computer_id) {
    g_source_remove (black_computer_id);
    black_computer_id = 0;
  }
  if (white_computer_id) {
    g_source_remove (white_computer_id);
    white_computer_id = 0;
  }

  if (flip_final_id) {
    g_source_remove (flip_final_id);
    flip_final_id = 0;
  }

  game_in_progress = 1;

  which_computer = OTHER_PLAYER (whose_turn);
  undo ();
  board_copy ();
  xy = squares[move_count];
  pixmaps[xy % 10 - 1][xy / 10 - 1] = 100;
  if ((((whose_turn == WHITE_TURN) && white_computer_level) ||
       ((whose_turn == BLACK_TURN) && black_computer_level))
      && (move_count > 4)) {
    undo ();
    board_copy ();
    xy = squares[move_count];
    pixmaps[xy % 10 - 1][xy / 10 - 1] = 100;
  }

  gui_status ();
  tiles_to_flip = 1;
  check_computer_players ();
}

void
about_cb (GtkWidget * widget, gpointer data)
{
  const gchar *authors[] = { "Ian Peters", NULL };

  const gchar *documenters[] = { "Eric Baudais", NULL };

  gchar *license = games_get_license (_(APP_NAME_LONG));

  gtk_show_about_dialog (GTK_WINDOW (window),
			 "name", _(APP_NAME_LONG),
			 "version", VERSION,
			 "copyright",
			 "Copyright \xc2\xa9 1998-2007 Ian Peters",
                         "license", license,
                         "comments", _("A disk flipping game derived from Reversi.\n\nIagno is a part of GNOME Games."),
			 "authors", authors,
                         "documenters", documenters,
			 "translator-credits", _("translator-credits"),
			 "logo-icon-name", "gnome-iagno",
			 "website-label", _("GNOME Games web site"),
                         "website", "http://www.gnome.org/projects/gnome-games/",
			 "wrap-license", TRUE,
                         NULL);
  g_free (license);
}

void
properties_cb (GtkWidget * widget, gpointer data)
{
  show_properties_dialog ();
}

gint
expose_event (GtkWidget * widget, GdkEventExpose * event)
{
  gdk_draw_drawable (widget->window,
		     widget->style->fg_gc[GTK_WIDGET_STATE (widget)],
		     buffer_pixmap,
		     event->area.x, event->area.y,
		     event->area.x, event->area.y,
		     event->area.width, event->area.height);

  return (FALSE);
}

gboolean
configure_event (GtkWidget * widget, GdkEventConfigure * event)
{
  static int old_width = 0, old_height = 0;
  guint i, j;

  if (old_width == event->width && old_height == event->height) {
    return TRUE;
  } else {
    old_width = event->width;
    old_height = event->height;
  }

  if (gridGC[0] != 0) {
    gdk_draw_rectangle (buffer_pixmap, gridGC[0], 1,
			0, 0, BOARDWIDTH, BOARDHEIGHT);
    for (i = 0; i < 8; i++)
      for (j = 0; j < 8; j++)
	gui_draw_pixmap_buffer (pixmaps[i][j], i, j);
    gui_draw_grid ();
  }

  return TRUE;
}

gint
button_press_event (GtkWidget * widget, GdkEventButton * event)
{
  guint x, y;

  if (game_in_progress == 0)
    return TRUE;

  if (!ggz_network_mode && (whose_turn == WHITE_TURN) && white_computer_level)
    return TRUE;

  if (!ggz_network_mode && (whose_turn == BLACK_TURN) && black_computer_level)
    return TRUE;

  if (event->button == 1) {
    x = event->x / (TILEWIDTH + GRIDWIDTH);
    y = event->y / (TILEHEIGHT + GRIDWIDTH);
    if (ggz_network_mode && player_id == whose_turn
	&& is_valid_move (x, y, whose_turn)) {
#ifdef GGZ_CLIENT
      send_my_move (CART (x + 1, y + 1), whose_turn);
#endif
    } else if (!ggz_network_mode && is_valid_move (x, y, whose_turn)) {
      move (x, y, whose_turn);
    } else {
      gui_message (_("Invalid move."));
    }

  }

  return TRUE;
}

void
gui_draw_pixmap (gint which, gint x, gint y)
{
  gdk_draw_drawable (drawing_area->window, gridGC[0], tiles_pixmap,
		     (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT,
		     x * (TILEWIDTH + GRIDWIDTH),
		     y * (TILEHEIGHT + GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
  gdk_draw_drawable (buffer_pixmap, gridGC[0], tiles_pixmap,
		     (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT,
		     x * (TILEWIDTH + GRIDWIDTH),
		     y * (TILEHEIGHT + GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
}

void
gui_draw_pixmap_buffer (gint which, gint x, gint y)
{
  gdk_draw_drawable (buffer_pixmap, gridGC[0], tiles_pixmap,
		     (which % 8) * TILEWIDTH, (which / 8) * TILEHEIGHT,
		     x * (TILEWIDTH + GRIDWIDTH),
		     y * (TILEHEIGHT + GRIDWIDTH), TILEWIDTH, TILEHEIGHT);
}

void
gui_draw_grid (void)
{
  int i;

  for (i = 1; i < 8; i++) {
    gdk_draw_line (buffer_pixmap, gridGC[grid],
		   i * BOARDWIDTH / 8 - 1, 0,
		   i * BOARDWIDTH / 8 - 1, BOARDHEIGHT);
    gdk_draw_line (buffer_pixmap, gridGC[grid],
		   0, i * BOARDHEIGHT / 8 - 1,
		   BOARDWIDTH, i * BOARDHEIGHT / 8 - 1);
  }

  gdk_draw_drawable (drawing_area->window, gridGC[0], buffer_pixmap,
		     0, 0, 0, 0, BOARDWIDTH, BOARDHEIGHT);
}

void
load_pixmaps (void)
{
  GdkPixbuf *image;
  GError *error = NULL;
  gchar *tmp;
  gchar *fname;

  g_return_if_fail (tile_set != NULL && tile_set[0] != '0');

  tmp = g_build_filename ("iagno", tile_set, NULL);
  fname = gnome_program_locate_file (NULL, GNOME_FILE_DOMAIN_APP_PIXMAP,
				     tmp, FALSE, NULL);
  g_free (tmp);

  if (!g_file_test (fname, G_FILE_TEST_EXISTS)) {
    g_free (fname);
    fname = gnome_program_locate_file (NULL,
				       GNOME_FILE_DOMAIN_APP_PIXMAP,
				       "iagno/classic.png", FALSE, NULL);
  }

  if (!g_file_test (fname, G_FILE_TEST_EXISTS | G_FILE_TEST_IS_REGULAR)) {
    g_print (_("Could not find \'%s\' pixmap file\n"), fname);
    exit (1);
  }

  image = gdk_pixbuf_new_from_file (fname, &error);
  if (error) {
    g_warning (G_STRLOC ": gdk-pixbuf error %s\n", error->message);
    g_error_free (error);
    error = NULL;
  }

  gdk_pixbuf_render_pixmap_and_mask_for_colormap (image,
						  gdk_colormap_get_system (),
						  &tiles_pixmap,
						  &tiles_mask, 127);

  gdk_pixbuf_unref (image);
  g_free (fname);
}

gint
flip_pixmaps (gpointer data)
{
  guint i, j;
  guint flipped_tiles = 0;

  if (!tiles_to_flip)
    return TRUE;

  for (i = 0; i < 8; i++)
    for (j = 0; j < 8; j++) {
      /* This first case only happens when undoing the "final flip". */
      if ((pixmaps[i][j] == 101) && (board[i][j] != 0)) {
	pixmaps[i][j] = board[i][j];
	gui_draw_pixmap (pixmaps[i][j], i, j);
	flipped_tiles = 1;
      } else if ((pixmaps[i][j] == 100)
		 || ((pixmaps[i][j] != 101) && (board[i][j] == 0))) {
	pixmaps[i][j] = 101;
	gui_draw_pixmap (0, i, j);
	flipped_tiles = 1;
      } else if (pixmaps[i][j] < board[i][j]) {
	if (animate == 0) {
	  if (pixmaps[i][j] == BLACK_TURN)
	    pixmaps[i][j] = board[i][j];
	  else
	    pixmaps[i][j]++;
	} else if (animate == 1) {
	  if (pixmaps[i][j] < 1)
	    pixmaps[i][j] += 2;
	  else if (pixmaps[i][j] >= 1 && pixmaps[i][j] < 8)
	    pixmaps[i][j] = 8;
	  else if (pixmaps[i][j] >= 8 && pixmaps[i][j] < 16)
	    pixmaps[i][j] = 16;
	  else if (pixmaps[i][j] >= 16 && pixmaps[i][j] < 23)
	    pixmaps[i][j] = 23;
	  else if (pixmaps[i][j] >= 23 && pixmaps[i][j] < 31)
	    pixmaps[i][j] = 31;
	  else if (pixmaps[i][j] > 31)
	    pixmaps[i][j] = 31;
	} else if (animate == 2)
	  pixmaps[i][j]++;
	if (pixmaps[i][j] > 0)
	  gui_draw_pixmap (pixmaps[i][j], i, j);
	flipped_tiles = 1;
      } else if (pixmaps[i][j] > board[i][j] && pixmaps[i][j] != 101) {
	if (animate == 0) {
	  if (pixmaps[i][j] == WHITE_TURN)
	    pixmaps[i][j] = board[i][j];
	  else
	    pixmaps[i][j]--;
	} else if (animate == 1) {
	  if (pixmaps[i][j] > 31)
	    pixmaps[i][j] -= 2;
	  else if (pixmaps[i][j] <= 31 && pixmaps[i][j] > 23)
	    pixmaps[i][j] = 23;
	  else if (pixmaps[i][j] <= 23 && pixmaps[i][j] > 16)
	    pixmaps[i][j] = 16;
	  else if (pixmaps[i][j] <= 16 && pixmaps[i][j] > 8)
	    pixmaps[i][j] = 8;
	  else if (pixmaps[i][j] <= 8 && pixmaps[i][j] > 1)
	    pixmaps[i][j] = 1;
	  else if (pixmaps[i][j] < 1)
	    pixmaps[i][j] = 1;
	} else if (animate == 2)
	  pixmaps[i][j]--;
	if (pixmaps[i][j] < 32)
	  gui_draw_pixmap (pixmaps[i][j], i, j);
	flipped_tiles = 1;
      }
    }

  if (!flipped_tiles)
    tiles_to_flip = 0;

  return TRUE;
}

static void
redraw_board (void)
{
  guint i, j;

  gui_status ();

  for (i = 0; i < 8; i++)
    for (j = 0; j < 8; j++)
      gui_draw_pixmap_buffer (pixmaps[i][j], i, j);

  gui_draw_grid ();
}

void
clear_board (void)
{
  guint i, j;

  if (flip_final_id) {
    g_source_remove (flip_final_id);
    flip_final_id = 0;
  }

  if (black_computer_id) {
    g_source_remove (black_computer_id);
    black_computer_id = 0;
  }

  if (white_computer_id) {
    g_source_remove (white_computer_id);
    white_computer_id = 0;
  }

  game_in_progress = 0;
  move_count = 0;
  for (i = 0; i < 8; i++)
    for (j = 0; j < 8; j++)
      board[i][j] = 0;

  memcpy (pixmaps, board, sizeof (gint8) * 8 * 8);

  bcount = 0;
  wcount = 0;

  redraw_board ();
}

void
init_new_game (void)
{
  clear_board ();
  game_in_progress = 1;
  move_count = 4;

  undo_set_sensitive (FALSE);

  board[3][3] = WHITE_TURN;
  board[3][4] = BLACK_TURN;
  board[4][3] = BLACK_TURN;
  board[4][4] = WHITE_TURN;

  bcount = 2;
  wcount = 2;
  init ();

  memcpy (pixmaps, board, sizeof (gint8) * 8 * 8);

  redraw_board ();

  whose_turn = BLACK_TURN;
  gui_status ();
  gtk_widget_show (mainmenu[0].widget);
  gtk_widget_show (mainmenu[1].widget);

  check_computer_players ();
}

void
create_window (void)
{
  GtkWidget *table;

  window = gnome_app_new ("iagno", _(APP_NAME_LONG));

  games_conf_add_window (GTK_WINDOW (window), NULL);

  notebook = gtk_notebook_new ();
  gtk_notebook_set_show_tabs (GTK_NOTEBOOK (notebook), FALSE);

  gtk_widget_realize (window);
  gtk_window_set_resizable (GTK_WINDOW (window), FALSE);
  g_signal_connect (G_OBJECT (window), "delete_event",
		    G_CALLBACK (quit_game_cb), NULL);

  gnome_app_create_menus (GNOME_APP (window), mainmenu);

  drawing_area = gtk_drawing_area_new ();

  gtk_widget_pop_colormap ();

  gnome_app_set_contents (GNOME_APP (window), notebook);
  gtk_notebook_append_page (GTK_NOTEBOOK (notebook), drawing_area, NULL);
  gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), MAIN_PAGE);

  gtk_widget_set_size_request (GTK_WIDGET (drawing_area),
			       BOARDWIDTH, BOARDHEIGHT);
  g_signal_connect (G_OBJECT (drawing_area), "expose_event",
		    G_CALLBACK (expose_event), NULL);
  g_signal_connect (G_OBJECT (window), "configure_event",
		    G_CALLBACK (configure_event), NULL);
  g_signal_connect (G_OBJECT (drawing_area), "button_press_event",
		    G_CALLBACK (button_press_event), NULL);
  gtk_widget_set_events (drawing_area,
			 GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK);
  /* We do our own double-buffering. */
  gtk_widget_set_double_buffered (drawing_area, FALSE);

  gtk_widget_show (drawing_area);

  appbar = GNOME_APPBAR (gnome_appbar_new (FALSE, TRUE, FALSE));
  gnome_app_set_statusbar (GNOME_APP (window), GTK_WIDGET (appbar));
  gnome_app_install_menu_hints (GNOME_APP (window), mainmenu);

  table = gtk_table_new (1, 8, FALSE);

  black_score = gtk_label_new (_("Dark:"));
  gtk_widget_show (black_score);

  gtk_table_attach (GTK_TABLE (table), black_score, 1, 2, 0, 1, 0, 0, 3, 1);

  black_score = gtk_label_new ("00");
  gtk_widget_show (black_score);

  gtk_table_attach (GTK_TABLE (table), black_score, 2, 3, 0, 1, 0, 0, 3, 1);

  white_score = gtk_label_new (_("Light:"));
  gtk_widget_show (white_score);

  gtk_table_attach (GTK_TABLE (table), white_score, 4, 5, 0, 1, 0, 0, 3, 1);

  white_score = gtk_label_new ("00");
  gtk_widget_show (white_score);

  gtk_table_attach (GTK_TABLE (table), white_score, 5, 6, 0, 1, 0, 0, 3, 1);
  undo_set_sensitive (FALSE);

  gtk_widget_show (table);

  gtk_box_pack_start (GTK_BOX (appbar), table, FALSE, TRUE, 0);

  gnome_appbar_set_status (GNOME_APPBAR (appbar), _("Welcome to Iagno!"));
}

void
gui_status (void)
{
  gchar message[3];

  sprintf (message, _("%.2d"), bcount);
  gtk_label_set_text (GTK_LABEL (black_score), message);
  sprintf (message, _("%.2d"), wcount);
  gtk_label_set_text (GTK_LABEL (white_score), message);
  undo_set_sensitive (move_count > 0);

  if (ggz_network_mode) {
    gtk_widget_hide (game_menu[0].widget);
    gtk_widget_hide (game_menu[1].widget);
    gtk_widget_hide (game_menu[2].widget);
    gtk_widget_hide (game_menu[3].widget);
    gtk_widget_show (game_menu[4].widget);
    gtk_widget_show (game_menu[5].widget);
    gtk_widget_show (game_menu[7].widget);
  } else {
    gtk_widget_show (game_menu[0].widget);
    gtk_widget_show (game_menu[1].widget);
    gtk_widget_show (game_menu[2].widget);
    gtk_widget_show (game_menu[3].widget);
    gtk_widget_hide (game_menu[4].widget);
    gtk_widget_hide (game_menu[5].widget);
    gtk_widget_hide (game_menu[7].widget);
  }

  gtk_widget_set_sensitive (settings_menu[0].widget, !ggz_network_mode);

#ifndef GGZ_CLIENT
  gtk_widget_set_sensitive (game_menu[1].widget, FALSE);
#endif

  if (ggz_network_mode) {
    if (whose_turn == player_id && whose_turn == BLACK_TURN) {
      gui_message (_("It is your turn to place a dark piece"));
    } else if (whose_turn == player_id && whose_turn == WHITE_TURN) {
      gui_message (_("It is your turn to place a light piece"));
    } else {
      gchar *str;
      str = g_strdup_printf (_("Waiting for %s to move"),
			     names[(seat + 1) % 2]);
      gui_message (str);
      g_free (str);
    }
  } else {
    if (whose_turn == BLACK_TURN) {
      gui_message (_("Dark's move"));
    } else if (whose_turn == WHITE_TURN) {
      gui_message (_("Light's move"));
    }

  }


}

void
gui_message (gchar * message)
{
  gnome_appbar_pop (GNOME_APPBAR (appbar));
  gnome_appbar_push (GNOME_APPBAR (appbar), message);
}

guint
check_computer_players (void)
{

  if (ggz_network_mode) {
    black_computer_id = 0;
    white_computer_id = 0;
    return TRUE;
  }
  if (black_computer_level && whose_turn == BLACK_TURN)
    switch (black_computer_level) {
    case 1:
      black_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_1,
		       (gpointer) BLACK_TURN);
      break;
    case 2:
      black_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_2,
		       (gpointer) BLACK_TURN);
      break;
    case 3:
      black_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_3,
		       (gpointer) BLACK_TURN);
      break;
    }

  if (white_computer_level && whose_turn == WHITE_TURN)
    switch (white_computer_level) {
    case 1:
      white_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_1,
		       (gpointer) WHITE_TURN);
      break;
    case 2:
      white_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_2,
		       (gpointer) WHITE_TURN);
      break;
    case 3:
      white_computer_id =
	g_timeout_add (computer_speed, (GSourceFunc) computer_move_3,
		       (gpointer) WHITE_TURN);
      break;
    }

  return TRUE;
}

void
set_bg_color (void)
{
  GdkImage *tmpimage;
  GdkColor bgcolor;

  tmpimage = gdk_drawable_get_image (tiles_pixmap, 0, 0, 1, 1);
  bgcolor.pixel = gdk_image_get_pixel (tmpimage, 0, 0);
  gdk_window_set_background (drawing_area->window, &bgcolor);

  if (gridGC[0])
    g_object_unref (gridGC[0]);
  gridGC[0] = gdk_gc_new (drawing_area->window);
  if (gridGC[1])
    g_object_unref (gridGC[1]);
  gridGC[1] = gdk_gc_new (drawing_area->window);

  gdk_gc_copy (gridGC[0], drawing_area->style->bg_gc[0]);
  gdk_gc_copy (gridGC[1], drawing_area->style->bg_gc[0]);

  gdk_gc_set_background (gridGC[0], &bgcolor);
  gdk_gc_set_foreground (gridGC[0], &bgcolor);

  /* Create a complementary color to use for the ON state */
  bgcolor.pixel = 0xFFFFFF - bgcolor.pixel;
  gdk_gc_set_background (gridGC[1], &bgcolor);
  gdk_gc_set_foreground (gridGC[1], &bgcolor);

  gdk_gc_set_line_attributes (gridGC[1], 0,
			      GDK_LINE_ON_OFF_DASH,
			      GDK_CAP_BUTT, GDK_JOIN_MITER);

  g_object_unref (tmpimage);
}

static int
save_state (GnomeClient * client, gint phase, GnomeRestartStyle save_style,
	    gint shutdown, GnomeInteractStyle interact_style,
	    gint fast, gpointer client_data)
{
  char *argv[20];
  int i;
  gint xpos, ypos;

  gdk_window_get_origin (window->window, &xpos, &ypos);

  i = 0;
  argv[i++] = (char *) client_data;
  argv[i++] = "-x";
  argv[i++] = g_strdup_printf ("%d", xpos);
  argv[i++] = "-y";
  argv[i++] = g_strdup_printf ("%d", ypos);

  gnome_client_set_restart_command (client, i, argv);
  gnome_client_set_clone_command (client, 0, NULL);

  g_free (argv[2]);
  g_free (argv[4]);

  return TRUE;
}

int
main (int argc, char **argv)
{
  GnomeClient *client;
  GnomeProgram *program;
  GOptionContext *context;

  bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
  bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
  textdomain (GETTEXT_PACKAGE);

  g_thread_init (NULL);

  context = g_option_context_new (NULL);
  g_option_context_add_main_entries (context, options, GETTEXT_PACKAGE);
  games_sound_add_option_group (context);

  program = gnome_program_init ("iagno", VERSION,
				LIBGNOMEUI_MODULE,
				argc, argv,
				GNOME_PARAM_GOPTION_CONTEXT, context,
				GNOME_PARAM_APP_DATADIR, DATADIR, NULL);

  gtk_window_set_default_icon_name ("gnome-iagno");

  games_conf_initialise (APP_NAME);

  client = gnome_master_client ();

  g_signal_connect (G_OBJECT (client), "save_yourself",
		    G_CALLBACK (save_state), argv[0]);
  g_signal_connect (G_OBJECT (client), "die",
		    G_CALLBACK (quit_game_cb), argv[0]);

  create_window ();

  load_properties ();

  load_pixmaps ();

  gtk_widget_show (window);

#ifdef GGZ_CLIENT
  network_init ();
#endif

  if (session_xpos >= 0 && session_ypos >= 0) {
    gdk_window_move (window->window, session_xpos, session_ypos);
  }

  buffer_pixmap = gdk_pixmap_new (drawing_area->window,
				  BOARDWIDTH, BOARDHEIGHT, -1);

  set_bg_color ();

  init_new_game ();

  gtk_main ();

  games_conf_shutdown ();

  g_object_unref (program);

  return 0;
}
