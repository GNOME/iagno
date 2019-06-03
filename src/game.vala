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

private struct GameStateStruct
{
    public Player   current_color;
    public Player   opponent_color;
    public uint8    size;

    public uint8    n_current_tiles;
    public uint8    n_opponent_tiles;
    public uint8    n_tiles;

    public bool     current_player_can_move;
    public bool     is_complete;

    private Player [,] tiles;
    private unowned uint8 [,] neighbor_tiles;

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

    internal GameStateStruct.copy_and_pass (GameStateStruct game)
     // requires (!game.current_player_can_move)
     // requires (!game.is_complete)
    {
        // move color
        opponent_color = game.current_color;
        current_color = Player.flip_color (opponent_color);

        // always given
        size = game.size;
        neighbor_tiles = game.neighbor_tiles;

        // tiles grid
        tiles = game.tiles;

        // tiles counters
        n_current_tiles = game.n_opponent_tiles;
        n_opponent_tiles = game.n_current_tiles;
        n_tiles = n_current_tiles + n_opponent_tiles;

        // empty neighbors
        empty_neighbors = game.empty_neighbors;

        // who can move
        current_player_can_move = true;
        is_complete = false;
        x_saved = 0;
        y_saved = 0;
    }

    internal GameStateStruct.copy_and_move (GameStateStruct game, PossibleMove move)
    {
        // move color
        opponent_color = game.current_color;
        current_color = Player.flip_color (opponent_color);

        // always given
        size = game.size;
        neighbor_tiles = game.neighbor_tiles;

        // tiles grid
        tiles = game.tiles;
        flip_tiles (ref tiles, move.x, move.y, opponent_color,  0, -1, move.n_tiles_n );
        flip_tiles (ref tiles, move.x, move.y, opponent_color,  1, -1, move.n_tiles_ne);
        flip_tiles (ref tiles, move.x, move.y, opponent_color,  1,  0, move.n_tiles_e );
        flip_tiles (ref tiles, move.x, move.y, opponent_color,  1,  1, move.n_tiles_se);
        flip_tiles (ref tiles, move.x, move.y, opponent_color,  0,  1, move.n_tiles_s );
        flip_tiles (ref tiles, move.x, move.y, opponent_color, -1,  1, move.n_tiles_so);
        flip_tiles (ref tiles, move.x, move.y, opponent_color, -1,  0, move.n_tiles_o );
        flip_tiles (ref tiles, move.x, move.y, opponent_color, -1, -1, move.n_tiles_no);
        tiles [move.x, move.y] = opponent_color;

        // tiles counters
        n_current_tiles = game.n_opponent_tiles - move.n_tiles;
        n_opponent_tiles = game.n_current_tiles + move.n_tiles + 1;
        n_tiles = n_current_tiles + n_opponent_tiles;

        // empty neighbors
        empty_neighbors = game.empty_neighbors;
        update_empty_neighbors (move.x, move.y);

        // who can move
        update_who_can_move ();
    }
    private static inline void flip_tiles (ref Player [,] tiles, uint8 x, uint8 y, Player color, int8 x_step, int8 y_step, uint8 count)
    {
        for (; count > 0; count--)
        {
            tiles [(int8) x + ((int8) count * x_step),
                   (int8) y + ((int8) count * y_step)] = color;
        }
    }

    internal GameStateStruct.from_grid (uint8 _size, Player [,] _tiles, Player color, uint8 [,] _neighbor_tiles)
    {
        // move color
        current_color = color;
        opponent_color = Player.flip_color (color);

        // always given
        size = _size;
        neighbor_tiles = _neighbor_tiles;

        // tiles grid
        tiles = _tiles;

        // tiles counters
        n_current_tiles = 0;
        n_opponent_tiles = 0;
        for (uint8 x = 0; x < _size; x++)
            for (uint8 y = 0; y < _size; y++)
                add_tile_of_color (_tiles [x, y]);
        n_tiles = n_current_tiles + n_opponent_tiles;

        // empty neighbors
        init_empty_neighbors ();

        // who can move
        update_who_can_move ();
    }
    private inline void add_tile_of_color (Player color)
    {
        if (color == current_color)
            n_current_tiles++;
        else if (color != Player.NONE)
            n_opponent_tiles++;
    }

