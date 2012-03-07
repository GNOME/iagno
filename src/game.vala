public enum Player
{
    NONE,
    LIGHT,
    DARK
}

public class Game
{
    /* Tiles on the board */
    public Player[,] tiles;
    
    public int width
    {
        get { return tiles.length[0]; }
    }

    public int height
    {
        get { return tiles.length[1]; }
    }

    /* Undo stack.  This is a record of all the tile changes since the start of the game
     * in the binary form ccxxxyyy where cc is the color (0-2), xxx is the x location (0-7)
     * and yyy is the y location (0-7).  Each set of changes is followed by the number of changes
     * preceeding.  This array is oversized, but big enough for the (impossible) worst case of
     * each move flipping 20 tiles. */
    private int undo_history[1344];
    private int undo_index = 0;

    /* Color to move next */
    public Player current_color;

    /* Indicate that a player should move */
    public signal void move ();

    /* Indicate a square has changed */
    public signal void square_changed (int x, int y);

    /* Indicate the game is complete */
    public signal void complete ();

    /* The number of tiles on the board */
    public int n_tiles
    {
        get
        {
            var count = 0;
            for (var x = 0; x < width; x++)
            {
                for (var y = 0; y < height; y++)
                {
                    if (tiles[x, y] != Player.NONE)
                        count++;
                }
            }
            return count;
        }
    }

    public int n_light_tiles
    {
        get { return count_tiles (Player.LIGHT); }
    }

    public int n_dark_tiles
    {
        get { return count_tiles (Player.DARK); }
    }

    public bool can_move
    {
        get
        {
            for (var x = 0; x < width; x++)
                for (var y = 0; y < height; y++)
                    if (can_place (x, y))
                        return true;
            return false;
        }
    }

    public bool is_complete
    {
        get { return n_tiles == width * height || n_light_tiles == 0 || n_dark_tiles == 0; }
    }

    public Game (int width = 8, int height = 8)
    {
        /* Setup board with four tiles by default */
        tiles = new Player[width, height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                tiles[x, y] = Player.NONE;
        set_tile (3, 3, Player.LIGHT, false);
        set_tile (3, 4, Player.DARK, false);
        set_tile (4, 3, Player.DARK, false);
        set_tile (4, 4, Player.LIGHT, false);

        /* Black plays first */
        current_color = Player.DARK;
    }

    public void start ()
    {
        if (n_tiles != 4)
            return;

        move ();
    }

    public Game.copy (Game game)
    {
        tiles = new Player[game.width, game.height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                tiles[x, y] = game.tiles[x, y];
        for (var i = 0; i < game.undo_index; i++)
            undo_history[i] = game.undo_history[i];
        undo_index = game.undo_index;
        current_color = game.current_color;
    }

    public Player get_owner (int x, int y)
    {
        if (is_valid_location (x, y))
            return tiles[x, y];
        else
            return Player.NONE;
    }

    public bool can_place (int x, int y)
    {
        return place (x, y, current_color, false) > 0;
    }

    public int place_tile (int x, int y)
    {
        var n_tiles = place (x, y, current_color, true);
        if (n_tiles == 0)
            return 0;

        /* Move to the next player */
        if (current_color == Player.LIGHT)
            current_color = Player.DARK;
        else
            current_color = Player.LIGHT;

        if (is_complete)
            complete ();
        else
            move ();

        return n_tiles;
    }

    public void pass ()
    {
        undo_history[undo_index] = 0;
        undo_index++;

        if (current_color == Player.LIGHT)
            current_color = Player.DARK;
        else
            current_color = Player.LIGHT;

        move ();
    }

    private int place (int x, int y, Player color, bool apply)
    {
        /* Square needs to be empty */
        if (!is_valid_location (x, y) || tiles[x, y] != Player.NONE)
            return 0;

        var n_flips = 0;
        n_flips += flip_tiles (x, y, 1, 0, color, apply);
        n_flips += flip_tiles (x, y, 1, 1, color, apply);
        n_flips += flip_tiles (x, y, 0, 1, color, apply);
        n_flips += flip_tiles (x, y, -1, 1, color, apply);
        n_flips += flip_tiles (x, y, -1, 0, color, apply);
        n_flips += flip_tiles (x, y, -1, -1, color, apply);
        n_flips += flip_tiles (x, y, 0, -1, color, apply);
        n_flips += flip_tiles (x, y, 1, -1, color, apply);

        /* Store the number of entries in the undo history */
        if (apply && n_flips > 0)
        {
            undo_history[undo_index] = n_flips + 1;
            undo_index++;
        }

        return n_flips;
    }

    private int count_tiles (Player color)
    {
        var count = 0;
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                if (tiles[x, y] == color)
                    count++;
        return count;
    }

    private bool is_valid_location (int x, int y)
    {
        return x >= 0 && x < width && y >= 0 && y < height;
    }

    private int flip_tiles (int x, int y, int x_step, int y_step, Player color, bool apply)
    {
        var enemy = Player.LIGHT;
        if (color == Player.LIGHT)
            enemy = Player.DARK;

        /* Count number of enemy pieces we are beside */
        var enemy_count = 0;
        var xt = x + x_step;
        var yt = y + y_step;
        while (is_valid_location (xt, yt))
        {
            if (tiles[xt, yt] != enemy)
                break;
            enemy_count++;
            xt += x_step;
            yt += y_step;
        }

        /* Must be a line of enemy pieces then one of ours */
        if (enemy_count == 0 || !is_valid_location (xt, yt) || tiles[xt, yt] != color)
            return 0;

        /* Place this tile and flip the adjacent ones */
        if (apply)
            for (var i = 0; i <= enemy_count; i++)
                set_tile (x + i * x_step, y + i * y_step, color, true);

        return enemy_count;
    }

    public bool can_undo
    {
        get { return undo_index > 0; }
    }

    public void undo (int count = 1)
    {
        if (!can_undo)
            return;

        if (count < 1)
            return;

        for (var i = 0; i < count; i++)
        {
            var n_changes = undo_history[undo_index - 1];
            undo_index--;

            /* Undo each tile change */
            for (var j = 0; j < n_changes; j++)
            {
                var n = undo_history[undo_index - 1];
                undo_index--;
                var c = (Player) (n >> 6);
                var xy = n & 0x3F;
                set_tile (xy % width, xy / width, c, false);
            }

            /* Previous player to move again */
            if (current_color == Player.LIGHT)
                current_color = Player.DARK;
            else
                current_color = Player.LIGHT;
        }

        move ();
    }

    private void set_tile (int x, int y, Player color, bool update_history)
    {
        if (tiles[x, y] == color)
            return;

        /* Store the old color in the history */
        if (update_history)
        {
            undo_history[undo_index] = ((int) tiles[x, y] << 6) | (y * width + x);
            undo_index++;
        }

        tiles[x, y] = color;
        square_changed (x, y);
    }
}
