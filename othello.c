/*
 * othello.c - Othello support routines for iagno
 * written by Ian Peters <itp@gnu.org>
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
#include <gnome.h>

#include "othello.h"
#include "gnothello.h"

#define WHITE_TURN 31
#define BLACK_TURN 1

/*
guint heuristic[8][8] = {{512,4,128,256,256,128,4,512},
			 {4,2,8,16,16,8,2,4},
			 {128,8,64,32,32,64,8,128},
			 {256,16,32,2,2,32,16,256},
			 {256,16,32,2,2,32,16,256},
			 {128,8,64,32,32,64,8,128},
			 {4,2,8,16,16,8,2,4},
			 {512,4,128,256,256,128,4,512}};
*/

guint heuristic[8][8] = {{9,2,7,8,8,7,2,9},
			 {2,1,3,4,4,3,1,2},
			 {7,3,6,5,5,6,3,7},
			 {8,4,5,1,1,5,4,8},
			 {8,4,5,1,1,5,4,8},
			 {7,3,6,5,5,6,3,7},
			 {2,1,3,4,4,3,1,2},
			 {9,2,7,8,8,7,2,9}};

guint flip_final_id = 0;
gint flip_final;

extern guint black_computer_level;
extern guint white_computer_level;

extern gint animate;
extern gint animate_stagger;

extern guint whose_turn;
extern guint game_in_progress;

extern gint8 pixmaps[8][8];
extern gint8 board[8][8];
extern MoveHistory game[61];

extern gint8 move_count;

extern gint bcount;
extern gint wcount;

extern gint timer_valid;

extern GtkWidget *time_display;

extern guint tiles_to_flip;

/* Wrapper for is_valid_move_board, to maintain API for CORBA stuff */

gint is_valid_move(guint x, guint y, guint me)
{
	return is_valid_move_board(board, x, y, me);
}

/* Check if a given square is a valid move for one of the players */

