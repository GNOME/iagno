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

// used in ComputerRevers{i,e}Hard
private const int16 [,] heuristic_8 =
{
    { 410,  23,  13,   8,   8,  13,  23, 410 },
    {  23, -75, -22, -51, -51, -22, -75,  23 },
    {  13, -22,  41,   3,   3,  41, -22,  13 },
    {   8, -51,   3, -87, -87,   3, -51,   8 },
    {   8, -51,   3, -87, -87,   3, -51,   8 },
    {  13, -22,  41,   3,   3,  41, -22,  13 },
    {  23, -75, -22, -51, -51, -22, -75,  23 },
    { 410,  23,  13,   8,   8,  13,  23, 410 }
};

private class ComputerReverseEasy : ComputerReversi
{
    internal ComputerReverseEasy (Game game)
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
        return ((!) a).n_tiles <= ((!) b).n_tiles ? -1 : 1;
    }

    /*\
    * * AI
    \*/

    protected override int16 end_of_game (GameStateStruct g)
    {
        return g.n_current_tiles < g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_current_tiles
                                                      : NEGATIVE_INFINITY + (int16) g.n_opponent_tiles;
    }

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        /* Try to lose */
        return (int16) g.n_current_tiles - (int16) g.n_opponent_tiles;
    }
}

private class ComputerReverseHard : ComputerReversi
{
    [CCode (notify = false)] public bool even_depth      { private get; protected construct; }
    [CCode (notify = false)] public bool fixed_heuristic { private get; protected construct; }

    construct
    {
        init_heuristic (size, fixed_heuristic, out heuristic);
    }

    internal ComputerReverseHard (Game game, uint8 initial_depth, bool fixed_heuristic = false)
    {
        Object (game            : game,
                even_depth      : initial_depth % 2 == 0,
                initial_depth   : initial_depth,
                fixed_heuristic : fixed_heuristic);
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
        return calculate_move_heuristic ((!) b) - calculate_move_heuristic ((!) a);
    }

