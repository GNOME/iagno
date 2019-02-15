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

    private double mark_red = 0.2;
    private double mark_green = 0.6;
    private double mark_blue = 0.4;
    private int mark_width = 2;

    private double border_red = 0.1;
    private double border_green = 0.1;
    private double border_blue = 0.1;
    private int border_width = 3;

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

    [CCode (notify = false)] private int board_x { private get { return (get_allocated_width () - board_size) / 2; }}
    [CCode (notify = false)] private int board_y { private get { return (get_allocated_height () - board_size) / 2; }}

    /* Keyboard */
    private bool show_highlight;
    private uint8 highlight_x;
    private uint8 highlight_y;
    private int highlight_state;
    private const int HIGHLIGHT_MAX = 5;

    /* Delay in milliseconds between tile flip frames */
    private const int PIXMAP_FLIP_DELAY = 20;

    /* Pre-rendered image */
    private uint render_size = 0;
    private Cairo.Pattern? tiles_pattern = null;
    private Cairo.Pattern? scoreboard_tiles_pattern = null;

    /* The images being showed on each location */
    private int [,] pixmaps;

    /* Animation timer */
    private uint animate_timeout = 0;

    // private double cursor = 0;
    private int current_player_number = 0;

    internal signal void move (uint8 x, uint8 y);

    private bool game_is_set = false;
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
            pixmaps = new int [_game.size, _game.size];
            for (uint8 x = 0; x < _game.size; x++)
                for (uint8 y = 0; y < _game.size; y++)
                    pixmaps [x, y] = get_pixmap (_game.get_owner (x, y));
            _game.notify ["is-complete"].connect (game_is_complete_cb);
            _game.square_changed.connect (square_changed_cb);

            show_highlight = false;
            highlight_x = 3;    // TODO default on 3 3 / 4 4 (on 8×8 board) when dark and
            highlight_y = 3;    // 3 4 / 4 3 when light, depending on first key pressed
            highlight_state = 0;

            queue_draw ();
        }
    }

    construct
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);
        set_size_request (350, 350);
    }

    /*\
    * * theme
    \*/

    private string? _theme = null;
    [CCode (notify = false)] internal string? theme
    {
        get { return _theme; }
        set {
            var key = new KeyFile ();
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

            mark_red          = key.get_double  ("Mark", "Red");
            mark_green        = key.get_double  ("Mark", "Green");
            mark_blue         = key.get_double  ("Mark", "Blue");
            mark_width        = key.get_integer ("Mark", "Width");

            border_red        = key.get_double  ("Border", "Red");
            border_green      = key.get_double  ("Border", "Green");
            border_blue       = key.get_double  ("Border", "Blue");
            border_width      = key.get_integer ("Border", "Width");

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

    private void calculate ()
        requires (game_is_set)
    {
        int size = int.min (get_allocated_width (), get_allocated_height ());
        paving_size = (size - 2 * border_width + spacing_width) / game.size;
        tile_size = paving_size - spacing_width;
        /* board_size excludes its borders */
        board_size = paving_size * game.size - spacing_width;
    }

    internal override bool draw (Cairo.Context cr)
    {
        if (!game_is_set)
            return false;

        calculate ();

        if (tiles_pattern == null || render_size != tile_size)
        {
            render_size = tile_size;
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size * 8, tile_size * 4);
            var c = new Cairo.Context (surface);
            load_image (c, tile_size * 8, tile_size * 4);
            tiles_pattern = new Cairo.Pattern.for_surface (surface);
        }

        cr.translate (board_x, board_y);

        /* draw board */
        cr.set_source_rgba (spacing_red, spacing_green, spacing_blue, 1.0);
        cr.rectangle (-border_width / 2.0, -border_width / 2.0, board_size + border_width, board_size + border_width);
        cr.fill_preserve ();
        cr.set_source_rgba (border_red, border_green, border_blue, 1.0);
        cr.set_line_width (border_width);
        cr.stroke ();

        /* draw tiles */
        for (var x = 0; x < game.size; x++)
        {
            for (var y = 0; y < game.size; y++)
            {
                int tile_x = x * paving_size;
                int tile_y = y * paving_size;

                /* draw background */
                cr.set_source_rgba (background_red, background_green, background_blue, 1.0);
                rounded_square (cr, tile_x, tile_y, tile_size, 0, background_radius);
                cr.fill ();

                if (highlight_x == x && highlight_y == y && (show_highlight || highlight_state != 0) && !game.is_complete)  // TODO on game.is_complete…
                {
                    /* manage animated highlight */
                    if (show_highlight && highlight_state != HIGHLIGHT_MAX)
                    {
                        highlight_state ++;
                        queue_draw_area (board_x + tile_x, board_y + tile_y, tile_size, tile_size);
                    }
                    else if (!show_highlight && highlight_state != 0)
                        highlight_state = 0;    // TODO highlight_state--; on mouse click, conflict updating coords & showing the anim on previous place

                    /* draw animated highlight */
                    cr.set_source_rgba (highlight_red, highlight_green, highlight_blue, highlight_alpha);
                    rounded_square (cr,
                                    tile_x + tile_size * (HIGHLIGHT_MAX - highlight_state) / (2 * HIGHLIGHT_MAX),     // TODO odd/even sizes problem
                                    tile_y + tile_size * (HIGHLIGHT_MAX - highlight_state) / (2 * HIGHLIGHT_MAX),
                                    tile_size * highlight_state / HIGHLIGHT_MAX,
                                    0,
                                    background_radius);
                    cr.fill ();
                }

                /* draw pieces */
                if (pixmaps [x, y] == 0)
                    continue;

                int texture_x = (pixmaps [x, y] % 8) * tile_size;
                int texture_y = (pixmaps [x, y] / 8) * tile_size;

                var matrix = Cairo.Matrix.identity ();
                matrix.translate (texture_x - tile_x, texture_y - tile_y);
                ((!) tiles_pattern).set_matrix (matrix);
                cr.set_source ((!) tiles_pattern);
                cr.rectangle (tile_x, tile_y, tile_size, tile_size);
                cr.fill ();
            }
        }
        return false;
    }

    private const double HALF_PI = Math.PI / 2.0;
    private void rounded_square (Cairo.Context cr, double x, double y, int size, double width, double radius_percent)
    {
        if (radius_percent <= 0)
        {
            cr.rectangle (x + width / 2.0, y + width / 2.0, size + width, size + width);
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

    private void square_changed_cb (uint8 x, uint8 y, Player replacement)
    {
        if (replacement == Player.NONE)
        {
            highlight_x = x;
            highlight_y = y;
        }
        update_square (x, y);
    }

    private void update_square (uint8 x, uint8 y)
        requires (game_is_set)
    {
        /* An undo occurred after the game was complete */
        if (flip_final_result_now)
            flip_final_result_now = false;

        set_square (x, y, get_pixmap (game.get_owner (x, y)));
    }

    private void set_square (uint8 x, uint8 y, int pixmap)
    {
        if (pixmaps [x, y] == pixmap)
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
                animate_timeout = Timeout.add (PIXMAP_FLIP_DELAY, animate_cb);
        }
        queue_draw_area ((int) (board_x + x * paving_size),
                         (int) (board_y + y * paving_size),
                         tile_size,
                         tile_size);
    }

    private bool animate_cb ()
        requires (game_is_set)
    {
        bool animating = false;

        for (uint8 x = 0; x < game.size; x++)
        {
            for (uint8 y = 0; y < game.size; y++)
            {
                int old = pixmaps [x, y];

                if (flip_final_result_now && game.is_complete)
                    flip_final_result_tile (x, y);
                else
                    update_square (x, y);

                if (pixmaps [x, y] != old)
                    animating = true;
            }
        }

        if (!animating)
        {
            animate_timeout = 0;
            return Source.REMOVE;
        }

        return Source.CONTINUE;
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
        if (!game.is_complete)  // we're connecting to a property change, not a signal
            return;

        if (game.n_light_tiles == 0 || game.n_dark_tiles == 0)  // complete win
            return;

        /*
         * Show the actual final positions of the pieces before flipping the board.
         * Otherwise, it could seem like the final player placed the other's piece.
         */
        Timeout.add_seconds (2, () => {
            if (!game.is_complete)  // in case an undo has been called
                return Source.REMOVE;

            set_winner_and_loser_variables ();
            flip_final_result_now = true;
            for (uint8 x = 0; x < game.size; x++)
                for (uint8 y = 0; y < game.size; y++)
                    flip_final_result_tile (x, y);

            return Source.REMOVE;
        });
    }

    private void flip_final_result_tile (uint8 x, uint8 y)
    {
        int pixmap;
        uint8 n = y * game.size + x;
        if (n < n_winning_tiles)
            pixmap = get_pixmap (winning_color);
        else if (n < n_winning_tiles + n_losing_tiles)
            pixmap = get_pixmap (losing_color);
        else
            pixmap = get_pixmap (Player.NONE);
        set_square (x, y, pixmap);
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

        for (uint8 x = 0; x < game.size; x++)
            for (uint8 y = 0; y < game.size; y++)
                update_square (x, y);

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
            uint8 x = (uint8) ((event.x - board_x) / paving_size);
            uint8 y = (uint8) ((event.y - board_y) / paving_size);
            if (x >= 0 && x < game.size && y >= 0 && y < game.size)
            {
                show_highlight = false;
                queue_draw ();
                highlight_x = x;
                highlight_y = y;
                move (x, y);
            }
        }

        return true;
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

        if ((game.size <= 4 && (key == "e" || key == "5" || key == "KP_5")) ||
            (game.size <= 5 && (key == "f" || key == "6" || key == "KP_6")) ||
            (game.size <= 6 && (key == "g" || key == "7" || key == "KP_7")) ||
            (game.size <= 7 && (key == "h" || key == "8" || key == "KP_8")) ||
            (game.size <= 8 && (key == "i" || key == "9" || key == "KP_9")) ||
            (game.size <= 9 && (key == "j" || key == "0" || key == "KP_0")))
            return false;

        switch (key)
        {
            case "Left":
            case "KP_Left":
                if (highlight_x > 0) highlight_x --;
                break;
            case "Right":
            case "KP_Right":
                if (highlight_x < game.size - 1) highlight_x ++;
                break;
            case "Up":
            case "KP_Up":
                if (highlight_y > 0) highlight_y --;
                break;
            case "Down":
            case "KP_Down":
                if (highlight_y < game.size - 1) highlight_y ++;
                break;

            case "space":
            case "Return":
            case "KP_Enter":

            case "Escape": break;

            case "a": highlight_x = 0; break;
            case "b": highlight_x = 1; break;
            case "c": highlight_x = 2; break;
            case "d": highlight_x = 3; break;
            case "e": highlight_x = 4; break;
            case "f": highlight_x = 5; break;
            case "g": highlight_x = 6; break;
            case "h": highlight_x = 7; break;
            case "i": highlight_x = 8; break;
            case "j": highlight_x = 9; break;

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
                highlight_x = game.size - 1;
                break;
            case "Page_Up":
            case "KP_Page_Up":
                highlight_y = 0;
                break;
            case "Page_Down":
            case "KP_Next":     // TODO use KP_Page_Down instead of KP_Next, probably a gtk+ or vala bug; check also KP_Prior
                highlight_y = game.size - 1;
                break;

            // allow <Tab> and <Shift><Tab> to change focus
            default:
                return false;
        }

        if (key == "Escape")
            show_highlight = false;
        else if (show_highlight)
            highlight_state = HIGHLIGHT_MAX;
        else
            show_highlight = true;

        queue_draw ();      // TODO is a queue_draw_area usable somehow here?
        return true;
    }

    /*\
    * * Scoreboard
    \*/

    private bool draw_scoreboard (Cairo.Context cr)
    {
        int height = scoreboard.get_allocated_height ();
        int width = scoreboard.get_allocated_width ();

        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);

        cr.save ();

        cr.set_source_rgba (mark_red, mark_green, mark_blue, 1.0);
        cr.set_line_width (mark_width);

        cr.translate (0, current_player_number * height / 2.0);
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

            cr.translate (width - height / 2.0, 0);
            var matrix = Cairo.Matrix.identity ();

            /* draw dark piece */
            matrix.translate (height / 2.0, 0);
            ((!) scoreboard_tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) scoreboard_tiles_pattern);
            cr.rectangle (0, 0, height / 2.0, height / 2.0);
            cr.fill ();

            /* draw white piece */
            matrix.translate (3 * height, height);
            ((!) scoreboard_tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) scoreboard_tiles_pattern);
            cr.rectangle (0, height / 2.0, height / 2.0, height / 2.0);
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
