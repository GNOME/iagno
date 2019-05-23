/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2010-2013 Robert Ancell
   Copyright 2013-2014 Michael Catanzaro
   Copyright 2014-2019 Arnaud Bonatti

   GNOME Reversi is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME Reversi is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME Reversi.  If not, see <https://www.gnu.org/licenses/>.
*/

private struct PossibleMove
{
    public uint8 x;
    public uint8 y;

    public uint8 n_tiles;
    public uint8 n_tiles_n;
    public uint8 n_tiles_ne;
    public uint8 n_tiles_e;
    public uint8 n_tiles_se;
    public uint8 n_tiles_s;
    public uint8 n_tiles_so;
    public uint8 n_tiles_o;
    public uint8 n_tiles_no;

    internal PossibleMove (uint8 x, uint8 y)
    {
        this.x = x;
        this.y = y;
    }
}

private class ComputerReversiEasy : ComputerReversi
{
    internal ComputerReversiEasy (Game game)
    {
        Object (game: game, initial_depth: 2);
    }

    /*\
    * * minimax / negamax / alpha-beta pruning
    \*/

    protected override void sort_moves (ref SList<PossibleMove?> moves)
    {
        moves.sort (compare_move);
    }

    private static inline int compare_move (PossibleMove? a, PossibleMove? b)
     // requires (a != null)
     // requires (b != null)
    {
        if (((!) a).n_tiles >= ((!) b).n_tiles)
            return -1;
        else
            return 1;
    }

    /*\
    * * AI
    \*/

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        /* Try to lose */
        return (int16) g.n_opponent_tiles - (int16) g.n_current_tiles;
    }
}

private class ComputerReversiHard : ComputerReversi
{
    private uint8 end_start;

    construct
    {
        end_start = (size * size) - 10;
        init_heuristic (size, out heuristic);
    }

    internal ComputerReversiHard (Game game, uint8 difficulty_level)
    {
        Object (game: game, initial_depth: difficulty_level * 2);
    }

    /*\
    * * minimax / negamax / alpha-beta pruning
    \*/

    protected override void sort_moves (ref SList<PossibleMove?> moves)
    {
        moves.sort_with_data (compare_move);
    }

    private inline int compare_move (PossibleMove? a, PossibleMove? b)
     // requires (a != null)
     // requires (b != null)
    {
        if (((!) a).n_tiles >= ((!) b).n_tiles)
            return -1;
        else
            return 1;
    }

    /*\
    * * AI
    \*/

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        /* End of the game: just maximize the number of tokens */
        if (g.n_tiles >= end_start)
            return (int16) g.n_current_tiles - (int16) g.n_opponent_tiles;

        /* Normal strategy: try to evaluate the position */
        return (int16) g.n_current_tiles - (int16) g.n_opponent_tiles + eval_heuristic (g, ref heuristic);
    }

    private static inline int16 eval_heuristic (GameStateStruct g, ref int16 [,] heuristic)
    {
        uint8 size = g.size;
        int16 count = 0;
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                bool is_current_color = g.is_current_color (x, y);

                // heuristic
                int16 h = heuristic [x, y];
                if (!is_current_color)
                    h = -h;
                count += h;

                // around
                int16 a = (int16) g.get_empty_neighbors (x, y);
                if (a == 0) // completely surrounded
                    a = -2;
                count += is_current_color ? -a : a;
            }
        }
        return count;
    }

    /*\
    * * heuristic table
    \*/

    private int16 [,] heuristic;

    private const int16 [,] heuristic_8 =
    {
        { 65,  -3, 6, 4, 4, 6,  -3, 65 },
        { -3, -29, 3, 1, 1, 3, -29, -3 },
        {  6,   3, 5, 3, 3, 5,   3,  6 },
        {  4,   1, 3, 1, 1, 3,   1,  4 },
        {  4,   1, 3, 1, 1, 3,   1,  4 },
        {  6,   3, 5, 3, 3, 5,   3,  6 },
        { -3, -29, 3, 1, 1, 3, -29, -3 },
        { 65,  -3, 6, 4, 4, 6,  -3, 65 }
    };

    private static void init_heuristic (uint8 size, out int16 [,] heuristic)
        requires (size >= 4)
    {
        if (size == 8)
            heuristic = heuristic_8;
        else
            create_heuristic (size, out heuristic);
    }

    private static void create_heuristic (uint8 size, out int16 [,] heuristic)
        requires (size >= 4)
    {
        heuristic = new int16 [size, size];
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                heuristic [x, y] = 0;

        // corners
        uint8 tmp1 = size - 1;
        heuristic [0   , 0   ] = 65;
        heuristic [0   , tmp1] = 65;
        heuristic [tmp1, tmp1] = 65;
        heuristic [tmp1, 0   ] = 65;

        if (size >= 6)
        {
            // corners neighbors
            uint8 tmp2 = size - 2;
            heuristic [0   , 1   ] = -3;
            heuristic [0   , tmp2] = -3;
            heuristic [tmp1, 1   ] = -3;
            heuristic [tmp1, tmp2] = -3;
            heuristic [1   , 0   ] = -3;
            heuristic [1   , tmp1] = -3;
            heuristic [tmp2, 0   ] = -3;
            heuristic [tmp2, tmp1] = -3;

            // corners diagonal neighbors
            heuristic [1   , 1   ] = -29;
            heuristic [1   , tmp2] = -29;
            heuristic [tmp2, tmp2] = -29;
            heuristic [tmp2, 1   ] = -29;
        }
    }
}

