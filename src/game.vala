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

public class Game : Object
{
    /* Tiles on the board */
    private Player[,] tiles;

    private int _size;
    [CCode (notify = false)] public int size
    {
        get { return _size; }
        private set { _size = value; }
    }

    /* Undoing */
    private int?[] undo_stack;
    private int history_index = -1;

    /* Color to move next; Dark always plays first;
     * should be dark if number_of_moves % 2 == 0 */
    [CCode (notify = false)] public Player current_color { get; private set; default = Player.DARK; }
    [CCode (notify = false)] public int number_of_moves { get; private set; default = 0; }

    /* Indicate who's the next player who can move */
    [CCode (notify = false)] public bool current_player_can_move { get; private set; default = true; }
    // there's a race for the final "counter" turn, and looks like notifying here helps, not sure why // TODO fix the race
    [CCode (notify = true)] public bool is_complete { get; private set; default = false; }

    /* Indicate that a player should move */
    public signal void turn_ended ();
    /* Indicate a square has changed */
    public signal void square_changed (int x, int y, Player new_color);

    /*\
    * * Number of tiles on the board
    \*/

    [CCode (notify = false)] public int initial_number_of_tiles { get; private set; }
    [CCode (notify = false)] public int n_tiles
    {
        get { return n_dark_tiles + n_light_tiles; }
    }

    private int _n_light_tiles = 2;
    [CCode (notify = false)] public int n_light_tiles
    {
        get { return _n_light_tiles; }
    }

    private int _n_dark_tiles = 2;
    [CCode (notify = false)] public int n_dark_tiles
    {
        get { return _n_dark_tiles; }
    }

    [CCode (notify = false)] public int n_current_tiles
    {
        get { return current_color == Player.LIGHT ? n_light_tiles : n_dark_tiles; }
        private set {
            if (current_color == Player.LIGHT)
                _n_light_tiles = value;
            else
                _n_dark_tiles = value;
        }
    }

    [CCode (notify = false)] public int n_opponent_tiles
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

    public Game (bool alternative_start = false, int tmp_size = 8)
        requires (tmp_size >= 4)
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

