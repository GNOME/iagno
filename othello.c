/*
 * othello.c - Othello support routines for gnothello
 * written by Ian Peters <ipeters@acm.org>
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

#include <gnome.h>

#include "othello.h"
#include "gnothello.h"

#define WHITE_TURN 31
#define BLACK_TURN 1

guint heuristic[8][8] = {{512,4,128,256,256,128,4,512},
			 {4,2,8,16,16,8,2,4},
			 {128,8,64,32,32,64,8,128},
			 {256,16,32,2,2,32,16,256},
			 {256,16,32,2,2,32,16,256},
			 {128,8,64,32,32,64,8,128},
			 {4,2,8,16,16,8,2,4},
			 {512,4,128,256,256,128,4,512}};

/*
guint heuristic[8][8] = {{9,2,7,8,8,7,2,9},
			 {2,1,3,4,4,3,1,2},
			 {7,3,6,5,5,6,3,7},
			 {8,4,5,1,1,5,4,8},
			 {8,4,5,1,1,5,4,8},
			 {7,3,6,5,5,6,3,7},
			 {2,1,3,4,4,3,1,2},
			 {9,2,7,8,8,7,2,9}};
*/

guint flip_final_id;
guint black_computer_busy = 0;
guint white_computer_busy = 0;

extern guint whose_turn;
extern guint new_game;

extern gint8 pixmaps[8][8];
extern gint8 board[8][8];
extern MoveHistory game[61];

extern gint8 move_count;

extern gint bcount;
extern gint wcount;

// Wrapper for is_valid_move_board, to maintain API for CORBA stuff

gint is_valid_move(guint x, guint y, guint me)
{
	return is_valid_move_board(board, x, y, me);
}

// Check if a given square is a valid move for one of the players

gint is_valid_move_board(gint8 board[8][8], guint x, guint y, guint me)
{
	gint tmp_x, tmp_y;
	guint not_me;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

	if(board[x][y] != 0)
		return(FALSE);

	// Check for flips going left

	tmp_x = x - 1;
	while(tmp_x >= 0 && board[tmp_x][y] == not_me)
		tmp_x--;
	if(tmp_x >= 0 && board[tmp_x][y] == me && tmp_x != x - 1)
		return(TRUE);

	// Check for flips going right

	tmp_x = x + 1;
	while(tmp_x < 8 && board[tmp_x][y] == not_me)
		tmp_x++;
	if(tmp_x < 8 && board[tmp_x][y] == me && tmp_x != x + 1)
		return(TRUE);

	// Check for flips going up

	tmp_y = y - 1;
	while(tmp_y >= 0 && board[x][tmp_y] == not_me)
		tmp_y--;
	if(tmp_y >= 0 && board[x][tmp_y] == me && tmp_y != y - 1)
		return(TRUE);

	// Check for flips going down

	tmp_y = y + 1;
	while(tmp_y < 8 && board[x][tmp_y] == not_me)
		tmp_y++;
	if(tmp_y < 8 && board[x][tmp_y] == me && tmp_y != y + 1)
		return(TRUE);

	// Check for flips going up/left

	tmp_x = x - 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y--;
	}
	if(tmp_x >= 0 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		return(TRUE);

	// Check for flips going up/right

	tmp_x = x + 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y--;
	}
	if(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		return(TRUE);

	// Check for flips going down/left

	tmp_x = x - 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y++;
	}
	if(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		return(TRUE);

	// Check for flips going down/right

	tmp_x = x + 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y++;
	}
	if(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		return(TRUE);

	return(FALSE);
}

// Wrapper for move_board, to maintain API for CORBA stuff

gint move(guint x, guint y, guint me)
{
	return move_board(board, x, y, me, 1);
}

