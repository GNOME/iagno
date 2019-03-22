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

private class GameState : Object
{
    [CCode (notify = false)] public Player current_color { internal get; protected construct set; default = Player.NONE; }

    internal string to_string ()
    {
        string s = "\n";

        for (uint8 y = 0; y < size; y++)
        {
            for (uint8 x = 0; x < size; x++)
                s += " " + tiles [x, y].to_string ();
            s += "\n";
        }

        return s;
    }

    /*\
    * * board
    \*/

    [CCode (notify = false)] public uint8 size { internal get; protected construct; default = 8; }

    protected Player [,] tiles;

    construct
    {
        tiles = new Player [size, size];
    }

    internal GameState.copy_simplify (Game game)
    {
        Object (size: game.size, current_color: game.current_color);

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                tiles [x, y] = game.tiles [x, y];

        current_player_can_move = game.current_player_can_move;
        is_complete = game.is_complete;
        n_current_tiles = game.n_current_tiles;
        n_opponent_tiles = game.n_opponent_tiles;
    }

    internal GameState.copy_and_pass (GameState game)
    {
        Object (size: game.size, current_color: Player.flip_color (game.current_color));

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                tiles [x, y] = game.tiles [x, y];

        n_current_tiles = game.n_opponent_tiles;
        n_opponent_tiles = game.n_current_tiles;

        // we already know all that, it is just for checking
        update_who_can_move ();
        if (!current_player_can_move || is_complete)
            assert_not_reached ();
    }

    internal GameState.copy_and_move (GameState game, uint8 move_x, uint8 move_y)
    {
        Player move_color = game.current_color;
        Object (size: game.size, current_color: Player.flip_color (move_color));

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                tiles [x, y] = game.tiles [x, y];

        n_current_tiles = game.n_opponent_tiles;
        n_opponent_tiles = game.n_current_tiles;

        if (_place_tile (move_x, move_y, move_color, /* apply move */ true) == 0)
        {
            critical ("Computer marked move (%d, %d) as valid, but is invalid when checking.\n%s", move_x, move_y, to_string ());
            assert_not_reached ();
        }

        update_who_can_move ();
    }

    /*\
    * * number of tiles on the board
    \*/

    [CCode (notify = false)] internal uint8 n_tiles
    {
        internal get { return n_dark_tiles + n_light_tiles; }
    }

    private uint8 _n_light_tiles = 2;
    [CCode (notify = false)] internal uint8 n_light_tiles
    {
        internal get { return _n_light_tiles; }
    }

    private uint8 _n_dark_tiles = 2;
    [CCode (notify = false)] internal uint8 n_dark_tiles
    {
        internal get { return _n_dark_tiles; }
    }

    [CCode (notify = false)] internal uint8 n_current_tiles
    {
        internal get { return current_color == Player.LIGHT ? n_light_tiles : n_dark_tiles; }
        protected set {
            if (current_color == Player.LIGHT)
                _n_light_tiles = value;
            else
                _n_dark_tiles = value;
        }
    }

    [CCode (notify = false)] internal uint8 n_opponent_tiles
    {
        internal get { return current_color == Player.DARK ? n_light_tiles : n_dark_tiles; }
        protected set {
            if (current_color == Player.DARK)
                _n_light_tiles = value;
            else
                _n_dark_tiles = value;
        }
    }

    /*\
    * * public information
    \*/

    internal Player get_owner (uint8 x, uint8 y)
        requires (is_valid_location_unsigned (x, y))
    {
        return tiles [x, y];
    }
 // internal new uint8 get (uint8 x, uint8 y)    // allows calling game [x, y]
 //     requires (x < size)
 //     requires (y < size)
 // {
 //     return tiles [x, y];
 // }

    internal inline bool is_valid_location_signed (int8 x, int8 y)
    {
        return x >= 0 && x < size
            && y >= 0 && y < size;
    }

    internal inline bool is_valid_location_unsigned (uint8 x, uint8 y)
    {
        return x < size && y < size;
    }

    /*\
    * * ... // completeness
    \*/

    internal uint8 test_placing_tile (uint8 x, uint8 y)
    {
        return _place_tile (x, y, current_color, /* apply move */ false);
    }