    private inline int calculate_move_heuristic (PossibleMove move)
    {
        int comparator = 0;
        calculate_dir_heuristic (ref comparator, move.x, move.y,  0, -1, move.n_tiles_n );
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1, -1, move.n_tiles_ne);
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1,  0, move.n_tiles_e );
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1,  1, move.n_tiles_se);
        calculate_dir_heuristic (ref comparator, move.x, move.y,  0,  1, move.n_tiles_s );
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1,  1, move.n_tiles_so);
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1,  0, move.n_tiles_o );
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1, -1, move.n_tiles_no);
        return 2 * comparator + (int) heuristic [move.x, move.y] + 8 * (int) neighbor_tiles [move.x, move.y];
    }

    private inline void calculate_dir_heuristic (ref int comparator, uint8 x, uint8 y, int8 x_step, int8 y_step, uint8 count)
    {
        for (; count > 0; count--)
            comparator += (int) heuristic [(int8) x + ((int8) count * x_step),
                                           (int8) y + ((int8) count * y_step)];
    }

    /*\
    * * AI
    \*/

    protected override int16 end_of_game (GameStateStruct g)
    {
        return g.n_current_tiles < g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_current_tiles
                                                      : NEGATIVE_INFINITY + (int16) g.n_opponent_tiles;
    }

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        return eval_heuristic (g, ref heuristic, even_depth);
    }

    private static inline int16 eval_heuristic (GameStateStruct g, ref int16 [,] heuristic, bool even_depth)
    {
        uint8 size = g.size;
        int16 count = 0;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
            {
                int16 a = (int16) g.get_empty_neighbors (x, y);
                if (a == 0) // completely surrounded
                    a = 6;

                int16 tile_heuristic = heuristic [x, y] + 8 * a;
                if (g.is_empty_tile (x, y))
                {
                    if (even_depth)
                        count -= tile_heuristic / 2;
                    else
                        count += tile_heuristic / 2;
                }
                else if (g.is_current_color (x, y))
                    count += tile_heuristic;
                else
                    count -= tile_heuristic;
            }

        mainline_penalty (g, border_penalty, ref count, MainLine.TOP);
        mainline_penalty (g, border_penalty, ref count, MainLine.LEFT);
        mainline_penalty (g, border_penalty, ref count, MainLine.RIGHT);
        mainline_penalty (g, border_penalty, ref count, MainLine.BOTTOM);
        mainline_penalty (g, corner_penalty, ref count, MainLine.TOPLEFT);
        mainline_penalty (g, corner_penalty, ref count, MainLine.TOPRIGHT);

        return count;
    }

    private const int16 border_penalty = 86;
    private const int16 corner_penalty = 86;
    private static void mainline_penalty (GameStateStruct g, int16 penalty, ref int16 count, MainLine mainline_id)
    {
        Player [] mainline = g.get_mainline (mainline_id);
        if (mainline [1] == g.current_color
         && mainline [0] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [i] == g.current_color);
            if (i != g.size - 2)
            {
                count += penalty;
                if (mainline [i + 1] == g.current_color)
                    count += penalty;
            }
        }
        if (mainline [g.size - 2] == g.current_color
         && mainline [g.size - 1] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [g.size - 1 - i] == g.current_color);
            if (i != g.size - 2)
            {
                count += penalty;
                if (mainline [g.size - 2 - i] == g.current_color)
                    count += penalty;
            }
        }
    }

    /*\
    * * heuristic table
    \*/

    private int16 [,] heuristic;

    private static void init_heuristic (uint8 size, bool fixed_heuristic, out int16 [,] heuristic)
        requires (size >= 4)
    {
        int16 [,] _heuristic;

        if (size == 8)
            _heuristic = heuristic_8;
        else
            create_heuristic (size, out _heuristic);

        heuristic = new int16 [size, size];
        for (uint8 i = 0; i < size; i++)
            for (uint8 j = 0; j < size; j++)
                heuristic [i, j] = (int16) (-1.7 * (_heuristic [i, j] + 112));

        if (fixed_heuristic)
            return;

        /* that part is fun */
        for (uint8 i = 0; i < 5; i++)
        {
            heuristic [Random.int_range (0, (int32) size),
                       Random.int_range (0, (int32) size)]
                    += Random.boolean () ? -1 : 1;

            uint8 x = (uint8) Random.int_range (0, (int32) size);
            uint8 y = (uint8) Random.int_range (0, (int32) size);
            bool minus = Random.boolean ();
            heuristic [x, y]                       += minus ? -1 : 1;
            heuristic [size - 1 - x, size - 1 - y] += minus ? -1 : 1;
        }
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
        heuristic [0   , 0   ] = 110;
        heuristic [0   , tmp1] = 110;
        heuristic [tmp1, tmp1] = 110;
        heuristic [tmp1, 0   ] = 110;

        if (size >= 6)
        {
            // corners neighbors
            uint8 tmp2 = size - 2;
            heuristic [0   , 1   ] = 35;
            heuristic [0   , tmp2] = 35;
            heuristic [tmp1, 1   ] = 35;
            heuristic [tmp1, tmp2] = 35;
            heuristic [1   , 0   ] = 35;
            heuristic [1   , tmp1] = 35;
            heuristic [tmp2, 0   ] = 35;
            heuristic [tmp2, tmp1] = 35;

            // corners diagonal neighbors
            heuristic [1   , 1   ] = 15;
            heuristic [1   , tmp2] = 15;
            heuristic [tmp2, tmp2] = 15;
            heuristic [tmp2, 1   ] = 15;
        }
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
        return ((!) a).n_tiles >= ((!) b).n_tiles ? -1 : 1;
    }

    /*\
    * * AI
    \*/

    protected override int16 end_of_game (GameStateStruct g)
    {
        return g.n_current_tiles > g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_opponent_tiles
                                                      : NEGATIVE_INFINITY + (int16) g.n_current_tiles;
    }

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        /* Try to lose */
        return (int16) g.n_opponent_tiles - (int16) g.n_current_tiles;
    }
}

private class ComputerReversiHard : ComputerReversi
{
    [CCode (notify = false)] public bool even_depth      { private get; protected construct; }
    [CCode (notify = false)] public bool fixed_heuristic { private get; protected construct; }

