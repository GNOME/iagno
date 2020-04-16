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

private class ReversiView : Gtk.DrawingArea
{
    private bool _show_playable_tiles = false;
    [CCode (notify = false)] internal bool show_playable_tiles
    {
        private  get { return _show_playable_tiles; }
        internal set { _show_playable_tiles = value; if (game_is_set) highlight_playable_tiles (); }
    }
    [CCode (notify = false)] internal bool show_turnable_tiles { private get; internal set; default = false; }

    private int board_x;
    private int board_y;

    /* Keyboard */
    private bool show_highlight = false;
    private bool highlight_set = false;
    private uint8 highlight_x = uint8.MAX;
    private uint8 highlight_y = uint8.MAX;
    private uint8 old_highlight_x = uint8.MAX;
    private uint8 old_highlight_y = uint8.MAX;
    private uint8 highlight_state = 0;
    private const uint8 HIGHLIGHT_MAX = 5;

    /* Mouse */
    private bool show_mouse_highlight = false;
    private bool mouse_position_set = false;
    private uint8 mouse_highlight_x = uint8.MAX;
    private uint8 mouse_highlight_y = uint8.MAX;
    private uint8 mouse_position_x = uint8.MAX;
    private uint8 mouse_position_y = uint8.MAX;

    /* Delay in milliseconds between tile flip frames */
    private const int PIXMAP_FLIP_DELAY = 20;

    /* Pre-rendered image */
    private uint render_size = 0;
    private Cairo.Pattern? tiles_pattern = null;
    private Cairo.Pattern? board_pattern = null;

    private bool noise_pixbuf_loaded = false;

    /* The images being showed on each location */
    private int [,] pixmaps;

    /* Animation timer */
    private uint animate_timeout = 0;

    /* Humans opening */
    private const uint8 HUMANS_OPENING_INTENSITY_MAX = 15;
    private uint8 humans_opening_intensity = 0;

    internal signal void move (uint8 x, uint8 y);
    internal signal void clear_impossible_to_move_here_warning ();

    private bool game_is_set = false;
    private uint8 game_size;
    private Game _game;
    [CCode (notify = false)] internal Game game
    {
        get
        {
            if (!game_is_set)
                assert_not_reached ();
            return _game;
        }
        set
        {
            Game? test = value;
            if (test == null)
                assert_not_reached ();

            if (game_is_set)
                SignalHandler.disconnect_by_func (_game, null, this);

            _game = value;
            game_size = _game.size;
            if (!game_is_set)
            {
                pixmaps = new int [game_size, game_size];
                tile_xs = new int [game_size, game_size];
                tile_ys = new int [game_size, game_size];
                game_is_set = true;
            }
            init_possible_moves ();
            for (uint8 x = 0; x < game_size; x++)
                for (uint8 y = 0; y < game_size; y++)
                    pixmaps [x, y] = get_pixmap (_game.get_owner (x, y));
            _game.completeness_updated.connect (game_is_complete_cb);
            _game.turn_ended.connect (turn_ended_cb);

            show_highlight = false;
            bool even_board = game_size % 2 == 0;
            if (even_board)
            {
                highlight_set = false;
                highlight_x = (uint8) (game_size / 2 - 1);
            }
            else    // always start on center on odd games
            {
                highlight_set = true;
                highlight_x = (uint8) (game_size / 2);
            }
            highlight_y = highlight_x;
            old_highlight_x = uint8.MAX;
            old_highlight_y = uint8.MAX;
            highlight_state = 0;

            show_mouse_highlight = false;
            mouse_position_set = false;
            mouse_highlight_x = uint8.MAX;
            mouse_highlight_y = uint8.MAX;
            mouse_position_x = uint8.MAX;
            mouse_position_y = uint8.MAX;

            last_state_set = false;
            if (_game.opening == Opening.HUMANS)
            {
                if (even_board)
                {
                    overture_steps  = { 0, 0, 0, 0 };
                    overture_target = { 0, 0, 0, 0 };
                }
                else
                {
                    overture_steps  = { 0, 0, 0, 0, 0, 0 };
                    overture_target = { 0, 0, 0, 0, 0, 0 };
                }
                current_overture_playable = 0;
                if (configuration_done)
                    configure_overture_origin ();

                humans_opening_intensity = HUMANS_OPENING_INTENSITY_MAX;
            }
            else
                humans_opening_intensity = 0;

            queue_draw ();

            if (show_playable_tiles)
                highlight_playable_tiles ();
        }
    }

    construct
    {
        hexpand = true;
        vexpand = true;

        set_events (Gdk.EventMask.EXPOSURE_MASK
                  | Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK
                  | Gdk.EventMask.ENTER_NOTIFY_MASK
                  | Gdk.EventMask.LEAVE_NOTIFY_MASK
                  | Gdk.EventMask.STRUCTURE_MASK);
        init_mouse ();
        init_keyboard ();

        theme_manager.theme_changed.connect (() => {
                tiles_pattern = null;
                if (configuration_done)
                    configure_theme ();
                queue_draw ();
            });
    }

    [CCode (notify = false)] public Iagno           iagno_instance  { private get; protected construct; }
    [CCode (notify = false)] public ThemeManager    theme_manager   { private get; protected construct; }
    internal ReversiView (Iagno iagno_instance, ThemeManager theme_manager)
    {
        Object (iagno_instance: iagno_instance, theme_manager: theme_manager);
    }

    /*\
    * * drawing
    \*/

    private bool configuration_done = false;
    private int paving_size;
    private int tile_size;
    private int board_size;
    private int [,] tile_xs;
    private int [,] tile_ys;

    protected override bool configure_event (Gdk.EventConfigure e)
        requires (game_is_set)
    {
        configure_theme ();
        configuration_done = true;
        return true;
    }
    private void configure_theme ()
    {
        int allocated_width  = get_allocated_width ();
        int allocated_height = get_allocated_height ();
        int size = int.min (allocated_width, allocated_height);
        paving_size = (size - 2 * theme_manager.border_width + theme_manager.spacing_width) / game_size;
        tile_size = paving_size - theme_manager.spacing_width;
        board_size = paving_size * game_size - theme_manager.spacing_width + 2 * theme_manager.border_width;
        board_x = (allocated_width  - board_size) / 2 + theme_manager.border_width;
        board_y = (allocated_height - board_size) / 2 + theme_manager.border_width;

        if (humans_opening_intensity != 0)
            configure_overture_origin ();

        for (uint8 x = 0; x < game_size; x++)
        {
            for (uint8 y = 0; y < game_size; y++)
            {
                tile_xs [x, y] = paving_size * (int) x;
                tile_ys [x, y] = paving_size * (int) y;
            }
        }
    }
    private inline void configure_overture_origin ()
    {
        if (game_size % 2 == 0)
        {
            overture_origin_xs [0] = (game_size - 3) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [1] = (game_size - 1) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [2] = (game_size + 1) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [3] = (game_size + 3) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;

            if (game_size == 4)
                // where we can
                overture_origin_y  = (int) ((game_size + 2.6) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2);
            else
                // on the line under the center zone
                overture_origin_y  = (game_size + 4) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
        }
        else
        {
            overture_origin_xs [0] = (game_size - 2) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [2] =  game_size      * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [4] = (game_size + 2) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
            overture_origin_xs [1] = overture_origin_xs [0];
            overture_origin_xs [3] = overture_origin_xs [2];
            overture_origin_xs [5] = overture_origin_xs [4];

            if (game_size == 5)
                // where we can
                overture_origin_y  = (int) ((game_size + 3.6) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2);
            else
                // on the line under the center zone
                overture_origin_y  = (game_size + 5) * board_size / (2 * game_size) - theme_manager.border_width - tile_size / 2;
        }
    }