    /*\
    * * public information
    \*/

    internal inline bool is_current_color (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return tiles [x, y] == current_color;
    }

    internal inline bool is_opponent_color (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return tiles [x, y] == opponent_color;
    }

    internal inline bool is_valid_location_signed (int8 x, int8 y)
    {
        return x >= 0 && x < size
            && y >= 0 && y < size;
    }

//    private inline bool is_valid_location_unsigned (uint8 x, uint8 y)
//    {
//        return x < size && y < size;
//    }

    /*\
    * * get possible moves
    \*/

    private uint8 x_saved;
    private uint8 y_saved;

    private void update_who_can_move ()
    {
        Player enemy = Player.flip_color (current_color);
        bool opponent_can_move = false;
        for (x_saved = 0; x_saved < size; x_saved++)
        {
            for (y_saved = 0; y_saved < size; y_saved++)
            {
                if (is_unplayable_basic (x_saved, y_saved))
                    continue;
                if (can_place (x_saved, y_saved, current_color))
                {
                    current_player_can_move = true;
                    is_complete = false;
                    return;
                }
                if (opponent_can_move)
                    continue;
                if (can_place (x_saved, y_saved, enemy))
                {
                    opponent_can_move = true;
                    is_complete = false;
                }
            }
        }
        current_player_can_move = false;
        if (!opponent_can_move)
            is_complete = true;
    }

    internal void get_possible_moves (out SList<PossibleMove?> moves)
    {
        moves = new SList<PossibleMove?> ();

        // use local variables so we can launch the method again with similar results
        uint8 x = x_saved;
        uint8 y = y_saved;
        for (; x < size; x++)
        {
            for (; y < size; y++)
            {
                PossibleMove move;
                if (place_tile (x, y, current_color, out move))
                    moves.prepend (move);
            }
            y = 0;
        }
    }

    /*\
    * * test placing tiles
    \*/

    internal inline bool test_placing_tile (uint8 x, uint8 y, out PossibleMove move)
    {
        return place_tile (x, y, current_color, out move);
    }

    private inline bool is_unplayable_basic (uint8 x, uint8 y)
    {
        if (empty_neighbors [x, y] == neighbor_tiles [x, y])
            return true;
        if (tiles [x, y] != Player.NONE)
            return true;
        return false;
    }

    private inline bool place_tile (uint8 x, uint8 y, Player color, out PossibleMove move)
     // requires (is_valid_location_unsigned (x, y))
    {
        move = PossibleMove (x, y);

        if (is_unplayable_basic (x, y))
            return false;

        move.n_tiles_n  = can_flip_tiles (x, y, color,  0, -1);
        move.n_tiles_ne = can_flip_tiles (x, y, color,  1, -1);
        move.n_tiles_e  = can_flip_tiles (x, y, color,  1,  0);
        move.n_tiles_se = can_flip_tiles (x, y, color,  1,  1);
        move.n_tiles_s  = can_flip_tiles (x, y, color,  0,  1);
        move.n_tiles_so = can_flip_tiles (x, y, color, -1,  1);
        move.n_tiles_o  = can_flip_tiles (x, y, color, -1,  0);
        move.n_tiles_no = can_flip_tiles (x, y, color, -1, -1);

        move.n_tiles = move.n_tiles_n + move.n_tiles_ne
                     + move.n_tiles_e + move.n_tiles_se
                     + move.n_tiles_s + move.n_tiles_so
                     + move.n_tiles_o + move.n_tiles_no;
        return move.n_tiles != 0;
    }

    /**
     * can_place:
     * @x: the x coordinate of the tile to test
     * @y: the y coordinate of the tile to test
     * @color: the player color to test
     *
     * You should test is_unplayable_basic() before launching this.
     *
     * This method is faster than place_tile(), as it returns early
     * when some turnable tiles are found in one of the directions.
     *
     * Returns: %true if the given @color can be play there
     */
    private inline bool can_place (uint8 x, uint8 y, Player color)
    {
        // diagonals first, to return early more often
        if (can_flip_tiles (x, y, color, -1, -1) > 0) return true;  // no
        if (can_flip_tiles (x, y, color,  1,  1) > 0) return true;  // se
        if (can_flip_tiles (x, y, color, -1,  1) > 0) return true;  // so
        if (can_flip_tiles (x, y, color,  1, -1) > 0) return true;  // ne
        if (can_flip_tiles (x, y, color,  1,  0) > 0) return true;  // n
        if (can_flip_tiles (x, y, color, -1,  0) > 0) return true;  // s
        if (can_flip_tiles (x, y, color,  0,  1) > 0) return true;  // e
        if (can_flip_tiles (x, y, color,  0, -1) > 0) return true;  // o
        return false;
    }