    protected uint8 _place_tile (uint8 x, uint8 y, Player color, bool apply)
        requires (is_valid_location_unsigned (x, y))
    {
        if (tiles [x, y] != Player.NONE)
            return 0;

        uint8 tiles_turned = 0;
        tiles_turned += flip_tiles (x, y, color,  1,  0, apply);
        tiles_turned += flip_tiles (x, y, color,  1,  1, apply);
        tiles_turned += flip_tiles (x, y, color,  0,  1, apply);
        tiles_turned += flip_tiles (x, y, color, -1,  1, apply);
        tiles_turned += flip_tiles (x, y, color, -1,  0, apply);
        tiles_turned += flip_tiles (x, y, color, -1, -1, apply);
        tiles_turned += flip_tiles (x, y, color,  0, -1, apply);
        tiles_turned += flip_tiles (x, y, color,  1, -1, apply);

        if (tiles_turned == 0)
            return 0;

        if (apply)
        {
            set_tile (x, y, color);
            end_of_turn ();
        }

        return tiles_turned;
    }

    protected virtual void end_of_turn () {}

    /*\
    * * can move
    \*/

    [CCode (notify = false)] internal bool current_player_can_move { internal get; private set; default = true; }
    [CCode (notify = true)] internal bool is_complete { internal get; protected set; default = false; }

    protected void update_who_can_move ()
    {
        Player enemy = Player.flip_color (current_color);
        bool opponent_can_move = false;
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
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

    internal bool can_place (uint8 x, uint8 y, Player color)
        requires (is_valid_location_unsigned (x, y))
        requires (color != Player.NONE)
    {
        if (tiles [x, y] != Player.NONE)
            return false;

        if (can_flip_tiles (x, y, color,  1,  0) > 0) return true;
        if (can_flip_tiles (x, y, color,  1,  1) > 0) return true;
        if (can_flip_tiles (x, y, color,  0,  1) > 0) return true;
        if (can_flip_tiles (x, y, color, -1,  1) > 0) return true;
        if (can_flip_tiles (x, y, color, -1,  0) > 0) return true;
        if (can_flip_tiles (x, y, color, -1, -1) > 0) return true;
        if (can_flip_tiles (x, y, color,  0, -1) > 0) return true;
        if (can_flip_tiles (x, y, color,  1, -1) > 0) return true;
        return false;
    }

    /*\
    * * flipping tiles
    \*/

    private uint8 flip_tiles (uint8 x, uint8 y, Player color, int8 x_step, int8 y_step, bool apply)
    {
        uint8 enemy_count = can_flip_tiles (x, y, color, x_step, y_step);
        if (enemy_count == 0)
            return 0;

        if (apply)
        {
            for (int8 i = 1; i <= enemy_count; i++)
            {
                if      (color == Player.DARK)  _n_light_tiles--;
                else if (color == Player.LIGHT) _n_dark_tiles--;
                else    assert_not_reached ();
                set_tile ((uint8) ((int8) x + (i * x_step)),
                          (uint8) ((int8) y + (i * y_step)),
                          color);
            }
        }
        return enemy_count;
    }

    protected uint8 can_flip_tiles (uint8 x, uint8 y, Player color, int8 x_step, int8 y_step)
    {
        Player enemy = Player.flip_color (color);

        /* Count number of enemy pieces we are beside */
        int8 enemy_count = -1;
        int8 xt = (int8) x;
        int8 yt = (int8) y;
        do {
            enemy_count++;
            xt += x_step;
            yt += y_step;
        } while (is_valid_location_signed (xt, yt) && tiles [xt, yt] == enemy);

        /* Must be a line of enemy pieces then one of ours */
        if (enemy_count <= 0 || !is_valid_location_signed (xt, yt) || tiles [xt, yt] != color)
            return 0;

        return (uint8) enemy_count;
    }

    protected virtual void set_tile (uint8 x, uint8 y, Player color)
    {
        if      (color == Player.DARK)  _n_dark_tiles++;
        else if (color == Player.LIGHT) _n_light_tiles++;
        else    assert_not_reached ();
        tiles [x, y] = color;
    }
}

private class Game : GameState
{
    /* Undoing */
    private uint8? [] undo_stack;
    private int history_index = -1;

    [CCode (notify = false)] internal uint8 number_of_moves { internal get; private set; default = 0; }

    /* Indicate that a player should move */
    internal signal void turn_ended ();
    /* Indicate a square has changed */
    internal signal void square_changed (uint8 x, uint8 y, Player new_color);

    [CCode (notify = false)] internal uint8 initial_number_of_tiles { internal get; private set; }

    /*\
    * * creation
    \*/

    [CCode (notify = false)] public bool alternative_start { internal get; protected construct; }

