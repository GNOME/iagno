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

private class GameView : Gtk.DrawingArea
{
    private Gtk.DrawingArea _scoreboard;
    [CCode (notify = false)] internal Gtk.DrawingArea scoreboard {
        private get { return _scoreboard; }
        internal set
        {
            _scoreboard = value;
            _scoreboard.draw.connect (draw_scoreboard);
        }
    }

    /* Theme */
    private string pieces_file;

    private double background_red = 0.2;
    private double background_green = 0.6;
    private double background_blue = 0.4;
    private int background_radius = 0;

    private double texture_alpha = 0.25;
    private bool   apply_texture = false;

    private double mark_red = 0.2;
    private double mark_green = 0.6;
    private double mark_blue = 0.4;
    private int mark_width = 2;

    private double border_red = 0.1;
    private double border_green = 0.1;
    private double border_blue = 0.1;
    private int border_width = 3;
    private double half_border_width = 1.5;

    private double spacing_red = 0.1;
    private double spacing_green = 0.3;
    private double spacing_blue = 0.2;
    private int spacing_width = 2;

    private double highlight_red = 0.1;
    private double highlight_green = 0.3;
    private double highlight_blue = 0.2;
    private double highlight_alpha = 0.4;

    // private int margin_width = 0;

    [CCode (notify = false)] internal string sound_flip     { internal get; private set; }
    [CCode (notify = false)] internal string sound_gameover { internal get; private set; }

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
    private Cairo.Pattern? scoreboard_tiles_pattern = null;
    private Cairo.Pattern? board_pattern = null;

    private bool noise_pixbuf_loaded = false;

    /* The images being showed on each location */
    private int [,] pixmaps;

    /* Animation timer */
    private uint animate_timeout = 0;

    // private double cursor = 0;
    private int current_player_number = 0;

    internal signal void move (uint8 x, uint8 y);

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
            game_is_set = true;
            game_size = _game.size;
            pixmaps = new int [game_size, game_size];
            tile_xs = new int [game_size, game_size];
            tile_ys = new int [game_size, game_size];
            for (uint8 x = 0; x < game_size; x++)
                for (uint8 y = 0; y < game_size; y++)
                    pixmaps [x, y] = get_pixmap (_game.get_owner (x, y));
            _game.completeness_updated.connect (game_is_complete_cb);
            _game.turn_ended.connect (turn_ended_cb);

            show_highlight = false;
            bool odd_game = game_size % 2 != 0; // always start on center on odd games
            highlight_set = _game.alternative_start || odd_game;
            highlight_x = odd_game ? (uint8) (game_size / 2) : (uint8) (game_size / 2 - 1);
            highlight_y = highlight_x;
            highlight_state = 0;

