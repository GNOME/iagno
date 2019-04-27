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
    [CCode (notify = false)] public Player current_color { internal get; protected construct; default = Player.NONE; }

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

    [CCode (notify = false)] public uint8 size { internal get; protected construct; default = 0; }

    private Player [,] tiles;
    private unowned uint8 [,] neighbor_tiles;

    construct
    {
        tiles           = new Player [size, size];
        empty_neighbors = new uint8  [size, size];
    }

    internal GameState.copy (GameState game)
    {
        Object (size: game.size, current_color: game.current_color);
        neighbor_tiles = game.neighbor_tiles;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
            {
                set_tile (x, y, game.tiles [x, y]);
                empty_neighbors [x, y] = game.empty_neighbors [x, y];
            }

        update_who_can_move ();
        if (current_player_can_move != game.current_player_can_move
         || is_complete != game.is_complete)
            assert_not_reached ();
    }

    internal GameState.copy_and_pass (GameState game)
    {
        Object (size: game.size, current_color: Player.flip_color (game.current_color));
        neighbor_tiles = game.neighbor_tiles;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
            {
                set_tile (x, y, game.tiles [x, y]);
                empty_neighbors [x, y] = game.empty_neighbors [x, y];
            }

        // we already know all that, it is just for checking
        update_who_can_move ();
        if (!current_player_can_move || is_complete)
            assert_not_reached ();
    }

    internal GameState.copy_and_move (GameState game, uint8 move_x, uint8 move_y)
    {
        Player move_color = game.current_color;
        Object (size: game.size, current_color: Player.flip_color (move_color));
        neighbor_tiles = game.neighbor_tiles;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
            {
                set_tile (x, y, game.tiles [x, y]);
                empty_neighbors [x, y] = game.empty_neighbors [x, y];
            }

        if (place_tile (move_x, move_y, move_color, /* apply move */ true) == 0)
        {
            critical ("Computer marked move (%d, %d) as valid, but is invalid when checking.\n%s", move_x, move_y, to_string ());
            assert_not_reached ();
        }

        update_who_can_move ();
    }

    internal GameState.from_grid (uint8 _size, Player [,] _tiles, Player color, uint8 [,] _neighbor_tiles)
    {
        Object (size: _size, current_color: color);
        neighbor_tiles = _neighbor_tiles;

        for (uint8 x = 0; x < _size; x++)
            for (uint8 y = 0; y < _size; y++)
                set_tile (x, y, _tiles [x, y]);

        calculate_empty_neighbors ();
        update_who_can_move ();
    }

    /*\
    * * number of tiles on the board
    \*/

    private uint8 _n_light_tiles = 0;
    private uint8 _n_dark_tiles = 0;

    [CCode (notify = false)] internal uint8 n_tiles
                                            { internal get { return _n_dark_tiles + _n_light_tiles; }}
    [CCode (notify = false)] internal uint8 n_light_tiles
                                            { internal get { return _n_light_tiles; }}
    [CCode (notify = false)] internal uint8 n_dark_tiles
                                            { internal get { return _n_dark_tiles; }}
    [CCode (notify = false)] internal uint8 n_current_tiles
                                            { internal get { return current_color == Player.LIGHT ? _n_light_tiles : _n_dark_tiles; }}
    [CCode (notify = false)] internal uint8 n_opponent_tiles
                                            { internal get { return current_color == Player.DARK ? _n_light_tiles : _n_dark_tiles; }}

    internal void add_tile_of_color (Player color)
    {
        if (color == Player.DARK)
            _n_dark_tiles++;
        else if (color == Player.LIGHT)
            _n_light_tiles++;
    }

    private void remove_tile_of_opponent_color (Player color)
    {
        if (color == Player.LIGHT)
            _n_dark_tiles--;
        else if (color == Player.DARK)
            _n_light_tiles--;
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
        return place_tile (x, y, current_color, /* apply move */ false);
    }

    private uint8 place_tile (uint8 x, uint8 y, Player color, bool apply)
        requires (is_valid_location_unsigned (x, y))
    {
        if (tiles [x, y] != Player.NONE)
            return 0;
        if (empty_neighbors [x, y] == neighbor_tiles [x, y])
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
            update_empty_neighbors (x, y);
        }

        return tiles_turned;
    }

    /*\
    * * can move
    \*/

    [CCode (notify = false)] internal bool current_player_can_move { internal get; private set; default = true; }
    [CCode (notify = true)] internal bool is_complete { internal get; private set; default = false; }

    private void update_who_can_move ()
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
        if (empty_neighbors [x, y] == neighbor_tiles [x, y])
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
    * * surrounding tiles
    \*/

    private uint8 [,] empty_neighbors;

    internal uint8 get_empty_neighbors (uint8 x, uint8 y)
    {
        return empty_neighbors [x, y];
    }

    private void calculate_empty_neighbors ()
    {
        int8 _size = (int8) size;

        int8 xmm; int8 ymm;
        int8 xpp; int8 ypp;
        for (int8 x = 0; x < _size; x++)
        {
            xmm = x - 1;
            xpp = x + 1;

            for (int8 y = 0; y < _size; y++)
            {
                ymm = y - 1;
                ypp = y + 1;

                empty_neighbors [x, y] = is_empty (xpp, y  )
                                       + is_empty (xpp, ypp)
                                       + is_empty (x,   ypp)
                                       + is_empty (xmm, ypp)
                                       + is_empty (xmm, y  )
                                       + is_empty (xmm, ymm)
                                       + is_empty (x,   ymm)
                                       + is_empty (xpp, ymm);
            }
        }
    }

    private uint8 is_empty (int8 x, int8 y)
    {
        if (!is_valid_location_signed (x, y))
            return 0;
        if (get_owner ((uint8) x, (uint8) y) != Player.NONE)
            return 0;

        return 1;
    }

    private void update_empty_neighbors (uint8 x, uint8 y)
    {
        int8 xmm = ((int8) x) - 1;
        int8 ymm = ((int8) y) - 1;
        int8 xpp = ((int8) x) + 1;
        int8 ypp = ((int8) y) + 1;

        bool ymm_is_valid = ymm >= 0;
        bool ypp_is_valid = ypp < size;

        if (xmm >= 0)
        {
                              empty_neighbors [xmm, y  ] -= 1;
            if (ymm_is_valid) empty_neighbors [xmm, ymm] -= 1;
            if (ypp_is_valid) empty_neighbors [xmm, ypp] -= 1;
        }
        if (ymm_is_valid)     empty_neighbors [x  , ymm] -= 1;
        if (ypp_is_valid)     empty_neighbors [x  , ypp] -= 1;
        if (xpp < size)
        {
                              empty_neighbors [xpp, y  ] -= 1;
            if (ymm_is_valid) empty_neighbors [xpp, ymm] -= 1;
            if (ypp_is_valid) empty_neighbors [xpp, ypp] -= 1;
        }
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
                remove_tile_of_opponent_color (color);
                set_tile ((uint8) ((int8) x + (i * x_step)),
                          (uint8) ((int8) y + (i * y_step)),
                          color);
            }
        }
        return enemy_count;
    }

    private uint8 can_flip_tiles (uint8 x, uint8 y, Player color, int8 x_step, int8 y_step)
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

    private void set_tile (uint8 x, uint8 y, Player color)
    {
        add_tile_of_color (color);
        tiles [x, y] = color;
    }
}