    protected override bool draw (Cairo.Context cr)
    {
        if (!game_is_set)
            return false;

        if (board_pattern == null || tiles_pattern == null || render_size != tile_size)
            init_patterns (cr);

        // draw board
        cr.translate (board_x - theme_manager.border_width, board_y - theme_manager.border_width);

        cr.set_source ((!) board_pattern);
        cr.rectangle (/* x and y */ 0.0,
                                    0.0,
                      /* w and h */ board_size,
                                    board_size);
        cr.fill ();

        // draw tiles (and highlight)
        cr.translate (theme_manager.border_width, theme_manager.border_width);

        if (humans_opening_intensity != 0)
            draw_overture (cr);

        draw_highlight (cr);
        add_highlights (cr);
        if (humans_opening_intensity == 0)
            draw_playables (cr);
        else
            draw_overture_playables (cr);

        return false;
    }

    private inline void init_patterns (Cairo.Context cr)
    {
        render_size = tile_size;

        Cairo.Surface surface;
        Cairo.Context context;

        // tiles pattern
        surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size * 8,
                                                                                          tile_size * 4);
        context = new Cairo.Context (surface);
        Rsvg.DimensionData size = theme_manager.tileset_handle.get_dimensions ();
        context.scale ((double) tile_size * 8.0 / (double) size.width,
                       (double) tile_size * 4.0 / (double) size.height);
        theme_manager.tileset_handle.render_cairo (context);
        tiles_pattern = new Cairo.Pattern.for_surface (surface);

        // noise pattern
        Cairo.Pattern? noise_pattern = null;

