/* ggz-network.c
 *
 * Copyright (C) 2006 -  Andreas Røsdal <andrearo@pvv.ntnu.no>
 *
 * This game is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
 * USA
 */

#include "config.h"
#include <gnome.h>
#include <pwd.h>

#include <ggzmod.h>
#include <ggz-embed.h>
#include <ggz-gtk.h>

#include "games-dlg-chat.h"
#include "games-dlg-players.h"

#include "gnothello.h"
#include "ggz-network.h"
#include "othello.h"

guint whose_turn = BLACK_TURN;

static gboolean
game_handle_io (GGZMod * mod)
{
  int op = -1;

  fd = ggzmod_get_server_fd (mod);

  // Read the fd
  if (ggz_read_int (fd, &op) < 0) {
    ggz_error_msg ("Couldn't read the game fd");
    return FALSE;
  }

  switch (op) {
  case RVR_MSG_SEAT:
    get_seat ();
    break;
  case RVR_MSG_PLAYERS:
    get_players ();
    /*game.state = RVR_STATE_WAIT; */
    break;
  case RVR_MSG_SYNC:
    get_sync ();
    init_new_game ();
    break;
  case RVR_MSG_START:
    /*state = RVR_STATE_PLAYING; */
    ggz_debug ("main", "Game has started");
    init_new_game ();
    break;
  case RVR_MSG_MOVE:
    get_move ();
    break;
  case RVR_MSG_GAMEOVER:
    get_gameover ();
    /*game.state = RVR_STATE_DONE; */
    break;
  default:
    ggz_error_msg ("Incorrect opcode\n");
    break;
  }

  return TRUE;
}




int
get_seat (void)
{

  if (ggz_read_int (fd, &seat) < 0)
    return -1;

  if (seat == 0) {
    gui_message (_("Waiting for an opponent to join the game."));
  }

  player_id = SEAT2PLAYER (seat);

  return 0;
}

int
get_players (void)
{
  int i;

  for (i = 0; i < 2; i++) {
    if (ggz_read_int (fd, &seats[i]) < 0)
      return -1;

    if (seats[i] != GGZ_SEAT_OPEN) {
      if (ggz_read_string (fd, (char *) &names[i], 17) < 0)
	return -1;
    }
  }

  return 0;

}

int
get_gameover ()
{
  int winner;

  if (ggz_read_int (fd, &winner) < 0)
    return -1;

  return 1;

}

// Get the move from the server and makes it (don't check for validity!!)
int
get_move (void)
{
  int move;

  if (ggz_read_int (fd, &move) < 0)
    return -1;

  if (move == RVR_ERROR_CANTMOVE) {
    return 1;
  }

  if (move < 0) {
    return -1;
  }
  game_make_move (move);

  return 0;

}

// make the move
void
game_make_move (int pos)
{
  int x = X (pos) - 1, y = Y (pos) - 1;

  // iagno move
  move (x, y, whose_turn);

  return;

}



void
send_my_move (int move, guint turn)
{
  if (ggz_write_int (fd, RVR_REQ_MOVE) < 0 || ggz_write_int (fd, move) < 0) {
    gui_message ("Can't send move!");
    return;
  }

  ggz_debug ("main", "Sent move: %d", move);
}

int
request_sync (void)
{
  if (ggz_write_int (fd, RVR_REQ_SYNC) < 0) {
    // Not that someone would check this return value, but...
    return -1;
  } else {
    gui_message ("Requesting sync from the server");
  }
  return 0;
}

int
get_sync (void)
{
/* FIXME: Not supported yet. */
  return 0;
}




static gboolean
handle_ggzmod (GIOChannel * channel, GIOCondition cond, gpointer data)
{
  GGZMod *mod = data;

  return (ggzmod_dispatch (mod) >= 0);
}

static gboolean
handle_game_server (GIOChannel * channel, GIOCondition cond, gpointer data)
{
  GGZMod *mod = data;

  return game_handle_io (mod);
}

static void
handle_ggzmod_server (GGZMod * mod, GGZModEvent e, const void *data)
{
  const int *fd = data;
  GIOChannel *channel;

  ggzmod_set_state (mod, GGZMOD_STATE_PLAYING);
  channel = g_io_channel_unix_new (*fd);
  g_io_add_watch (channel, G_IO_IN, handle_game_server, mod);
}

/****************************************************************************
  Callback function that's called by the library when a connection is
  established (or lost) to the GGZ server.  The server parameter gives
  the server (or NULL).
****************************************************************************/
static void
ggz_connected (GGZServer * server)
{
  /* Nothing useful to do... */
}

/****************************************************************************
  Callback function that's called by the library when we launch a game.  This
  means we now have a connection to a gnect server so handling can be given
  back to the regular gnect code.
****************************************************************************/
static void
ggz_game_launched (void)
{
  network_init ();
  init_new_game ();
  gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), MAIN_PAGE);
}

/****************************************************************************
  Callback function that's invoked when GGZ is exited.
****************************************************************************/
static void
ggz_closed (void)
{
  gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), MAIN_PAGE);
  ggz_network_mode = FALSE;
  init_new_game ();
}

void
network_init (void)
{
  GGZMod *mod;
  GIOChannel *channel;
  int ret, ggzmodfd;

  if (!ggzmod_is_ggz_mode ())
    return;
  ggz_network_mode = TRUE;

  mod = ggzmod_new (GGZMOD_GAME);
  ggzmod_set_handler (mod, GGZMOD_EVENT_SERVER, handle_ggzmod_server);

  ret = ggzmod_connect (mod);
  if (ret != 0) {
    /* Error: GGZ core client error (e.g. faked GGZMODE env variable) */
    return;
  }

  ggzmodfd = ggzmod_get_fd (mod);
  channel = g_io_channel_unix_new (ggzmodfd);
  g_io_add_watch (channel, G_IO_IN, handle_ggzmod, mod);

  init_player_list (mod);
  init_chat (mod);

}

void
on_network_game (void)
{
  GtkWidget *ggzbox;
  struct passwd *pwent;  


  if (ggz_network_mode) {
    gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), NETWORK_PAGE);
    return;
  }

  init_new_game ();
  ggz_network_mode = TRUE;

  ggz_gtk_initialize (FALSE,
		      ggz_connected, ggz_game_launched, ggz_closed,
		      NETWORK_ENGINE, NETWORK_VERSION, "iagno.xml",
		      "GGZ Gaming Zone");

  pwent = getpwuid(getuid());

  ggz_embed_ensure_server ("GGZ Gaming Zone", "gnome.ggzgamingzone.org",
			   5688, pwent->pw_name);

  ggzbox = ggz_gtk_create_main_area (window);
  gtk_notebook_append_page (GTK_NOTEBOOK (notebook), ggzbox, NULL);
  gtk_notebook_set_current_page (GTK_NOTEBOOK (notebook), NETWORK_PAGE);
}