gint move_board(gint8 board[8][8], guint x, guint y, guint me, gint real)
{
	gint tmp_x, tmp_y;
	guint not_me;
	gint adder = 0, adder_diff = 0;
	int animate = 0;
	int animate_stagger = 0;
	gint count = 1;

	// Just in case we didn't know this, a game is in progress

	new_game = 0;

	// Stuff to do if this is a ``real'' move

	if(real) {

		// Copy the old board and move info to the undo buffer

		memcpy(game[move_count].board, board, sizeof(gint8) * 8 * 8);
		game[move_count].x = x;
		game[move_count].y = y;
		game[move_count].me = me;

		move_count++;

		animate = gnome_config_get_int("/gnothello/Preferences/animate=2");
		animate_stagger = gnome_config_get_int("/gnothello/Preferences/animstagger=0");

		if(whose_turn == WHITE_TURN) {
			whose_turn = BLACK_TURN;
			gui_message(_("Black's turn"));
		} else {
			whose_turn = WHITE_TURN;
			gui_message(_("White's turn"));
		}

		pixmaps[x][y] = me;
		gui_draw_pixmap(me, x, y);
	}

	if(me == WHITE_TURN) {
		not_me = BLACK_TURN;
		if(animate && animate_stagger)
			adder_diff = -PIXMAP_STAGGER_DELAY;
	} else {
		not_me = WHITE_TURN;
		if(animate && animate_stagger)
			adder_diff = PIXMAP_STAGGER_DELAY;
	}

	board[x][y] = me;

	// Flip going left

	adder = 0;

	tmp_x = x - 1;
	while(tmp_x >= 0 && board[tmp_x][y] == not_me)
		tmp_x--;
	if(tmp_x >= 0 && board[tmp_x][y] == me && tmp_x != x - 1) {
		tmp_x = x - 1;
		while(tmp_x >= 0 && board[tmp_x][y] == not_me) {
			board[tmp_x][y] = me;
			if((pixmaps[tmp_x][y] == not_me) && real)
				pixmaps[tmp_x][y] += adder;
			adder += adder_diff;
			tmp_x--;
			count++;
		}
	}

	// Flip going right

	adder = 0;

	tmp_x = x + 1;
	while(tmp_x < 8 && board[tmp_x][y] == not_me)
		tmp_x++;
	if(tmp_x < 8 && board[tmp_x][y] == me && tmp_x != x + 1) {
		tmp_x = x + 1;
		while(tmp_x < 8 && board[tmp_x][y] == not_me) {
			board[tmp_x][y] = me;
			if((pixmaps[tmp_x][y] == not_me) && real)
				pixmaps[tmp_x][y] += adder;
			adder += adder_diff;
			tmp_x++;
			count++;
		}
	}

	// Flip going up

	adder = 0;

	tmp_y = y - 1;
	while(tmp_y >= 0 && board[x][tmp_y] == not_me)
		tmp_y--;
	if(tmp_y >= 0 && board[x][tmp_y] == me && tmp_y != y - 1) {
		tmp_y = y - 1;
		while(tmp_y >= 0 && board[x][tmp_y] == not_me) {
			board[x][tmp_y] = me;
			if((pixmaps[x][tmp_y] == not_me) && real)
				pixmaps[x][tmp_y] += adder;
			adder += adder_diff;
			tmp_y--;
			count++;
		}
	}

	// Flip going down

	adder = 0;

	tmp_y = y + 1;
	while(tmp_y < 8 && board[x][tmp_y] == not_me)
		tmp_y++;
	if(tmp_y < 8 && board[x][tmp_y] == me && tmp_y != y + 1) {
		tmp_y = y + 1;
		while(tmp_y < 8 && board[x][tmp_y] == not_me) {
			board[x][tmp_y] = me;
			if((pixmaps[x][tmp_y] == not_me) && real)
				pixmaps[x][tmp_y] += adder;
			adder += adder_diff;
			tmp_y++;
			count++;
		}
	}

	// Flip going up/left

	adder = 0;

	tmp_x = x - 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y--;
	}
	if(tmp_x >= 0 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x - 1) {
		tmp_x = x - 1;
		tmp_y = y - 1;
		while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if((pixmaps[tmp_x][tmp_y] == not_me) && real)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x--;
			tmp_y--;
			count++;
		}
	}

	// Flip going up/right

	adder = 0;

	tmp_x = x + 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y--;
	}
	if(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x + 1) {
		tmp_x = x + 1;
		tmp_y = y - 1;
		while(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if((pixmaps[tmp_x][tmp_y] == not_me) && real)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x++;
			tmp_y--;
			count++;
		}
	}

	// Flip going down/left

	adder = 0;

	tmp_x = x - 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y++;
	}
	if(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x - 1) {
		tmp_x = x - 1;
		tmp_y = y + 1;
		while(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if((pixmaps[tmp_x][tmp_y] == not_me) && real)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x--;
			tmp_y++;
			count++;
		}
	}

	// Flip going down/right

	adder = 0;

	tmp_x = x + 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y++;
	}
	if(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x + 1) {
		tmp_x = x + 1;
		tmp_y = y + 1;
		while(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if((pixmaps[tmp_x][tmp_y] == not_me) && real)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x++;
			tmp_y++;
			count++;
		}
	}

	// More stuff for a ``real'' move

	if(real) {

		// Update the statusbar counters

		if(me == BLACK_TURN) {
			bcount += count;
			wcount -= count - 1;
		} else {
			wcount += count;
			bcount -= count - 1;
		}

		gui_status();

		// Check for end of game or pass situations

		check_valid_moves();
	}

	return(FALSE);
}