        if (theme_manager.apply_texture)
        {
            Gdk.Pixbuf? noise_pixbuf = null;

            try
            {
                noise_pixbuf = new Gdk.Pixbuf.from_resource_at_scale ("/org/gnome/Reversi/ui/noise.png",
                                                                      /* x and y */ tile_size, tile_size,
                                                                      /* preserve aspect ratio */ false);
            }
            catch (Error e) { warning (e.message); }
            noise_pixbuf_loaded = noise_pixbuf != null;
            if (noise_pixbuf_loaded)
            {
                surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size,
                                                                                                  tile_size);
                context = new Cairo.Context (surface);
                Gdk.cairo_set_source_pixbuf (context, (!) noise_pixbuf, 0.0, 0.0);
                context.paint_with_alpha (theme_manager.texture_alpha);
                // or  surface = Gdk.cairo_surface_create_from_pixbuf ((!) noise_pixbuf, 0, null); ?

                noise_pattern = new Cairo.Pattern.for_surface (surface);
                // ((!) noise_pattern).set_extend (Cairo.Extend.REPEAT);
            }
        }

        // board pattern
        surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, board_size,
                                                                                          board_size);
        context = new Cairo.Context (surface);

        draw_board_background (context);
        draw_tiles_background (context, ref noise_pattern);

        board_pattern = new Cairo.Pattern.for_surface (surface);
    }

    private inline void draw_board_background (Cairo.Context cr)
    {
        cr.set_source_rgba (theme_manager.spacing_red, theme_manager.spacing_green, theme_manager.spacing_blue, 1.0);
        cr.rectangle (/* x and y */ theme_manager.half_border_width,
                                    theme_manager.half_border_width,
                      /* w and h */ board_size - theme_manager.border_width,
                                    board_size - theme_manager.border_width);
        cr.fill_preserve ();
        cr.set_source_rgba (theme_manager.border_red, theme_manager.border_green, theme_manager.border_blue, 1.0);
        cr.set_line_width (theme_manager.border_width);
        cr.stroke ();
    }

    private inline void draw_tiles_background (Cairo.Context cr, ref Cairo.Pattern? noise_pattern)
    {
        cr.translate (theme_manager.border_width, theme_manager.border_width);

        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                draw_tile_background (cr, ref noise_pattern, tile_xs [x, y], tile_ys [x, y]);
    }
    private inline void draw_tile_background (Cairo.Context cr, ref Cairo.Pattern? noise_pattern, int tile_x, int tile_y)
    {
        cr.set_source_rgba (theme_manager.background_red, theme_manager.background_green, theme_manager.background_blue, 1.0);
        rounded_square (cr, tile_x, tile_y, tile_size, 0, theme_manager.background_radius);
        if (theme_manager.apply_texture && noise_pixbuf_loaded)
        {
            cr.fill_preserve ();

            Cairo.Matrix matrix = Cairo.Matrix.identity ();
            matrix.translate (-tile_x, -tile_y);
            ((!) noise_pattern).set_matrix (matrix);
            cr.set_source ((!) noise_pattern);
        }
        cr.fill ();
    }

    private inline void draw_overture (Cairo.Context cr)
     // requires (game_size % 2 == 0)
    {
        uint8 half_game_size = game_size / 2;
        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
            {
                // even and odd boards
                if ((x == half_game_size || x == half_game_size - 1)
                 && (y == half_game_size || y == half_game_size - 1))
                    continue;

                // odd boards only
                if (game_size % 2 != 0
                 && (((y == half_game_size + 1) && (x == half_game_size - 1 || x == half_game_size || x == half_game_size + 1))
                  || ((x == half_game_size + 1) && (y == half_game_size - 1 || y == half_game_size))))
                    continue;

                darken_tile (cr, x, y);
            }

        if (game.opening != Opening.HUMANS)
        {
            humans_opening_intensity--;
            queue_draw ();
        }
    }

    private inline void draw_highlight (Cairo.Context cr)
    {
        if (game.is_complete)   // TODO highlight last played tile on game.is_complete, even if it's the opponent one...
            return;

        bool display_mouse_highlight = !show_highlight  // no mouse highlight if keyboard one
                                    && (show_mouse_highlight || highlight_state != 0)
                                    // disable the hover if the computer is thinking; that should not happen with current AI
                                    && (iagno_instance.player_one == game.current_color || iagno_instance.computer == null);

        bool display_keybd_highlight = show_highlight
                                    && !show_mouse_highlight;

        // disappearing keyboard highlight after Escape pressed, if mouse hovered tile is not playable (else it is selected)
        bool display_ghost_highlight = !show_highlight
                                    && !show_mouse_highlight
                                    && highlight_state != 0
                                    && old_highlight_x != uint8.MAX
                                    && old_highlight_y != uint8.MAX;

        if (display_ghost_highlight)
            draw_tile_highlight (cr, old_highlight_x, old_highlight_y);
        else if (display_mouse_highlight)
            draw_tile_highlight (cr, mouse_highlight_x, mouse_highlight_y);
        else if (display_keybd_highlight)
            draw_tile_highlight (cr, highlight_x, highlight_y);
    }
    private inline void draw_tile_highlight (Cairo.Context cr, uint8 x, uint8 y)
    {
        unowned PossibleMove move;
        bool test_placing_tile = game.test_placing_tile (x, y, out move);
        bool highlight_on = show_highlight || (mouse_is_in && show_mouse_highlight && test_placing_tile);

        /* manage animated highlight */
        if (highlight_on && highlight_state != HIGHLIGHT_MAX)
        {
            highlight_state++;
            queue_draw_tile (x, y);
        }
        else if (!highlight_on && highlight_state != 0)
        {
            // either we hit Escape with a keyboard highlight and the mouse does not hover a playable tile,
            // or we moved mouse from a playable tile to a non playable one; in both cases, we decrease the
            // highlight state and redraw for the mouse highlight to re-animate when re-entering a playable
            // tile, or for the keyboard highlight to animate when disappearing; the first displays nothing
            highlight_state--;
            queue_draw_tile (x, y);
            if (old_highlight_x != x || old_highlight_y != y)   // is not a keyboard highlight disappearing
        // TODO && mouse_is_in) for having an animation when the cursor quits the board; currently causes glitches
                return;
        }
        highlight_tile (cr, x, y, highlight_state, /* soft highlight */ false);
        if (test_placing_tile
         && show_turnable_tiles
         && !(iagno_instance.computer != null && iagno_instance.player_one != game.current_color))
        {
            highlight_turnable_tiles (cr, move.x, move.y,  0, -1, move.n_tiles_n );
            highlight_turnable_tiles (cr, move.x, move.y,  1, -1, move.n_tiles_ne);
            highlight_turnable_tiles (cr, move.x, move.y,  1,  0, move.n_tiles_e );
            highlight_turnable_tiles (cr, move.x, move.y,  1,  1, move.n_tiles_se);
            highlight_turnable_tiles (cr, move.x, move.y,  0,  1, move.n_tiles_s );
            highlight_turnable_tiles (cr, move.x, move.y, -1,  1, move.n_tiles_so);
            highlight_turnable_tiles (cr, move.x, move.y, -1,  0, move.n_tiles_o );
            highlight_turnable_tiles (cr, move.x, move.y, -1, -1, move.n_tiles_no);
        }
    }
    private inline void highlight_turnable_tiles (Cairo.Context cr, uint8 x, uint8 y, int8 x_step, int8 y_step, uint8 count)
    {
        for (; count > 0; count--)
        {
            int8 _x = (int8) x + ((int8) count * x_step);
            int8 _y = (int8) y + ((int8) count * y_step);
            queue_draw_tile (_x, _y);
            highlight_tile (cr, _x, _y, highlight_state, /* soft highlight */ true);
        }
    }

    private inline void add_highlights (Cairo.Context cr)
    {
        if (!show_playable_tiles && playable_tiles_highlight_state == 0)
            return;
        if (iagno_instance.computer != null && iagno_instance.player_one != game.current_color)
        {
            init_possible_moves ();
            return;
        }

        if (show_playable_tiles && show_turnable_tiles)
        {
            unowned PossibleMove move;
            if (show_mouse_highlight && game.test_placing_tile (mouse_highlight_x, mouse_highlight_y, out move))
                return;
            if (show_highlight && game.test_placing_tile (highlight_x, highlight_y, out move))
                return;
        }

        bool decreasing = playable_tiles_highlight_state > HIGHLIGHT_MAX;
        uint8 intensity;
        if (decreasing)
            intensity = 2 * HIGHLIGHT_MAX + 1 - playable_tiles_highlight_state;
        else
            intensity = playable_tiles_highlight_state;

        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                add_highlight (cr, x, y, intensity);

        if (decreasing && intensity == 1)
            init_possible_moves ();
        else if (!show_playable_tiles)
            playable_tiles_highlight_state++;
        else if (playable_tiles_highlight_state < HIGHLIGHT_MAX)
            playable_tiles_highlight_state++;
    }
    private inline void add_highlight (Cairo.Context cr, uint8 x, uint8 y, uint8 intensity)
    {
        if (possible_moves [x, y] == false)
            return;

        queue_draw_tile (x, y);
        highlight_tile (cr, x, y, intensity, /* soft highlight */ true);
    }

    private inline void draw_playables (Cairo.Context cr)
    {
        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                draw_playable (cr, pixmaps [x, y], tile_xs [x, y], tile_ys [x, y]);
    }
    private inline void draw_playable (Cairo.Context cr, int pixmap, int tile_x, int tile_y)
    {
        if (pixmap == 0)
            return;

        Cairo.Matrix matrix = Cairo.Matrix.identity ();
        matrix.translate (/* texture x */ (pixmap % 8) * tile_size - /* x position */ tile_x,
                          /* texture y */ (pixmap / 8) * tile_size - /* y position */ tile_y);
        ((!) tiles_pattern).set_matrix (matrix);
        cr.set_source ((!) tiles_pattern);
        cr.rectangle (/* x and y */ tile_x,
                                    tile_y,
                      /* w and h */ tile_size,
                                    tile_size);
        cr.fill ();
    }

    private const uint8 OVERTURE_STEPS_MAX = 10;
    private int [] overture_origin_xs = new int [6];            // 4 for even boards, 6 for odd ones
    private int overture_origin_y = 0;
    private uint8 [] overture_steps  = { 0, 0, 0, 0, 0, 0 };    // { 0, 0, 0, 0 } for even boards
    private uint8 [] overture_target = { 0, 0, 0, 0, 0, 0 };    // { 0, 0, 0, 0 } for even boards
    private uint8 current_overture_playable = 0;
    private inline void draw_overture_playables (Cairo.Context cr)
    {
        bool even_board = game_size % 2 == 0;
        if (current_overture_playable < (even_board ? 4 : 6))
            draw_overture_indicator (cr);

        for (uint8 i = 0; i < (even_board ? 4 : 6); i++)
            draw_overture_playable (cr, i);

        if (!even_board)
        {
            uint8 half_game_size = game_size / 2;
            draw_playable (cr, pixmaps [half_game_size, half_game_size],
                               tile_xs [half_game_size, half_game_size],
                               tile_ys [half_game_size, half_game_size]);
        }
    }
    private inline void draw_overture_indicator (Cairo.Context cr)
    {
        double diameter_factor = game_size == 4 ? 1.95 : 1.8;
        cr.set_source_rgba (theme_manager.background_red, theme_manager.background_green, theme_manager.background_blue, 1.0);
        cr.arc ((double) overture_origin_xs [current_overture_playable] + (double) tile_size / 2.0,
                (double) overture_origin_y + (double) tile_size / 2.0,
                (double) tile_size / diameter_factor,
                0.0,
                Math.PI * 2.0);
        cr.fill ();
    }
    private inline void draw_overture_playable (Cairo.Context cr, uint8 playable_id)
    {
        if (overture_steps [playable_id] == OVERTURE_STEPS_MAX)
        {
            uint8 x, y;
            get_x_and_y (playable_id, out x, out y);
            draw_playable (cr, pixmaps [x, y], tile_xs [x, y], tile_ys [x, y]);
            return;
        }

        int tile_x = overture_origin_xs [playable_id];
        int tile_y = overture_origin_y;

        if (overture_target [playable_id] != 0)
        {
            uint8 x, y;
            get_x_and_y (playable_id, out x, out y);
            tile_x += (tile_xs [x, y] - tile_x) * overture_steps [playable_id] / OVERTURE_STEPS_MAX;
            tile_y += (tile_ys [x, y] - tile_y) * overture_steps [playable_id] / OVERTURE_STEPS_MAX;

            overture_steps [playable_id]++;
            queue_draw ();
        }
        if (game_size % 2 == 0)
            _draw_overture_playable (cr, tile_x, tile_y, /* pixmap */ (playable_id % 2) * 30 + 1);
        else
            _draw_overture_playable (cr, tile_x, tile_y, /* pixmap */ ((playable_id / 2 + 1) % 2) * 30 + 1);
    }
    private void _draw_overture_playable (Cairo.Context cr, int tile_x, int tile_y, int pixmap)
    {
        Cairo.Matrix matrix = Cairo.Matrix.identity ();
        matrix.translate (/* texture x */ (pixmap % 8) * tile_size - /* x position */ tile_x,
                          /* texture y */ (pixmap / 8) * tile_size - /* y position */ tile_y);
        ((!) tiles_pattern).set_matrix (matrix);
        cr.set_source ((!) tiles_pattern);
        cr.rectangle (/* x and y */ tile_x,
                                    tile_y,
                      /* w and h */ tile_size,
                                    tile_size);
        cr.fill ();
    }
    private void get_x_and_y (uint8 playable_id, out uint8 x, out uint8 y)
    {
        uint8 half_game_size = game_size / 2;
        if (game_size % 2 == 0)
            switch (overture_target [playable_id])
            {
                case 1: x = half_game_size - 1; y = half_game_size - 1; break;
                case 2: x = half_game_size    ; y = half_game_size - 1; break;
                case 3: x = half_game_size - 1; y = half_game_size    ; break;
                case 4: x = half_game_size    ; y = half_game_size    ; break;
                default: assert_not_reached ();
            }
        else
            switch (overture_target [playable_id])
            {
                case 1: x = half_game_size - 1; y = half_game_size - 1; break;
                case 2: x = half_game_size    ; y = half_game_size - 1; break;
                case 3: x = half_game_size + 1; y = half_game_size - 1; break;
                case 4: x = half_game_size - 1; y = half_game_size    ; break;
                case 6: x = half_game_size + 1; y = half_game_size    ; break;
                case 7: x = half_game_size - 1; y = half_game_size + 1; break;
                case 8: x = half_game_size    ; y = half_game_size + 1; break;
                case 9: x = half_game_size + 1; y = half_game_size + 1; break;
                default: assert_not_reached ();
            }
    }

    /*\
    * * drawing utilities
    \*/

    private const double HALF_PI = Math.PI_2;
    private void rounded_square (Cairo.Context cr, double x, double y, int size, double width, double radius_percent)
    {
        if (radius_percent <= 0.0)
        {
            cr.rectangle (/* x and y */ x + width / 2.0,
                                        y + width / 2.0,
                          /* w and h */ size + width,
                                        size + width);
            return;
        }

        if (radius_percent > 50.0)
            radius_percent = 50.0;
        double radius_border = radius_percent * size / 100.0;
        double radius_arc = radius_border - width / 2.0;
        double x1 = x + radius_border;
        double y1 = y + radius_border;
        double x2 = x + size - radius_border;
        double y2 = y + size - radius_border;

        cr.arc (x1, y1, radius_arc,  Math.PI, -HALF_PI);
        cr.arc (x2, y1, radius_arc, -HALF_PI,      0.0);
        cr.arc (x2, y2, radius_arc,      0.0,  HALF_PI);
        cr.arc (x1, y2, radius_arc,  HALF_PI,  Math.PI);
        cr.arc (x1, y1, radius_arc,  Math.PI, -HALF_PI);
    }

    private void highlight_tile (Cairo.Context cr, uint8 x, uint8 y, uint8 intensity, bool soft_highlight)
    {
        if (soft_highlight)
            cr.set_source_rgba (theme_manager.highlight_soft_red,
                                theme_manager.highlight_soft_green,
                                theme_manager.highlight_soft_blue,
                                theme_manager.highlight_soft_alpha);
        else
            cr.set_source_rgba (theme_manager.highlight_hard_red,
                                theme_manager.highlight_hard_green,
                                theme_manager.highlight_hard_blue,
                                theme_manager.highlight_hard_alpha);
        rounded_square (cr,
                        // TODO odd/even sizes problem
                        tile_xs [x, y] + tile_size * (HIGHLIGHT_MAX - intensity) / (2 * HIGHLIGHT_MAX),
                        tile_ys [x, y] + tile_size * (HIGHLIGHT_MAX - intensity) / (2 * HIGHLIGHT_MAX),
                        tile_size * intensity / HIGHLIGHT_MAX,
                        0,
                        theme_manager.background_radius);
        cr.fill ();
    }

    private void darken_tile (Cairo.Context cr, uint8 x, uint8 y)
    {
        double alpha = theme_manager.highlight_hard_alpha * 1.6 * (double) humans_opening_intensity / (double) HUMANS_OPENING_INTENSITY_MAX;
        cr.set_source_rgba (theme_manager.highlight_hard_red,
                            theme_manager.highlight_hard_green,
                            theme_manager.highlight_hard_blue,
                            alpha);
        rounded_square (cr,
                        // TODO odd/even sizes problem
                        tile_xs [x, y],
                        tile_ys [x, y],
                        tile_size,
                        0,
                        theme_manager.background_radius);
        cr.fill ();
    }

    private void queue_draw_tile (uint8 x, uint8 y)
        requires (x < game_size)
        requires (y < game_size)
    {
        queue_draw_area (board_x + tile_xs [x, y],
                         board_y + tile_ys [x, y],
                         tile_size,
                         tile_size);
    }

    /*\
    * * turning tiles
    \*/

    private bool last_state_set = false;
    private GameStateObject last_state;

    private inline void update_highlight_after_undo ()
        requires (last_state_set)
    {
        // get the tile that was played on and is now empty
        uint8 x;
        uint8 y;
        get_missing_tile (out x, out y);

        // clear the previous highlight (if any)
        if (show_highlight || show_mouse_highlight || (highlight_state != 0))
        {
            highlight_state = 0;
            if (show_highlight)
                set_square (highlight_x,
                            highlight_y,
                            get_pixmap (game.get_owner (highlight_x, highlight_y)),
                            /* is final animation */ false,
                            /* force redraw */ true);
            if (show_mouse_highlight)
                set_square (mouse_highlight_x,
                            mouse_highlight_y,
                            get_pixmap (game.get_owner (mouse_highlight_x, mouse_highlight_y)),
                            /* is final animation */ false,
                            /* force redraw */ true);

            if (!game.is_complete)
            {
                if (show_highlight
                 && x == highlight_x
                 && y == highlight_y)
                    highlight_state = HIGHLIGHT_MAX;
                else if (show_mouse_highlight
                      && x == mouse_highlight_x
                      && y == mouse_highlight_y)
                    highlight_state = HIGHLIGHT_MAX;
                else
                    highlight_state = 1;
            }
        }

        // set highlight on undone play position
        highlight_set = true;
        highlight_x = x;
        highlight_y = y;
        mouse_highlight_x = x;
        mouse_highlight_y = y;
        if (!mouse_is_in)
            show_highlight = true;
        else if (!show_highlight)
            show_mouse_highlight = true;

        // reload playable tiles
        if (show_playable_tiles)
        {
            init_possible_moves (); // clears previous highlights
            highlight_playable_tiles (/* force reload */ true);
        }
    }
    private void get_missing_tile (out uint8 x, out uint8 y)
    {
        y = 0;  // avoids a warning

        for (x = 0; x < game_size; x++)
        {
            for (y = 0; y < game_size; y++)
            {
                if (game.get_owner (x, y) != Player.NONE)
                    continue;
                if (last_state.get_owner (x, y) == game.current_color)
                    return;
            }
        }
        assert_not_reached ();
    }

    private void turn_ended_cb (bool undoing, bool no_draw)
    {
        if (humans_opening_intensity != 0)
        {
            bool even_board = game_size % 2 == 0;
            uint8 half_game_size = game_size / 2;
            uint8 target;
            if (even_board)
            {
                if (     (!last_state_set || last_state.get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size - 1, half_game_size - 1) != Player.NONE) target = 1;
                else if ((!last_state_set || last_state.get_owner (half_game_size    , half_game_size - 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size    , half_game_size - 1) != Player.NONE) target = 2;
                else if ((!last_state_set || last_state.get_owner (half_game_size - 1, half_game_size    ) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size - 1, half_game_size    ) != Player.NONE) target = 3;
                else if ((!last_state_set || last_state.get_owner (half_game_size    , half_game_size    ) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size    , half_game_size    ) != Player.NONE) target = 4;
                else assert_not_reached ();

                overture_target [current_overture_playable] = target;
                current_overture_playable++;
            }
            else
            {
                if (     (!last_state_set || last_state.get_owner (half_game_size - 1, half_game_size - 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size - 1, half_game_size - 1) != Player.NONE) target = 1;
                else if ((!last_state_set || last_state.get_owner (half_game_size    , half_game_size - 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size    , half_game_size - 1) != Player.NONE) target = 2;
                else if ((!last_state_set || last_state.get_owner (half_game_size + 1, half_game_size - 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size + 1, half_game_size - 1) != Player.NONE) target = 3;
                else if ((!last_state_set || last_state.get_owner (half_game_size - 1, half_game_size    ) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size - 1, half_game_size    ) != Player.NONE) target = 4;
                else if ((!last_state_set || last_state.get_owner (half_game_size + 1, half_game_size    ) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size + 1, half_game_size    ) != Player.NONE) target = 6;
                else if ((!last_state_set || last_state.get_owner (half_game_size - 1, half_game_size + 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size - 1, half_game_size + 1) != Player.NONE) target = 7;
                else if ((!last_state_set || last_state.get_owner (half_game_size    , half_game_size + 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size    , half_game_size + 1) != Player.NONE) target = 8;
                else if ((!last_state_set || last_state.get_owner (half_game_size + 1, half_game_size + 1) == Player.NONE)
                                  && game.current_state.get_owner (half_game_size + 1, half_game_size + 1) != Player.NONE) target = 9;
                else assert_not_reached ();

                overture_target [current_overture_playable] = target;
                current_overture_playable++;
                overture_target [current_overture_playable] = 10 - target;
                current_overture_playable++;
            }
        }
        if (!no_draw)
        {
            update_squares ();
            playable_tiles_highlight_state = 0;
            if (undoing)
                update_highlight_after_undo ();
            else if (show_playable_tiles)
                highlight_playable_tiles ();
        }

        last_state = game.current_state;
        last_state_set = true;
    }

    private inline void update_squares ()
    {
        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                update_square (x, y);
    }

    private inline void update_square (uint8 x, uint8 y)
        requires (game_is_set)
    {
        set_square (x, y, get_pixmap (game.get_owner (x, y)), /* is final animation */ false);
    }

    private void set_square (uint8 x, uint8 y, int pixmap, bool is_final_animation, bool force_redraw = false)
    {
        if (!force_redraw && pixmaps [x, y] == pixmap)
            return;

        if (pixmap == 0 || pixmaps [x, y] == 0)
            pixmaps [x, y] = pixmap;
        else
        {
            if (pixmap > pixmaps [x, y])
                pixmaps [x, y]++;
            else
                pixmaps [x, y]--;
            if (animate_timeout == 0)
                animate_timeout = Timeout.add (PIXMAP_FLIP_DELAY, () => {
                        bool animating = false;

                        for (uint8 ix = 0; ix < game_size; ix++)
                        {
                            for (uint8 iy = 0; iy < game_size; iy++)
                            {
                                int old = pixmaps [ix, iy];

                                if (is_final_animation  // do not rely only on flip_final_result_now, it fails randomly with hard IA (?!)
                                 && flip_final_result_now
                                 && game.is_complete)
                                    flip_final_result_tile (ix, iy);
                                else
                                    update_square (ix, iy);

                                if (pixmaps [ix, iy] != old)
                                    animating = true;
                            }
                        }

                        if (animating)
                            return Source.CONTINUE;
                        else
                        {
                            animate_timeout = 0;
                            if (!show_highlight)
                                _on_motion (mouse_position_x, mouse_position_y, /* force redraw */ true);
                            return Source.REMOVE;
                        }
                    });
        }
        queue_draw_tile (x, y);
    }

    private static int get_pixmap (Player color)
    {
        switch (color)
        {
            default:
            case Player.NONE:
                return 0;
            case Player.DARK:
                return 1;
            case Player.LIGHT:
                return 31;
        }
    }

    /*\
    * * game complete
    \*/

    internal signal void notify_final_animation (bool undo);

    private bool flip_final_result_now = false;  // the final animation is delayed until this is true

    /* set only when a game is finished */
    private Player winning_color;
    private int  n_winning_tiles;
    private Player losing_color;
    private int  n_losing_tiles;

    private void game_is_complete_cb ()
    {
        if (!game.is_complete)
            return;

        if (game.n_light_tiles == 0 || game.n_dark_tiles == 0)  // complete win
            return;

        /*
         * Show the actual final positions of the pieces before flipping the board.
         * Otherwise, it could seem like the final player placed the other's piece.
         */
        if (game_size >= 6)
            Timeout.add_seconds (2, () => {
                    if (!game.is_complete)  // in case an undo has been called
                        return Source.REMOVE;

                    notify_final_animation (/* undoing */ false);
                    set_winner_and_loser_variables ();
                    flip_final_result_now = true;
                    for (uint8 x = 0; x < game_size; x++)
                        for (uint8 y = 0; y < game_size; y++)
                            flip_final_result_tile (x, y);

                    return Source.REMOVE;
                });
    }

    private void flip_final_result_tile (uint8 x, uint8 y)
    {
        int pixmap;
        uint8 n = y * game_size + x;
        if (n < n_winning_tiles)
            pixmap = get_pixmap (winning_color);
        else if (n < n_winning_tiles + n_losing_tiles)
            pixmap = get_pixmap (losing_color);
        else
            pixmap = get_pixmap (Player.NONE);
        set_square (x, y, pixmap, /* is final animation */ true);
    }

    private void set_winner_and_loser_variables ()
    {
        n_winning_tiles = game.n_light_tiles;
        n_losing_tiles  = game.n_dark_tiles;
        if (n_losing_tiles > n_winning_tiles)
        {
            winning_color = Player.DARK;
            losing_color  = Player.LIGHT;
            int t = n_winning_tiles;
            n_winning_tiles = n_losing_tiles;
            n_losing_tiles = t;
        }
        else
        {
            winning_color = Player.LIGHT;
            losing_color  = Player.DARK;
        }
    }

    internal bool undo_final_animation ()
    {
        if (!flip_final_result_now)
            return false;

        notify_final_animation (/* undoing */ true);
        flip_final_result_now = false;
        update_squares ();
        highlight_playable_tiles ();

        return true;
    }

    /*\
    * * mouse user actions
    \*/

    private Gtk.EventControllerMotion motion_controller;    // for keeping in memory
    private Gtk.GestureMultiPress click_controller;         // for keeping in memory
    private bool mouse_is_in = false;

    private void init_mouse ()  // called on construct
    {
        motion_controller = new Gtk.EventControllerMotion (this);
        motion_controller.motion.connect (on_motion);
//        motion_controller.enter.connect (on_mouse_in);    // FIXME should work                                //  1/10
//        motion_controller.leave.connect (on_mouse_out);   // FIXME should work                                //  2/10

        click_controller = new Gtk.GestureMultiPress (this);
        click_controller.set_button (/* all buttons */ 0);
        click_controller.pressed.connect (on_click);
    }

//    private void on_mouse_in (Gtk.EventControllerMotion _motion_controller, double event_x, double event_y)   //  3/10
    protected override bool enter_notify_event (Gdk.EventCrossing event)                                        //  4/10
    {
        uint8 x;
        uint8 y;
        if (pointer_is_in_board (event.x, event.y, out x, out y))                                               //  5/10
//        if (pointer_is_in_board (event_x, event_y, out x, out y))                                             //  6/10
            on_cursor_moving_in (x, y);
        else if (mouse_is_in)
            assert_not_reached ();
        return false;                                                                                           //  7/10
    }

    private void on_cursor_moving_in (uint8 x, uint8 y)
    {
        mouse_position_x = x;
        mouse_position_y = y;
        mouse_position_set = true;
        mouse_is_in = true;
        _on_motion (x, y, /* force redraw */ true);
    }

//    private void on_mouse_out (Gtk.EventControllerMotion _motion_controller)                                  //  8/10
    protected override bool leave_notify_event (Gdk.EventCrossing event)                                        //  9/10
    {
        mouse_is_in = false;
        if (mouse_position_set)
            queue_draw_tile (mouse_highlight_x, mouse_highlight_y);
        return false;                                                                                           // 10/10
    }

    private bool pointer_is_in_board (double pos_x, double pos_y, out uint8 x, out uint8 y)
    {
        int _x = (int) Math.floor ((pos_x - (double) board_x) / (double) paving_size);
        int _y = (int) Math.floor ((pos_y - (double) board_y) / (double) paving_size);
        if (_x >= 0 && _x < game_size
         && _y >= 0 && _y < game_size)
        {
            x = (uint8) _x;
            y = (uint8) _y;
            return true;
        }
        else
        {
            x = uint8.MAX;  // garbage
            y = uint8.MAX;  // garbage
            return false;
        }
    }

    uint timeout_id = 0;
    private void on_motion (Gtk.EventControllerMotion _motion_controller, double event_x, double event_y)
    {
        uint8 x;
        uint8 y;
        if (pointer_is_in_board (event_x, event_y, out x, out y))
        {
            if (!mouse_is_in)
                on_cursor_moving_in (x, y);
            else if (x != mouse_position_x || y != mouse_position_y)
            {
                mouse_position_x = x;
                mouse_position_y = y;
                mouse_position_set = true;
                if (show_highlight
                 || (x != mouse_highlight_x)
                 || (y != mouse_highlight_y))
                {
                    if (timeout_id != 0)
                    {
                        Source.remove (timeout_id);
                        timeout_id = 0;
                    }
                    uint delay;
                    if (show_turnable_tiles)        delay = 120;
                    else if (show_playable_tiles)   delay =  50;
                    else                            delay = 200;
                    timeout_id = Timeout.add (delay, () => {
                            if (mouse_is_in)
                                _on_motion (x, y, /* force redraw */ false);
                            timeout_id = 0;
                            return Source.REMOVE;
                        });
                }
            }
        }
        else
        {
            mouse_is_in = false;
            show_mouse_highlight = false;
            if (mouse_position_set)
                queue_draw_tile (mouse_highlight_x, mouse_highlight_y);
        }
    }
    private void _on_motion (uint8 x, uint8 y, bool force_redraw)
    {
        if (!force_redraw
         && ((x != mouse_position_x)
          || (y != mouse_position_y)))
            return;

        bool old_show_mouse_highlight = show_mouse_highlight;
        unowned PossibleMove move;
        show_mouse_highlight = mouse_is_in && game.test_placing_tile (x, y, out move);

        if (show_mouse_highlight)
            clear_impossible_to_move_here_warning ();

        if (old_show_mouse_highlight && !show_mouse_highlight)
        {
            old_highlight_x = uint8.MAX;
            old_highlight_y = uint8.MAX;
        }

        uint8 old_mouse_highlight_x = mouse_highlight_x;
        uint8 old_mouse_highlight_y = mouse_highlight_y;

        mouse_highlight_x = x;
        mouse_highlight_y = y;

        if (old_mouse_highlight_x != uint8.MAX && old_mouse_highlight_y != uint8.MAX)
            queue_draw_tile (old_mouse_highlight_x, old_mouse_highlight_y);
        if (show_mouse_highlight && show_highlight)
        {
            show_highlight = false;
            if (highlight_x != x || highlight_y != y)
                queue_draw_tile (highlight_x, highlight_y);
        }
        if ((show_mouse_highlight || force_redraw)
         // happens if the mouse is out of the board and the computer starts
         && (mouse_highlight_x != uint8.MAX && mouse_highlight_y != uint8.MAX))
        {
            queue_draw_tile (mouse_highlight_x, mouse_highlight_y);
        }
    }

    private inline void on_click (Gtk.GestureMultiPress _click_controller, int n_press, double event_x, double event_y)
    {
        if (!game_is_set)
            return;

        uint button = _click_controller.get_current_button ();
        if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_SECONDARY)
            return;

        uint8 x;
        uint8 y;
        if (pointer_is_in_board (event_x, event_y, out x, out y))
        {
            mouse_is_in = true;
            show_highlight = false;
            old_highlight_x = highlight_x;
            old_highlight_y = highlight_y;
            queue_draw ();
            highlight_set = true;
            highlight_x = x;
            highlight_y = y;
            move_if_possible (highlight_x, highlight_y);
        }
    }

    /*\
    * * keyboard user actions
    \*/

    private Gtk.EventControllerKey key_controller;    // for keeping in memory

    private void init_keyboard ()  // called on construct
    {
        key_controller = new Gtk.EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
    }

    private inline bool on_key_pressed (Gtk.EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        if (!game_is_set)
            return false;

        string key = (!) (Gdk.keyval_name (keyval) ?? "");
        if (key == "")
            return false;

        if (show_highlight && (key == "space" || key == "Return" || key == "KP_Enter"))
        {
            move_if_possible (highlight_x, highlight_y);
            return true;
        }

        if ((game_size <= 4 && (key == "e" || key == "E" || key == "5" || key == "KP_5")) ||
            (game_size <= 5 && (key == "f" || key == "F" || key == "6" || key == "KP_6")) ||
            (game_size <= 6 && (key == "g" || key == "G" || key == "7" || key == "KP_7")) ||
            (game_size <= 7 && (key == "h" || key == "H" || key == "8" || key == "KP_8")) ||
            (game_size <= 8 && (key == "i" || key == "I" || key == "9" || key == "KP_9")) ||
            (game_size <= 9 && (key == "j" || key == "J" || key == "0" || key == "KP_0")))
            return false;

        old_highlight_x = highlight_x;
        old_highlight_y = highlight_y;
        switch (key)
        {
            case "Up":
            case "KP_Up":
                set_highlight_position_if_needed (Direction.TOP);
                if (highlight_y > 0) highlight_y--;
                break;
            case "Left":
            case "KP_Left":
                set_highlight_position_if_needed (Direction.LEFT);
                if (highlight_x > 0) highlight_x--;
                break;
            case "Right":
            case "KP_Right":
                set_highlight_position_if_needed (Direction.RIGHT);
                if (highlight_x < game_size - 1) highlight_x++;
                break;
            case "Down":
            case "KP_Down":
                set_highlight_position_if_needed (Direction.BOTTOM);
                if (highlight_y < game_size - 1) highlight_y++;
                break;

            case "space":
            case "Return":
            case "KP_Enter":
                if (show_mouse_highlight)
                {
                    move_if_possible (mouse_highlight_x, mouse_highlight_y);
                    return true;
                }
                else if (mouse_position_set)
                {
                    highlight_x = mouse_position_x;
                    highlight_y = mouse_position_y;
                }
                else init_highlight_on_light_tile_if_needed ();
                break;

            case "Escape": break;

            case "a": case "A": init_highlight_on_light_tile_if_needed (); highlight_x = 0; break;
            case "b": case "B": init_highlight_on_light_tile_if_needed (); highlight_x = 1; break;
            case "c": case "C": init_highlight_on_light_tile_if_needed (); highlight_x = 2; break;
            case "d": case "D": init_highlight_on_light_tile_if_needed (); highlight_x = 3; break;
            case "e": case "E": init_highlight_on_light_tile_if_needed (); highlight_x = 4; break;
            case "f": case "F": init_highlight_on_light_tile_if_needed (); highlight_x = 5; break;
            case "g": case "G": init_highlight_on_light_tile_if_needed (); highlight_x = 6; break;
            case "h": case "H": init_highlight_on_light_tile_if_needed (); highlight_x = 7; break;
            case "i": case "I": init_highlight_on_light_tile_if_needed (); highlight_x = 8; break;
            case "j": case "J": init_highlight_on_light_tile_if_needed (); highlight_x = 9; break;

            case "1": case "KP_1": init_highlight_on_light_tile_if_needed (); highlight_y = 0; break;
            case "2": case "KP_2": init_highlight_on_light_tile_if_needed (); highlight_y = 1; break;
            case "3": case "KP_3": init_highlight_on_light_tile_if_needed (); highlight_y = 2; break;
            case "4": case "KP_4": init_highlight_on_light_tile_if_needed (); highlight_y = 3; break;
            case "5": case "KP_5": init_highlight_on_light_tile_if_needed (); highlight_y = 4; break;
            case "6": case "KP_6": init_highlight_on_light_tile_if_needed (); highlight_y = 5; break;
            case "7": case "KP_7": init_highlight_on_light_tile_if_needed (); highlight_y = 6; break;
            case "8": case "KP_8": init_highlight_on_light_tile_if_needed (); highlight_y = 7; break;
            case "9": case "KP_9": init_highlight_on_light_tile_if_needed (); highlight_y = 8; break;
            case "0": case "KP_0": init_highlight_on_light_tile_if_needed (); highlight_y = 9; break;

            case "Home":
            case "KP_Home":
                init_highlight_on_light_tile_if_needed ();
                highlight_x = 0;
                break;
            case "End":
            case "KP_End":
                init_highlight_on_light_tile_if_needed ();
                highlight_x = game_size - 1;
                break;
            case "Page_Up":
            case "KP_Page_Up":
                init_highlight_on_light_tile_if_needed ();
                highlight_y = 0;
                break;
            case "Page_Down":
            case "KP_Next":     // TODO use KP_Page_Down instead of KP_Next, probably a gtk+ or vala bug; check also KP_Prior
                init_highlight_on_light_tile_if_needed ();
                highlight_y = game_size - 1;
                break;

            // allow <Tab> and <Shift><Tab> to change focus
            default:
                return false;
        }

        highlight_set = true;

        if (key != "space" && key != "Return" && key != "KP_Enter")
            clear_impossible_to_move_here_warning ();

        if (key == "Escape")
            show_highlight = false;
        else if (show_highlight)
            highlight_state = HIGHLIGHT_MAX;
        else
            show_highlight = true;

        queue_draw_tile (old_highlight_x, old_highlight_y);
        if ((old_highlight_x != highlight_x)
         || (old_highlight_y != highlight_y))
            queue_draw_tile (highlight_x, highlight_y);
        if (key != "Escape")
        {
            show_mouse_highlight = false;
            if (mouse_position_set)
                queue_draw_tile (mouse_highlight_x, mouse_highlight_y);
        }
        else if (mouse_position_set && mouse_is_in)
        {
            highlight_x = mouse_position_x;
            highlight_y = mouse_position_y;
            _on_motion (highlight_x, highlight_y, /* force redraw */ true);
        }
        return true;
    }

    private void set_highlight_position_if_needed (Direction direction)
    {
        if (mouse_position_set && show_mouse_highlight)
        {
            /* If mouse highlight is visible, use it for the keyboard highlight. */

            highlight_x = mouse_highlight_x;
            highlight_y = mouse_highlight_y;
            return;
        }

        if (highlight_set)
            /* If keyboard highlight is already set (and visible), this is good. */
            return;

        if (game.current_color == Player.LIGHT)
        {
            /* This section is for when computer started, so then is human turn. */

            init_highlight_on_light_tile ();
            return;
        }

        if (iagno_instance.computer != null && iagno_instance.player_one == Player.LIGHT)
        {
            /* This section is for when computer starts but player moves before.
               It is similar to the case of a two-players game, with an opening.
               The starting [highlight_x, highlight_y] tile is the top-left one.
               The target tile is the one that will give correct highlight after
               a move in the given direction, not directly the one to highlight. */

            if (Gtk.get_locale_direction () == Gtk.TextDirection.LTR)
                switch (direction)
                {
                    case Direction.TOP:                       highlight_y++;    break;
                    case Direction.LEFT:    highlight_x++;    highlight_y++;    break;
                    case Direction.RIGHT:                                       break;
                    case Direction.BOTTOM:  highlight_x++;                      break;
                }
            else
                switch (direction)
                {
                    case Direction.TOP:     highlight_x++;    highlight_y++;    break;
                    case Direction.LEFT:    highlight_x++;                      break;
                    case Direction.RIGHT:                     highlight_y++;    break;
                    case Direction.BOTTOM:                                      break;
                }
            return;
        }

        switch (game.opening)
        {
            /* This section is for when a human starts (for one or two players).
               The starting [highlight_x, highlight_y] tile is the top-left one.
               The target tile is the one that will give correct highlight after
               a move in the given direction, not directly the one to highlight. */

            case Opening.HUMANS:
                if (Gtk.get_locale_direction () == Gtk.TextDirection.LTR)
                    switch (direction)
                    {
                        case Direction.TOP:                       highlight_y++;    break;
                        case Direction.LEFT:    highlight_x++;    highlight_y++;    break;
                        case Direction.RIGHT:                                       break;
                        case Direction.BOTTOM:  highlight_x++;                      break;
                    }
                else
                    switch (direction)
                    {
                        case Direction.TOP:     highlight_x++;    highlight_y++;    break;
                        case Direction.LEFT:    highlight_x++;                      break;
                        case Direction.RIGHT:                     highlight_y++;    break;
                        case Direction.BOTTOM:                                      break;
                    }
                return;

            case Opening.REVERSI:
                switch (direction)
                {
                    case Direction.TOP:                                         break;
                    case Direction.LEFT:                                        break;
                    case Direction.RIGHT:   highlight_x++;    highlight_y++;    break;
                    case Direction.BOTTOM:  highlight_x++;    highlight_y++;    break;
                }
                return;

            case Opening.INVERTED:
                switch (direction)
                {
                    case Direction.TOP:     highlight_x++;                      break;
                    case Direction.LEFT:                      highlight_y++;    break;
                    case Direction.RIGHT:   highlight_x++;                      break;
                    case Direction.BOTTOM:                    highlight_y++;    break;
                }
                return;

            case Opening.ALTER_TOP:
                switch (direction)
                {
                    case Direction.TOP:     highlight_x++;    highlight_y += 3; break;
                    case Direction.LEFT:                      highlight_y += 2; break;
                    case Direction.RIGHT:   highlight_x++;    highlight_y += 2; break;
                    case Direction.BOTTOM:                    highlight_y++;    break;
                }
                return;

            case Opening.ALTER_LEFT:
                switch (direction)
                {
                    case Direction.TOP:     highlight_x += 2;                   break;
                    case Direction.LEFT:    highlight_x += 3; highlight_y++;    break;
                    case Direction.RIGHT:   highlight_x++;                      break;
                    case Direction.BOTTOM:  highlight_x += 2; highlight_y++;    break;
                }
                return;

            case Opening.ALTER_RIGHT:
                switch (direction)
                {
                    case Direction.TOP:     highlight_x--;                      break;
                    case Direction.LEFT:                                        break;
                    case Direction.RIGHT:   highlight_x -= 2; highlight_y++;    break;
                    case Direction.BOTTOM:  highlight_x--;    highlight_y++;    break;
                }
                return;

            case Opening.ALTER_BOTTOM:
                switch (direction)
                {
                    case Direction.TOP:                                         break;
                    case Direction.LEFT:                      highlight_y--;    break;
                    case Direction.RIGHT:   highlight_x++;    highlight_y--;    break;
                    case Direction.BOTTOM:  highlight_x++;    highlight_y -= 2; break;
                }
                return;
        }
        assert_not_reached ();
    }

    private void init_highlight_on_light_tile_if_needed ()
    {
        if (!highlight_set && game.current_color == Player.LIGHT)
            init_highlight_on_light_tile ();
    }

    private void init_highlight_on_light_tile ()
      // requires (!highlight_set)
      // requires (game.current_color == Player.LIGHT)
    {
        uint8 half_size = (uint8) (game_size / 2);
        if (game.get_owner (half_size - 1, half_size - 1) == Player.LIGHT)
        {
            highlight_x = half_size - 1;
            highlight_y = highlight_x;
            return;
        }
        if (game.get_owner (half_size, half_size) == Player.LIGHT)
        {
            highlight_x = half_size;
            highlight_y = half_size;
            return;
        }
        if (game.get_owner (half_size - 1, half_size) == Player.LIGHT)
        {
            highlight_x = half_size - 1;
            highlight_y = half_size;
            return;
        }
        if (game.get_owner (half_size, half_size - 1) == Player.LIGHT)
        {
            highlight_x = half_size;
            highlight_y = half_size - 1;
            return;
        }
        assert_not_reached ();
    }

    private enum Direction {
        TOP,
        LEFT,
        RIGHT,
        BOTTOM;
    }

    /*\
    * * testing move
    \*/

    private uint8 playable_tiles_highlight_state;
    private bool [,] possible_moves;

    private void init_possible_moves ()
    {
        playable_tiles_highlight_state = 0;
        possible_moves = new bool [game_size, game_size];

        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                possible_moves [x, y] = false;
    }

    private inline void move_if_possible (uint8 x, uint8 y)
    {
        if ((iagno_instance.computer == null || iagno_instance.player_one == game.current_color)
         && (game.get_owner (x, y) != Player.NONE))
            highlight_playable_tiles ();
        else
            move (x, y);
    }

    private inline void highlight_playable_tiles (bool force_reload = false)
    {
        if (!force_reload && playable_tiles_highlight_state != 0)
            return;

        SList<PossibleMove?> moves;
        game.get_possible_moves (out moves);
        playable_tiles_highlight_state = 1;
        moves.@foreach ((move) => {
                uint8 x = ((!) move).x;
                uint8 y = ((!) move).y;
                possible_moves [x, y] = true;
                queue_draw_tile (x, y);
            });
    }
}