private abstract class ComputerReversi : ComputerPlayer
{
    public Game  game           { private   get; protected construct; }
    public uint8 initial_depth  { private   get; protected construct; }

    public uint8 size           { protected get; private   construct; }
    public uint8 move_randomly  { protected get; private   construct; } // TODO getter should be private, but...

    /* do not forget int16.MIN ≠ - int16.MAX */
    private const int16 POSITIVE_INFINITY           =  32000;
    private const int16 NEGATIVE_INFINITY           = -32000;
    private const int16 LESS_THAN_NEGATIVE_INFINITY = -32001;

    construct
    {
        size = game.size;
        move_randomly = game.initial_number_of_tiles + (size < 6 ? 2 : 4);
    }

    /*\
    * * common methods
    \*/

    protected override void complete_move (PossibleMove chosen_move)
    {
        if (!game.place_tile (chosen_move.x, chosen_move.y))
        {
            critical (@"Computer chose an invalid move: $(chosen_move.x),$(chosen_move.y)\n$game");

            /* Has been reached, once. So let's have a fallback. */
            PossibleMove random_move;
            random_select (game.current_state.game_state_struct, out random_move);
            if (!game.place_tile (random_move.x, random_move.y))
            {
                critical (@"Computer chose an invalid move for the second time: $(random_move.x),$(random_move.y)\n$game");
                assert_not_reached ();
            }
        }
    }

    private static void random_select (GameStateStruct g, out PossibleMove random_move)
    {
        SList<PossibleMove?> moves;
        g.get_possible_moves (out moves);

     // int32 length = (int32) moves.length ();
     // if (length <= 0)
     //     assert_not_reached ();
     //
     // int32 i = Random.int_range (0, length);
     // unowned PossibleMove? move = moves.nth_data ((uint) i);
     //
     // if (move == null)
     //     assert_not_reached ();
     // random_move = (!) move;

        random_move = (!) moves.nth_data ((uint) Random.int_range (0, (int32) moves.length ()));
    }

    /*\
    * * minimax / negamax / alpha-beta pruning
    \*/

    protected override void run_search (out PossibleMove best_move)
     // requires (game.current_player_can_move)
    {
        /* Choose a location to place by building the tree of possible moves and
         * using the minimax algorithm to pick the best branch with the chosen
         * strategy. */
        GameStateStruct g = game.current_state.game_state_struct;

        /* For the first/first two moves play randomly so the game is not always the same */
        if (g.n_tiles < move_randomly)
        {
            random_select (g, out best_move);
            return;
        }

        best_move = PossibleMove (0, 0); // garbage

        /* The search sometimes returns NEGATIVE_INFINITY. */
        int16 a = LESS_THAN_NEGATIVE_INFINITY;

        SList<PossibleMove?> moves;
        game.get_possible_moves (out moves);    // like g.get_possible_moves, but pre-calculated
        sort_moves (ref moves);

        /* Try each move using alpha-beta pruning to optimise finding the best branch */
        foreach (unowned PossibleMove? move in moves)
        {
         // if (move == null)
         //     assert_not_reached ();

            GameStateStruct _g = GameStateStruct.copy_and_move (g, (!) move);

            int16 a_new = -1 * search (_g, initial_depth, NEGATIVE_INFINITY, -a);
            if (a_new > a)
            {
                a = a_new;
                best_move = (!) move;
            }

            /* Checking move_pending here is optional. It helps avoid a long unnecessary search
             * if the move has been cancelled, but is expensive because it requires taking a mutex. */
            if (!move_pending)
                return;
        }
    }

    private int16 search (GameStateStruct g, uint8 depth, int16 a, int16 b)
     // requires (a <= b)
    {
        /* End of the game, return a near-infinite evaluation */
        if (g.is_complete)
            return g.n_current_tiles > g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_opponent_tiles
                                                          : NEGATIVE_INFINITY + (int16) g.n_current_tiles;

        /* End of the search, calculate how good a result this is. */
        if (depth == 0)
            return calculate_heuristic (g);

        if (g.current_player_can_move)
        {
            SList<PossibleMove?> moves;
            g.get_possible_moves (out moves);
            sort_moves (ref moves);

            /* Try each move using alpha-beta pruning to optimise finding the best branch */
            foreach (unowned PossibleMove? move in moves)
            {
             // if (move == null)
             //     assert_not_reached ();

                GameStateStruct _g = GameStateStruct.copy_and_move (g, (!) move);

                int16 a_new = -1 * search (_g, depth - 1, -b, -a);
                if (a_new > a)
                    a = a_new;

                /* This branch has worse values, so ignore it */
                if (b <= a)
                    break;
            }
        }
        else // pass
        {
            GameStateStruct _g = GameStateStruct.copy_and_pass (g);

            int16 a_new = -1 * search (_g, depth - 1, -b, -a);
            if (a_new > a)
                a = a_new;
        }

        return a;
    }

    protected abstract int16 calculate_heuristic (GameStateStruct g);
    protected abstract void sort_moves (ref SList<PossibleMove?> moves);
}