            queue_draw ();
        }
    }

    construct
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK
                  | Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK);
        set_size_request (350, 350);
    }

    private Iagno iagno_instance;
    internal GameView (Iagno iagno_instance)
    {
        this.iagno_instance = iagno_instance;
    }

    /*\
    * * theme
    \*/

    private string? _theme = null;
    [CCode (notify = false)] internal string? theme
    {
        get { return _theme; }
        set {
            KeyFile key = new KeyFile ();
            if (value == null || (!) value == "default")
                set_default_theme (ref key);
            else
                try
                {
                    string key_path = Path.build_filename (DATA_DIRECTORY, "themes", "key");
                    string filepath = Path.build_filename (key_path, (!) value);
                    if (Path.get_dirname (filepath) != key_path)
                        throw new FileError.FAILED ("Theme file is not in the \"key\" directory.");

                    key.load_from_file (filepath, GLib.KeyFileFlags.NONE);
                }
                catch (Error e)
                {
                    warning ("Failed to load theme: %s", e.message);
                    set_default_theme (ref key);
                    value = "default";
                }

            load_theme (key);
            _theme = value;

            /* redraw all */
            tiles_pattern = null;
            // scoreboard_tiles_pattern = null;
            scoreboard.queue_draw ();
            queue_draw ();
        }
    }

    private void set_default_theme (ref KeyFile key)
    {
        Gtk.Settings? defaults = Gtk.Settings.get_default ();

        string filename;
        if (defaults != null && "HighContrast" in ((!) defaults).gtk_theme_name)
            filename = "high_contrast.theme";
        else if (defaults != null && (((!) defaults).gtk_application_prefer_dark_theme == true
                                   || ((!) defaults).gtk_theme_name == "Adwaita-dark"))
            filename = "adwaita.theme";
        else
            filename = "classic.theme";

        string filepath = Path.build_filename (DATA_DIRECTORY, "themes", "key", filename);
        try
        {
            key.load_from_file (filepath, GLib.KeyFileFlags.NONE);
        }
        catch { assert_not_reached (); }
    }

    private void load_theme (GLib.KeyFile key)
    {
        try
        {
            string svg_path = Path.build_filename (DATA_DIRECTORY, "themes", "svg");
            pieces_file = Path.build_filename (svg_path, key.get_string ("Pieces", "File"));
            if (Path.get_dirname (pieces_file) != svg_path)
                pieces_file = Path.build_filename (svg_path, "black_and_white.svg");

            background_red    = key.get_double  ("Background", "Red");
            background_green  = key.get_double  ("Background", "Green");
            background_blue   = key.get_double  ("Background", "Blue");
            background_radius = key.get_integer ("Background", "Radius");

            texture_alpha     = key.get_double  ("Background", "TextureAlpha");
            apply_texture     = (texture_alpha > 0.0) && (texture_alpha <= 1.0);

            mark_red          = key.get_double  ("Mark", "Red");
            mark_green        = key.get_double  ("Mark", "Green");
            mark_blue         = key.get_double  ("Mark", "Blue");
            mark_width        = key.get_integer ("Mark", "Width");

            border_red        = key.get_double  ("Border", "Red");
            border_green      = key.get_double  ("Border", "Green");
            border_blue       = key.get_double  ("Border", "Blue");
            border_width      = key.get_integer ("Border", "Width");
            half_border_width = (double) border_width / 2.0;

            spacing_red       = key.get_double  ("Spacing", "Red");
            spacing_green     = key.get_double  ("Spacing", "Green");
            spacing_blue      = key.get_double  ("Spacing", "Blue");
            spacing_width     = key.get_integer ("Spacing", "Width");

            highlight_red     = key.get_double  ("Highlight", "Red");
            highlight_green   = key.get_double  ("Highlight", "Green");
            highlight_blue    = key.get_double  ("Highlight", "Blue");
            highlight_alpha   = key.get_double  ("Highlight", "Alpha");

            // margin_width     = key.get_integer  ("Margin", "Width");

            sound_flip          = key.get_string  ("Sound", "Flip");
            sound_gameover      = key.get_string  ("Sound", "GameOver");
        }
        catch (KeyFileError e)      // TODO better
        {
            warning ("Errors when loading theme: %s", e.message);
        }
    }

    /*\
    * * drawing
    \*/

    private int paving_size;
    private int tile_size;
    private int board_size;
    private int [,] tile_xs;
    private int [,] tile_ys;

    private inline void calculate ()
        requires (game_is_set)
    {
        int allocated_width  = get_allocated_width ();
        int allocated_height = get_allocated_height ();
        int size = int.min (allocated_width, allocated_height);
        paving_size = (size - 2 * border_width + spacing_width) / game_size;
        tile_size = paving_size - spacing_width;
        board_size = paving_size * game_size - spacing_width + 2 * border_width;
        board_x = (allocated_width  - board_size) / 2 + border_width;
        board_y = (allocated_height - board_size) / 2 + border_width;

        for (uint8 x = 0; x < game_size; x++)
        {
            for (uint8 y = 0; y < game_size; y++)
            {
                tile_xs [x, y] = paving_size * (int) x;
                tile_ys [x, y] = paving_size * (int) y;
            }
        }
    }

    internal override bool draw (Cairo.Context cr)
    {
        if (!game_is_set)
            return false;

        // initialize
        calculate ();

        if (board_pattern == null || tiles_pattern == null || render_size != tile_size)
            init_patterns (cr);

        // draw board
        cr.translate (board_x - border_width, board_y - border_width);

        cr.set_source ((!) board_pattern);
        cr.rectangle (0, 0, /* width and height */ board_size, board_size);
        cr.fill ();

        // draw tiles (and highlight)
        cr.translate (border_width, border_width);

        draw_highlight (cr);
        draw_playables (cr);

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
        load_image (context, tile_size * 8, tile_size * 4);
        tiles_pattern = new Cairo.Pattern.for_surface (surface);

        // noise pattern
        Gdk.Pixbuf? noise_pixbuf = null;
        Cairo.Pattern? noise_pattern = null;

        if (apply_texture)
        {
            try
            {
                noise_pixbuf = new Gdk.Pixbuf.from_resource_at_scale ("/org/gnome/Reversi/ui/noise.png",
                                                                      /* x */ tile_size,
                                                                      /* y */ tile_size,
                                                                      /* preserve aspect ratio */ false);
            }
            catch (Error e) { warning (e.message); }
            noise_pixbuf_loaded = noise_pixbuf != null;
            if (noise_pixbuf_loaded)
            {
                surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size,
                                                                                                  tile_size);
                context = new Cairo.Context (surface);
                Gdk.cairo_set_source_pixbuf (context, (!) noise_pixbuf, 0, 0);
                context.paint_with_alpha (texture_alpha);
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
        cr.set_source_rgba (spacing_red, spacing_green, spacing_blue, 1.0);
        cr.rectangle (half_border_width, half_border_width, /* width and height */ board_size - border_width, board_size - border_width);
        cr.fill_preserve ();
        cr.set_source_rgba (border_red, border_green, border_blue, 1.0);
        cr.set_line_width (border_width);
        cr.stroke ();
    }

    private inline void draw_tiles_background (Cairo.Context cr, ref Cairo.Pattern? noise_pattern)
    {
        cr.translate (border_width, border_width);

        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                draw_tile_background (cr, ref noise_pattern, tile_xs [x, y], tile_ys [x, y]);
    }
    private inline void draw_tile_background (Cairo.Context cr, ref Cairo.Pattern? noise_pattern, int tile_x, int tile_y)
    {
        cr.set_source_rgba (background_red, background_green, background_blue, 1.0);
        rounded_square (cr, tile_x, tile_y, tile_size, 0, background_radius);
        if (apply_texture && noise_pixbuf_loaded)
        {
            cr.fill_preserve ();

            var matrix = Cairo.Matrix.identity ();
            matrix.translate (-tile_x, -tile_y);
            ((!) noise_pattern).set_matrix (matrix);
            cr.set_source ((!) noise_pattern);
        }
        cr.fill ();
    }

    private inline void draw_highlight (Cairo.Context cr)
    {
        if (game.is_complete)   // TODO highlight last played tile on game.is_complete, even if it's the opponent one...
            return;

        for (uint8 x = 0; x < game_size; x++)
            for (uint8 y = 0; y < game_size; y++)
                draw_tile_highlight (cr, x, y);
    }
    private inline void draw_tile_highlight (Cairo.Context cr, uint8 x, uint8 y)
    {
        bool display_mouse_highlight = !show_highlight  // no mouse highlight if keyboard one
                                    && (show_mouse_highlight    || highlight_state != 0)
                                    && (mouse_highlight_x == x)
                                    && (mouse_highlight_y == y)
                                    // disable the hover if the computer is thinking; that should not happen with current AI
                                    && (iagno_instance.player_one == game.current_color || iagno_instance.computer == null);

        bool display_keybd_highlight = show_highlight
                                    && !show_mouse_highlight
                                    && (highlight_x == x)
                                    && (highlight_y == y);

        // disappearing keyboard highlight after Escape pressed, if mouse hovered tile is not playable (else it is selected)
        bool display_ghost_highlight = !show_highlight
                                    && !show_mouse_highlight
                                    && highlight_state != 0
                                    && (old_highlight_x == x)
                                    && (old_highlight_y == y);

        if (!display_mouse_highlight && !display_keybd_highlight && !display_ghost_highlight)
            return;

        bool highlight_on = show_highlight || (show_mouse_highlight && (game.get_owner (x, y) == Player.NONE));

        /* manage animated highlight */
        if (highlight_on && highlight_state != HIGHLIGHT_MAX)
        {
            highlight_state++;
            queue_draw_area (board_x + tile_xs [x, y], board_y + tile_ys [x, y], tile_size, tile_size);
        }
        else if (!highlight_on && highlight_state != 0)
        {
            // either we hit Escape with a keyboard highlight and the mouse does not hover a playable tile,
            // or we moved mouse from a playable tile to a non playable one; in both cases, we decrease the
            // highlight state and redraw for the mouse highlight to re-animate when re-entering a playable
            // tile, or for the keyboard highlight to animate when disappearing; the first displays nothing
            highlight_state--;
            queue_draw_area (board_x + tile_xs [x, y], board_y + tile_ys [x, y], tile_size, tile_size);
            if (old_highlight_x != x || old_highlight_y != y)   // is not a keyboard highlight disappearing
                return;
        }

        /* draw animated highlight */
        cr.set_source_rgba (highlight_red, highlight_green, highlight_blue, highlight_alpha);
        rounded_square (cr,
                        // TODO odd/even sizes problem
                        tile_xs [x, y] + tile_size * (HIGHLIGHT_MAX - highlight_state) / (2 * HIGHLIGHT_MAX),
                        tile_ys [x, y] + tile_size * (HIGHLIGHT_MAX - highlight_state) / (2 * HIGHLIGHT_MAX),
                        tile_size * highlight_state / HIGHLIGHT_MAX,
                        0,
                        background_radius);
        cr.fill ();
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

        int texture_x = (pixmap % 8) * tile_size;
        int texture_y = (pixmap / 8) * tile_size;

        var matrix = Cairo.Matrix.identity ();
        matrix.translate (texture_x - tile_x, texture_y - tile_y);
        ((!) tiles_pattern).set_matrix (matrix);
        cr.set_source ((!) tiles_pattern);
        cr.rectangle (tile_x, tile_y, /* width and height */ tile_size, tile_size);
        cr.fill ();
    }

    /*\
    * * drawing utilities
    \*/

    private const double HALF_PI = Math.PI / 2.0;
    private void rounded_square (Cairo.Context cr, double x, double y, int size, double width, double radius_percent)
    {
        if (radius_percent <= 0)
        {
            cr.rectangle (x + width / 2.0, y + width / 2.0, /* width and height */ size + width, size + width);
            return;
        }

        if (radius_percent > 50)
            radius_percent = 50;
        double radius_border = radius_percent * size / 100.0;
        double radius_arc = radius_border - width / 2.0;
        double x1 = x + radius_border;
        double y1 = y + radius_border;
        double x2 = x + size - radius_border;
        double y2 = y + size - radius_border;

        cr.arc (x1, y1, radius_arc,  Math.PI, -HALF_PI);
        cr.arc (x2, y1, radius_arc, -HALF_PI,        0);
        cr.arc (x2, y2, radius_arc,        0,  HALF_PI);
        cr.arc (x1, y2, radius_arc,  HALF_PI,  Math.PI);
        cr.arc (x1, y1, radius_arc,  Math.PI, -HALF_PI);
    }

    private void load_image (Cairo.Context c, int width, int height)
    {
        try
        {
            var h = new Rsvg.Handle.from_file (pieces_file);

            var m = Cairo.Matrix.identity ();
            m.scale ((double) width / h.width, (double) height / h.height);
            c.set_matrix (m);
            h.render_cairo (c);

            return;
        }
        catch (Error e)
        {
            /* Fall through and try loading as a pixbuf */
        }

        try
        {
            var p = new Gdk.Pixbuf.from_file_at_scale (pieces_file, width, height, false);
            Gdk.cairo_set_source_pixbuf (c, p, 0, 0);
            c.paint ();
        }
        catch (Error e)
        {
            warning ("Failed to load theme image %s: %s", pieces_file, e.message);
        }
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
        if (!show_highlight)
            show_mouse_highlight = true;
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
        if (!no_draw)
        {
            update_squares ();
            if (undoing)
                update_highlight_after_undo ();
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
                                _motion_notify_event (mouse_position_x, mouse_position_y, /* force redraw */ true);
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

        flip_final_result_now = false;
        update_squares ();

        return true;
    }

    /*\
    * * user actions
    \*/

    internal override bool button_press_event (Gdk.EventButton event)
    {
        if (!game_is_set)
            return false;

        if (event.button == Gdk.BUTTON_PRIMARY || event.button == Gdk.BUTTON_SECONDARY)
        {
            int8 x = (int8) ((event.x - board_x) / paving_size);
            int8 y = (int8) ((event.y - board_y) / paving_size);
            if (game.current_state.is_valid_location_signed (x, y))
            {
                show_highlight = false;
                queue_draw ();
                highlight_set = true;
                highlight_x = (uint8) x;
                highlight_y = (uint8) y;
                move (highlight_x, highlight_y);
                if (game.test_placing_tile (highlight_x, highlight_y))
                    queue_draw_tile (highlight_x, highlight_y);
            }
        }

        return true;
    }

    internal override bool motion_notify_event (Gdk.EventMotion event)
    {
        uint8 x = (uint8) ((event.x - board_x) / paving_size);
        uint8 y = (uint8) ((event.y - board_y) / paving_size);
        if ((x >= 0 && x < game_size)
         && (y >= 0 && y < game_size)
         && ((x != mouse_position_x)
          || (y != mouse_position_y)))
        {
            mouse_position_x = x;
            mouse_position_y = y;
            mouse_position_set = true;
            if (show_highlight
             || (x != mouse_highlight_x)
             || (y != mouse_highlight_y))
                Timeout.add (200, () => { _motion_notify_event (x, y); return Source.REMOVE; });
        }

        return base.motion_notify_event (event);
    }
    private void _motion_notify_event (uint8 x, uint8 y, bool force_redraw = false)
    {
        if (!force_redraw
         && ((x != mouse_position_x)
          || (y != mouse_position_y)))
            return;

        bool old_show_mouse_highlight = show_mouse_highlight;
        show_mouse_highlight = game.test_placing_tile (x, y);

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
        if (show_mouse_highlight || force_redraw)
        {
            queue_draw_tile (mouse_highlight_x, mouse_highlight_y);
        }
    }

    internal override bool key_press_event (Gdk.EventKey event)
    {
        if (!game_is_set)
            return false;

        string key = (!) (Gdk.keyval_name (event.keyval) ?? "");

        if (show_highlight && (key == "space" || key == "Return" || key == "KP_Enter"))
        {
            move (highlight_x, highlight_y);
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
            case "Left":
            case "KP_Left":
                if (mouse_position_set && show_mouse_highlight) { highlight_x = mouse_highlight_x; highlight_y = mouse_highlight_y; }
                else if (!highlight_set && game.current_color == Player.LIGHT) highlight_y = game_size / 2;
                if (highlight_x > 0) highlight_x--;
                break;
            case "Right":
            case "KP_Right":
                if (mouse_position_set && show_mouse_highlight) { highlight_x = mouse_highlight_x; highlight_y = mouse_highlight_y; }
                else if (!highlight_set)
                {
                    highlight_x = game_size / 2;
                    if (game.current_color == Player.DARK) highlight_y = highlight_x;
                }
                if (highlight_x < game_size - 1) highlight_x++;
                break;
            case "Up":
            case "KP_Up":
                if (mouse_position_set && show_mouse_highlight) { highlight_x = mouse_highlight_x; highlight_y = mouse_highlight_y; }
                else if (!highlight_set && game.current_color == Player.LIGHT) highlight_x = game_size / 2;
                if (highlight_y > 0) highlight_y--;
                break;
            case "Down":
            case "KP_Down":
                if (mouse_position_set && show_mouse_highlight) { highlight_x = mouse_highlight_x; highlight_y = mouse_highlight_y; }
                else if (!highlight_set)
                {
                    highlight_y = game_size / 2;
                    if (game.current_color == Player.DARK) highlight_x = highlight_y;
                }
                if (highlight_y < game_size - 1) highlight_y++;
                break;

            case "space":
            case "Return":
            case "KP_Enter":
                if (show_mouse_highlight)
                {
                    move (mouse_highlight_x, mouse_highlight_y);
                    return true;
                }
                else if (mouse_position_set)
                {
                    highlight_x = mouse_position_x;
                    highlight_y = mouse_position_y;
                }
                break;

            case "Escape": break;

            case "a": case "A": highlight_x = 0; break;
            case "b": case "B": highlight_x = 1; break;
            case "c": case "C": highlight_x = 2; break;
            case "d": case "D": highlight_x = 3; break;
            case "e": case "E": highlight_x = 4; break;
            case "f": case "F": highlight_x = 5; break;
            case "g": case "G": highlight_x = 6; break;
            case "h": case "H": highlight_x = 7; break;
            case "i": case "I": highlight_x = 8; break;
            case "j": case "J": highlight_x = 9; break;

            case "1": case "KP_1": highlight_y = 0; break;
            case "2": case "KP_2": highlight_y = 1; break;
            case "3": case "KP_3": highlight_y = 2; break;
            case "4": case "KP_4": highlight_y = 3; break;
            case "5": case "KP_5": highlight_y = 4; break;
            case "6": case "KP_6": highlight_y = 5; break;
            case "7": case "KP_7": highlight_y = 6; break;
            case "8": case "KP_8": highlight_y = 7; break;
            case "9": case "KP_9": highlight_y = 8; break;
            case "0": case "KP_0": highlight_y = 9; break;

            case "Home":
            case "KP_Home":
                highlight_x = 0;
                break;
            case "End":
            case "KP_End":
                highlight_x = game_size - 1;
                break;
            case "Page_Up":
            case "KP_Page_Up":
                highlight_y = 0;
                break;
            case "Page_Down":
            case "KP_Next":     // TODO use KP_Page_Down instead of KP_Next, probably a gtk+ or vala bug; check also KP_Prior
                highlight_y = game_size - 1;
                break;

            // allow <Tab> and <Shift><Tab> to change focus
            default:
                return false;
        }

        highlight_set = true;

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
        else if (mouse_position_set)
        {
            highlight_x = mouse_position_x;
            highlight_y = mouse_position_y;
            _motion_notify_event (highlight_x, highlight_y, /* force redraw */ true);
        }
        return true;
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
    * * Scoreboard
    \*/

    private bool draw_scoreboard (Cairo.Context cr)
    {
        int height = scoreboard.get_allocated_height ();
        int width = scoreboard.get_allocated_width ();
        double half_height = height / 2.0;

        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);

        cr.save ();

        cr.set_source_rgba (mark_red, mark_green, mark_blue, 1.0);
        cr.set_line_width (mark_width);

        cr.translate (0, current_player_number * half_height);
        cr.move_to (height / 4.0, height / 8.0);
        cr.line_to (width - 5.0 * height / 8.0, height / 4.0);
        cr.line_to (height / 4.0, 3.0 * height / 8.0);
        cr.stroke ();

        cr.restore ();

        // if (scoreboard_tiles_pattern == null)
        // {
            /* prepare drawing of pieces */
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, height * 4, height * 2);
            var c = new Cairo.Context (surface);
            load_image (c, height * 4, height * 2);
            scoreboard_tiles_pattern = new Cairo.Pattern.for_surface (surface);

            cr.translate (width - half_height, 0);
            var matrix = Cairo.Matrix.identity ();

            /* draw dark piece */
            matrix.translate (half_height, 0);
            ((!) scoreboard_tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) scoreboard_tiles_pattern);
            cr.rectangle (0, 0, /* width and height */ half_height, half_height);
            cr.fill ();

            /* draw white piece */
            matrix.translate (3 * height, height);
            ((!) scoreboard_tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) scoreboard_tiles_pattern);
            cr.rectangle (0, half_height, /* width and height */ half_height, half_height);
            cr.fill ();
        // }

        // TODO
        /* if (cursor > current_player_number)
        {
            cursor -= 0.14;
            if (cursor < 0)
                cursor = 0;
            scoreboard.queue_draw ();
        }
        else if (cursor < current_player_number)
        {
            cursor += 0.14;
            if (cursor > 1)
                cursor = 1;
            scoreboard.queue_draw ();
        } */

        return true;
    }

    internal void update_scoreboard ()
        requires (game_is_set)
    {
        current_player_number = (game.current_color == Player.DARK) ? 0 : 1;
        scoreboard.queue_draw ();  // TODO queue_draw_area (…), or only refresh part of the DrawingArea, or both
    }
}
