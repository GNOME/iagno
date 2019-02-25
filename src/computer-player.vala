/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This file is part of Iagno.
 *
 * Iagno is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Iagno is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Iagno. If not, see <http://www.gnu.org/licenses/>.
 */

private class ComputerPlayer : Object
{
    private struct PossibleMove
    {
        public uint8 x;
        public uint8 y;
        public uint8 n_tiles;

        private PossibleMove (uint8 x, uint8 y, uint8 n_tiles)
        {
            this.x = x;
            this.y = y;
            this.n_tiles = n_tiles;
        }
    }

    /* Big enough. Don't use int.MIN / int.MAX, because int.MIN ≠ - int.MAX */
    private const int POSITIVE_INFINITY =  10000;
    private const int NEGATIVE_INFINITY = -10000;

    /* Game being played */
    private Game game;

    /* Strength */
    private int difficulty_level;

    /* Value of owning each location */
    private const int [] heuristic =    // TODO make int [,]
    {
        65,  -3, 6, 4, 4, 6,  -3, 65,
        -3, -29, 3, 1, 1, 3, -29, -3,
         6,   3, 5, 3, 3, 5,   3,  6,
         4,   1, 3, 1, 1, 3,   1,  4,
         4,   1, 3, 1, 1, 3,   1,  4,
         6,   3, 5, 3, 3, 5,   3,  6,
        -3, -29, 3, 1, 1, 3, -29, -3,
        65,  -3, 6, 4, 4, 6,  -3, 65
    };

    /* Source ID of a pending move timeout */
    private uint pending_move_id = 0;

    /* Indicates the results of the AI's search should be discarded.
     * The mutex is only needed for its memory barrier. */
    private bool _move_pending;
    private RecMutex _move_pending_mutex;
    [CCode (notify = false)] private bool move_pending
    {
        get
        {
            _move_pending_mutex.lock ();
            bool result = _move_pending;
            _move_pending_mutex.unlock ();
            return result;
        }

        set
        {
            _move_pending_mutex.lock ();
            _move_pending = value;
            _move_pending_mutex.unlock ();
        }
    }

    internal ComputerPlayer (Game game, int difficulty_level = 1)
    {
        this.game = game;
        this.difficulty_level = difficulty_level;
    }

    private void complete_move (uint8 x, uint8 y)
    {
        if (game.place_tile (x, y) == 0)
        {
            critical ("Computer chose an invalid move: %d,%d\n%s", x, y, game.to_string ());
            assert_not_reached ();
        }
    }

    /* For tests only. */
    internal void move ()
    {
        uint8 x;
        uint8 y;

        run_search (out x, out y);
        complete_move (x, y);
    }

    internal async void move_async (double delay_seconds = 0.0)
    {
        Timer timer = new Timer ();
        uint8 x = 0; // garbage, should not be needed
        uint8 y = 0; // idem

        while (move_pending)
        {
            /* We were called while a previous search was in progress.
             * Wait for that to finish before continuing. */
            Timeout.add (200, move_async.callback);
            yield;
        }

        timer.start ();
        new Thread<void *> ("AI thread", () => {
            move_pending = true;
            run_search (out x, out y);
            move_async.callback ();
            return null;
        });
        yield;

        timer.stop ();

        if (!move_pending)
            return;

        if (timer.elapsed () < delay_seconds)
        {
            pending_move_id = Timeout.add ((uint) ((delay_seconds - timer.elapsed ()) * 1000), move_async.callback);
            yield;
        }

        pending_move_id = 0;
        move_pending = false;

        /* complete_move() needs to be called on the UI thread. */
        Idle.add (() => {
            complete_move (x, y);
            return Source.REMOVE;
        });
    }

    internal void cancel_move ()
    {
        if (!move_pending)
            return;

        /* If AI thread has finished and its move is queued, unqueue it. */
        if (pending_move_id != 0)
        {
            Source.remove (pending_move_id);
            pending_move_id = 0;
        }

        /* If AI thread is running, this tells move_async() to ignore its result.
         * If not, it's harmless, so it's safe to call cancel_move() on the human's turn. */
        move_pending = false;
    }

    /*\
    * * Minimax / Negamax / alpha-beta pruning
    \*/

    private void run_search (out uint8 x, out uint8 y)
        requires (game.current_player_can_move)
    {
        /* For the first/first two moves play randomly so the game is not always the same */
        if (game.n_tiles < game.initial_number_of_tiles + (game.size < 6 ? 2 : 4))
        {
            random_select (ref game, out x, out y);
            return;
        }

        x = 0;  // garbage
        y = 0;  // idem

        /* Choose a location to place by building the tree of possible moves and
         * using the minimax algorithm to pick the best branch with the chosen
         * strategy. */
        Game g = new Game.copy (game);
        int depth = difficulty_level * 2;
        /* The -1 is because the search sometimes returns NEGATIVE_INFINITY. */
        int a = NEGATIVE_INFINITY - 1;

        List<PossibleMove?> moves = new List<PossibleMove?> ();
        get_possible_moves_sorted (g, ref moves);

        /* Try each move using alpha-beta pruning to optimise finding the best branch */
        foreach (PossibleMove? move in moves)
        {
            if (move == null)
                assert_not_reached ();

            if (g.place_tile (((!) move).x, ((!) move).y, true) == 0)
            {
                critical ("Computer marked move (depth %d, %d,%d, %d flips) as valid, but is invalid when checking.\n%s", depth, ((!) move).x, ((!) move).y, ((!) move).n_tiles, g.to_string ());
                assert_not_reached ();
            }

            int a_new = -1 * search (ref g, depth, NEGATIVE_INFINITY, -a);
            if (a_new > a)
            {
                a = a_new;
                x = ((!) move).x;
                y = ((!) move).y;
            }

            g.undo ();
        }
    }

