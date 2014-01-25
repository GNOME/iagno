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

    public int width
    {
        get { return tiles.length[0]; }
    }

    public int height
    {
        get { return tiles.length[1]; }
    }

    /* Undo stack.  This is a record of all the tile changes since the start of the game
     * in the binary form ccxxxyyy where cc is the color (0-2), xxx is the x location (0-7)
     * and yyy is the y location (0-7).  Each set of changes is followed by the number of changes
     * preceeding.  This array is oversized, but big enough for the (impossible) worst case of
     * each move flipping 20 tiles. */
    private int undo_history[1344];
    private int undo_index = 0;

    /* Color to move next */
    public Player current_color { get; private set; }

    /* Indicate that a player should move */
    public signal void move ();

    /* Indicate a square has changed */
    public signal void square_changed (int x, int y);

    /* Indicate the game is complete */
    public signal void complete ();

    /* The number of tiles on the board */
    public int n_tiles
    {
        get { return n_light_tiles + n_dark_tiles; }
    }

    public int n_light_tiles
    {
        get { return count_tiles (Player.LIGHT); }
    }

    public int n_dark_tiles
    {
        get { return count_tiles (Player.DARK); }
    }

    public Game (int width = 8, int height = 8)
    {
        /* Setup board with four tiles by default */
        tiles = new Player[width, height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                tiles[x, y] = Player.NONE;
        set_tile (3, 3, Player.LIGHT, false);
        set_tile (3, 4, Player.DARK, false);
        set_tile (4, 3, Player.DARK, false);
        set_tile (4, 4, Player.LIGHT, false);

        /* Black plays first */
        current_color = Player.DARK;
    }

    public Game.from_strings (string[] setup, Player to_move, int width = 8, int height = 8)
        requires (setup.length == height)
        requires (setup[0].length == width)
    {
        tiles = new Player[width, height];

        for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++)
                tiles[x, y] = Player.from_char (setup[y][x]);

        current_color = to_move;

        warn_if_fail (string.joinv ("\n", setup).strip () == to_string ().strip ());
    }

    public Game.copy (Game game)
    {
        tiles = new Player[game.width, game.height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                tiles[x, y] = game.tiles[x, y];
        for (var i = 0; i < game.undo_index; i++)
            undo_history[i] = game.undo_history[i];
        undo_index = game.undo_index;
        current_color = game.current_color;
    }

    public Player get_owner (int x, int y)
    {
        if (is_valid_location (x, y))
            return tiles[x, y];
        else
            return Player.NONE;
    }

    public bool is_complete ()
        ensures (result || n_tiles < width * height)
    {
        return !can_move (Player.LIGHT) && !can_move (Player.DARK);
    }

    public bool can_move (Player color)
    {
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                if (can_place (x, y, color))
                    return true;
        return false;
    }

    public bool can_place (int x, int y, Player color)
    {
        return place (x, y, color, false) > 0;
    }

    public int place_tile (int x, int y)
    {
        var n_tiles = place (x, y, current_color, true);
        if (n_tiles == 0)
            return 0;

        current_color = Player.flip_color (current_color);

        if (is_complete ())
            complete ();
        else
            move ();

        return n_tiles;
    }

    public void pass ()
        requires (!can_move (current_color))
    {
        undo_history[undo_index] = 0;
        undo_index++;
        current_color = Player.flip_color (current_color);
        move ();
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

        /* Store the number of entries in the undo history */
        if (apply && n_flips > 0)
        {
            undo_history[undo_index] = n_flips + 1;
            undo_index++;
        }

        return n_flips;
    }

    public int count_tiles (Player color)
    {
        var count = 0;
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                if (tiles[x, y] == color)
                    count++;
        return count;
    }

    private bool is_valid_location (int x, int y)
    {
        return x >= 0 && x < width && y >= 0 && y < height;
    }

    private int flip_tiles (int x, int y, int x_step, int y_step, Player color, bool apply)
    {
        var enemy = Player.LIGHT;
        if (color == Player.LIGHT)
            enemy = Player.DARK;

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
            for (var i = 0; i <= enemy_count; i++)
                set_tile (x + i * x_step, y + i * y_step, color, true);

        return enemy_count;
    }

    public bool can_undo ()
    {
        return undo_index > 0;
    }

    public void undo (int count = 1)
        requires (count == 1 || count == 2)
    {
        if (!can_undo ())
            return;

        for (var i = 0; i < count; i++)
        {
            var n_changes = undo_history[undo_index - 1];
            undo_index--;

            /* Undo each tile change */
            for (var j = 0; j < n_changes; j++)
            {
                var n = undo_history[undo_index - 1];
                undo_index--;
                var c = (Player) (n >> 6);
                var xy = n & 0x3F;
                set_tile (xy % width, xy / width, c, false);
            }

            /* Previous player to move again */
            current_color = Player.flip_color (current_color);
        }
    }

    private void set_tile (int x, int y, Player color, bool update_history)
    {
        if (tiles[x, y] == color)
            return;

        /* Store the old color in the history */
        if (update_history)
        {
            undo_history[undo_index] = ((int) tiles[x, y] << 6) | (y * width + x);
            undo_index++;
        }

        tiles[x, y] = color;
        square_changed (x, y);
    }

    public string to_string ()
    {
        string s = "\n";

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
                s += tiles[x, y].to_string ();
            s += "\n";
        }

        return s;
    }

}
