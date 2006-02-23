/*
 * Network.c - network code for iagno.
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <gnome.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include <netdb.h>
#include "othello.h"
#include "gnothello.h"
#include "games-network.h"
#include "games-network-dialog.h"
#include "network.h"

char *game_server = "localhost"; 
char *game_port = "26478";

static void game_handle_input (NetworkGame *ng, char *buf);

void
network_start (void)
{
  games_network_start();
}

void
network_stop (void)
{
  games_network_stop ();
}

gboolean
is_network_running (void)
{
  return (get_network_status () == CONNECTED);
}

int
game_move (guint x, guint y, guint me)
{
  static char msgbuf[256];

  gnome_triggers_do ("", NULL, "gnothello", "flip-piece", NULL);

  snprintf (msgbuf, sizeof (msgbuf), "move %u %u %u\n", x, y, me);

  games_send_gamedata(msgbuf);

  return move (x, y, me);
}

int
network_allow (void)
{
  return games_network_allow ();
}


void
network_new (GtkWidget *parent_window)
{
  set_game_input_cb (game_handle_input);
  set_game_clear_cb (clear_board);
  set_game_msg_cb (gui_message);
  games_network_new (game_server, game_port, parent_window);
}


static void 
game_handle_input (NetworkGame *ng, char *buf)
{
  char *args;

  args = strchr (buf, ' ');

  if (args) {
    *args = '\0';
    args++;
  }

  if (!strcmp (buf, "set_peer")) {
    int me;
      
    if (ng->mycolor) {
      network_set_status (ng, DISCONNECTED, _("Invalid move attempted"));
      return;
    }
      
    if (!args || sscanf (args, "%d", &me) != 1
        || (me != WHITE_TURN && me != BLACK_TURN)) {
      network_set_status (ng, DISCONNECTED, _("Invalid game data (set_peer)"));
      return;
    }
    white_level_cb (NULL, "0");
    black_level_cb (NULL, "0");
      
    ng->mycolor = me;
    network_gui_message (_("Peer introduction complete"));
  } else if (! strcmp (buf, "move")) {
    int x, y, me;

    if (!args || sscanf(args, "%d %d %d", &x, &y, &me) != 3
        || !me || me != (32-ng->mycolor)
        || x >= 8 || y >= 8) {
      network_set_status (ng, DISCONNECTED, _("Invalid game data (move)"));
      return;
    }

    move (x, y, me);
  } else if (!strcmp(buf, "new_game")) {

    if (!ng->sent_newgame) {
      g_string_append_printf (ng->outbuf, "new_game %s \n", player_name);
    } else {
      network_gui_connected();
      network_gui_message (_("New game ready to be started"));
      network_gui_add_player(args);
    }
    ng->sent_newgame = 0;

    whose_turn = BLACK_TURN;
  } else if (!strcmp(buf, "start_game")) {
    network_gui_message (_("New game started"));
                                                                                
    if (!ng->sent_startgame) {
      g_string_append_printf (ng->outbuf, "start_game\n");
    }

    ng->sent_startgame = 0;
                                                                                
    init_new_game ();
    network_gui_close();
  }
}