gint computer_move_1(guint me)
{
	guint xs[32], ys[32];
	guint num_moves = 0;
	guint i, j;

	if(whose_turn != me)
		return(FALSE);

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			if(is_valid_move(i, j, me)) {
				xs[num_moves] = i;
				ys[num_moves] = j;
				num_moves++;
			}

	if(num_moves) {
		i = (rand()>>3) % num_moves;
		move(xs[i], ys[i], me);
	}

	if(me == WHITE_TURN)
		white_computer_busy = 0;
	else
		black_computer_busy = 0;

	return(FALSE);
}

void minimax(gint8 board[8][8], gint* score, gint* x, gint* y, gint depth, guint me)
{
	gint best_score = -15000;
	gint i, j;
	gint xs[32], ys[32], num_moves = 0;
	gint8 tboard[8][8];
	gint the_score, the_x, the_y;
	gint best_x, best_y;
	guint not_me;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			if(is_valid_move_board(board, i, j, me)) {
				if(!depth)
					printf("%d, %d\n", i, j);
				xs[num_moves] = i;
				ys[num_moves] = j;
				num_moves++;
			}

	for(i = 0; i < num_moves; i++) {
		memcpy(tboard, board, sizeof(gint8) * 8 * 8);
		move_board(tboard, xs[i], ys[i], me, 0);
		if(depth == 4) {
			the_score = eval_board(board, me);
			the_x = xs[i];
			the_y = ys[i];
		} else {
			minimax(tboard, &the_score, &the_x, &the_y, depth + 1, not_me);
		}
		if(the_score > best_score) {
			best_score = the_score;
			best_x = the_x;
			best_y = the_y;
		}
	}

	*score = best_score;
	*x = best_x;
	*y = best_y;
}

gint computer_move_2(guint me)
{
	gint x, y, score;

	if(whose_turn != me)
		return(FALSE);

	minimax(board, &score, &x, &y, 0, me);

	printf("%d, %d\n", x, y);

	move(x, y, me);

	if(me == WHITE_TURN)
		white_computer_busy = 0;
	else
		black_computer_busy = 0;

	return(FALSE);
}

gint computer_move_3(guint me)
{
	guint i, j;
	guint best_x = 8, best_y = 8;
	gint best_move = -10000;
	gint tmp_move;
	gint8 tboard[8][8];

	if(whose_turn != me)
		return(FALSE);

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			if(is_valid_move(i, j, me)) {
				memcpy(tboard, board, sizeof(gint8) * 8 * 8);
				move_board(tboard, i, j, me, 0);
				tmp_move = eval_board(tboard, me);
				if(tmp_move == best_move && (rand()>>4) % 2) {
					best_x = i;
					best_y = j;
				}
				if(tmp_move > best_move) {
					best_move = tmp_move;
					best_x = i;
					best_y = j;
				}
			}

	if (best_move)
		move(best_x, best_y, me);

	if(me == WHITE_TURN)
		white_computer_busy = 0;
	else
		black_computer_busy = 0;

	return(FALSE);
}

gint count_pieces(gint me)
{
	guint tmp = 0;
	guint i, j;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			if(board[i][j] == me)
				tmp++;

	return(tmp);
}