    private int search (ref Game g, int depth, int a, int b)
        requires (a <= b)
    {
        /* End of the game, return a near-infinite evaluation */
        if (g.is_complete)
            return g.n_current_tiles > g.n_opponent_tiles ? POSITIVE_INFINITY - g.n_opponent_tiles : NEGATIVE_INFINITY + g.n_current_tiles;

        /* Checking move_pending here is optional. It helps avoid a long unnecessary search
         * if the move has been cancelled, but is expensive because it requires taking a mutex. */
        if (!move_pending)
            return 0;

        /* End of the search, calculate how good a result this is. */
        if (depth == 0)
            return calculate_heuristic (ref g, ref difficulty_level);

        if (g.current_player_can_move)
        {
            List<PossibleMove?> moves = new List<PossibleMove?> ();
            get_possible_moves_sorted (g, ref moves);

            /* Try each move using alpha-beta pruning to optimise finding the best branch */
            foreach (PossibleMove? move in moves)
            {
                if (move == null)
                    assert_not_reached ();

                if (g.place_tile (((!) move).x, ((!) move).y) == 0)
                {
                    critical ("Computer marked move (depth %d, %d,%d, %d flips) as valid, but is invalid when checking.\n%s", depth, ((!) move).x, ((!) move).y, ((!) move).n_tiles, g.to_string ());
                    assert_not_reached ();
                }

                int a_new = -1 * search (ref g, depth - 1, -b, -a);
                if (a_new > a)
                    a = a_new;

                g.undo ();

                /* This branch has worse values, so ignore it */
                if (b <= a)
                    break;
            }
        }
        else
        {
            g.pass ();

            int a_new = -1 * search (ref g, depth - 1, -b, -a);
            if (a_new > a)
                a = a_new;

            g.undo ();
        }

        return a;
    }

    private static void get_possible_moves_sorted (Game g, ref List<PossibleMove?> moves)
    {
        for (uint8 x = 0; x < g.size; x++)
        {
            for (uint8 y = 0; y < g.size; y++)
            {
                uint8 n_tiles = g.place_tile (x, y, false);
                if (n_tiles == 0)
                    continue;

                PossibleMove move = PossibleMove (x, y, n_tiles);
                moves.insert_sorted (move, compare_move);
            }
        }
    }

    private static int compare_move (PossibleMove? a, PossibleMove? b)
    {
        if (a == null || b == null)
            assert_not_reached ();
        return ((!) b).n_tiles - ((!) a).n_tiles;
    }

    /*\
    * * AI
    \*/

    private static int calculate_heuristic (ref Game g, ref int difficulty_level)
    {
        int tile_difference = g.n_current_tiles - g.n_opponent_tiles;

        /* Try to lose */
        if (difficulty_level == 1)
            return -tile_difference;

        /* End of the game: just maximize the number of tokens */
        if (g.n_tiles >= 54)
            return tile_difference;

        /* Normal strategy: try to evaluate the position */
        return tile_difference + eval_heuristic (ref g) + around (ref g) ;
    }

    private static int eval_heuristic (ref Game g)
    {
        if (g.size != 8)     // TODO
            return 0;

        int count = 0;

        for (uint8 x = 0; x < g.size; x++)
        {
            for (uint8 y = 0; y < g.size; y++)
            {
                int h = heuristic [y * g.size + x];
                if (g.get_owner (x, y) != g.current_color)
                    h = -h;
                count += h;
            }
        }

        return count;
    }

    private static int around (ref Game g)
    {
        int count = 0;
        for (int8 x = 0; x < g.size; x++)
        {
            for (int8 y = 0; y < g.size; y++)
            {
                int a = 0;
                a -= is_empty (ref g, x + 1, y    );
                a -= is_empty (ref g, x + 1, y + 1);
                a -= is_empty (ref g, x,     y + 1);
                a -= is_empty (ref g, x - 1, y + 1);
                a -= is_empty (ref g, x - 1, y    );
                a -= is_empty (ref g, x - 1, y - 1);
                a -= is_empty (ref g, x,     y - 1);
                a -= is_empty (ref g, x + 1, y - 1);

                /* Two points for completely surrounded tiles */
                if (a == 0)
                    a = 2;

                count += g.get_owner (x, y) == g.current_color ? a : -a;
            }
        }
        return count;
    }

    private static int is_empty (ref Game g, int8 x, int8 y)
    {
        if (g.is_valid_location_signed (x, y) && g.get_owner (x, y) == Player.NONE)
            return 1;

        return 0;
    }

    /*\
    * * First random moves
    \*/

    private static void random_select (ref Game g, out uint8 move_x, out uint8 move_y)
    {
        List<uint8> moves = new List<uint8> ();
        for (uint8 x = 0; x < g.size; x++)
            for (uint8 y = 0; y < g.size; y++)
                if (g.can_place (x, y, g.current_color))
                    moves.append (x * g.size + y);

        int length = (int) moves.length ();
        if (length == 0)
            assert_not_reached ();

        uint8 i = (uint8) Random.int_range (0, length);
        uint8 xy = moves.nth_data (i);
        move_x = xy / g.size;
        move_y = xy % g.size;
    }
}