    construct
    {
        init_heuristic (size, fixed_heuristic, out heuristic);
    }

    internal ComputerReversiHard (Game game, uint8 initial_depth, bool fixed_heuristic = false)
    {
        Object (game            : game,
                even_depth      : initial_depth % 2 == 0,
                initial_depth   : initial_depth,
                fixed_heuristic : fixed_heuristic);
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
        return calculate_move_heuristic ((!) b) - calculate_move_heuristic ((!) a);
    }

    private inline int calculate_move_heuristic (PossibleMove move)
    {
        int comparator = 0;
        calculate_dir_heuristic (ref comparator, move.x, move.y,  0, -1, move.n_tiles_n );
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1, -1, move.n_tiles_ne);
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1,  0, move.n_tiles_e );
        calculate_dir_heuristic (ref comparator, move.x, move.y,  1,  1, move.n_tiles_se);
        calculate_dir_heuristic (ref comparator, move.x, move.y,  0,  1, move.n_tiles_s );
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1,  1, move.n_tiles_so);
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1,  0, move.n_tiles_o );
        calculate_dir_heuristic (ref comparator, move.x, move.y, -1, -1, move.n_tiles_no);
        return 2 * comparator + (int) heuristic [move.x, move.y] - 8 * (int) neighbor_tiles [move.x, move.y];
    }

    private inline void calculate_dir_heuristic (ref int comparator, uint8 x, uint8 y, int8 x_step, int8 y_step, uint8 count)
    {
        for (; count > 0; count--)
            comparator += (int) heuristic [(int8) x + ((int8) count * x_step),
                                           (int8) y + ((int8) count * y_step)];
    }

    /*\
    * * AI
    \*/

    protected override int16 end_of_game (GameStateStruct g)
    {
        return g.n_current_tiles > g.n_opponent_tiles ? POSITIVE_INFINITY - (int16) g.n_opponent_tiles
                                                      : NEGATIVE_INFINITY + (int16) g.n_current_tiles;
    }

    protected override int16 calculate_heuristic (GameStateStruct g)
    {
        return eval_heuristic (g, ref heuristic, even_depth);
    }

    private static inline int16 eval_heuristic (GameStateStruct g, ref int16 [,] heuristic, bool even_depth)
    {
        uint8 size = g.size;
        int16 count = 0;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
            {
                int16 a = (int16) g.get_empty_neighbors (x, y);
                if (a == 0) // completely surrounded
                    a = -6;

                int16 tile_heuristic = heuristic [x, y] - 8 * a;
                if (g.is_empty_tile (x, y))
                {
                    if (even_depth)
                        count -= tile_heuristic / 2;
                    else
                        count += tile_heuristic / 2;
                }
                else if (g.is_current_color (x, y))
                    count += tile_heuristic;
                else
                    count -= tile_heuristic;
            }

        mainline_penalty (g, border_penalty, ref count, MainLine.TOP);
        mainline_penalty (g, border_penalty, ref count, MainLine.LEFT);
        mainline_penalty (g, border_penalty, ref count, MainLine.RIGHT);
        mainline_penalty (g, border_penalty, ref count, MainLine.BOTTOM);
        mainline_penalty (g, corner_penalty, ref count, MainLine.TOPLEFT);
        mainline_penalty (g, corner_penalty, ref count, MainLine.TOPRIGHT);

        return count;
    }

    private const int16 border_penalty = 206;
    private const int16 corner_penalty = 206;
    private static void mainline_penalty (GameStateStruct g, int16 penalty, ref int16 count, MainLine mainline_id)
    {
        Player [] mainline = g.get_mainline (mainline_id);
        if (mainline [1] == g.current_color
         && mainline [0] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [i] == g.current_color);
            if (i != g.size - 2)
            {
                count -= penalty;
                if (mainline [i + 1] == g.current_color)
                    count -= penalty;
            }
        }
        else if (mainline [1] == g.opponent_color
              && mainline [0] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [i] == g.opponent_color);
            if (i != g.size - 2)
            {
                count += penalty;
                if (mainline [i + 1] == g.opponent_color)
                    count += penalty;
            }
        }
        if (mainline [g.size - 2] == g.current_color
         && mainline [g.size - 1] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [g.size - 1 - i] == g.current_color);
            if (i != g.size - 2)
            {
                count -= penalty;
                if (mainline [g.size - 2 - i] == g.current_color)
                    count -= penalty;
            }
        }
        else if (mainline [g.size - 2] == g.opponent_color
              && mainline [g.size - 1] == Player.NONE)
        {
            uint8 i = 1;
            do { i++; if (i == g.size - 2) break; }
            while (mainline [g.size - 1 - i] == g.opponent_color);
            if (i != g.size - 2)
            {
                count += penalty;
                if (mainline [g.size - 2 - i] == g.opponent_color)
                    count += penalty;
            }
        }
    }

    /*\
    * * heuristic table
    \*/

    private int16 [,] heuristic;

    private static inline void init_heuristic (uint8 size, bool fixed_heuristic, out int16 [,] heuristic)
        requires (size >= 4)
    {
        if (size == 8)
            heuristic = heuristic_8;
        else
            create_heuristic (size, out heuristic);

        if (fixed_heuristic)
            return;

        /* that part is fun */
        for (uint8 i = 0; i < 5; i++)
        {
            heuristic [Random.int_range (0, (int32) size),
                       Random.int_range (0, (int32) size)]
                    += Random.boolean () ? -1 : 1;

            uint8 x = (uint8) Random.int_range (0, (int32) size);
            uint8 y = (uint8) Random.int_range (0, (int32) size);
            bool minus = Random.boolean ();
            heuristic [x, y]                       += minus ? -1 : 1;
            heuristic [size - 1 - x, size - 1 - y] += minus ? -1 : 1;
        }
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
        heuristic [0   , 0   ] = 110;
        heuristic [0   , tmp1] = 110;
        heuristic [tmp1, tmp1] = 110;
        heuristic [tmp1, 0   ] = 110;

        if (size >= 6)
        {
            // corners neighbors
            uint8 tmp2 = size - 2;
            heuristic [0   , 1   ] = 35;
            heuristic [0   , tmp2] = 35;
            heuristic [tmp1, 1   ] = 35;
            heuristic [tmp1, tmp2] = 35;
            heuristic [1   , 0   ] = 35;
            heuristic [1   , tmp1] = 35;
            heuristic [tmp2, 0   ] = 35;
            heuristic [tmp2, tmp1] = 35;

            // corners diagonal neighbors
            heuristic [1   , 1   ] = 15;
            heuristic [1   , tmp2] = 15;
            heuristic [tmp2, tmp2] = 15;
            heuristic [tmp2, 1   ] = 15;
        }
    }
}

