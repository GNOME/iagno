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

public class GameView : Gtk.DrawingArea
{
    /* Theme */
    private string pieces_file;

    private double background_red;
    private double background_green;
    private double background_blue;

    private double border_red;
    private double border_green;
    private double border_blue;
    private int border_width;

    private double spacing_red;
    private double spacing_green;
    private double spacing_blue;
    private int spacing_width;

    // private int margin_width;

    public string sound_flip     { get; private set; }
    public string sound_gameover { get; private set; }

    /* Utilities, see calculate () */
    private int tile_size;
    private int board_size;
    private int x_offset { get { return (get_allocated_width () - board_size) / 2 + border_width; }}
    private int y_offset { get { return (get_allocated_height () - board_size) / 2 + border_width; }}

    /* Delay in milliseconds between tile flip frames */
    private const int PIXMAP_FLIP_DELAY = 20;

    /* Pre-rendered image */
    private uint render_size = 0;
    private Cairo.Pattern? tiles_pattern = null;

    /* The images being showed on each location */
    private int[,] pixmaps;

    /* Animation timer */
    private uint animate_timeout = 0;

    public signal void move (int x, int y);

    /* Used for a delay between the last move and flipping the pieces */
    private bool flip_final_result_now = false;

    private Game? _game = null;
    public Game? game
    {
        get { return _game; }
        set
        {
            if (_game != null)
                SignalHandler.disconnect_by_func (_game, null, this);
            _game = value;
            pixmaps = new int[game.size,game.size];
            if (_game != null)
            {
                _game.square_changed.connect (square_changed_cb);
                for (var x = 0; x < game.size; x++)
                    for (var y = 0; y < game.size; y++)
                        pixmaps[x, y] = get_pixmap (_game.get_owner (x, y));
            }
            queue_draw ();
        }
    }

    private string? _theme = null;
    public string? theme
    {
        get { return _theme; }
        set {
            if (value == "default")
            {
                set_default_theme ();
                _theme = "default";
            }
            else
            {
                var key = new GLib.KeyFile ();
                key.load_from_file (Path.build_filename (DATA_DIRECTORY, "themes", "key", value), GLib.KeyFileFlags.NONE);

                // TODO try ... catch { set_default_theme (); _theme="default"; }
                load_theme (key);
                _theme = value;
            }

            // redraw all
            tiles_pattern = null;
            queue_draw ();
        }
    }

    private void set_default_theme ()
    {
        var defaults = Gtk.Settings.get_default ();
        var key = new GLib.KeyFile ();
        string filename;
        if (defaults.gtk_theme_name == "HighContrast")
            filename = "high_contrast.theme";
        else if (defaults.gtk_application_prefer_dark_theme == true)
            filename = "adwaita.theme";
        else
            filename = "classic.theme";
        key.load_from_file (Path.build_filename (DATA_DIRECTORY, "themes", "key", filename), GLib.KeyFileFlags.NONE);
        load_theme (key);
    }

    private void load_theme (GLib.KeyFile key)
    {
        string path = Path.build_filename (DATA_DIRECTORY, "themes", "svg");

        pieces_file = Path.build_filename (path, key.get_string ("Pieces", "File"));
        if (Path.get_dirname (pieces_file) != path)     // security
            pieces_file = Path.build_filename (path, "black_and_white.svg");

        background_red   = key.get_double  ("Background", "Red");
        background_green = key.get_double  ("Background", "Green");
        background_blue  = key.get_double  ("Background", "Blue");

        border_red       = key.get_double  ("Border", "Red");
        border_green     = key.get_double  ("Border", "Green");
        border_blue      = key.get_double  ("Border", "Blue");
        border_width     = key.get_integer ("Border", "Width");

        spacing_red      = key.get_double  ("Spacing", "Red");
        spacing_green    = key.get_double  ("Spacing", "Green");
        spacing_blue     = key.get_double  ("Spacing", "Blue");
        spacing_width    = key.get_integer ("Spacing", "Width");

        // margin_width = key.get_integer  ("Margin", "Width");

        sound_flip       = key.get_string  ("Sound", "Flip");
        sound_gameover   = key.get_string  ("Sound", "GameOver");
    }

