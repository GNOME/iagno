/*
 * gnothello.h - Header for gnothello.c
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

#ifndef _GNOTHELLO_H_
#define _GNOTHELLO_H_

#define BLACK_TURN 1
#define WHITE_TURN 31
#define PIXMAP_FLIP_DELAY 20
#define PIXMAP_STAGGER_DELAY 3
#define COMPUTER_MOVE_DELAY 1000

#define TILEWIDTH   60
#define TILEHEIGHT  60
#define GRIDWIDTH   1
#define BOARDWIDTH  ((TILEWIDTH+GRIDWIDTH)  * 8)
#define BOARDHEIGHT ((TILEHEIGHT+GRIDWIDTH) * 8)

typedef struct _MoveHistory MoveHistory;

struct _MoveHistory
{
        gint8 board[8][8];
        gint8 x;
        gint8 y;
	gint8 me;
};

void new_game_cb(GtkWidget *widget, gpointer data);
void new_net_game_cb(GtkWidget *widget, gpointer data);
void quit_game_cb(GtkWidget *widget, gpointer data);
void undo_move_cb(GtkWidget *widget, gpointer data);
void redo_move_cb(GtkWidget *widget, gpointer data);
void black_level_cb (GtkWidget *widget, gpointer data);
void white_level_cb (GtkWidget *widget, gpointer data);
void about_cb (GtkWidget *widget, gpointer data);
void comp_black_cb (GtkWidget *widget, gpointer data);
void comp_white_cb (GtkWidget *widget, gpointer data);
void quick_moves_cb (GtkWidget *widget, gpointer data);
void anim_cb (GtkWidget *widget, gpointer data);
void anim_stagger_cb (GtkWidget *widget, gpointer data);
void load_tiles_cb(GtkWidget *widget, gpointer data);
void fill_menu(GtkWidget *menu);
void set_selection(GtkWidget *widget, void *data);
void free_str(GtkWidget *widget, void *data);
void load_tiles_callback(GtkWidget *widget, void *data);
void cancel(GtkWidget *widget, void *data);
gint expose_event (GtkWidget *widget ,GdkEventExpose *event);
gint configure_event (GtkWidget *widget, GdkEventConfigure *event);
gint button_press_event (GtkWidget *widget, GdkEventButton *event);
void gui_draw_pixmap(gint which, gint x, gint y);
void gui_draw_pixmap_buffer(gint which, gint x, gint y);
gint flip_pixmaps(gpointer data);
void init_new_game();
void create_window();
void gui_status();
void gui_message(gchar *message);
guint check_computer_players();
void load_pixmaps();
void properties_cb (GtkWidget *widget, gpointer data);
void set_bg_color(void);
void gui_draw_grid(void);

extern guint whose_turn;

#endif