    internal Game (bool alternative_start = false, uint8 _size = 8)
        requires (_size >= 4)
        requires (_size <= 16)
    {
        Object (alternative_start: alternative_start, size: _size, current_color: /* Dark always starts */ Player.DARK);

        for (uint8 x = 0; x < _size; x++)
            for (uint8 y = 0; y < _size; y++)
                tiles [x, y] = Player.NONE;

        init_undo_stack (_size, out undo_stack);

        if (_size % 2 == 0)
        {
            /* Setup board with four tiles by default */
            initial_number_of_tiles = 4;
            tiles [_size / 2 - 1, _size / 2 - 1] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [_size / 2 - 1, _size / 2] = Player.DARK;
            tiles [_size / 2, _size / 2 - 1] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [_size / 2, _size / 2] = Player.LIGHT;
            n_current_tiles = 2;
            n_opponent_tiles = 2;
        }
        else
        {
            /* Logical starting position for odd board */
            initial_number_of_tiles = 7;
            tiles [(_size - 1) / 2, (_size - 1) / 2] = Player.DARK;
            tiles [(_size + 1) / 2, (_size - 3) / 2] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [(_size - 3) / 2, (_size + 1) / 2] = alternative_start ? Player.LIGHT : Player.DARK;
            tiles [(_size - 1) / 2, (_size - 3) / 2] = Player.LIGHT;
            tiles [(_size - 3) / 2, (_size - 1) / 2] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [(_size + 1) / 2, (_size - 1) / 2] = alternative_start ? Player.DARK : Player.LIGHT;
            tiles [(_size - 1) / 2, (_size + 1) / 2] = Player.LIGHT;
            n_current_tiles = 3;
            n_opponent_tiles = 4;
        }
    }

    internal Game.from_strings (string [] setup, Player to_move, uint8 _size = 8)
        requires (_size >= 4)
        requires (_size <= 16)
        requires (to_move != Player.NONE)
        requires (setup.length == _size)
    {
        Object (size: _size, current_color: to_move);

        initial_number_of_tiles = (_size % 2 == 0) ? 4 : 7;
        init_undo_stack (_size, out undo_stack);

        uint8 n_dark_tiles = 0;
        uint8 n_light_tiles = 0;

        for (uint8 y = 0; y < _size; y++)
        {
            if (setup [y].length != _size * 2)
                warn_if_reached ();
            for (uint8 x = 0; x < _size; x++)
            {
                Player player = Player.from_char (setup [y][x * 2 + 1]);
                if      (player == Player.DARK)  n_dark_tiles++;
                else if (player == Player.LIGHT) n_light_tiles++;
                tiles [x, y] = player;
            }
        }

        if (to_move == Player.DARK)
        {
            n_current_tiles  = n_dark_tiles;
            n_opponent_tiles = n_light_tiles;
        }
        else
        {
            n_current_tiles  = n_light_tiles;
            n_opponent_tiles = n_dark_tiles;
        }

        warn_if_fail (string.joinv ("\n", (string?[]) setup).strip () == to_string ().strip ());
    }

    /*\
    * * actions (apart undo)
    \*/

    internal /* success */ bool place_tile (uint8 x, uint8 y)
    {
        return _place_tile (x, y, current_color, /* apply move */ true) != 0;
    }

    internal void pass ()
        requires (!current_player_can_move)
    {
        end_of_turn ();
    }

    protected override void end_of_turn ()
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        current_color = Player.flip_color (current_color);
        number_of_moves++;
        history_index++;
        undo_stack [history_index] = null;
        update_who_can_move ();
        turn_ended ();
    }

    /*\
    * * undo
    \*/

    internal void undo (uint8 count = 1)
        requires (count == 1 || count == 2)
        requires (number_of_moves >= count)
        requires (history_index < undo_stack.length)
    {
        Player enemy = current_color;
        current_color = Player.flip_color (current_color);
        number_of_moves--;

        /* pass the end of turn mark of the history */
        history_index--;

        /* if not pass */
        uint8? undo_item = undo_stack [history_index];
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

    protected override void set_tile (uint8 x, uint8 y, Player color)
        requires (history_index >= -1 && history_index < undo_stack.length - 2)
    {
        history_index++;
        undo_stack [history_index] = x + y * size;
        base.set_tile (x, y, color);
        square_changed (x, y, color);
    }

    private void unset_tile (uint8 tile_number, Player replacement_color)
    {
        n_current_tiles--;
        history_index--;
        uint8 x = tile_number % size;
        uint8 y = tile_number / size;
        tiles [x, y] = replacement_color;
        square_changed (x, y, replacement_color);
    }

    private static void init_undo_stack (uint8 size, out uint8? [] undo_stack)
    {
        // Stack is oversized: there are (size * size - initial tiles) turns,
        // each adds one piece, a null marking the end of turn, then possibly
        // another null marking the opponent passing, and it is impossible to
        // flip (size - 2) enemy pieces in each of the 4 possible directions.
        undo_stack = new uint8? [(size * size - 4) * (3 + (size - 2) * 4)];
    }
}