    public GameView ()
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK);
        set_size_request (350, 350);
    }

    private void calculate ()
    {
        var size = int.min (get_allocated_width (), get_allocated_height ());
        /* tile_size includes a grid spacing */
        tile_size = (size - 2 * border_width + spacing_width) / game.size;
        /* board_size includes its borders */
        board_size = tile_size * game.size - spacing_width + 2 * border_width;
    }

    public override bool draw (Cairo.Context cr)
    {
        if (game == null)
            return false;

        calculate ();

        if (tiles_pattern == null || render_size != tile_size)
        {
            render_size = tile_size;
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size * 8, tile_size * 4);
            var c = new Cairo.Context (surface);
            load_image (c);
            tiles_pattern = new Cairo.Pattern.for_surface (surface);
        }

        cr.translate (x_offset, y_offset);

        /* draw background; TODO save for border */
        cr.set_source_rgba (background_red, background_green, background_blue, 1.0);
        cr.rectangle (-border_width / 2.0, -border_width / 2.0, board_size - border_width, board_size - border_width);
        cr.fill ();

        /* draw lines */
        cr.set_source_rgba (spacing_red, spacing_green, spacing_blue, 1.0);
        cr.set_line_width (spacing_width);
        for (var i = 1; i < game.size; i++)
        {
            cr.move_to (i * tile_size - spacing_width / 2.0, 0);
            cr.rel_line_to (0, board_size - border_width);

            cr.move_to (0, i * tile_size - spacing_width / 2.0);
            cr.rel_line_to (board_size - border_width, 0);
        }
        cr.stroke ();

        /* draw border */
        cr.set_source_rgba (border_red, border_green, border_blue, 1.0);
        cr.set_line_width (border_width);
        cr.rectangle (-border_width / 2.0, -border_width / 2.0, board_size - border_width, board_size - border_width);
        cr.stroke ();

        /* draw pieces */
        cr.translate (-spacing_width / 2, -spacing_width / 2);
        for (var x = 0; x < game.size; x++)
        {
            for (var y = 0; y < game.size; y++)
            {
                if (pixmaps[x, y] == 0)
                    continue;

                var tile_x = x * tile_size;
                var tile_y = y * tile_size;
                var texture_x = (pixmaps[x, y] % 8) * tile_size;
                var texture_y = (pixmaps[x, y] / 8) * tile_size;

                var matrix = Cairo.Matrix.identity ();
                matrix.translate (texture_x - tile_x, texture_y - tile_y);
                tiles_pattern.set_matrix (matrix);
                cr.set_source (tiles_pattern);
                cr.rectangle (tile_x, tile_y, tile_size, tile_size);
                cr.fill ();
            }
        }
        return false;
    }

    private void load_image (Cairo.Context c)
    {
        var width = tile_size * 8;
        var height = tile_size * 4;

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

    private void square_changed_cb (int x, int y)
    {
        var pixmap = get_pixmap (game.get_owner (x, y));

        /* Show the result by laying the tiles with winning color first */
        if (flip_final_result_now && game.is_complete)
        {
            var n = y * game.size + x;
            var winning_color = Player.LIGHT;
            var losing_color = Player.DARK;
            var n_winning_tiles = game.n_light_tiles;
            var n_losing_tiles = game.n_dark_tiles;
            if (n_losing_tiles > n_winning_tiles)
            {
                winning_color = Player.DARK;
                losing_color = Player.LIGHT;
                var t = n_winning_tiles;
                n_winning_tiles = n_losing_tiles;
                n_losing_tiles = t;
            }
            if (n < n_winning_tiles)
                pixmap = get_pixmap (winning_color);
            else if (n < n_winning_tiles + n_losing_tiles)
                pixmap = get_pixmap (losing_color);
            else
                pixmap = get_pixmap (Player.NONE);
        }
        /* An undo occurred after the game was complete */
        else if (flip_final_result_now)
        {
            flip_final_result_now = false;
        }

        set_square (x, y, pixmap);

        if (game.is_complete && game.n_light_tiles > 0 && game.n_dark_tiles > 0)
        {
            /*
             * Show the actual final positions of the pieces before flipping the board.
             * Otherwise, it could seem like the final player placed the other's piece.
             */
            Timeout.add_seconds (2, () =>  {
                flip_final_result_now = true;
                square_changed_cb (x, y);
                return Source.REMOVE;
            });
        }
    }

    private void set_square (int x, int y, int pixmap)
    {
        if (pixmaps[x, y] == pixmap)
            return;

        if (pixmap == 0 || pixmaps[x, y] == 0)
            pixmaps[x, y] = pixmap;
        else
        {
            if (pixmap > pixmaps[x, y])
                pixmaps[x, y]++;
            else
                pixmaps[x, y]--;
            if (animate_timeout == 0)
                animate_timeout = Timeout.add (PIXMAP_FLIP_DELAY, animate_cb);
        }
        queue_draw_area (x_offset + x * tile_size, y_offset + y * tile_size, tile_size, tile_size);
    }

    private bool animate_cb ()
    {
        var animating = false;

        for (var x = 0; x < game.size; x++)
        {
            for (var y = 0; y < game.size; y++)
            {
                var old = pixmaps[x, y];
                square_changed_cb (x, y);
                if (pixmaps[x, y] != old)
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

    private int get_pixmap (Player color)
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

    public override bool button_press_event (Gdk.EventButton event)
    {
        /* left button is first, right button is third */
        if (event.button == 1 || event.button == 3)
        {
            var x = (int) (event.x - x_offset) / tile_size;
            var y = (int) (event.y - y_offset) / tile_size;
            if (x >= 0 && x < game.size && y >= 0 && y < game.size)
                move (x, y);
        }

        return true;
    }
}