private abstract class ComputerReversi : ComputerPlayer
{
    [CCode (notify = false)] public Game  game           { private   get; protected construct; }
    [CCode (notify = false)] public uint8 initial_depth  { private   get; protected construct; }

    [CCode (notify = false)] public uint8 size           { protected get; private   construct; }
    [CCode (notify = false)] public uint8 move_randomly  { protected get; private   construct; } // TODO getter should be private, but...

    /* do not forget int16.MIN ≠ - int16.MAX */
    protected const int16 POSITIVE_INFINITY           =  32000;
    protected const int16 NEGATIVE_INFINITY           = -32000;
    private   const int16 LESS_THAN_NEGATIVE_INFINITY = -32001;

    protected uint8 [,] neighbor_tiles;

    construct
    {
        size = game.size;
        move_randomly = game.initial_number_of_tiles + (size < 6 ? 2 : 4);
        neighbor_tiles = game.copy_neighbor_tiles ();
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
            if (size != 8 || game.reverse)
                random_select (g, out best_move);
            else
            {
                do
                {
                    random_select (g, out best_move);
                }
                while ((best_move.x == 1 || best_move.x == 6)
                    && (best_move.y == 1 || best_move.y == 6));
            }
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
        /* End of the game, return (usually) a near-infinite evaluation */
        if (g.is_complete)
            return end_of_game (g);

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
    protected abstract int16 end_of_game (GameStateStruct g);
    protected abstract void sort_moves (ref SList<PossibleMove?> moves);
}
