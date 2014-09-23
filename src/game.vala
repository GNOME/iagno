/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Game : Object
{
    /* Tiles on the board */
    private Player[,] tiles;

    private int _size;
    public int size
    {
        get { return _size; }
        private set { _size = value; }
    }

    /* Undoing */
    private int?[] undo_stack;
    private int history_index = -1;

    /* Color to move next; Dark always plays first;
     * should be dark if number_of_moves % 2 == 0 */
    public Player current_color { get; private set; default = Player.DARK; }
    private int number_of_moves = 0;

    /* Indicate that a player should move */
    public signal void move ();
    /* Indicate a square has changed */
    public signal void square_changed (int x, int y);
    /* Indicate the game is complete */
    public signal void complete ();

    /*\
    * * Number of tiles on the board
    \*/

    public int n_tiles
    {
        get { return n_dark_tiles + n_light_tiles; }
    }

    private int _n_light_tiles = 2;
    public int n_light_tiles
    {
        get { return _n_light_tiles; }
    }

    private int _n_dark_tiles = 2;
    public int n_dark_tiles
    {
        get { return _n_dark_tiles; }
    }

    public int n_current_tiles
    {
        get { return current_color == Player.LIGHT ? n_light_tiles : n_dark_tiles; }
        private set {
            if (current_color == Player.LIGHT)
                _n_light_tiles = value;
            else
                _n_dark_tiles = value;
        }
    }

    public int n_opponent_tiles
    {
        get { return current_color == Player.DARK ? n_light_tiles : n_dark_tiles; }
        private set {
            if (current_color == Player.DARK)
                _n_light_tiles = value;
            else
                _n_dark_tiles = value;
        }
    }

    /*\
    * * Creation / exporting
    \*/

    public Game (int tmp_size = 8)
        requires (tmp_size >= 4)
        requires (tmp_size % 2 == 0)
    {
        size = tmp_size;
        tiles = new Player[size, size];
        for (var x = 0; x < size; x++)
            for (var y = 0; y < size; y++)
                tiles[x, y] = Player.NONE;

        /* Stack is oversized: there is 60 turns, each adds one piece,
         * there's place for the end of turn and the opponent passing,
         * and you could flip max ((size - 2) * 3) tiles in one turn. */
        undo_stack = new int?[180 * (size - 1)]; /* (3 + (size - 2) * 3) * 60 */

        /* Setup board with four tiles by default */
        tiles [size / 2 - 1, size / 2 - 1] = Player.LIGHT;
        tiles [size / 2 - 1, size / 2] = Player.DARK;
        tiles [size / 2, size / 2 - 1] = Player.DARK;
        tiles [size / 2, size / 2] = Player.LIGHT;
    }

    public Game.from_strings (string[] setup, Player to_move, int tmp_size = 8)
        requires (tmp_size >= 4)
        requires (setup.length == tmp_size)
    {
        size = tmp_size;
        tiles = new Player[size, size];
        undo_stack = new int?[180 * (size - 1)];

        for (int y = 0; y < size; y++)
        {
            if (setup[y].length != size * 2)
                warn_if_reached ();
            for (int x = 0; x < size; x++)
                tiles[x, y] = Player.from_char (setup[y][x * 2 + 1]);
        }

        current_color = to_move;

        warn_if_fail (string.joinv ("\n", setup).strip () == to_string ().strip ());
    }

    public string to_string ()
    {
        string s = "\n";

        for (int y = 0; y < size; y++)
        {
            for (int x = 0; x < size; x++)
                s += " " + tiles[x, y].to_string ();
            s += "\n";
        }

        return s;
    }

    public Game.copy (Game game)
    {
        size = game.size;
        tiles = new Player[size, size];
        undo_stack = new int?[180 * (size - 1)];
        for (var x = 0; x < size; x++)
            for (var y = 0; y < size; y++)
                tiles[x, y] = game.tiles[x, y];
        number_of_moves = game.number_of_moves;
        current_color = game.current_color;
        n_current_tiles = game.n_current_tiles;
        n_opponent_tiles = game.n_opponent_tiles;
        /* warning: history not copied */
    }

    /*\
    * * Public information
    \*/

    public bool is_valid_location (int x, int y)
    {
        return x >= 0 && x < size && y >= 0 && y < size;
    }

    public Player get_owner (int x, int y)
        requires (is_valid_location (x, y))
    {
        return tiles[x, y];
    }

    public bool is_complete ()
        ensures (result || n_tiles < size * size)
    {
        return !can_move (null);
    }

    public bool can_move (Player? color)
        requires (color != Player.NONE)
    {
        for (var x = 0; x < size; x++)
            for (var y = 0; y < size; y++)
            {
                if (color != Player.DARK && can_place (x, y, Player.LIGHT))
                    return true;
                if (color != Player.LIGHT && can_place (x, y, Player.DARK))
                    return true;
            }
        return false;
    }

    public bool can_place (int x, int y, Player color)
        requires (is_valid_location (x, y))
        requires (color != Player.NONE)
    {
        if (tiles[x, y] != Player.NONE)
            return false;

        if (flip_tiles (x, y, 1, 0, color, false) > 0) return true;
        if (flip_tiles (x, y, 1, 1, color, false) > 0) return true;
        if (flip_tiles (x, y, 0, 1, color, false) > 0) return true;
        if (flip_tiles (x, y, -1, 1, color, false) > 0) return true;
        if (flip_tiles (x, y, -1, 0, color, false) > 0) return true;
        if (flip_tiles (x, y, -1, -1, color, false) > 0) return true;
        if (flip_tiles (x, y, 0, -1, color, false) > 0) return true;
        if (flip_tiles (x, y, 1, -1, color, false) > 0) return true;
        return false;
    }

    /*\
    * * Actions (apart undo)
    \*/

    public int place_tile (int x, int y)
        requires (is_valid_location (x, y))
    {
        if (tiles[x, y] != Player.NONE)
            return 0;

        var tiles_turned = 0;
        tiles_turned += flip_tiles (x, y, 1, 0, current_color, true);
        tiles_turned += flip_tiles (x, y, 1, 1, current_color, true);
        tiles_turned += flip_tiles (x, y, 0, 1, current_color, true);
        tiles_turned += flip_tiles (x, y, -1, 1, current_color, true);
        tiles_turned += flip_tiles (x, y, -1, 0, current_color, true);
        tiles_turned += flip_tiles (x, y, -1, -1, current_color, true);
        tiles_turned += flip_tiles (x, y, 0, -1, current_color, true);
        tiles_turned += flip_tiles (x, y, 1, -1, current_color, true);

        if (tiles_turned == 0)
            return 0;

        set_tile (x, y, current_color);
        end_of_turn ();

        if (is_complete ())
            complete ();
        else
            move ();

        return tiles_turned;
    }

    public void pass ()
        requires (!can_move (current_color))
    {
        end_of_turn ();

        move ();
    }

    private void end_of_turn ()
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        current_color = Player.flip_color (current_color);
        number_of_moves++;
        history_index++;
        undo_stack[history_index] = null;
    }

    /*\
    * * Flipping tiles
    \*/

    private int flip_tiles (int x, int y, int x_step, int y_step, Player color, bool apply)
    {
        var enemy = Player.flip_color (color);

        /* Count number of enemy pieces we are beside */
        var enemy_count = -1;
        var xt = x;
        var yt = y;
        do {
            enemy_count++;
            xt += x_step;
            yt += y_step;
        } while (is_valid_location (xt, yt) && tiles[xt, yt] == enemy);

        /* Must be a line of enemy pieces then one of ours */
        if (enemy_count == 0 || !is_valid_location (xt, yt) || tiles[xt, yt] != color)
            return 0;

        /* Flip the enemy's tiles */
        if (apply)
            for (var i = 1; i <= enemy_count; i++)
            {
                n_opponent_tiles--;
                /* TODO set_tile() always sets to current_color... */
                set_tile (x + i * x_step, y + i * y_step, color);
            }

        return enemy_count;
    }

    private void set_tile (int x, int y, Player color)
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        n_current_tiles++;
        history_index++;
        undo_stack[history_index] = x + y * size;
        tiles[x, y] = color;
        square_changed (x, y);
    }

    /*\
    * * Undo
    \*/

    public bool can_undo (int count = 1)
        requires (count == 1 || count == 2)
    {
        return number_of_moves >= count;
    }

    public void undo (int count = 1)
        requires (count == 1 || count == 2)
        requires (number_of_moves >= count)
        requires (history_index < undo_stack.length)
    {
        var enemy = current_color;
        current_color = Player.flip_color (current_color);
        number_of_moves--;

        /* pass the end of turn mark of the history */
        history_index--;

        /* if not pass */
        if (undo_stack[history_index] != null)
        {
            /* last log entry is the placed tile, previous are flipped tiles */
            unset_tile (undo_stack[history_index], Player.NONE);
            while (history_index > -1 && undo_stack[history_index] != null)
            {
                n_opponent_tiles++;
                unset_tile (undo_stack[history_index], enemy);
            }
        }

        if (count == 2)
            undo (1);
    }

    private void unset_tile (int tile_number, Player replacement_color)
    {
        n_current_tiles--;
        history_index--;
        var x = tile_number % size;
        var y = tile_number / size;
        tiles [x, y] = replacement_color;
        square_changed (x, y);
    }
}
