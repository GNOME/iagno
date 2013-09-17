/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

private enum Strategy
{
    PERFECT,
    VICTORY,
    BEST
}

private struct PossibleMove
{
    int x;
    int y;
    int n_tiles;
}

public class ComputerPlayer
{
    /* Game being played */
    private Game game;

    /* Strength */
    private int level;

    /* Value of owning each location */
    private const int[] heuristic =
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

    public ComputerPlayer (Game game, int level)
    {
        this.game = game;
        this.level = level;
    }

    public void move ()
    {
        /* For the first two moves play randomly so the game is not always the same */
        if (game.n_tiles < 8)
        {
            int x, y;
            random_select (out x, out y);
            game.place_tile (x, y);
            return;
        }

        var depth = 7 - (3 - level) * 2;
        var tiles_remaining = 64 - game.n_tiles;

        /* Choose a strategy based on how close to the end we are.
         * At the end of the game try and maximise the number of tokens.
         * Near the end try and push for a win.
         * For the rest of the game try and maximise everything.
         * Note, for level 1 we default to the "PERFECT" strategy, which is not as
         * good as the "BEST" strategy, so as not to make the AI too difficult.
         */
        var strategy = (level == 1) ? Strategy.PERFECT : Strategy.BEST;
        if (tiles_remaining <= depth + 10)
            strategy = Strategy.PERFECT;
        else if (tiles_remaining <= depth + 12)
            strategy = Strategy.VICTORY;

        /* Choose a location to place by building the tree of possible moves and
         * using the minimax algorithm to pick the best branch with the chosen
         * strategy. */
        int x = 0, y = 0;
        search (new Game.copy (game), strategy, depth, int.MIN, int.MAX, 1, ref x, ref y);
        if (game.place_tile (x, y) == 0)
            warning ("Computer chose an invalid move: %d,%d", x, y);
    }

    private int search (Game g, Strategy strategy, int depth, int a, int b, int p, ref int move_x, ref int move_y)
    {
        /* If the end of the search depth or end of the game calculate how good a result this is */
        if (depth == 0 || g.is_complete)
            return calculate_heuristic (g, strategy);

        /* Find all possible moves and sort from most new tiles to least new tiles */
        List<PossibleMove?> moves = null;
        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                var n_tiles = g.place_tile (x, y);
                if (n_tiles > 0)
                {
                    var move = PossibleMove ();
                    move.x = x;
                    move.y = y;
                    //warning ("%d %d", x, y);
                    move.n_tiles = n_tiles;
                    moves.insert_sorted (move, compare_move);
                    g.undo ();
                }
            }
        }

        /* If no moves then pass */
        if (moves == null)
        {
            var move = PossibleMove ();
            move.x = 0;
            move.y = 0;
            move.n_tiles = 0;
            moves.append (move);
        }

        /* Try each move using alpha-beta pruning to optimise finding the best branch */
        foreach (var move in moves)
        {
            if (move.n_tiles == 0)
                g.pass ();
            else if (g.place_tile (move.x, move.y) == 0)
            {
                warning ("Computer marked move (depth %d, %d,%d, %d flips) as valid, but is invalid when checking", depth, move.x, move.y, move.n_tiles);
                continue;
            }

            /* If our move then maximise the result */
            if (p > 0)
            {
                int next_x_move = 0, next_y_move = 0;
                var a_new = search (g, strategy, depth - 1, a, b, -p, ref next_x_move, ref next_y_move);
                if (a_new > a)
                {
                    a = a_new;
                    move_x = move.x;
                    move_y = move.y;
                }
            }
            /* If enemy move then minimise the result */
            else
            {
                int next_x_move = 0, next_y_move = 0;
                var b_new = search (g, strategy, depth - 1, a, b, -p, ref next_x_move, ref next_y_move);
                if (b_new < b)
                {
                    b = b_new;
                    move_x = move.x;
                    move_y = move.y;
                }
            }

            g.undo ();

            /* This branch has worse values, so ignore it */
            if (b <= a)
                break;
        }

        if (p > 0)
            return a;
        else
            return b;
    }

    private static int compare_move (PossibleMove? a, PossibleMove? b)
    {
        return b.n_tiles - a.n_tiles;
    }

    /* Perhaps surprisingly, the *lower* the return value from this method,
     * the "better" the position. So callers want to minimize the result here
     * to find the best move.
     */
    private int calculate_heuristic (Game g, Strategy strategy)
    {
        var tile_difference = g.n_dark_tiles - g.n_light_tiles;
        if (g.current_color == Player.DARK)
            tile_difference = -tile_difference;

        switch (strategy)
        {
        /* Maximise the number of tokens */
        case Strategy.PERFECT:
            return tile_difference;

        /* Maximise a win over a loss */
        case Strategy.VICTORY:
            return tile_difference.clamp (-1, 1);

        /* Try to maximise a number of values */
        default:
            return tile_difference - around (g) - eval_heuristic (g);
        }
    }

    private static int eval_heuristic (Game g)
    {
        var count = 0;
        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                var h = heuristic[y * 8 + x];
                if (g.get_owner (x, y) != g.current_color)
                    h = -h;
                count += h;
            }
        }

        return count;
    }

    /* Attempts to assign a score based on the positions available to each
     * player. However, adding this value to the heuristic results in much
     * worse play by the computer, so it is currently unused. The idea may
     * be sound, and it could just be that too much weight is placed on this
     * value.
     */
    private static int around (Game g)
    {
        var count = 0;
        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                var a = 0;
                a += is_empty (g, x + 1, y);
                a += is_empty (g, x + 1, y + 1);
                a += is_empty (g, x, y + 1);
                a += is_empty (g, x - 1, y + 1);
                a += is_empty (g, x - 1, y);
                a += is_empty (g, x - 1, y - 1);
                a += is_empty (g, x, y - 1);
                a += is_empty (g, x + 1, y - 1);

                /* Two points for completely surrounded tiles */
                if (a == 0)
                    a = 2;

                if (g.get_owner (x, y) != g.current_color)
                    a = -a;
                count += a;
            }
        }

        return count;
    }

    private static int is_empty (Game g, int x, int y)
    {
        if (x < 0 || x >= 8 || y < 0 || y >= 8 || g.get_owner (x, y) != Player.NONE)
            return 0;

        return 1;
    }

    private void random_select (out int move_x, out int move_y)
    {
        List<int> moves = null;
        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                if (game.can_place (x, y))
                    moves.append (x * 8 + y);
            }
        }
        if (moves != null)
        {
            var i = Random.int_range (0, (int) moves.length ());
            var xy = moves.nth_data (i);
            move_x = xy / 8;
            move_y = xy % 8;
        }
        else
            move_x = move_y = 0;
    }
}
