#ifndef NETWORK_H
#define NETWORK_H

#define BLACK_TURN 1
#define WHITE_TURN 31

extern char *game_server;
extern gint game_move (guint, guint, guint);
extern void game_handle_input (NetworkGame *ng, char *buf);
extern int network_allow (void);
extern void network_new (GtkWidget *parent_window);
extern void network_start (void);
extern void network_stop (void);

#endif

