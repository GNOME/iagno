#ifndef NETWORK_H
#define NETWORK_H

#ifdef HAVE_ORBIT
#include <orb/orbit.h>
     extern char *ior;
     extern CORBA_ORB orb;
     gint game_move (guint, guint, guint);

     void network_init (void);
#    define CORBA_def(x) x
#else
#    define network_new()
#    define game_move(a,b,c) move(a,b,c)
#    define CORBA_def(x) 
#    define network_init()
#    define network_allow() TRUE
#endif /* HAVE_ORBIT */

#endif

