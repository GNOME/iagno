/* Originally was a lame CORBA-based implementation that was no use on the Internet.
   This is a simple line-oriented text protocol that you almost "can't get wrong".

   To be improved: Make it more obvious what is going on (instead of
   just using status bar) and indicate which color you are playing
   as. All UI stuff.

   -- Elliot
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
#include "gnothello-game.h"
#include "othello.h"
#include "gnothello.h"
#include "network.h"

/* (('g'<<8)+'n' */
#define GAME_PORT "26478"

/* Shared with gnothello.c */
char *game_server = "gnothello.gnome.org";

typedef struct {
  char inbuf[1024];
  int inpos;

  int fd;
  GIOChannel *fd_gioc;
  guint read_tag, write_tag;
  int mycolor;
  int sent_newgame;

  enum { CONNECTING, CONNECTED, DISCONNECTED } status;

  GString *outbuf;
} NetworkGame;

static NetworkGame *netgame = NULL;
typedef enum { CALLER_READ_CB, CALLER_WRITE_CB, CALLER_OTHER } CallerType;

static gboolean network_handle_read(GIOChannel *source, GIOCondition cond, gpointer data);
static gboolean network_handle_write(GIOChannel *source, GIOCondition cond, gpointer data);
static void network_set_status(NetworkGame *ng, int status, const char *message);
static void network_handle_input(NetworkGame *ng, char *buf);
static gboolean network_io_setup(NetworkGame *ng, CallerType caller);

void
network_start(void)
{
  NetworkGame *nng;

  if(netgame)
    return;

  netgame = nng = g_new0(NetworkGame, 1);
  nng->outbuf = g_string_new("");
  network_set_status(nng, DISCONNECTED, _("Network initialization complete."));
}

void
network_stop(void)
{
  if(!netgame)
    return;

  network_set_status(netgame, DISCONNECTED, _("Network shutdown in progress."));
  network_io_setup(netgame, CALLER_OTHER);
  g_string_free(netgame->outbuf, TRUE);
  g_free(netgame);
  netgame = NULL;
}

static void
network_set_status(NetworkGame *ng, int status, const char *message)
{
  if(status != CONNECTED)
    game_in_progress = 0;

  if(status == DISCONNECTED)
    {
      close(ng->fd); ng->fd = -1; g_io_channel_unref(ng->fd_gioc); ng->fd_gioc = NULL;
      g_string_truncate(netgame->outbuf, 0);
    }

  ng->status = status;
  ng->mycolor = 0;
  gui_message((char *)message);
}

static gboolean
network_io_setup(NetworkGame *ng, CallerType caller)
{
  gboolean need_read = FALSE, need_write = FALSE, retval = TRUE;

  if(ng->status == CONNECTING)
    {
      need_write = TRUE;
      need_read = FALSE;
    }
  else if(ng->status == CONNECTED)
    {
      need_read = TRUE;
      need_write = ng->outbuf->len?TRUE:FALSE;
    }

  if(need_read && !ng->read_tag)
    {
      ng->read_tag = g_io_add_watch(ng->fd_gioc, G_IO_IN|G_IO_ERR|G_IO_HUP|G_IO_NVAL,
				    network_handle_read, ng);
    }
  else if(!need_read && ng->read_tag)
    {
      if(caller == CALLER_READ_CB)
	retval = FALSE;
      else
	g_source_remove(ng->read_tag);
      ng->read_tag = 0;
    }

  if(need_write && !ng->write_tag)
    {
      ng->write_tag = g_io_add_watch(ng->fd_gioc, G_IO_OUT,
				     network_handle_write, ng);
    }
  else if(!need_write && ng->write_tag)
    {
      if(caller == CALLER_WRITE_CB)
	retval = FALSE;
      else
	g_source_remove(ng->write_tag);
      ng->write_tag = 0;
    }

  return retval;
}

static gboolean
network_handle_read(GIOChannel *source, GIOCondition cond, gpointer data)
{
  NetworkGame *ng = data;
  int maxread, n;
  char *ctmp;

  maxread = sizeof(ng->inbuf) - ng->inpos - 2;

  if(!(cond & G_IO_IN) || !maxread)
    goto errout;

  n = read(ng->fd, ng->inbuf + ng->inpos, maxread);
  if(n <= 0)
    goto errout;

  ng->inpos += n;
  ng->inbuf[ng->inpos] = '\0';
  while((ctmp = strchr(ng->inbuf, '\n')))
    {
      int itmp;
      *(ctmp++) = '\0';
      network_handle_input(ng, ng->inbuf);
      itmp = ng->inpos - (ctmp - ng->inbuf);
      memmove(ng->inbuf, ctmp, itmp);
      ng->inpos -= ctmp - ng->inbuf;
      ng->inbuf[ng->inpos] = '\0';
    }

  return network_io_setup(ng, CALLER_READ_CB);

 errout:     
  /* Shut down the connection, either it was broken or someone is messing with us */
  network_set_status(ng, DISCONNECTED, _("The remote player disconnected"));
  return network_io_setup(ng, CALLER_READ_CB);
}

