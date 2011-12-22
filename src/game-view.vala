public class GameView : Gtk.DrawingArea
{
    private const int GRIDWIDTH = 1;
    private const int PIXMAP_FLIP_DELAY = 20;

    private uint tile_width = 80;
    private uint tile_height = 80;
    private uint board_width = 648;
    private uint board_height = 648;
    private double[] dash = {4.0};

    private Cairo.Surface? tiles_surface = null;
    private Cairo.Surface? background_surface = null;

    private int[,] pixmaps;

    private uint animate_timeout = 0;

    public signal void move (int x, int y);

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

    private string? _tile_set = null;
    public string? tile_set
    {
        get { return _tile_set; }
        set { _tile_set = value; tiles_surface = null; redraw (); }
    }

    private bool _show_grid;
    public bool show_grid
    {
        get { return _show_grid; }
        set { _show_grid = value; redraw (); }
    }

    public override bool draw (Cairo.Context cr)
    {
        if (game == null)
            return false;

        if (tiles_surface == null)
            load_pixmaps ();

        var p = new Cairo.Pattern.for_surface (background_surface);
        p.set_extend (Cairo.Extend.REPEAT);
        cr.set_source (p);
        cr.move_to (0, 0);
        cr.line_to (0, board_height);
        cr.line_to (board_width, board_height);
        cr.line_to (board_width, 0);
        cr.line_to (0, 0);
        cr.fill ();

        for (var x = 0; x < 8; x++)
        {
            for (var y = 0; y < 8; y++)
            {
                var tile_surface_x = x * (int) (tile_width + GRIDWIDTH) - (pixmaps[x, y] % 8) * (int) tile_width;
                var tile_surface_y = y * (int) (tile_height + GRIDWIDTH) - (pixmaps[x, y] / 8) * (int) tile_height;

                cr.set_source_surface (tiles_surface, tile_surface_x, tile_surface_y);
                cr.rectangle (x * (tile_width + GRIDWIDTH), y * (tile_height + GRIDWIDTH), tile_width, tile_height);
                cr.fill ();
            }
        }

        if (show_grid)
        {
            cr.set_source_rgb (1.0, 1.0, 1.0);
            cr.set_operator (Cairo.Operator.DIFFERENCE);
            cr.set_dash (dash, 2.5);
            cr.set_line_width (GRIDWIDTH);
            for (var i = 1; i < 8; i++)
            {
                cr.move_to (i * board_width / 8 - 0.5, 0);
                cr.line_to (i * board_width / 8 - 0.5, board_height);

                cr.move_to (0, i * board_height / 8 - 0.5);
                cr.line_to (board_width, i * board_height / 8 - 0.5);
            }

            cr.stroke ();
        }

        return false;
    }

    private void load_pixmaps ()
    {
        var dname = GnomeGamesSupport.runtime_get_directory (GnomeGamesSupport.RuntimeDirectory.GAME_PIXMAP_DIRECTORY);
        var fname = Path.build_filename (dname, tile_set);

        /* fall back to default tileset "classic.png" if tile_set not found */
        if (!FileUtils.test (fname, FileTest.EXISTS | FileTest.IS_REGULAR))
            fname = Path.build_filename (dname, "classic.png");

        if (!FileUtils.test (fname, FileTest.EXISTS | FileTest.IS_REGULAR))
        {
            stderr.printf (_("Could not find \'%s\' pixmap file\n"), fname);
            Posix.exit (Posix.EXIT_FAILURE);
        }

        Gdk.Pixbuf image;
        try
        {
            image = new Gdk.Pixbuf.from_file (fname);
        }
        catch (Error e)
        {
            warning ("gdk-pixbuf error %s\n", e.message);
            return;
        }

        tile_width = image.get_width () / 8;
        tile_height = image.get_height () / 4;

        /* Make sure the dash width evenly subdivides the tile height, and is at least 4 pixels long.
         * This makes the dash crossings always cross in the same place, which looks nicer. */
        var dash_count = (tile_height + GRIDWIDTH) / 4;
        if (dash_count % 2 != 0)
            dash_count--;
        dash[0] = ((double)(tile_height + GRIDWIDTH)) / dash_count;

        board_width = (tile_width + GRIDWIDTH) * 8;
        board_height = (tile_height + GRIDWIDTH) * 8;
        set_size_request ((int) board_width, (int) board_height);

        tiles_surface = get_window ().create_similar_surface (Cairo.Content.COLOR_ALPHA, image.get_width (), image.get_height ());
        var cr = new Cairo.Context (tiles_surface);
        Gdk.cairo_set_source_pixbuf (cr, image, 0, 0);
        cr.paint ();

        background_surface = get_window ().create_similar_surface (Cairo.Content.COLOR_ALPHA, 1, 1);
        cr = new Cairo.Context (background_surface);
        Gdk.cairo_set_source_pixbuf (cr, image, 0, 0);
        cr.paint ();
    }

    public void redraw ()
    {
        queue_draw_area (0, 0, (int) board_width, (int) board_height);
    }

    private void square_changed_cb (int x, int y)
    {
        var target = get_pixmap (game.get_owner (x, y));

        if (pixmaps[x, y] == target)
            return;

        if (target == 0 || pixmaps[x, y] == 0)
            pixmaps[x, y] = target;
        else
        {
            if (target > pixmaps[x, y])
                pixmaps[x, y]++;
            else
                pixmaps[x, y]--;
            if (animate_timeout == 0)
                animate_timeout = Timeout.add (PIXMAP_FLIP_DELAY, animate_cb);
        }
        queue_draw_area (x * (int) (tile_width + GRIDWIDTH), y * (int) (tile_height + GRIDWIDTH), (int) tile_width, (int) tile_height);
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
            var x = (int) event.x / (int) (tile_width + GRIDWIDTH);
            var y = (int) event.y / (int) (tile_height + GRIDWIDTH);
            move (x, y);
        }

        return true;
    }
}
