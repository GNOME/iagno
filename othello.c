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

guint flip_final_id;
guint black_computer_busy = 0;
guint white_computer_busy = 0;

extern guint whose_turn;
extern guint new_game;

extern gint pixmaps[8][8];

extern gint board[8][8];

gint is_valid_move(guint x, guint y, guint me)
{
	gint tmp;
	gint tmp_x, tmp_y;
	guint valid = 0;
	guint not_me;

	if(me == WHITE_TURN)
		not_me = BLACK_TURN;
	else
		not_me = WHITE_TURN;

	if(board[x][y] != 0)
		return(FALSE);

	tmp = 0;
	tmp_x = x - 1;
	while(tmp_x >= 0 && board[tmp_x][y] == not_me) {
		tmp += heuristic[tmp_x][y];
		tmp_x--;
	}
	if(tmp_x >= 0 && board[tmp_x][y] == me && tmp_x != x - 1)
		valid += tmp;

	tmp = 0;
	tmp_x = x + 1;
	while(tmp_x < 8 && board[tmp_x][y] == not_me) {
		tmp += heuristic[tmp_x][y];
		tmp_x++;
	}
	if(tmp_x < 8 && board[tmp_x][y] == me && tmp_x != x + 1)
		valid += tmp;

	tmp = 0;
	tmp_y = y - 1;
	while(tmp_y >= 0 && board[x][tmp_y] == not_me) {
		tmp += heuristic[x][tmp_y];
		tmp_y--;
	}
	if(tmp_y >= 0 && board[x][tmp_y] == me && tmp_y != y - 1)
		valid += tmp;

	tmp = 0;
	tmp_y = y + 1;
	while(tmp_y < 8 && board[x][tmp_y] == not_me) {
		tmp += heuristic[x][tmp_y];
		tmp_y++;
	}
	if(tmp_y < 8 && board[x][tmp_y] == me && tmp_y != y + 1)
		valid += tmp;

	tmp = 0;
	tmp_x = x - 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp += heuristic[tmp_x][tmp_y];
		tmp_x--;
		tmp_y--;
	}
	if(tmp_x >= 0 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		valid += tmp;

	tmp = 0;
	tmp_x = x + 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp += heuristic[tmp_x][tmp_y];
		tmp_x++;
		tmp_y--;
	}
	if(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		valid += tmp;

	tmp = 0;
	tmp_x = x - 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp += heuristic[tmp_x][tmp_y];
		tmp_x--;
		tmp_y++;
	}
	if(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		valid += tmp;

	tmp = 0;
	tmp_x = x + 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp += heuristic[tmp_x][tmp_y];
		tmp_x++;
		tmp_y++;
	}
	if(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		valid += tmp;

	if(valid) {
		valid += heuristic[x][y];
		return(valid);
	}

	return(FALSE);
}

