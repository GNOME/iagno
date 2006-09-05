/*
 * File: game.h
 * Author: Ismael Orenstein
 * Project: GGZ Reversi game module
 * Date: 09/17/2000
 * Desc: Description of game variables
 * $Id$
 *
 * Copyright (C) 2000 Ismael Orenstein.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#define BLACK -1
#define WHITE +1
#define EMPTY  0

/* REVERSI PROTOCOL VERSION 0.0.5
 *
 * The server handles everything, from the AI to the validity of moves
 *
 * RVR_STATE_INIT:
 *
 * First, it fetchs from the ggz_server how much seats there are, and how much are open/closed
 *
 * RVR_STATE_JOIN:
 *
 * Then, it waits until some player join . When he does, it sends:
 *
 * To Joining player:
 * 	RVR_MSG_SEAT (int)SEAT_NUM
 * To All Human players:
 * 	RVR_MSG_PLAYERS PLAYER_IDENTIFER[BLACK] PLAYER_IDENTIFIER[WHITE]
 *  where PLAYER_IDENTIFIER is:
 *  	(int)PLAYER_TYPE
 *  	if PLAYER_TYPE == GGZ_SEAT_OPEN
 *  		(str)PLAYER_NAME
 *
 * If the game was already happening, send the current game state to the new player
 *
 * 	RVR_MSG_SYNC (char)TURN BOARD_STATE
 * 	where TURN is the current turn, and:
 * 		BOARD_STATE = (char)POSITION * 64
 *
 * When all the open seats are filled, it enters playing state (state = RVR_STATE_PLAYING) and sends:
 *
 * To All Human players:
 * 	RVR_MSG_START
 *
 * RVR_STATE_PLAYING:
 *
 * If current player is AI:
 *
 * 	doMove(AI_MOVE());
 *
 * If it isn't AI, then it waits until client sends a RVR_REQ_MOVE
 *
 * When client sends a RVR_REQ_MOVE, the server must check if he is the current player and
 * if the move is valid. (The client should do it too, must the server must recheck to avoid cheating)
 * Then the server executes the move, and sends:
 * 
 * To All Human players:
 *
 *	RVR_MSG_MOVE (int)MOVE
 * 	where MOVE can be a array index (0-63) or one of the following error values:
 * 		RVR_ERROR_WRONGTURN
 * 			The player tried to move when it wasn't his turn
 * 		RVR_ERROR_INVALIDMOVE
 * 			The player tried a invalid move (Cheating sign!)
 * 		RVR_ERROR_CANTMOVE
 * 			The player can't move (no possible move)
 *
 * Then the server checks if the game is over (No more valid moves) and who has won. If the game is over,
 * it sends to All Human players:
 *
 * 	RVR_MSG_GAMEOVER (int)WINNER
 * 		where WINNER can be: BLACK, WHITE, EMPTY(draw)
 *
 * If some player left while the game was happening, it sends to all Human players:
 *
 * 	RVR_MSG_PLAYERS
 *
 * And it will wait until someone returns
 *
 * Any time, the server can receive a RVR_REQ_SYNC message from the client.
 *  If this is the case, it sents a RVR_MSG_SYNC to this player.
 *
 * The client (more information should be avaiable on the client's game.h file):
 * 
 * The client waits until a RVR_MSG_SEAT is sent to him, indicating what is his seat.
 * Then it waits until a RVR_MSG_PLAYERS, with the type/name of all the players
 * Then it waits until a RVR_MSG_START is sent.
 *
 * If a RVR_MSG_SYNC message is sent to him, it replaces the current game state with the one sent.
 * 
 * Then he enters playing mode.
 *
 * If it is his turn, The user selects a valid square and the client sends:
 * 	RVR_REQ_MOVE (int)MOVE
 * Then it waits until the server sends:
 * 	RVR_MSG_MOVE (int)MOVE
 * If move >= 0, do the move. Else, tell the player what was the error.
 * 
 * If it isn't his turn, it waits until the server sents a
 * 	RVR_MSG_MOVE (int)MOVE
 * If move >= 0, do the move. Else, tell (if necessary) what was the error.
 * 
 * After the move is done, change to the other turn.	
 *
 * If anyone has left the table, it will receive a RVR_MSG_PLAYERS from the server. Then it enters waiting mode again.
 *
 * When the game is over, it sends a RVR_MSG_GAMEOVER (int)winner to the players, and enters DONE state. If it receives enough RVR_REQ_AGAIN msgs, it sends a RVR_MSG_START to the players.
 *
 * Luckily that's all, this protocol is perfect and it shouldn't be modified anymore. Or so I hope. :) */