gint is_valid_move_board(gint8 board[8][8], guint x, guint y, guint me)
{
	gint tmp_x, tmp_y;
	guint not_me;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

	if(board[x][y] != 0)
		return(FALSE);

	/* Check for flips going left */

	tmp_x = x - 1;
	while(tmp_x >= 0 && board[tmp_x][y] == not_me)
		tmp_x--;
	if(tmp_x >= 0 && board[tmp_x][y] == me && tmp_x != x - 1)
		return(TRUE);

	/* Check for flips going right */

	tmp_x = x + 1;
	while(tmp_x < 8 && board[tmp_x][y] == not_me)
		tmp_x++;
	if(tmp_x < 8 && board[tmp_x][y] == me && tmp_x != x + 1)
		return(TRUE);

	/* Check for flips going up */

	tmp_y = y - 1;
	while(tmp_y >= 0 && board[x][tmp_y] == not_me)
		tmp_y--;
	if(tmp_y >= 0 && board[x][tmp_y] == me && tmp_y != y - 1)
		return(TRUE);

	/* Check for flips going down */

	tmp_y = y + 1;
	while(tmp_y < 8 && board[x][tmp_y] == not_me)
		tmp_y++;
	if(tmp_y < 8 && board[x][tmp_y] == me && tmp_y != y + 1)
		return(TRUE);

	/* Check for flips going up/left */

	tmp_x = x - 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y--;
	}
	if(tmp_x >= 0 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		return(TRUE);

	/* Check for flips going up/right */

	tmp_x = x + 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y--;
	}
	if(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		return(TRUE);

	/* Check for flips going down/left */

	tmp_x = x - 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y++;
	}
	if(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		return(TRUE);

	/* Check for flips going down/right */

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

/* Wrapper for move_board, to maintain API for CORBA stuff */

gint move(guint x, guint y, guint me)
{
        int retval;

	retval = move_board(board, x, y, me, 1);

	check_valid_moves();
	check_computer_players();

	return retval;
}

gint move_board(gint8 board[8][8], guint x, guint y, guint me, gint real)
{
	gint tmp_x, tmp_y;
	guint not_me;
	gint adder = 0, adder_diff = 0;
	gint count = 1;

	/* Stuff to do if this is a ``real'' move */

	if(real) {

		/* Copy the old board and move info to the undo buffer */

		memcpy(game[move_count].board, board, sizeof(gint8) * 8 * 8);
		game[move_count].x = x;
		game[move_count].y = y;
		game[move_count].me = me;

		move_count++;

		if(whose_turn == WHITE_TURN) {
			whose_turn = BLACK_TURN;
			gui_message(_("Dark's move"));
			if(!white_computer_level) {
				gtk_clock_stop(GTK_CLOCK(time_display));
			}
		} else {
			whose_turn = WHITE_TURN;
			gui_message(_("Light's move"));
			if(!black_computer_level) {
				gtk_clock_stop(GTK_CLOCK(time_display));
			}
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

	/* Flip going left */

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

	/* Flip going right */

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

	/* Flip going up */

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

	/* Flip going down */

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

	/* Flip going up/left */

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

	/* Flip going up/right */

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

	/* Flip going down/left */

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

	/* Flip going down/right */

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

	/* More stuff for a ``real'' move */

	if(real) {

		/* Update the statusbar counters */

		if(me == BLACK_TURN) {
			bcount += count;
			wcount -= count - 1;
		} else {
			wcount += count;
			bcount -= count - 1;
		}

		gui_status();

		if(not_me == BLACK_TURN && !black_computer_level && timer_valid) {
			gtk_clock_start(GTK_CLOCK(time_display));
		}
		if(not_me == WHITE_TURN && !white_computer_level && timer_valid) {
			gtk_clock_start(GTK_CLOCK(time_display));
		}

		tiles_to_flip = 1;
	}

	return(FALSE);
}

gint computer_move_1(guint me)
{
	guint xs[32], ys[32];
	guint num_moves = 0;
	guint i, j;

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

	return(FALSE);
}

gint computer_move_3(guint me)
{
	guint i, j;
	guint best_x = 8, best_y = 8;
	gint best_move = -10000;
	gint tmp_move;
	gint8 tboard[8][8];

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

	if (best_move != -10000) {
		move(best_x, best_y, me);
	}

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

	tiles_to_flip = 1;

/*
	if(white_computer_level && !black_computer_level && (black_pieces > white_pieces) && timer_valid) {
		sprintf(foo, "w%d", white_computer_level);
		i = gnome_score_log(milliseconds_total/100000-black_pieces, foo, FALSE);
		gnome_scores_display(_("Gnothello"), "gnothello", foo, i);
	}

	if(black_computer_level && !white_computer_level && (white_pieces > black_pieces) && timer_valid) {
		sprintf(foo, "b%d", black_computer_level);
		i = gnome_score_log(milliseconds_total/100000-white_pieces, foo, FALSE);
		gnome_scores_display(_("Gnothello"), "gnothello", foo, i);
	}
*/

	return(FALSE);
}

gint check_valid_moves()
{
	guint i, j;
	guint white_moves = 0;
	guint black_moves = 0;

	if(!game_in_progress)
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
		gtk_clock_stop(GTK_CLOCK(time_display));
		white_moves = count_pieces(WHITE_TURN);
		black_moves = count_pieces(BLACK_TURN);
		if(white_moves > black_moves)
			gui_message(_("Light player wins!"));
		if(black_moves > white_moves)
			gui_message(_("Dark player wins!"));
		if(white_moves == black_moves)
			gui_message(_("The game was a draw."));
		whose_turn = 0;
		game_in_progress = 0;
		if (flip_final)
			flip_final_id = gtk_timeout_add(3000,
					flip_final_results, NULL);
		return(TRUE);
	}

	if(whose_turn == WHITE_TURN) {
		gui_message(_("Light must pass, Dark's move"));
		whose_turn = BLACK_TURN;
		if(white_computer_level ^ black_computer_level) {
			if(!black_computer_level && timer_valid)
				gtk_clock_start(GTK_CLOCK(time_display));
			else
				gtk_clock_stop(GTK_CLOCK(time_display));
		}
		return(TRUE);
	}

	if(whose_turn == BLACK_TURN) {
		gui_message(_("Dark must pass, Light's move"));
		whose_turn = WHITE_TURN;
		if(white_computer_level ^ black_computer_level) {
			if(!white_computer_level && timer_valid)
				gtk_clock_start(GTK_CLOCK(time_display));
			else
				gtk_clock_stop(GTK_CLOCK(time_display));
		}
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
/*			if(board[i][j] == not_me)
				score -= heuristic[i][j]; */
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
	gint heuristic_score;

	not_me = (me == WHITE_TURN) ? BLACK_TURN : WHITE_TURN;

/*	mobility_score = (32 - mobility(board, not_me) - move_count);
	mobility_score = (mobility_score > 0) ? mobility_score : 0; */

	heuristic_score = eval_heuristic(board, me);

	return(heuristic_score);
}
