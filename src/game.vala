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

private enum MainLine
{
    TOP,
    LEFT,
    RIGHT,
    BOTTOM,
    TOPLEFT,
    TOPRIGHT;
}

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

    internal GameStateStruct.from_grid (uint8 _size, Player [,] _tiles, Player color, uint8 [,] _neighbor_tiles, bool humans_opening)
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
        if (humans_opening)
        {
            current_player_can_move = true;
            is_complete = false;
        }
        else
            update_who_can_move ();
    }
    private inline void add_tile_of_color (Player color)
    {
        if (color == current_color)
            n_current_tiles++;
        else if (color != Player.NONE)
            n_opponent_tiles++;
    }

    internal GameStateStruct.empty (uint8 _size, uint8 [,] _neighbor_tiles)
    {
        // move color
        current_color = Player.DARK;    // Dark always starts
        opponent_color = Player.LIGHT;

        // always given
        size = _size;
        neighbor_tiles = _neighbor_tiles;

        // tiles grid
        tiles = new Player [_size, _size];
        for (uint8 x = 0; x < _size; x++)
            for (uint8 y = 0; y < _size; y++)
                tiles [x, y] = Player.NONE;

        // tiles counters
        n_current_tiles = 0;
        n_opponent_tiles = 0;
        n_tiles = 0;

        // empty neighbors
        init_empty_neighbors ();    // could do better

        // who can move
        current_player_can_move = true;
        is_complete = false;
        x_saved = size / 2 - 2;
        y_saved = size / 2 - 2;
    }

    internal GameStateStruct.copy_and_add (GameStateStruct game, uint8 x, uint8 y)
    {
        // move color
        opponent_color = game.current_color;
        current_color = Player.flip_color (opponent_color);

        // always given
        size = game.size;
        neighbor_tiles = game.neighbor_tiles;

        // tiles grid
        tiles = game.tiles;
        if (tiles [x, y] != Player.NONE)
            assert_not_reached ();
        tiles [x, y] = opponent_color;

        // tiles counters
        n_current_tiles = game.n_opponent_tiles;
        n_opponent_tiles = game.n_current_tiles + 1;
        n_tiles = n_current_tiles + n_opponent_tiles;

        // empty neighbors
        init_empty_neighbors ();    // laziness

        // who can move
        current_player_can_move = true;
        is_complete = false;
        x_saved = size / 2 - 2;
        y_saved = size / 2 - 2;
    }

    internal GameStateStruct.copy_and_add_two (GameStateStruct game, uint8 x1, uint8 y1, uint8 x2, uint8 y2)
    {
        // move color
        opponent_color = game.current_color;
        current_color = Player.flip_color (opponent_color);

        // always given
        size = game.size;
        neighbor_tiles = game.neighbor_tiles;

        // tiles grid
        tiles = game.tiles;
        if (tiles [x1, y1] != Player.NONE
         || tiles [x2, y2] != Player.NONE)
            assert_not_reached ();
        tiles [x1, y1] = opponent_color;
        tiles [x2, y2] = opponent_color;

        // tiles counters
        n_current_tiles = game.n_opponent_tiles;
        n_opponent_tiles = game.n_current_tiles + 2;
        n_tiles = n_current_tiles + n_opponent_tiles;

        // empty neighbors
        init_empty_neighbors ();    // laziness

        // who can move
        current_player_can_move = true;
        is_complete = false;
        x_saved = size / 2 - 2;
        y_saved = size / 2 - 2;
    }

    /*\
    * * public information
    \*/

    internal inline bool is_current_color (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return tiles [x, y] == current_color;
    }

    internal inline bool is_empty_tile (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return tiles [x, y] == Player.NONE;
    }

    private inline bool is_valid_location_signed (int8 x, int8 y)
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

    /*\
    * * mainlines
    \*/

    internal Player [] get_mainline (MainLine mainline_id)  // keeping an updated copy of each mainline is a bit slower
    {
        Player [] mainline = new Player [size];
        switch (mainline_id)
        {
            case MainLine.TOP:      for (uint8 i = 0; i < size; i++) mainline [i] = tiles [i, 0];            break;
            case MainLine.LEFT:     for (uint8 i = 0; i < size; i++) mainline [i] = tiles [0, i];            break;
            case MainLine.RIGHT:    for (uint8 i = 0; i < size; i++) mainline [i] = tiles [size - 1, i];     break;
            case MainLine.BOTTOM:   for (uint8 i = 0; i < size; i++) mainline [i] = tiles [i, size - 1];     break;
            case MainLine.TOPLEFT:  for (uint8 i = 0; i < size; i++) mainline [i] = tiles [i, i];            break;
            case MainLine.TOPRIGHT: for (uint8 i = 0; i < size; i++) mainline [i] = tiles [size - 1 - i, i]; break;
            default: assert_not_reached ();
        }
        return mainline;
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

    internal GameStateObject.from_grid (uint8 size, Player [,] tiles, Player color, uint8 [,] neighbor_tiles, bool humans_opening = false)
    {
        _game_state_struct = GameStateStruct.from_grid (size, tiles, color, neighbor_tiles, humans_opening);
    }

    internal GameStateObject.empty (uint8 size, uint8 [,] neighbor_tiles)
    {
        _game_state_struct = GameStateStruct.empty (size, neighbor_tiles);
    }

    internal GameStateObject.copy_and_add (GameStateObject game, uint8 x, uint8 y)
    {
        _game_state_struct = GameStateStruct.copy_and_add (game.game_state_struct, x, y);
    }

    internal GameStateObject.copy_and_add_two (GameStateObject game, uint8 x, uint8 y, uint8 x2, uint8 y2)
    {
        _game_state_struct = GameStateStruct.copy_and_add_two (game.game_state_struct, x, y, x2, y2);
    }

    /*\
    * * public information
    \*/

    internal Player get_owner (uint8 x, uint8 y)
     // requires (is_valid_location_unsigned (x, y))
    {
        return game_state_struct.tiles [x, y];
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
    [CCode (notify = false)] public bool            reverse                 { internal get; protected construct;     }
    [CCode (notify = false)] public Opening         opening                 { internal get; protected construct set; }
    [CCode (notify = false)] public GameStateObject current_state           { internal get; protected construct set; }
    [CCode (notify = false)] public uint8           initial_number_of_tiles { internal get; protected construct;     }
    [CCode (notify = false)] public bool            print_logs              { internal get; protected construct;     }

    construct
    {
        undo_stack.append (current_state);
        update_possible_moves ();

        if (print_logs)
        {
            string e_or_i = reverse ? "e" : "i";
            if (initial_number_of_tiles <= 1)
                print (@"\nnew two-player revers$e_or_i game\n");
            else
                print (@"\nnew one-player revers$e_or_i game ($opening opening)\n");    // TODO is human Dark or Light?
        }
    }

    internal Game (bool _reverse, Opening _opening = Opening.REVERSI, uint8 _size = 8, bool _print_logs = false)
        requires (_size >= 4)
        requires (_size <= 16)
    {
        uint8 [,] _neighbor_tiles;
        init_neighbor_tiles (_size, out _neighbor_tiles);

        GameStateObject _current_state;
        uint8 _initial_number_of_tiles;
        bool even_board = _size % 2 == 0;
        bool humans_opening = _opening == Opening.HUMANS;
        if (even_board && humans_opening)
        {
            _initial_number_of_tiles = 0;

            _current_state = new GameStateObject.empty (_size, _neighbor_tiles);
        }
        else
        {
            Player [,] tiles = new Player [_size, _size];

            for (uint8 x = 0; x < _size; x++)
                for (uint8 y = 0; y < _size; y++)
                    tiles [x, y] = Player.NONE;

            if (even_board)
                setup_even_board (_size, _opening, ref tiles, out _initial_number_of_tiles);
            else
                setup_odd_board  (_size, _opening, ref tiles, out _initial_number_of_tiles);

            Player first_player = humans_opening ? Player.LIGHT : /* Dark "always" starts */ Player.DARK;
            _current_state = new GameStateObject.from_grid (_size, tiles, first_player, _neighbor_tiles, humans_opening);
        }

        Object (size                    : _size,
                reverse                 : _reverse,
                opening                 : _opening,
                current_state           : _current_state,
                initial_number_of_tiles : _initial_number_of_tiles,
                print_logs              : _print_logs);
        neighbor_tiles = (owned) _neighbor_tiles;
    }
    private static inline void setup_even_board (uint8 size, Opening opening, ref Player [,] tiles, out uint8 initial_number_of_tiles)
    {
        /* setup board with four tiles by default */
        uint8 half_size = size / 2;
        initial_number_of_tiles = 4;
        Player [,] start_position;
        switch (opening)
        {
            case Opening.REVERSI:      start_position = {{ Player.LIGHT, Player.DARK  }, { Player.DARK , Player.LIGHT }}; break;
            case Opening.INVERTED:     start_position = {{ Player.DARK , Player.LIGHT }, { Player.LIGHT, Player.DARK  }}; break;
            case Opening.ALTER_TOP:    start_position = {{ Player.DARK , Player.DARK  }, { Player.LIGHT, Player.LIGHT }}; break;
            case Opening.ALTER_LEFT:   start_position = {{ Player.DARK , Player.LIGHT }, { Player.DARK , Player.LIGHT }}; break;
            case Opening.ALTER_RIGHT:  start_position = {{ Player.LIGHT, Player.DARK  }, { Player.LIGHT, Player.DARK  }}; break;
            case Opening.ALTER_BOTTOM: start_position = {{ Player.LIGHT, Player.LIGHT }, { Player.DARK , Player.DARK  }}; break;
            default: assert_not_reached ();
        }
        tiles [half_size - 1, half_size - 1] = start_position [0, 0];
        tiles [half_size    , half_size - 1] = start_position [0, 1];
        tiles [half_size - 1, half_size    ] = start_position [1, 0];
        tiles [half_size    , half_size    ] = start_position [1, 1];
    }
    private static inline void setup_odd_board (uint8 size, Opening opening, ref Player [,] tiles, out uint8 initial_number_of_tiles)
    {
        /* logical starting position for odd board */
        uint8 mid_board = (size - 1) / 2;
        initial_number_of_tiles = opening == Opening.HUMANS ? 1 : 7;
        Player [,] start_position;
        switch (opening)
        {
            case Opening.HUMANS:       start_position = {{ Player.NONE , Player.NONE , Player.NONE  },
                                                         { Player.NONE , Player.DARK , Player.NONE  },
                                                         { Player.NONE , Player.NONE , Player.NONE  }}; break;
            case Opening.REVERSI:      start_position = {{ Player.NONE , Player.LIGHT, Player.DARK  },
                                                         { Player.LIGHT, Player.DARK , Player.LIGHT },
                                                         { Player.DARK , Player.LIGHT, Player.NONE  }}; break;
            case Opening.INVERTED:     start_position = {{ Player.DARK , Player.LIGHT, Player.NONE  },
                                                         { Player.LIGHT, Player.DARK , Player.LIGHT },
                                                         { Player.NONE , Player.LIGHT, Player.DARK  }}; break;
            case Opening.ALTER_TOP:    start_position = {{ Player.NONE , Player.DARK , Player.LIGHT },
                                                         { Player.LIGHT, Player.DARK , Player.LIGHT },
                                                         { Player.LIGHT, Player.DARK , Player.NONE  }}; break;
            case Opening.ALTER_LEFT:   start_position = {{ Player.LIGHT, Player.LIGHT, Player.NONE  },
                                                         { Player.DARK , Player.DARK , Player.DARK  },
                                                         { Player.NONE , Player.LIGHT, Player.LIGHT }}; break;
            case Opening.ALTER_RIGHT:  start_position = {{ Player.NONE , Player.LIGHT, Player.LIGHT },
                                                         { Player.DARK , Player.DARK , Player.DARK  },
                                                         { Player.LIGHT, Player.LIGHT, Player.NONE  }}; break;
            case Opening.ALTER_BOTTOM: start_position = {{ Player.LIGHT, Player.DARK , Player.NONE  },
                                                         { Player.LIGHT, Player.DARK , Player.LIGHT },
                                                         { Player.NONE , Player.DARK , Player.LIGHT }}; break;
            default: assert_not_reached ();
        }
        tiles [mid_board - 1, mid_board - 1] = start_position [0, 0];
        tiles [mid_board    , mid_board - 1] = start_position [0, 1];
        tiles [mid_board + 1, mid_board - 1] = start_position [0, 2];
        tiles [mid_board - 1, mid_board    ] = start_position [1, 0];
        tiles [mid_board    , mid_board    ] = Player.DARK;
        tiles [mid_board + 1, mid_board    ] = start_position [1, 2];
        tiles [mid_board - 1, mid_board + 1] = start_position [2, 0];
        tiles [mid_board    , mid_board + 1] = start_position [2, 1];
        tiles [mid_board + 1, mid_board + 1] = start_position [2, 2];
    }

    internal Game.from_strings (string [] setup, Player to_move, bool _reverse = false, uint8 _size = 8, bool _print_logs = false)
        requires (_size >= 4)
        requires (_size <= 16)
        requires (to_move != Player.NONE)
        requires (setup.length == _size)
    {
        uint8 [,] _neighbor_tiles;
        init_neighbor_tiles (_size, out _neighbor_tiles);

        Player [,] tiles = new Player [_size, _size];

        for (uint8 y = 0; y < _size; y++)
        {
            if (setup [y].length != _size * 2)
                warn_if_reached ();
            for (uint8 x = 0; x < _size; x++)
                tiles [x, y] = Player.from_char (setup [y] [x * 2 + 1]);
        }

        GameStateObject _current_state = new GameStateObject.from_grid (_size, tiles, to_move, _neighbor_tiles);

        Object (size                    : _size,
                reverse                 : _reverse,
                opening                 : /* garbage */ Opening.REVERSI,
                current_state           : _current_state,
                initial_number_of_tiles : (_size % 2 == 0) ? 4 : 7,
                print_logs              : _print_logs);
        neighbor_tiles = (owned) _neighbor_tiles;

        warn_if_fail (string.joinv ("\n", (string? []) setup).strip () == to_string ().strip ());
    }

    /*\
    * * information
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
        if (opening == Opening.HUMANS)
            return humans_opening_place_tile (x, y);

        PossibleMove move;
        if (!current_state.test_placing_tile (x, y, out move))
            return false;

        if (print_logs)
        {
            string current_color_string = current_color == Player.DARK ? "dark :" : "light:";
            print (@"$current_color_string ($x, $y)\n");
        }

        current_state = new GameStateObject.copy_and_move (current_state, move);
        undo_stack.append (current_state);
        end_of_turn (/* undoing */ false, /* no_draw */ false);
        return true;
    }

    internal /* success */ bool pass ()
    {
        if (current_player_can_move)
            return false;

        if (print_logs)
        {
            if (current_color == Player.DARK)
                print ("dark : pass\n");
            else
                print ("light: pass\n");
        }

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

    internal bool test_placing_tile (uint8 x, uint8 y, out unowned PossibleMove move)
    {
        if (opening == Opening.HUMANS)
        {
            move = PossibleMove (x, y); // good enough

            return humans_opening_test_placing_tile (x, y);
        }

        unowned SList<PossibleMove?>? test_move = possible_moves.nth (0);
        while (test_move != null)
        {
            move = (!) ((!) test_move).data;
            if (move.x == x && move.y == y)
                return true;
            test_move = ((!) test_move).next;
        }
        return false;
    }

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
        if (opening == Opening.HUMANS)
            humans_opening_update_possible_moves ();
        else
            current_state.get_possible_moves (out possible_moves);
    }

    /*\
    * * humans opening
    \*/

    private inline bool humans_opening_place_tile (uint8 x, uint8 y)
    {
        uint8 half_game_size = size / 2;
        bool even_board = size % 2 == 0;

        if (!humans_opening_test_placing_tile (x, y))
            return false;

        if (even_board)
        {
            if (current_state.n_dark_tiles == 2)
                humans_opening_update_opening_even ();

            if (print_logs)
            {
                string current_color_string = current_color == Player.DARK ? "dark :" : "light:";
                print (@"$current_color_string ($x, $y)\n");
            }
            current_state = new GameStateObject.copy_and_add (current_state, x, y);
        }
        else
        {
            if (current_color == Player.LIGHT && n_light_tiles != 0)
                humans_opening_update_opening_odd (x, y);

            uint8 x2;
            uint8 y2;
            if (x == half_game_size)            x2 = half_game_size;
            else if (x == half_game_size - 1)   x2 = half_game_size + 1;
            else /*  x == half_game_size + 1 */ x2 = half_game_size - 1;
            if (y == half_game_size)            y2 = half_game_size;
            else if (y == half_game_size - 1)   y2 = half_game_size + 1;
            else /*  y == half_game_size + 1 */ y2 = half_game_size - 1;
            if (print_logs)
            {
                string current_color_string = current_color == Player.DARK ? "dark :" : "light:";
                print (@"$current_color_string ($x, $y) and ($x2, $y2)\n");
            }
            current_state = new GameStateObject.copy_and_add_two (current_state, x, y, x2, y2);
        }

        if (n_light_tiles == (even_board ? 2 : 4))
        {
            undo_stack.remove (0);
            undo_stack.append (current_state);
        }

        end_of_turn (/* undoing */ false, /* no_draw */ false);
        return true;
    }
    private inline void humans_opening_update_opening_even ()
    {
        uint8 half_game_size = size / 2;
        if (get_owner (half_game_size - 1, half_game_size - 1) == Player.DARK)
        {
            if (get_owner (half_game_size, half_game_size - 1) == Player.DARK)  opening = Opening.ALTER_TOP;
            else if (get_owner (half_game_size, half_game_size) == Player.DARK) opening = Opening.REVERSI;
            else                                                                opening = Opening.ALTER_LEFT;
        }
        else
        {
            if (get_owner (half_game_size, half_game_size - 1) == Player.LIGHT) opening = Opening.ALTER_BOTTOM;
            else if (get_owner (half_game_size, half_game_size) == Player.DARK) opening = Opening.ALTER_RIGHT;
            else                                                                opening = Opening.INVERTED;
        }
    }
    private inline void humans_opening_update_opening_odd (uint8 x, uint8 y)
    {
        uint8 half_game_size = size / 2;
        if (x == half_game_size || y == half_game_size)
        {
            if (get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE)
                opening = Opening.REVERSI;
            else
                opening = Opening.INVERTED;
        }
        else
        {
            if (x == y)
            {
                if (get_owner (half_game_size, half_game_size - 1) == Player.LIGHT)
                        opening = Opening.ALTER_LEFT;
                else    opening = Opening.ALTER_BOTTOM;
            }
            else
            {
                if (get_owner (half_game_size, half_game_size - 1) == Player.LIGHT)
                        opening = Opening.ALTER_RIGHT;
                else    opening = Opening.ALTER_TOP;
            }
        }
    }

    private bool humans_opening_test_placing_tile (uint8 x, uint8 y)
    {
        if (get_owner (x, y) != Player.NONE)
            return false;

        if (size % 2 == 0)
            return humans_opening_test_placing_tile_even (x, y);
        else
            return humans_opening_test_placing_tile_odd (x, y);
    }
    private inline bool humans_opening_test_placing_tile_even (uint8 x, uint8 y)
    {
        uint8 half_game_size = size / 2;

        if (x < half_game_size - 1 || x > half_game_size
         || y < half_game_size - 1 || y > half_game_size)
            return false;

        if (current_color == Player.LIGHT && n_light_tiles == 0)
        {
            uint8 opposite_x = x == half_game_size ? half_game_size - 1 : half_game_size;
            uint8 opposite_y = y == half_game_size ? half_game_size - 1 : half_game_size;
            if (get_owner (opposite_x, opposite_y) == Player.DARK)
                return false;
        }
        return true;
    }
    private inline bool humans_opening_test_placing_tile_odd (uint8 x, uint8 y)
    {
        uint8 half_game_size = size / 2;

        if (x < half_game_size - 1 || x > half_game_size + 1
         || y < half_game_size - 1 || y > half_game_size + 1)
            return false;

        if (current_color == Player.LIGHT)
        {
            if (n_light_tiles == 0)
            {
                if (x != half_game_size && y != half_game_size)
                    return false;
            }
            else
            {
                if (get_owner (half_game_size - 1, half_game_size - 1) != Player.NONE
                 || get_owner (half_game_size + 1, half_game_size - 1) != Player.NONE)
                {
                    if (x != half_game_size && y != half_game_size)
                        return false;
                }
            }
        }
        return true;
    }

    private inline void humans_opening_update_possible_moves ()
    {
        if (size % 2 == 0)
            humans_opening_update_possible_moves_even ();
        else
            humans_opening_update_possible_moves_odd ();
    }
    private inline void humans_opening_update_possible_moves_even ()
    {
        possible_moves = new SList<PossibleMove?> ();

        uint8 half_game_size = size / 2;

        bool top_left;
        bool top_right;
        bool bottom_left;
        bool bottom_right;

        if (current_color == Player.LIGHT && n_light_tiles == 0)
        {
            top_left = get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE
                    && get_owner (half_game_size    , half_game_size    ) == Player.NONE;
            top_right    = !top_left;
            bottom_left  = !top_left;
            bottom_right = top_left;
        }
        else
        {
            top_left     = get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE;
            top_right    = get_owner (half_game_size    , half_game_size - 1) == Player.NONE;
            bottom_left  = get_owner (half_game_size - 1, half_game_size    ) == Player.NONE;
            bottom_right = get_owner (half_game_size    , half_game_size    ) == Player.NONE;
        }

        if (top_left)     possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size - 1));
        if (top_right)    possible_moves.prepend (PossibleMove (half_game_size    , half_game_size - 1));
        if (bottom_left)  possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size    ));
        if (bottom_right) possible_moves.prepend (PossibleMove (half_game_size    , half_game_size    ));
    }
    private inline void humans_opening_update_possible_moves_odd ()
    {
        possible_moves = new SList<PossibleMove?> ();

        uint8 half_game_size = size / 2;

        // light starts, first ply
        if (n_light_tiles == 0)
        {
            possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size    ));
            possible_moves.prepend (PossibleMove (half_game_size    , half_game_size - 1));
            possible_moves.prepend (PossibleMove (half_game_size    , half_game_size + 1));
            possible_moves.prepend (PossibleMove (half_game_size + 1, half_game_size    ));
        }
        // first dark ply
        else if (current_color == Player.DARK)
        {
            for (uint8 x = half_game_size - 1; x <= half_game_size + 1; x++)
                for (uint8 y = half_game_size - 1; y <= half_game_size + 1; y++)
                    if (get_owner (x, y) == Player.NONE)
                        possible_moves.prepend (PossibleMove (x, y));
        }
        // dark played vertically or horizontally the center of the opening zone
        else if (get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE
              && get_owner (half_game_size - 1, half_game_size + 1) == Player.NONE)
        {
            possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size - 1));
            possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size + 1));
            possible_moves.prepend (PossibleMove (half_game_size + 1, half_game_size - 1));
            possible_moves.prepend (PossibleMove (half_game_size + 1, half_game_size + 1));
        }
        // light started horizontally, dark played in a corner of the opening zone
        else if (get_owner (half_game_size, half_game_size - 1) == Player.NONE)
        {
            possible_moves.prepend (PossibleMove (half_game_size    , half_game_size - 1));
            possible_moves.prepend (PossibleMove (half_game_size    , half_game_size + 1));
        }
        // light started vertically, dark played in a corner of the opening zone
        else
        {
            possible_moves.prepend (PossibleMove (half_game_size - 1, half_game_size    ));
            possible_moves.prepend (PossibleMove (half_game_size + 1, half_game_size    ));
        }
    }
}

private enum Opening {
    HUMANS,
    REVERSI,
    INVERTED,
    ALTER_TOP,
    ALTER_LEFT,
    ALTER_RIGHT,
    ALTER_BOTTOM;

    internal string to_string ()
    {
        switch (this)
        {
            case HUMANS:        return "humans";
            case REVERSI:       return "reversi";
            case INVERTED:      return "inverted";
            case ALTER_TOP:     return "alter-top";
            case ALTER_LEFT:    return "alter-left";
            case ALTER_RIGHT:   return "alter-right";
            case ALTER_BOTTOM:  return "alter-bottom";
            default:            assert_not_reached ();
        }
    }
}
