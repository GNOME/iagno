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

    internal PossibleMove (uint8 x, uint8 y, uint8 n_tiles)
    {
        this.x = x;
        this.y = y;
        this.n_tiles = n_tiles;
    }
}

private class ComputerReversi : ComputerPlayer
{
    /* Game being played */
    private Game game;

    /* Big enough. Don't use int16.MIN / int16.MAX, because int16.MIN ≠ - int16.MAX */
    private const int16 POSITIVE_INFINITY           =  10000;
    private const int16 NEGATIVE_INFINITY           = -10000;
    private const int16 LESS_THAN_NEGATIVE_INFINITY = -10001;

    /* Strength */
    private uint8 difficulty_level;
    private uint8 initial_depth;

    internal ComputerReversi (Game game, uint8 difficulty_level = 1)
    {
        this.game = game;
        this.difficulty_level = difficulty_level;
        this.initial_depth = difficulty_level * 2;
        init_heuristic (game.size);
    }

    protected override void complete_move (uint8 x, uint8 y)
    {
        if (!game.place_tile (x, y))
        {
            critical (@"Computer chose an invalid move: $x,$y\n$game");

            /* Has been reached, once. So let's have a fallback. */
            uint8 new_x;
            uint8 new_y;
            random_select (game.current_state, out new_x, out new_y);
            if (!game.place_tile (new_x, new_y))
            {
                critical (@"Computer chose an invalid move for the second time: $new_x,$new_y\n$game");
                assert_not_reached ();
            }
        }
    }

    /*\
    * * Minimax / Negamax / alpha-beta pruning
    \*/

    protected override void run_search (out uint8 x, out uint8 y)
        requires (game.current_player_can_move)
    {
        /* For the first/first two moves play randomly so the game is not always the same */
        if (game.current_state.n_tiles < game.initial_number_of_tiles + (game.size < 6 ? 2 : 4))
        {
            random_select (game.current_state, out x, out y);
            return;
        }

        x = 0;  // garbage
        y = 0;  // idem

        /* Choose a location to place by building the tree of possible moves and
         * using the minimax algorithm to pick the best branch with the chosen
         * strategy. */
        GameState g = game.current_state;
        /* The search sometimes returns NEGATIVE_INFINITY. */
        int16 a = LESS_THAN_NEGATIVE_INFINITY;

        List<PossibleMove?> moves;
        g.get_possible_moves (out moves);
        moves.sort (compare_move);

        /* Try each move using alpha-beta pruning to optimise finding the best branch */
        foreach (PossibleMove? move in moves)
        {
            if (move == null)
                assert_not_reached ();

            GameState _g = new GameState.copy_and_move (g, ((!) move).x, ((!) move).y);

            int16 a_new = -1 * search (_g, initial_depth, NEGATIVE_INFINITY, -a);
            if (a_new > a)
            {
                a = a_new;
                x = ((!) move).x;
                y = ((!) move).y;
            }
        }
    }

    private int16 search (GameState g, uint8 depth, int16 a, int16 b)
        requires (a <= b)
    {
        /* End of the game, return a near-infinite evaluation */
        if (g.is_complete)
            return g.n_current_tiles > g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_opponent_tiles
                                                          : NEGATIVE_INFINITY + (int16) g.n_current_tiles;

        /* Checking move_pending here is optional. It helps avoid a long unnecessary search
         * if the move has been cancelled, but is expensive because it requires taking a mutex. */
        if (!move_pending)
            return 0;

        /* End of the search, calculate how good a result this is. */
        if (depth == 0)
            return calculate_heuristic (g, ref difficulty_level, ref heuristic);

        if (g.current_player_can_move)
        {
            List<PossibleMove?> moves;
            g.get_possible_moves (out moves);
            moves.sort (compare_move);

            /* Try each move using alpha-beta pruning to optimise finding the best branch */
            foreach (PossibleMove? move in moves)
            {
                if (move == null)
                    assert_not_reached ();

                GameState _g = new GameState.copy_and_move (g, ((!) move).x, ((!) move).y);

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
            GameState _g = new GameState.copy_and_pass (g);

            int16 a_new = -1 * search (_g, depth - 1, -b, -a);
            if (a_new > a)
                a = a_new;
        }

        return a;
    }

    private static int compare_move (PossibleMove? a, PossibleMove? b)
        requires (a != null)
        requires (b != null)
    {
        if (((!) a).n_tiles >= ((!) b).n_tiles)
            return -1;
        else
            return 1;
    }

    /*\
    * * AI
    \*/

    private static int16 calculate_heuristic (GameState g, ref uint8 difficulty_level, ref int16 [,] heuristic)
    {
        int16 tile_difference = (int16) g.n_current_tiles - (int16) g.n_opponent_tiles;

        /* Try to lose */
        if (difficulty_level == 1)
            return -tile_difference;

        /* End of the game: just maximize the number of tokens */
        if (g.n_tiles >= (g.size * g.size) - 10)
            return tile_difference;

        /* Normal strategy: try to evaluate the position */
        return tile_difference + eval_heuristic (g, ref heuristic);
    }

    private static int16 eval_heuristic (GameState g, ref int16 [,] heuristic)
    {
        uint8 size = g.size;
        int16 count = 0;
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                // heuristic
                int16 h = heuristic [x, y];
                if (!g.is_current_color (x, y))
                    h = -h;
                count += h;

                // around
                int16 a = (int16) g.get_empty_neighbors (x, y);
                if (a == 0) // completely surrounded
                    a = -2;
                count += g.is_current_color (x, y) ? -a : a;
            }
        }
        return count;
    }

    /*\
    * * First random moves
    \*/

    private static void random_select (GameState g, out uint8 move_x, out uint8 move_y)
    {
        List<uint8> moves = new List<uint8> ();
        uint8 size = g.size;
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                if (g.can_move (x, y))
                    moves.append (x * size + y);

        int length = (int) moves.length ();
        if (length <= 0)
            assert_not_reached ();

        uint8 i = (uint8) Random.int_range (0, length);
        uint8 xy = moves.nth_data (i);
        move_x = xy / size;
        move_y = xy % size;
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

    private void init_heuristic (uint8 size)
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
