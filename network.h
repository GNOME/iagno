#ifndef NETWORK_H
#define NETWORK_H

#ifdef HAVE_ORBIT

#include <orb/orbit.h>
#include <libgnorba/gnorba.h>

     extern char *ior;
     extern CORBA_ORB orb;
     extern gint game_move (guint, guint, guint);

     extern void network_init (void);
     extern int network_allow(void);
     extern void network_new (void);
#    define CORBA_def(x) x
#else
#    define network_new()
#    define game_move(a,b,c) move(a,b,c)
#    define CORBA_def(x) 
#    define network_init()
#    define network_allow() TRUE
#endif /* HAVE_ORBIT */

#endif

