/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class GameView : Gtk.DrawingArea
{
    /* Space between tiles in pixels */
    private const int GRID_WIDTH = 1;

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

    private int tile_size
    {
        get
        {
            return int.min (get_allocated_width () / 8, get_allocated_height () / (int) 8) - GRID_WIDTH;
        }
    }
    
    private int x_offset
    {
        get
        {
            return (get_allocated_width () - 8 * (tile_size + GRID_WIDTH)) / 2;
        }
    }

    private int y_offset
    {
        get
        {
            return (get_allocated_height () - 8 * (tile_size + GRID_WIDTH)) / 2;
        }
    }

    private int board_size { get { return (tile_size + GRID_WIDTH) * 8; } }

    public GameView ()
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK);
        pixmaps = new int[8,8];
    }

    private Game? _game = null;
    public Game? game
    {
        get { return _game; }
        set
        {
            if (_game != null)
                SignalHandler.disconnect_by_func (_game, null, this);
            _game = value;
            if (_game != null)
            {
                _game.square_changed.connect (square_changed_cb);
                for (var x = 0; x < 8; x++)
                    for (var y = 0; y < 8; y++)
                        pixmaps[x, y] = get_pixmap (_game.get_owner (x, y));
            }
            redraw ();
        }
    }

    private string? _theme = null;
    public string? theme
    {
        get { return _theme; }
        set { _theme = value; tiles_pattern = null; queue_draw (); }
    }

    private bool _flip_final_result;
    public bool flip_final_result
    {
        get { return _flip_final_result; }
        set
        {
            _flip_final_result = value;
            if (game == null)
                return;
            for (var x = 0; x < game.width; x++)
                for (var y = 0; y < game.height; y++)
                    square_changed_cb (x, y);
        }
    }

    public override Gtk.SizeRequestMode get_request_mode ()
    {
        return Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT;
    }

    public override void get_preferred_width_for_height (int height, out int minimum_width, out int natural_width)
    {
        /* Try and be square */
        minimum_width = natural_width = height;
    }

    public override void get_preferred_width (out int minimum, out int natural)
    {
        minimum = natural = (int) (8 * (20 + GRID_WIDTH));
    }

    public override void get_preferred_height (out int minimum, out int natural)
    {
        minimum = natural = (int) (8 * (20 + GRID_WIDTH));
    }

    public override bool draw (Cairo.Context cr)
    {
        if (game == null)
            return false;

        if (tiles_pattern == null || render_size != tile_size)
        {
            render_size = tile_size;
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, tile_size * 8, tile_size * 4);
            var c = new Cairo.Context (surface);
            load_theme (c);
            tiles_pattern = new Cairo.Pattern.for_surface (surface);
        }

        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                var tile_x = x_offset + x * (tile_size + GRID_WIDTH);
                var tile_y = y_offset + y * (tile_size + GRID_WIDTH);
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

        cr.set_source_rgba (1.0, 1.0, 1.0, 0.5);
        cr.set_operator (Cairo.Operator.DIFFERENCE);
        cr.set_line_width (GRID_WIDTH);
        for (var i = 1; i < 8; i++)
        {
            cr.move_to (x_offset + i * board_size / 8 - 0.5, y_offset);
            cr.rel_line_to (0, board_size);

            cr.move_to (x_offset, y_offset + i * board_size / 8 - 0.5);
            cr.rel_line_to (board_size, 0);
        }

        cr.rectangle (x_offset + 0.5, y_offset + 0.5, board_size - 1, board_size - 1);

        cr.stroke ();

        return false;
    }

    private void load_theme (Cairo.Context c)
    {
        var width = tile_size * 8;
        var height = tile_size * 4;

        try
        {
            var h = new Rsvg.Handle.from_file (theme);

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
            var p = new Gdk.Pixbuf.from_file_at_scale (theme, width, height, false);
            Gdk.cairo_set_source_pixbuf (c, p, 0, 0);
            c.paint ();
        }
        catch (Error e)
        {
            warning ("Failed to load theme %s: %s", theme, e.message);
        }
    }

    public void redraw ()
    {
        queue_draw ();
    }

    private void square_changed_cb (int x, int y)
    {
        var pixmap = get_pixmap (game.get_owner (x, y));

        /* Show the result by laying the tiles with winning color first */
        if (flip_final_result_now && game.is_complete ())
        {
            var n = y * game.width + x;
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
        else if (flip_final_result_now && !game.is_complete ())
        {
            flip_final_result_now = false;
        }

        set_square (x, y, pixmap);

        if (game.is_complete () && flip_final_result && game.n_light_tiles > 0 && game.n_dark_tiles > 0)
        {
            /*
             * Show the actual final positions of the pieces before flipping the board.
             * Otherwise, it could seem like the final player placed the other's piece.
             */
            Timeout.add_seconds (2, () =>
                {
                    flip_final_result_now = true;
                    square_changed_cb (x, y);
                    /* Disconnect from mainloop */
                    return false;
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
        queue_draw_area (x_offset + x * (int) (tile_size + GRID_WIDTH), y_offset + y * (int) (tile_size + GRID_WIDTH), tile_size, tile_size);
    }

    private bool animate_cb ()
    {
        var animating = false;

        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
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
            return false;
        }

        return true;
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
        if (event.button == 1)
        {
            var x = (int) (event.x - x_offset) / (tile_size + GRID_WIDTH);
            var y = (int) (event.y - y_offset) / (tile_size + GRID_WIDTH);
            if (x >= 0 && x < 8 && y >= 0 && y < 8)
                move (x, y);
        }

        return true;
    }
}
