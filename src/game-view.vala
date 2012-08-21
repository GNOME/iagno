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

    private bool _show_grid;
    public bool show_grid
    {
        get { return _show_grid; }
        set { _show_grid = value; redraw (); }
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
            var pixbuf = load_theme ();
            Gdk.cairo_set_source_pixbuf (c, pixbuf, 0, 0);
            c.paint ();

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

        if (show_grid)
        {
            /* Make sure the dash width evenly subdivides the tile height, and is at least 4 pixels long.
            * This makes the dash crossings always cross in the same place, which looks nicer. */
            var dash_count = (tile_size + GRID_WIDTH) / 4;
            if (dash_count % 2 != 0)
                dash_count--;
            double dash[1];
            dash[0] = ((double)(tile_size + GRID_WIDTH)) / dash_count;
            cr.set_dash (dash, 2.5);

            cr.set_source_rgb (1.0, 1.0, 1.0);
            cr.set_operator (Cairo.Operator.DIFFERENCE);
            cr.set_line_width (GRID_WIDTH);
            for (var i = 1; i < 8; i++)
            {
                cr.move_to (x_offset + i * board_size / 8 - 0.5, y_offset);
                cr.rel_line_to (0, board_size);

                cr.move_to (x_offset, y_offset + i * board_size / 8 - 0.5);
                cr.rel_line_to (board_size, 0);
            }

            cr.stroke ();
        }

        return false;
    }

    private Gdk.Pixbuf load_theme ()
    {
        var width = tile_size * 8;
        var height = tile_size * 4;

        try
        {
            return Rsvg.pixbuf_from_file_at_size (theme, width, height);
        }
        catch (Error e)
        {
        }
        
        try
        {
            return new Gdk.Pixbuf.from_file_at_scale (theme, width, height, false);
        }
        catch (Error e)
        {
        }

        return new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, width, height);
    }

    public void redraw ()
    {
        queue_draw ();
    }

    private void square_changed_cb (int x, int y)
    {
        var pixmap = get_pixmap (game.get_owner (x, y));

        /* If requested show the result by laying the tiles with winning color first */
        if (game.is_complete && flip_final_result)
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

        set_square (x, y, pixmap);
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
