#ifndef NETWORK_H
#define NETWORK_H

extern char *game_server;
extern gint game_move (guint, guint, guint);

extern int network_allow(void);
extern void network_new (void);
extern void network_stop(void);

#endif