        if (size % 2 == 0)
        {
            /* Setup board with four tiles by default */
            initial_number_of_tiles = 4;
            tiles [size / 2 - 1, size / 2 - 1] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [size / 2 - 1, size / 2] = Player.DARK;
            tiles [size / 2, size / 2 - 1] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [size / 2, size / 2] = Player.LIGHT;
            n_current_tiles = 2;
            n_opponent_tiles = 2;
        }
        else
        {
            /* Logical starting position for odd board */
            initial_number_of_tiles = 7;
            tiles [(size - 1) / 2, (size - 1) / 2] = Player.DARK;
            tiles [(size + 1) / 2, (size - 3) / 2] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [(size - 3) / 2, (size + 1) / 2] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [(size - 1) / 2, (size - 3) / 2] = Player.LIGHT;
            tiles [(size - 3) / 2, (size - 1) / 2] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [(size + 1) / 2, (size - 1) / 2] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [(size - 1) / 2, (size + 1) / 2] = Player.LIGHT;
            n_current_tiles = 3;
            n_opponent_tiles = 4;
        }
    }

    public Game.from_strings (string[] setup, Player to_move, int tmp_size = 8)
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

    public bool can_place (int x, int y, Player color)
        requires (is_valid_location (x, y))
        requires (color != Player.NONE)
    {
        if (tiles[x, y] != Player.NONE)
            return false;

        if (can_flip_tiles (x, y, 1, 0, color) > 0) return true;
        if (can_flip_tiles (x, y, 1, 1, color) > 0) return true;
        if (can_flip_tiles (x, y, 0, 1, color) > 0) return true;
        if (can_flip_tiles (x, y, -1, 1, color) > 0) return true;
        if (can_flip_tiles (x, y, -1, 0, color) > 0) return true;
        if (can_flip_tiles (x, y, -1, -1, color) > 0) return true;
        if (can_flip_tiles (x, y, 0, -1, color) > 0) return true;
        if (can_flip_tiles (x, y, 1, -1, color) > 0) return true;
        return false;
    }

    /*\
    * * Actions (apart undo)
    \*/

    public int place_tile (int x, int y, bool apply = true)
        requires (is_valid_location (x, y))
    {
        if (tiles[x, y] != Player.NONE)
            return 0;

        var tiles_turned = 0;
        tiles_turned += flip_tiles (x, y, 1, 0, apply);
        tiles_turned += flip_tiles (x, y, 1, 1, apply);
        tiles_turned += flip_tiles (x, y, 0, 1, apply);
        tiles_turned += flip_tiles (x, y, -1, 1, apply);
        tiles_turned += flip_tiles (x, y, -1, 0, apply);
        tiles_turned += flip_tiles (x, y, -1, -1, apply);
        tiles_turned += flip_tiles (x, y, 0, -1, apply);
        tiles_turned += flip_tiles (x, y, 1, -1, apply);

        if (tiles_turned == 0)
            return 0;

        if (apply)
        {
            set_tile (x, y);
            end_of_turn ();
        }

        return tiles_turned;
    }

    public void pass ()
        requires (!current_player_can_move)
    {
        end_of_turn ();
    }

    private void end_of_turn ()
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        current_color = Player.flip_color (current_color);
        number_of_moves++;
        history_index++;
        undo_stack[history_index] = null;
        update_who_can_move ();
        turn_ended ();
    }

    private void update_who_can_move ()
    {
        var enemy = Player.flip_color (current_color);
        var opponent_can_move = false;
        for (var x = 0; x < size; x++)
        {
            for (var y = 0; y < size; y++)
            {
                if (can_place (x, y, current_color))
                {
                    current_player_can_move = true;
                    return;
                }
                if (can_place (x, y, enemy))
                    opponent_can_move = true;
            }
        }
        current_player_can_move = false;
        if (!opponent_can_move)
            is_complete = true;
    }

    /*\
    * * Flipping tiles
    \*/

    private int flip_tiles (int x, int y, int x_step, int y_step, bool apply)
    {
        var enemy_count = can_flip_tiles (x, y, x_step, y_step, current_color);
        if (enemy_count == 0)
            return 0;

        if (apply)
        {
            for (var i = 1; i <= enemy_count; i++)
            {
                n_opponent_tiles--;
                set_tile (x + i * x_step, y + i * y_step);
            }
        }
        return enemy_count;
    }

    private int can_flip_tiles (int x, int y, int x_step, int y_step, Player color)
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

        return enemy_count;
    }

    private void set_tile (int x, int y)
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        n_current_tiles++;
        history_index++;
        undo_stack[history_index] = x + y * size;
        tiles[x, y] = current_color;
        square_changed (x, y, current_color);
    }

    /*\
    * * Undo
    \*/

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
        int? undo_item = undo_stack [history_index];
        if (undo_item != null)
        {
            /* last log entry is the placed tile, previous are flipped tiles */
            unset_tile ((!) undo_item, Player.NONE);
            undo_item = undo_stack [history_index];
            while (history_index > -1 && undo_item != null)
            {
                n_opponent_tiles++;
                unset_tile ((!) undo_item, enemy);
                if (history_index > -1)
                    undo_item = undo_stack [history_index];
                else
                    undo_item = null;
            }
        }

        if (count == 1)
        {
            is_complete = false;
            update_who_can_move ();
        }
        else
        {
            undo (count - 1);
        }
    }

    private void unset_tile (int tile_number, Player replacement_color)
    {
        n_current_tiles--;
        history_index--;
        var x = tile_number % size;
        var y = tile_number / size;
        tiles [x, y] = replacement_color;
        square_changed (x, y, replacement_color);
    }
}