#include "ggzdmod.h"

// Reversi protocol
// The numbers aren't on order, because I used the same constants from TicTacToe - simplify testing
#define RVR_MSG_SEAT 0
#define RVR_MSG_PLAYERS 1
#define RVR_MSG_SYNC 6
#define RVR_REQ_SYNC 7
#define RVR_REQ_AGAIN 8
#define RVR_MSG_START 5
#define RVR_MSG_MOVE 2
#define RVR_MSG_GAMEOVER 3
#define RVR_REQ_MOVE 4

// States
#define RVR_STATE_INIT 0
#define RVR_STATE_WAIT 1
#define RVR_STATE_PLAYING 2
#define RVR_STATE_DONE 3

// Responses from server
#define RVR_SERVER_ERROR -1
#define RVR_SERVER_OK 0
#define RVR_SERVER_JOIN 1
#define RVR_SERVER_LEFT 2
#define RVR_SERVER_QUIT 3

// Errors
#define RVR_ERROR_INVALIDMOVE -1
#define RVR_ERROR_WRONGTURN -2
#define RVR_ERROR_CANTMOVE -3

// Takes cartesian coordinates and transform them into a array index
#define CART(X,Y) ( (Y-1)*8+(X-1) )

// Takes a index and transform it in cartesians coordinates
#define X(I) ( (I%8)+1 )
#define Y(I) ( (I/8)+1 )

// See what's the value at that place (like a 10x10 board)
#define GET(X,Y) ( (X==0 || Y==0 || X>8 || Y>8) ? EMPTY : rvr_game.board[CART(X,Y)] )

// Takes a seat and transform into a player code
#define SEAT2PLAYER(seat) ( (seat==0)?BLACK:WHITE )

// Takes a player code and transform into a seat index
#define PLAYER2SEAT(player) ( (player==BLACK)?0:1 )


struct rvr_game_t {
  /* GGZ data */
  GGZdMod *ggz;
  // Board
  char board[64];
  // Score
  int black;
  int white;
  // State
  char state;
  // Turn
  char turn;
};

// Intializes game variables
void game_init(GGZdMod * ggzdmod);
// Handle server messages
void game_handle_ggz_state(GGZdMod * ggz,
			   GGZdModEvent event, const void *data);
void game_handle_ggz_seat(GGZdMod * ggz,
			  GGZdModEvent event, const void *data);
// Handle player messages
void game_handle_player(GGZdMod * ggz, GGZdModEvent event, const void *data);
// Handle player move
int game_handle_move(int, int *);

// Send to the player what is his seat
int game_send_seat(int);
// Send to everyone who is playing
int game_send_players(void);
// Send game state to player
int game_send_sync(int);
// Sends the start message and start the game
int game_start(void);

// Play the game (if it is the AI)
void game_play(void);
// AI move
int game_bot_move(int);
// Check if move is valid (return a error code or the move)
int game_check_move(int, int);
// Check if a move is valid in this direction (return true or false)
int game_check_direction(int, int, int, int, int);
// Make the move, mark the board, increases the score and sends out the msg
int game_make_move(int, int);
// Mark the board at this direction (and increases the score)
int game_mark_board(int, int, int, int, int);
// Check if game is over
int game_check_over(void);
// Skip current player move
void game_skip_move(void);
// Game is over! Send gameover message and stop everything
void game_gameover(void);
// Play again?
int game_play_again(int);
// Update scores
void game_update_scores(void);