gint flip_final_results()
{
	guint i;
	guint white_pieces;
	guint black_pieces;
	guint adder = 0;
	guint animate_stagger;

	animate_stagger = gnome_config_get_int("/gnothello/Preferences/animstagger=0");

	white_pieces = count_pieces(WHITE_TURN);
	black_pieces = count_pieces(BLACK_TURN);

	for(i = 0; i < black_pieces; i++) {
		board[i % 8][i / 8] = BLACK_TURN;
		if(pixmaps[i % 8][i / 8] < 1)
			pixmaps[i % 8][i / 8] = WHITE_TURN;
		if(pixmaps[i % 8][i / 8] == WHITE_TURN) {
			pixmaps[i % 8][i / 8] += adder;
			if(animate_stagger)
				adder++;
		}
	}
	for(i = black_pieces; i < 64 - white_pieces; i++) {
		board[i % 8][i / 8] = 0;
		pixmaps[i % 8][i / 8] = 100;
	}
	for(i = 64 - white_pieces; i < 64; i++) {
		board[i % 8][i / 8] = WHITE_TURN;
		if(pixmaps[i % 8][i / 8] == 0)
			pixmaps[i % 8][i / 8] = BLACK_TURN;
		if(pixmaps[i % 8][i / 8] == BLACK_TURN) {
			pixmaps[i % 8][i / 8] -= adder;
			if(animate_stagger)
				adder++;
		}
	}

	return(FALSE);
}

gint check_valid_moves()
{
	guint i, j;
	guint white_moves = 0;
	guint black_moves = 0;

	if(new_game)
		return(TRUE);

	switch(whose_turn) {
		case WHITE_TURN:
			for(i = 0; i < 8; i++)
				for(j = 0; j < 8; j++)
					if(is_valid_move(i, j, WHITE_TURN))
						white_moves++;
			if(white_moves)
				return(TRUE);
		break;
		case BLACK_TURN:
			for(i = 0; i < 8; i++)
				for(j = 0; j < 8; j++)
					if(is_valid_move(i, j, BLACK_TURN))
						black_moves++;
			if(black_moves)
				return(TRUE);
		break;
	}

	switch(whose_turn) {
		case WHITE_TURN:
			for(i = 0; i < 8; i++)
				for(j = 0; j < 8; j++)
					if(is_valid_move(i, j, BLACK_TURN))
						black_moves++;
		break;
		case BLACK_TURN:
			for(i = 0; i < 8; i++)
				for(j = 0; j < 8; j++)
					if(is_valid_move(i, j, WHITE_TURN))
						white_moves++;
		break;
	}

	if(!white_moves && !black_moves) {
		white_moves = count_pieces(WHITE_TURN);
		black_moves = count_pieces(BLACK_TURN);
		if(white_moves > black_moves)
			gui_message(_("White player wins!"));
		if(black_moves > white_moves)
			gui_message(_("Black player wins!"));
		if(white_moves == black_moves)
			gui_message(_("The game was a draw."));
		whose_turn = 0;
		new_game = 1;
		flip_final_id = gtk_timeout_add(3000, flip_final_results, NULL);
		return(TRUE);
	}

	if(whose_turn == WHITE_TURN) {
		gui_message(_("White must pass, Black's turn"));
		whose_turn = BLACK_TURN;
		return(TRUE);
	}

	if(whose_turn == BLACK_TURN) {
		gui_message(_("Black must pass, White's turn"));
		whose_turn = WHITE_TURN;
		return(TRUE);
	}

	return(TRUE);
}

gint eval_heuristic(gint8 board[8][8], guint me)
{
	guint i, j;
	guint not_me;
	gint score = 0;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			if(board[i][j] == me)
				score += heuristic[i][j];
			if(board[i][j] == not_me)
				score -= heuristic[i][j];
		}

	return(score);
}

gint mobility(gint8 board[8][8], guint me)
{
	guint i, j;
	guint moves = 0;

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++)
			if(is_valid_move_board(board, i, j, me))
				moves++;

	return(moves);
}

gint eval_board(gint8 board[8][8], guint me)
{
	guint not_me;
	gint mobility_score, heuristic_score;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

	mobility_score = (32 - mobility(board, not_me) - move_count);
	mobility_score = (mobility_score > 0) ? mobility_score : 0;

	heuristic_score = eval_heuristic(board, me);

	return(heuristic_score + mobility_score);
}