    /**
     * can_flip_tiles:
     * @x: the x coordinate to start with
     * @y: the y coordinate to start with
     * @color: the player color to test
     * @x_step: the step on the x direction, %1, %0 or %-1
     * @y_step: the step on the y direction, %1, %0 or %-1
     *
     * Returns: the number of turnable tiles in the given direction
     */
    private inline uint8 can_flip_tiles (uint8 x, uint8 y, Player color, int8 x_step, int8 y_step)
    {
        Player enemy = Player.flip_color (color);

        /* Count number of enemy pieces we are beside */
        int8 enemy_count = -1;
        bool is_valid_location = false; // garbage; TODO report bug
        int8 xt = (int8) x;
        int8 yt = (int8) y;
        do {
            enemy_count++;
            xt += x_step;
            yt += y_step;
            is_valid_location = is_valid_location_signed (xt, yt);
        }
        while (is_valid_location && tiles [xt, yt] == enemy);

        /* Must be a line of enemy pieces then one of ours */
        if (enemy_count <= 0 || !is_valid_location || tiles [xt, yt] != color)
            return 0;

        return (uint8) enemy_count;
    }

    /*\
    * * surrounding tiles
    \*/

    private uint8 [,] empty_neighbors;

    internal uint8 get_empty_neighbors (uint8 x, uint8 y)
    {
        return empty_neighbors [x, y];
    }

    private inline void init_empty_neighbors ()
    {
        empty_neighbors = new uint8 [size, size];
        int8 _size = (int8) size;

        int8 xmm; int8 ymm;
        int8 xpp; int8 ypp;
        bool xmm_is_valid;
        bool xpp_is_valid;
        for (int8 x = 0; x < _size; x++)
        {
            xmm = x - 1;
            xpp = x + 1;
            xmm_is_valid = xmm >= 0;
            xpp_is_valid = xpp < size;

            for (int8 y = 0; y < _size; y++)
            {
                ymm = y - 1;
                ypp = y + 1;

                uint8 empty_neighbors_x_y   = is_empty (x,   ymm)
                                            + is_empty (x,   ypp);
                if (xmm_is_valid)
                    empty_neighbors_x_y    += is_empty (xmm, y  )
                                            + is_empty (xmm, ymm)
                                            + is_empty (xmm, ypp);
                if (xpp_is_valid)
                    empty_neighbors_x_y    += is_empty (xpp, y  )
                                            + is_empty (xpp, ymm)
                                            + is_empty (xpp, ypp);

                empty_neighbors [x, y] = empty_neighbors_x_y;
            }
        }
    }

    private inline uint8 is_empty (int8 x, int8 y)
    {
        if (!is_valid_location_signed (x, y))
            return 0;
        if (tiles [x, y] != Player.NONE)
            return 0;

        return 1;
    }

    private inline void update_empty_neighbors (uint8 x, uint8 y)
    {
        int8 xmm = ((int8) x) - 1;
        int8 ymm = ((int8) y) - 1;
        int8 xpp = xmm + 2;
        int8 ypp = ymm + 2;

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
}

private class GameStateObject : Object
{
    private GameStateStruct _game_state_struct;
    [CCode (notify = false)] internal GameStateStruct game_state_struct { internal get { return _game_state_struct; }}

    [CCode (notify = false)] internal Player current_color              { internal get { return game_state_struct.current_color; }}