gint move(guint x, guint y, guint me)
{
	gint tmp_x, tmp_y;
	guint valid;
	guint not_me;
	gint adder = 0, adder_diff = 0;
	int animate;
	int animate_stagger;

	new_game = 0;

	animate = gnome_config_get_int("/gnothello/Preferences/animate=2");
	animate_stagger = gnome_config_get_int("/gnothello/Preferences/animstagger=0");

	if(me == WHITE_TURN) {
		not_me = BLACK_TURN;
		if(animate && animate_stagger)
			adder_diff = -PIXMAP_STAGGER_DELAY;
	} else {
		not_me = WHITE_TURN;
		if(animate && animate_stagger)
			adder_diff = PIXMAP_STAGGER_DELAY;
	}

	if(whose_turn == WHITE_TURN) {
		whose_turn = BLACK_TURN;
		gui_message(_("  Black's turn..."));
	} else {
		whose_turn = WHITE_TURN;
		gui_message(_("  White's turn..."));
	}

	board[x][y] = me;
	pixmaps[x][y] = me;

	gui_draw_pixmap(me, x, y);

	valid = 0;

	tmp_x = x - 1;
	while(tmp_x >= 0 && board[tmp_x][y] == not_me)
		tmp_x--;
	if(tmp_x >= 0 && board[tmp_x][y] == me && tmp_x != x - 1)
		valid++;
	if(valid) {
		tmp_x = x - 1;
		while(tmp_x >= 0 && board[tmp_x][y] == not_me) {
			board[tmp_x][y] = me;
			if(pixmaps[tmp_x][y] == not_me)
				pixmaps[tmp_x][y] += adder;
			adder += adder_diff;
			tmp_x--;
		}
	}

	valid = 0;

	tmp_x = x + 1;
	while(tmp_x < 8 && board[tmp_x][y] == not_me)
		tmp_x++;
	if(tmp_x < 8 && board[tmp_x][y] == me && tmp_x != x + 1)
		valid++;
	if(valid) {
		tmp_x = x + 1;
		while(tmp_x < 8 && board[tmp_x][y] == not_me) {
			board[tmp_x][y] = me;
			if(pixmaps[tmp_x][y] == not_me)
				pixmaps[tmp_x][y] += adder;
			adder += adder_diff;
			tmp_x++;
		}
	}

	valid = 0;

	tmp_y = y - 1;
	while(tmp_y >= 0 && board[x][tmp_y] == not_me)
		tmp_y--;
	if(tmp_y >= 0 && board[x][tmp_y] == me && tmp_y != y - 1)
		valid++;
	if(valid) {
		tmp_y = y - 1;
		while(tmp_y >= 0 && board[x][tmp_y] == not_me) {
			board[x][tmp_y] = me;
			if(pixmaps[x][tmp_y] == not_me)
				pixmaps[x][tmp_y] += adder;
			adder += adder_diff;
			tmp_y--;
		}
	}

	valid = 0;

	tmp_y = y + 1;
	while(tmp_y < 8 && board[x][tmp_y] == not_me)
		tmp_y++;
	if(tmp_y < 8 && board[x][tmp_y] == me && tmp_y != y + 1)
		valid++;
	if(valid) {
		tmp_y = y + 1;
		while(tmp_y < 8 && board[x][tmp_y] == not_me) {
			board[x][tmp_y] = me;
			if(pixmaps[x][tmp_y] == not_me)
				pixmaps[x][tmp_y] += adder;
			adder += adder_diff;
			tmp_y++;
		}
	}

	valid = 0;

	tmp_x = x - 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y--;
	}
	if(tmp_x >= 0 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		valid++;
	if(valid) {
		tmp_x = x - 1;
		tmp_y = y - 1;
		while(tmp_y >= 0 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if(pixmaps[tmp_x][tmp_y] == not_me)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x--;
			tmp_y--;
		}
	}

	valid = 0;

	tmp_x = x + 1;
	tmp_y = y - 1;
	while(tmp_y >= 0 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y--;
	}
	if(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		valid++;
	if(valid) {
		tmp_x = x + 1;
		tmp_y = y - 1;
		while(tmp_x < 8 && tmp_y >= 0 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if(pixmaps[tmp_x][tmp_y] == not_me)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x++;
			tmp_y--;
		}
	}

	valid = 0;

	tmp_x = x - 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x >= 0 && board[tmp_x][tmp_y] == not_me) {
		tmp_x--;
		tmp_y++;
	}
	if(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x - 1)
		valid++;
	if(valid) {
		tmp_x = x - 1;
		tmp_y = y + 1;
		while(tmp_x >= 0 && tmp_y < 8 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if(pixmaps[tmp_x][tmp_y] == not_me)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x--;
			tmp_y++;
		}
	}

	valid = 0;

	tmp_x = x + 1;
	tmp_y = y + 1;
	while(tmp_y < 8 && tmp_x < 8 && board[tmp_x][tmp_y] == not_me) {
		tmp_x++;
		tmp_y++;
	}
	if(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == me && tmp_x != x + 1)
		valid++;
	if(valid) {
		tmp_x = x + 1;
		tmp_y = y + 1;
		while(tmp_x < 8 && tmp_y < 8 && board[tmp_x][tmp_y] == not_me) {
			board[tmp_x][tmp_y] = me;
			if(pixmaps[tmp_x][tmp_y] == not_me)
				pixmaps[tmp_x][tmp_y] += adder;
			adder += adder_diff;
			tmp_x++;
			tmp_y++;
		}
	}

	if(valid)
		return(TRUE);

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

gint computer_move_3(guint me)
{
	guint i, j;
	guint best_x = 8, best_y = 8;
	guint best_move = 0;
	guint tmp_move;

	if(whose_turn != me)
		return(FALSE);

	for(i = 0; i < 8; i++)
		for(j = 0; j < 8; j++) {
			tmp_move = is_valid_move(i, j, me);
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

	animate_stagger = gnome_config_get_bool("/gnothello/Preferences/animstagger=0");

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
			gui_message(_("  White player wins!"));
		if(black_moves > white_moves)
			gui_message(_("  Black player wins!"));
		if(white_moves == black_moves)
			gui_message(_("  The game was a draw."));
		whose_turn = 0;
		new_game = 1;
		flip_final_id = gtk_timeout_add(3000, flip_final_results, NULL);
		return(TRUE);
	}

	if(whose_turn == WHITE_TURN) {
		gui_message(_("  White must pass...Black's turn..."));
		whose_turn = BLACK_TURN;
		return(TRUE);
	}

	if(whose_turn == BLACK_TURN) {
		gui_message(_("  Black must pass...White's turn..."));
		whose_turn = WHITE_TURN;
		return(TRUE);
	}

	return(TRUE);
}