private class Game : Object
{
    private GLib.ListStore undo_stack = new GLib.ListStore (typeof (GameState));
    [CCode (notify = false)] internal uint8 number_of_moves
    {
        internal get
        {
            uint n_items = undo_stack.get_n_items ();
            if (n_items == 0 || n_items >= 256)
                assert_not_reached ();
            return (uint8) (n_items - 1);
        }
    }

    /* Indicate that a player should move */
    internal signal void turn_ended (bool undoing, bool no_draw);

    /*\
    * * creation
    \*/

    [CCode (notify = false)] public uint8       size                    { internal get; protected construct;     }
    [CCode (notify = false)] public GameState   current_state           { internal get; protected construct set; }
    [CCode (notify = false)] public bool        alternative_start       { internal get; protected construct;     }
    [CCode (notify = false)] public uint8       initial_number_of_tiles { internal get; protected construct;     }

    construct
    {
        undo_stack.append (current_state);
    }

    internal Game (bool _alternative_start = false, uint8 _size = 8)
        requires (_size >= 4)
        requires (_size <= 16)
    {
        bool even_board = (_size % 2 == 0);

        Player [,] tiles = new Player [_size, _size];

        for (uint8 x = 0; x < _size; x++)
            for (uint8 y = 0; y < _size; y++)
                tiles [x, y] = Player.NONE;

        uint8 _initial_number_of_tiles;
        if (even_board)
        {
            /* setup board with four tiles by default */
            uint8 half_size = _size / 2;
            _initial_number_of_tiles = 4;
            tiles [half_size - 1, half_size - 1] = _alternative_start ? Player.DARK : Player.LIGHT;
            tiles [half_size - 1, half_size    ] = Player.DARK;
            tiles [half_size    , half_size - 1] = _alternative_start ? Player.LIGHT : Player.DARK;
            tiles [half_size    , half_size    ] = Player.LIGHT;
        }
        else
        {
            /* logical starting position for odd board */
            uint8 mid_board = (_size - 1) / 2;
            _initial_number_of_tiles = 7;
            tiles [mid_board    , mid_board    ] = Player.DARK;
            tiles [mid_board + 1, mid_board - 1] = _alternative_start ? Player.LIGHT : Player.DARK;
            tiles [mid_board - 1, mid_board + 1] = _alternative_start ? Player.LIGHT : Player.DARK;
            tiles [mid_board    , mid_board - 1] = Player.LIGHT;
            tiles [mid_board - 1, mid_board    ] = _alternative_start ? Player.DARK : Player.LIGHT;
            tiles [mid_board + 1, mid_board    ] = _alternative_start ? Player.DARK : Player.LIGHT;
            tiles [mid_board    , mid_board + 1] = Player.LIGHT;
        }

        uint8 [,] _neighbor_tiles;
        init_neighbor_tiles (_size, out _neighbor_tiles);
        GameState _current_state = new GameState.from_grid (_size, tiles, /* Dark always starts */ Player.DARK, _neighbor_tiles);

        Object (size                    : _size,
                current_state           : _current_state,
                alternative_start       : _alternative_start,
                initial_number_of_tiles : _initial_number_of_tiles);
        neighbor_tiles = (owned) _neighbor_tiles;
    }