    [CCode (notify = false)] internal uint8  n_light_tiles              { internal get {
            if (game_state_struct.current_color == Player.LIGHT)
                return game_state_struct.n_current_tiles;
         // else if (game_state_struct.current_color == Player.DARK)
                return game_state_struct.n_opponent_tiles;
         // else assert_not_reached ();
        }}
    [CCode (notify = false)] internal uint8  n_dark_tiles               { internal get {
            if (game_state_struct.current_color == Player.DARK)
                return game_state_struct.n_current_tiles;
         // else if (game_state_struct.current_color == Player.LIGHT)
                return game_state_struct.n_opponent_tiles;
         // else assert_not_reached ();
        }}

    [CCode (notify = false)] internal bool   current_player_can_move    { internal get { return game_state_struct.current_player_can_move; }}
    [CCode (notify = false)] internal bool   is_complete                { internal get { return game_state_struct.is_complete; }}

    internal string to_string ()
    {
        return game_state_struct.to_string ();
    }

    /*\
    * * board
    \*/

    internal GameStateObject.copy_and_pass (GameStateObject game)
    {
        _game_state_struct = GameStateStruct.copy_and_pass (game.game_state_struct);
    }

    internal GameStateObject.copy_and_move (GameStateObject game, PossibleMove move)
    {
        _game_state_struct = GameStateStruct.copy_and_move (game.game_state_struct, move);
    }

    internal GameStateObject.from_grid (uint8 size, Player [,] tiles, Player color, uint8 [,] neighbor_tiles)
    {
        _game_state_struct = GameStateStruct.from_grid (size, tiles, color, neighbor_tiles);
    }

    /*\
    * * public information
    \*/

    internal Player get_owner (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return game_state_struct.tiles [x, y];
    }

    internal inline bool is_valid_location_signed (int8 x, int8 y)
    {
        return game_state_struct.is_valid_location_signed (x, y);
    }

    /*\
    * * proxy calls
    \*/

    internal void get_possible_moves (out SList<PossibleMove?> moves)
    {
        game_state_struct.get_possible_moves (out moves);
    }

    internal bool test_placing_tile (uint8 x, uint8 y, out PossibleMove move)
    {
        return game_state_struct.test_placing_tile (x, y, out move);
    }
}

private class Game : Object
{
    private GLib.ListStore undo_stack = new GLib.ListStore (typeof (GameStateObject));
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

    [CCode (notify = false)] public uint8           size                    { internal get; protected construct;     }
    [CCode (notify = false)] public GameStateObject current_state           { internal get; protected construct set; }
    [CCode (notify = false)] public bool            alternative_start       { internal get; protected construct;     }
    [CCode (notify = false)] public uint8           initial_number_of_tiles { internal get; protected construct;     }

    construct
    {
        undo_stack.append (current_state);
        update_possible_moves ();
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
        GameStateObject _current_state = new GameStateObject.from_grid (_size, tiles, /* Dark always starts */ Player.DARK, _neighbor_tiles);

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
        GameStateObject _current_state = new GameStateObject.from_grid (_size, tiles, to_move, _neighbor_tiles);

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
        PossibleMove move;
        if (!current_state.test_placing_tile (x, y, out move))
            return false;

        current_state = new GameStateObject.copy_and_move (current_state, move);
        undo_stack.append (current_state);
        end_of_turn (/* undoing */ false, /* no_draw */ false);
        return true;
    }

    internal /* success */ bool pass ()
    {
        if (current_player_can_move)
            return false;

        current_state = new GameStateObject.copy_and_pass (current_state);
        undo_stack.append (current_state);
        end_of_turn (/* undoing */ false, /* no_draw */ true);
        return true;
    }

    private void end_of_turn (bool undoing, bool no_draw)
    {
        update_possible_moves ();
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
        if (tmp_current_state == null || !((!) tmp_current_state is GameStateObject))
            assert_not_reached ();
        current_state = (GameStateObject) (!) tmp_current_state;

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

    internal uint8 [,] copy_neighbor_tiles ()
    {
        return neighbor_tiles;
    }

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

    /*\
    * * possible moves
    \*/

    private SList<PossibleMove?> possible_moves;

    internal void get_possible_moves (out SList<PossibleMove?> moves)
    {
        moves = possible_moves.copy_deep ((a) => {
             // if (a == null)
             //     assert_not_reached ();
                return /* (PossibleMove) */ a;
            });
    }

    private inline void update_possible_moves ()
    {
        current_state.get_possible_moves (out possible_moves);
    }
}
