#include <config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gnome.h>
#include <orb/orbit.h>
#include "gnothello-game.h"
#include "othello.h"
#include "gnothello.h"
#include "network.h"

#ifdef HAVE_ORBIT

/* Shared with gnothello.c */
char *ior = NULL;

/* Globals */
CORBA_Environment  ev;
PortableServer_POA poa;
CORBA_ORB orb;

Gnothello gnothello_server = CORBA_OBJECT_NIL;
Gnothello gnothello_peer = CORBA_OBJECT_NIL;

PortableServer_ServantBase__epv base_epv = {
  NULL,
  NULL,
  NULL
};


static void
server_set_peer (PortableServer_Servant servant, CORBA_Object peer, CORBA_Environment *e)
{
	gnothello_peer = CORBA_Object_duplicate (peer, &ev);

	black_level_cb (NULL, "0");
	white_level_cb (NULL, "0");
	whose_turn = BLACK_TURN;
	init_new_game();
}

static CORBA_long
server_move(PortableServer_Servant servant, CORBA_long x, CORBA_long y, CORBA_long me, CORBA_Environment *ev)
{
	return move (x, y, me);
}

static void
server_new_game(PortableServer_Servant servant, CORBA_Environment *ev)
{
	init_new_game ();
}

POA_Gnothello__epv  gnothello_epv = {
	NULL,			/* _private */
	server_set_peer,
	server_move,
	server_new_game
};

POA_Gnothello__vepv poa_gnothello_vepv    = { &base_epv, &gnothello_epv };
POA_Gnothello       poa_gnothello_servant = { NULL, &poa_gnothello_vepv };

#define ID "IDL:www.gnome.org:Gnothello:1.0"
PortableServer_ObjectId objid = { 0, sizeof (ID), ID };

Gnothello
init_server (void)
{
	CORBA_exception_init(&ev);

	POA_Gnothello__init (&poa_gnothello_servant, &ev);
	if (ev._major != CORBA_NO_EXCEPTION){
		printf ("Can not initialize gnothello server\n");
		exit (1);
	}

	poa = (PortableServer_POA)CORBA_ORB_resolve_initial_references(orb, "RootPOA", &ev);
	PortableServer_POAManager_activate (
		PortableServer_POA__get_the_POAManager (poa, &ev), &ev);

	/* Activate the object */
	PortableServer_POA_activate_object_with_id(
		poa, &objid, &poa_gnothello_servant, &ev);

	/* Get a reference to the object */
	gnothello_server = PortableServer_POA_servant_to_reference(
		poa, &poa_gnothello_servant, &ev);

	if (!gnothello_server){
		printf ("Cannot get objref\n");
		exit (1);
	}

	return gnothello_server;
}

extern void
network_init (void)
{
	static int inited;

	if (inited)
		return;

	inited = 1;
	
	init_server ();
	printf ("%s\n",
		CORBA_ORB_object_to_string (orb, gnothello_server, &ev));
	fflush (stdout);
	
	if (ior){
		/* This means, I am a client */
		
		gnothello_peer = CORBA_ORB_string_to_object (orb, ior, &ev);

		Gnothello_set_peer (gnothello_peer, gnothello_server, &ev);
		whose_turn = BLACK_TURN;
		black_level_cb (NULL, "0");
		white_level_cb (NULL, "0");
		init_new_game ();
	}
}
       
extern gint
game_move (guint x, guint y, guint me)
{
        gnome_triggers_do("", NULL, "gnothello", "flip-piece", NULL);
	if (ior){
		if (me == BLACK_TURN){
			if (gnothello_peer)
				Gnothello_move (gnothello_peer, x, y, me, &ev);
			return move (x, y, me);
		} else
			g_warning ("impossible\n");
	} else {
		if (me == BLACK_TURN)
			return move (x, y, me);
		else {
			if (gnothello_peer)
				Gnothello_move (gnothello_peer, x, y, me, &ev);
			return move (x, y, me);
		}
	}
	
	return 0;
}

extern int
network_allow (void)
{
	if (ior){
		if (whose_turn == BLACK_TURN)
			return TRUE;
		else
			return FALSE;
	} else {
		return TRUE;
	}
}

extern void
network_new (void)
{
	if (gnothello_peer)
		Gnothello_new_game (gnothello_peer, &ev);
}

#endif