static gboolean
network_handle_write(GIOChannel *source, GIOCondition cond, gpointer data)
{
  NetworkGame *ng = data;
  int n;

  if(ng->status == CONNECTING)
    {
      int errval;
      socklen_t optlen = sizeof(errval);
      if(getsockopt(ng->fd, SOL_SOCKET, SO_ERROR, &errval, &optlen))
	g_error("getsockopt failed!");

      if(errval)
	network_set_status(ng, DISCONNECTED, _("Error occurred during connect attempt."));
      else
	network_set_status(ng, CONNECTED, _("Connection succeeded, waiting for opponent"));
	
      return network_io_setup(ng, CALLER_WRITE_CB);
    }

  g_assert(ng->outbuf->len);
  g_assert(ng->status == CONNECTED);
  n = write(ng->fd, ng->outbuf->str, ng->outbuf->len);
  if(n <= 0)
    {
      network_set_status(ng, DISCONNECTED, _("Error occurred during write."));
    }
  else
    g_string_erase(ng->outbuf, 0, n);

  return network_io_setup(ng, CALLER_WRITE_CB);
}

static void
network_handle_input(NetworkGame *ng, char *buf)
{
  char *args;

  args = strchr(buf, ' ');

  if(args)
    {
      *args = '\0';
      args++;
    }

  if(!strcmp(buf, "set_peer"))
    {
      int me;

      if(ng->mycolor)
	return network_set_status(ng, DISCONNECTED, _("Invalid move attempted"));
	
      if(!args || sscanf(args, "%d", &me) != 1
	 || (me != WHITE_TURN && me != BLACK_TURN))
	return network_set_status(ng, DISCONNECTED, _("Invalid game data (set_peer)"));

      white_level_cb(NULL, "0");
      black_level_cb(NULL, "0");

      ng->mycolor = me;
      gui_message(_("Peer introduction complete"));
    }
  else if(!strcmp(buf, "move"))
    {
      int x, y, me;

      if(!args || sscanf(args, "%d %d %d", &x, &y, &me) != 3
	 || !me || me != (32-ng->mycolor)
	 || x >= 8 || y >= 8)
	return network_set_status(ng, DISCONNECTED, _("Invalid game data (move)"));

      move(x, y, me);
    }
  else if(!strcmp(buf, "new_game"))
    {
      gui_message(_("New game started"));

      if(!ng->sent_newgame)
	g_string_sprintfa(netgame->outbuf, "new_game\n");
      ng->sent_newgame = 0;

      whose_turn = BLACK_TURN;
      init_new_game();
    }
}

int
game_move (guint x, guint y, guint me)
{
  NetworkGame *ng = netgame;

  gnome_triggers_do("", NULL, "gnothello", "flip-piece", NULL);

  if(ng)
    {
      if(me != ng->mycolor)
	g_error("Impossible!");

      if(ng->status == CONNECTED)
	{
	  g_string_sprintfa(ng->outbuf, "move %u %u %u\n", x, y, me);
	  network_io_setup(ng, CALLER_OTHER);
	}
    }

  return move(x, y, me);
}

int
network_allow (void)
{
  if(netgame && netgame->mycolor)
    return whose_turn == netgame->mycolor;

  return !netgame;
}

static void
network_connect (void)
{
  int x;
  struct addrinfo *res = NULL, hints;

  g_string_truncate(netgame->outbuf, 0);
  netgame->inpos = 0;

  memset(&hints, 0, sizeof(hints));
  hints.ai_socktype = SOCK_STREAM;
  x = getaddrinfo(game_server, GAME_PORT, &hints, &res);
  if(x)
    return network_set_status(netgame, DISCONNECTED, gai_strerror(x));

  if(netgame->status != DISCONNECTED)
    {
      network_set_status(netgame, DISCONNECTED, _("Cleaning up connection"));
      network_io_setup(netgame, CALLER_OTHER);
    }

  netgame->fd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
  g_assert(netgame->fd >= 0);
  fcntl(netgame->fd, F_SETFL, O_NONBLOCK);
  netgame->fd_gioc = g_io_channel_unix_new(netgame->fd);
  x = connect(netgame->fd, res->ai_addr, res->ai_addrlen);
  if(x)
    {
      if(errno == EINPROGRESS)
	network_set_status(netgame, CONNECTING, _("Connection in progress..."));
      else
	{
	  perror("gnothello");
	  network_set_status(netgame, DISCONNECTED, _("Connection failed"));
	}
    }
  else
    network_set_status(netgame, CONNECTED, _("Connection succeeded, waiting for opponent"));

  network_io_setup(netgame, CALLER_OTHER);

  freeaddrinfo(res);
}

void
network_new(void)
{
  network_start();

  if(!game_server)
    return network_set_status(netgame, DISCONNECTED, _("No game server defined"));

  if(netgame->status != CONNECTED)
    network_connect();

  clear_board();
 
  g_string_sprintfa(netgame->outbuf, "new_game\n");
  netgame->sent_newgame = 1;

  network_io_setup(netgame, CALLER_OTHER);
}
