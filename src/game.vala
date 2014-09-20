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

    /* undoing */
    private UndoItem? state = null;
    private UndoItem? previous_state = null;
    private int number_of_moves = 0;

    /* Color to move next */
    public Player current_color { get; private set; }

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

    private int _n_light_tiles = 0;
    public int n_light_tiles
    {
        get { return _n_light_tiles; }
    }

    private int _n_dark_tiles = 0;
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

        /* Dark plays first */
        current_color = Player.DARK;

        /* Setup board with four tiles by default */
        set_tile (size / 2 - 1, size / 2 - 1, Player.LIGHT, false);
        set_tile (size / 2 - 1, size / 2, Player.DARK, false);
        set_tile (size / 2, size / 2 - 1, Player.DARK, false);
        set_tile (size / 2, size / 2, Player.LIGHT, false);
        n_current_tiles = 2;
        n_opponent_tiles = 2;
    }

    public Game.from_strings (string[] setup, Player to_move, int tmp_size = 8)
        requires (tmp_size >= 4)
        requires (setup.length == tmp_size)
        /* warning, only testing the first string */
        requires (setup[0].length == tmp_size)
    {
        size = tmp_size;
        tiles = new Player[size, size];

        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
                tiles[x, y] = Player.from_char (setup[y][x]);

        current_color = to_move;

        warn_if_fail (string.joinv ("\n", setup).strip () == to_string ().strip ());
    }

    public Game.copy (Game game)
    {
        size = game.size;
        tiles = new Player[size, size];
        for (var x = 0; x < size; x++)
            for (var y = 0; y < size; y++)
                tiles[x, y] = game.tiles[x, y];
        number_of_moves = game.number_of_moves;
        current_color = game.current_color;
        n_current_tiles = game.n_current_tiles;
        n_opponent_tiles = game.n_opponent_tiles;
        /* don't copy history */
    }

    public string to_string ()
    {
        string s = "\n";

        for (int y = 0; y < size; y++)
        {
            for (int x = 0; x < size; x++)
                s += tiles[x, y].to_string ();
            s += "\n";
        }

        return s;
    }

    /*\
    * * Public information
    \*/

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
    {
        return place (x, y, color, false) > 0;
    }

    /*\
    * * Public actions (apart undo)
    \*/

    public int place_tile (int x, int y)
    {
        var tiles_turned = place (x, y, current_color, true);
        if (tiles_turned == 0)
            return 0;

        number_of_moves++;
        current_color = Player.flip_color (current_color);

        if (is_complete ())
            complete ();
        else
            move ();

        return tiles_turned;
    }

    public void pass ()
        requires (!can_move (current_color))
    {
        number_of_moves++;
        current_color = Player.flip_color (current_color);
        move ();
    }

    /*\
    * * Placing tiles
    \*/

    private bool is_valid_location (int x, int y)
    {
        return x >= 0 && x < size && y >= 0 && y < size;
    }

    private int place (int x, int y, Player color, bool apply)
    {
        /* Square needs to be empty */
        if (!is_valid_location (x, y) || tiles[x, y] != Player.NONE)
            return 0;

        var n_flips = 0;
        n_flips += flip_tiles (x, y, 1, 0, color, apply);
        n_flips += flip_tiles (x, y, 1, 1, color, apply);
        n_flips += flip_tiles (x, y, 0, 1, color, apply);
        n_flips += flip_tiles (x, y, -1, 1, color, apply);
        n_flips += flip_tiles (x, y, -1, 0, color, apply);
        n_flips += flip_tiles (x, y, -1, -1, color, apply);
        n_flips += flip_tiles (x, y, 0, -1, color, apply);
        n_flips += flip_tiles (x, y, 1, -1, color, apply);

        if (apply && n_flips > 0)
            set_tile (x, y, color, true);

        return n_flips;
    }

    private int flip_tiles (int x, int y, int x_step, int y_step, Player color, bool apply)
    {
        var enemy = Player.flip_color (color);

        /* Count number of enemy pieces we are beside */
        var enemy_count = 0;
        var xt = x + x_step;
        var yt = y + y_step;
        while (is_valid_location (xt, yt))
        {
            if (tiles[xt, yt] != enemy)
                break;
            enemy_count++;
            xt += x_step;
            yt += y_step;
        }

        /* Must be a line of enemy pieces then one of ours */
        if (enemy_count == 0 || !is_valid_location (xt, yt) || tiles[xt, yt] != color)
            return 0;

        /* Place this tile and flip the adjacent ones */
        if (apply)
            for (var i = 1; i <= enemy_count; i++)
                set_tile (x + i * x_step, y + i * y_step, color, true);

        return enemy_count;
    }

    private void set_tile (int x, int y, Player color, bool update_history)
    {
        if (update_history)
        {
            add_move (x, y, tiles[x, y]);
            n_current_tiles++;
            if (tiles[x, y] != Player.NONE)
                n_opponent_tiles--;
        }
        else
        {
            n_current_tiles--;
            if (color != Player.NONE)
                n_opponent_tiles++;
        }

        tiles[x, y] = color;
        square_changed (x, y);
    }

    /*\
    * * Undo
    \*/

    private struct UndoItem
    {
        public int number;
        public int x;
        public int y;
        public Player color;
        public weak UndoItem? next;
        public UndoItem? previous;
    }

    public bool can_undo (int count = 1)
        requires (count == 1 || count == 2)
    {
        return number_of_moves >= count;
    }

    public void undo (int count = 1)
        requires (count == 1 || count == 2)
        requires (number_of_moves >= count)
    {
        current_color = Player.flip_color (current_color);
        while (state != null && state.number == number_of_moves - 1)
        {
            set_tile (state.x, state.y, state.color, false);

            state = previous_state;
            previous_state = state == null ? null : state.previous;
        };
        number_of_moves--;

        if (count == 2)
            undo (1);
    }

    private void add_move (int x, int y, Player color)
    {
        previous_state = state == null ? null : state;
        state = UndoItem () { number = number_of_moves, x = x, y = y, color = color, next = null, previous = previous_state };
        if (previous_state != null)
            previous_state.next = state;
    }
}