    internal Game.from_strings (string [] setup, Player to_move, uint8 _size = 8)
        requires (_size >= 4)
        requires (_size <= 16)
        requires (to_move != Player.NONE)
        requires (setup.length == _size)
    {
        Player [,] tiles = new Player [_size, _size];

        for (uint8 y = 0; y < _size; y++)
        {
            if (setup [y].length != _size * 2)
                warn_if_reached ();
            for (uint8 x = 0; x < _size; x++)
                tiles [x, y] = Player.from_char (setup [y] [x * 2 + 1]);
        }

        uint8 [,] _neighbor_tiles;
        init_neighbor_tiles (_size, out _neighbor_tiles);
        GameState _current_state = new GameState.from_grid (_size, tiles, to_move, _neighbor_tiles);

        Object (size                    : _size,
                current_state           : _current_state,
                alternative_start       : /* garbage */ false,
                initial_number_of_tiles : (_size % 2 == 0) ? 4 : 7);
        neighbor_tiles = (owned) _neighbor_tiles;

        warn_if_fail (string.joinv ("\n", (string? []) setup).strip () == to_string ().strip ());
    }

    /*\
    * * informations
    \*/

    internal Player get_owner (uint8 x, uint8 y)
    {
        return current_state.get_owner (x, y);
    }

    internal signal void completeness_updated (bool completeness);

    [CCode (notify = false)] internal bool is_complete               { get { return current_state.is_complete;               }}
    [CCode (notify = false)] internal uint8 n_light_tiles            { get { return current_state.n_light_tiles;             }}
    [CCode (notify = false)] internal uint8 n_dark_tiles             { get { return current_state.n_dark_tiles;              }}
    [CCode (notify = false)] internal bool current_player_can_move   { get { return current_state.current_player_can_move;   }}
    [CCode (notify = false)] internal Player current_color           { get { return current_state.current_color;             }}

    internal string to_string ()
    {
        return @"$current_state";
    }

    /*\
    * * actions (apart undo)
    \*/

    internal /* success */ bool place_tile (uint8 x, uint8 y)
    {
        uint8 n_tiles = current_state.test_placing_tile (x, y);
        if (n_tiles == 0)
            return false;

        current_state = new GameState.copy_and_move (current_state, x, y);
        undo_stack.append (current_state);
        end_of_turn (/* undoing */ false, /* no_draw */ false);
        return true;
    }

    internal /* success */ bool pass ()
    {
        if (current_player_can_move)
            return false;

        current_state = new GameState.copy_and_pass (current_state);
        undo_stack.append (current_state);
        end_of_turn (/* undoing */ false, /* no_draw */ true);
        return true;
    }

    private void end_of_turn (bool undoing, bool no_draw)
    {
        completeness_updated (current_state.is_complete);
        turn_ended (undoing, no_draw);
    }

    /*\
    * * undo
    \*/

    internal void undo (uint8 count = 1)
        requires (count == 1 || count == 2)
        requires (number_of_moves >= count)
    {
        uint undo_stack_n_items = undo_stack.get_n_items ();
        Object? tmp_current_state = undo_stack.get_object (undo_stack_n_items - 2);
        if (tmp_current_state == null || !((!) tmp_current_state is GameState))
            assert_not_reached ();
        current_state = (GameState) (!) tmp_current_state;

        /* for now, we forget about this undone move in the undo stack
           TODO keep an index of current state instead, and allow redo */
        undo_stack.remove (undo_stack_n_items - 1);

        if (count == 1 && current_player_can_move)
            end_of_turn (/* undoing */ true, /* no_draw */ false);
        else if (count == 2)
        {
            end_of_turn (/* undoing */ true, /* no_draw */ true);
            undo (count - 1);
        }
    }

    /*\
    * * neighbor tiles
    \*/

    private uint8 [,] neighbor_tiles;

    private static void init_neighbor_tiles (uint8 size, out uint8 [,] neighbor_tiles)
    {
        neighbor_tiles = new uint8 [size, size];
        uint8 max = size - 1;

        for (uint8 i = 1; i < max; i++)
        {
            // edges
            neighbor_tiles [i  , 0  ] = 5;
            neighbor_tiles [i  , max] = 5;
            neighbor_tiles [0  , i  ] = 5;
            neighbor_tiles [max, i  ] = 5;

            // center
            for (uint8 j = 1; j < max; j++)
                neighbor_tiles [i, j] = 8;
        }

        // corners
        neighbor_tiles [0  , 0  ] = 3;
        neighbor_tiles [0  , max] = 3;
        neighbor_tiles [max, max] = 3;
        neighbor_tiles [max, 0  ] = 3;
    }
}
