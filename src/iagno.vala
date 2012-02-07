public class Iagno : Gtk.Application
{
    /* Application settings */
    private Settings settings;

    /* Widgets */
    private Gtk.Window window;
    private Gtk.Statusbar statusbar;
    private uint statusbar_id;
    private GameView view;
    private Gtk.Label dark_score_label;
    private Gtk.Label light_score_label;
    private SimpleAction undo_action;

    /* Light computer player (if there is one) */
    private ComputerPlayer? light_computer = null;

    /* Dark computer player (if there is one) */
    private ComputerPlayer? dark_computer = null;

    /* Timer to delay computer moves */
    private uint computer_timer = 0;

    /* The game being played */
    private Game? game = null;

    /* true if the last move was a pass */
    private bool was_pass = false;

    /* Possible themes */
    private GnomeGamesSupport.FileList? theme_file_list = null;

    private const GLib.ActionEntry app_actions[] =
    {
        {"new-game", new_game_cb},
        {"undo-move", undo_move_cb},
        {"preferences", preferences_cb},
        {"help", help_cb},
        {"about", about_cb},
        {"quit", quit_cb}
    };

    protected override void startup()
    {
        base.startup ();
        add_action_entries (app_actions, this);
        undo_action = lookup_action ("undo-move") as SimpleAction;
    }

    public Iagno ()
    {
        Object (application_id: "org.gnome.iagno", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate ()
    {
        if (window != null)
        {
            window.show ();
            return;
        }

        settings = new Settings ("org.gnome.iagno");

        var builder = new Gtk.Builder ();
        try
        {
            builder.add_from_file (DATA_DIRECTORY + "/iagno.ui");
        }
        catch (Error e)
        {
            stderr.printf ("Could not load UI: %s\n", e.message);
            return;
        }
        set_app_menu (builder.get_object ("iagno-menu") as MenuModel);
        window = builder.get_object ("window") as Gtk.Window;
        var top_grid = builder.get_object ("grid") as Gtk.Grid;
        window.set_title (_("Iagno"));

        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/iagno/", window);
        add_window (window);

        undo_action.set_enabled (true);

        view = new GameView ();
        view.hexpand = true;
        view.vexpand = true;
        view.game = game;
        view.move.connect (player_move_cb);
        view.show_grid = settings.get_boolean ("show-grid");
        view.flip_final_result = settings.get_boolean ("flip-final-results");
        var tile_set = settings.get_string ("tileset");
        var theme = load_theme_texture (tile_set);
        if (theme == null)
        {
            warning ("Unable to load theme %s, falling back to default", tile_set);
            theme = load_theme_texture ("black_and_white.svg", true);
        }
        view.theme = theme;
        view.show ();
        top_grid.attach (view, 0, 2, 1, 1);

        statusbar = new Gtk.Statusbar ();
        statusbar.show ();

        var toolbar = builder.get_object ("toolbar") as Gtk.Toolbar;
        toolbar.show_arrow = false;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        toolbar.insert (new Gtk.SeparatorToolItem (), -1);
        var status_item = new Gtk.ToolItem ();
        status_item.set_visible_horizontal (true);
        status_item.set_expand (true);

        var status_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        status_alignment.add (statusbar);
        status_item.add (status_alignment);

        toolbar.insert (status_item, -1);
        toolbar.show_all ();

        var grid = new Gtk.Grid ();
        grid.set_column_spacing (6);
        grid.show ();
        statusbar.pack_start (grid, false, true, 0);

        var label = new Gtk.Label (_("Dark:"));
        label.show ();
        grid.attach (label, 1, 0, 1, 1);

        dark_score_label = new Gtk.Label ("00");
        dark_score_label.show ();
        grid.attach (dark_score_label, 2, 0, 1, 1);

        label = new Gtk.Label (_("Light:"));
        label.show ();
        grid.attach (label, 4, 0, 1, 1);

        light_score_label = new Gtk.Label ("00");
        light_score_label.show ();
        grid.attach (light_score_label, 5, 0, 1, 1);

        statusbar_id = statusbar.get_context_id ("iagno");

        start_game ();

        window.show ();
    }

    private GnomeGamesSupport.Preimage? load_theme_texture (string filename, bool fail_on_error = false)
    {
        var path = Path.build_filename (DATA_DIRECTORY, "themes", filename);
        try
        {
            return new GnomeGamesSupport.Preimage.from_file (path);
        }
        catch (Error e)
        {
            warning ("Failed to load theme %s: %s", filename, path);
            return null;
        }
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void new_game_cb ()
    {
        start_game ();
    }

    private void start_game ()
    {
        /* Cancel any pending computer moves */
        if (computer_timer != 0)
        {
            Source.remove (computer_timer);
            computer_timer = 0;
        }

        if (game != null)
            SignalHandler.disconnect_by_func (game, null, this);

        game = new Game ();
        game.move.connect (game_move_cb);
        game.complete.connect (game_complete_cb);
        view.game = game;

        var dark_level = settings.get_int ("black-level");
        if (dark_level > 0)
            dark_computer = new ComputerPlayer (game, dark_level);
        else
            dark_computer = null;
        var light_level = settings.get_int ("white-level");
        if (light_level > 0)
            light_computer = new ComputerPlayer (game, light_level);
        else
            light_computer = null;

        update_ui ();

        game.start ();
    }

    private void update_ui ()
    {
        /* Can't undo when running two computer players */
        if (light_computer != null && dark_computer != null)
            undo_action.set_enabled (false);
        else
            undo_action.set_enabled (game.can_undo);
        /* Translators: this is a 2 digit representation of the current score. */
        dark_score_label.set_text (_("%.2d").printf (game.n_dark_tiles));
        light_score_label.set_text (_("%.2d").printf (game.n_light_tiles));

        if (was_pass)
        {
            if (game.current_color == Player.DARK)
                show_message (_("Light must pass, Dark's move"));
            else
                show_message (_("Dark must pass, Light's move"));
        }
        else
        {
            if (game.current_color == Player.DARK)
                show_message (_("Dark's move"));
            else if (game.current_color == Player.LIGHT)
                show_message (_("Light's move"));
        }
    }

    private void undo_move_cb ()
    {
        /* Cancel any pending computer moves */
        if (computer_timer != 0)
        {
            Source.remove (computer_timer);
            computer_timer = 0;
        }

        /* Undo once if the human player just moved, otherwise undo both moves */
        if ((game.current_color == Player.DARK && dark_computer != null) ||
            (game.current_color == Player.LIGHT && light_computer != null))
            game.undo (1);
        else
            game.undo (2);
    }

    private void about_cb ()
    {
        string[] authors = { "Ian Peters", "Robert Ancell", null };
        string[] documenters = { "Eric Baudais", null };

        Gtk.show_about_dialog (window,
                               "name", _("Iagno"),
                               "version", VERSION,
                               "copyright",
                               "Copyright \xc2\xa9 1998-2008 Ian Peters",
                               "license", GnomeGamesSupport.get_license (_("Iagno")),
                               "comments", _("A disk flipping game derived from Reversi.\n\nIagno is a part of GNOME Games."),
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "iagno",
                               "website-label", _("GNOME Games web site"),
                               "website", "http://www.gnome.org/projects/gnome-games/",
                               "wrap-license", true,
                               null);
    }

    private void preferences_cb ()
    {
        show_preferences_dialog ();
    }

    private void show_message (string message)
    {
        statusbar.pop (statusbar_id);
        statusbar.push (statusbar_id, message);
    }

    private void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:iagno", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void game_move_cb ()
    {
        play_sound ("flip-piece");

        if (!game.can_move)
        {
            was_pass = true;
            game.pass ();
            return;
        }

        update_ui ();
        was_pass = false;

        /* Get the computer to move after a delay (so it looks like it's thinking) */
        if ((game.current_color == Player.LIGHT && light_computer != null) ||
            (game.current_color == Player.DARK && dark_computer != null))
            computer_timer = Timeout.add (1000, computer_move_cb);
    }

    private bool computer_move_cb ()
    {
        if (game.current_color == Player.LIGHT)
            light_computer.move ();
        else
            dark_computer.move ();
        computer_timer = 0;
        return false;
    }

    private void game_complete_cb ()
    {
        if (game.n_light_tiles > game.n_dark_tiles)
            show_message (_("Light player wins!"));
        if (game.n_dark_tiles > game.n_light_tiles)
            show_message (_("Dark player wins!"));
        if (game.n_light_tiles == game.n_dark_tiles)
            show_message (_("The game was a draw."));

        play_sound ("gameover");
    }

    private void play_sound (string name)
    {
        if (!settings.get_boolean ("sound"))
            return;

        CanberraGtk.play_for_widget (view, 0,
                                     Canberra.PROP_MEDIA_NAME, name,
                                     Canberra.PROP_MEDIA_FILENAME, Path.build_filename (SOUND_DIRECTORY, "%s.ogg".printf (name)));
    }

    private void player_move_cb (int x, int y)
    {
        /* Ignore if we are waiting for the AI to move */
        if (game.current_color == Player.LIGHT && settings.get_int ("white-level") > 0)
            return;
        if (game.current_color == Player.DARK && settings.get_int ("black-level") > 0)
            return;

        if (game.place_tile (x, y) == 0)
            show_message (_("Invalid move."));
    }

    private void dark_human_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("black-level", 0);
    }

    private void dark_level_one_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("black-level", 1);
    }

    private void dark_level_two_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("black-level", 2);
    }

    private void dark_level_three_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("black-level", 3);
    }

    private void light_human_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("white-level", 0);
    }

    private void light_level_one_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("white-level", 1);
    }

    private void light_level_two_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("white-level", 2);
    }

    private void light_level_three_cb (Gtk.ToggleButton widget)
    {
        if (widget.get_active ())
            settings.set_int ("white-level", 3);
    }

    private void sound_select (Gtk.ToggleButton widget)
    {
        var play_sounds = widget.get_active ();
        settings.set_boolean ("sound", play_sounds);
    }

    private void grid_toggled_cb (Gtk.ToggleButton widget)
    {
        view.show_grid = widget.get_active ();
        settings.set_boolean ("show-grid", view.show_grid);
    }

    private void flip_final_toggled_cb (Gtk.ToggleButton widget)
    {
        view.flip_final_result = widget.get_active ();
        settings.set_boolean ("flip-final-results", view.flip_final_result);
    }

    private void propbox_response_cb (Gtk.Widget widget, int response_id)
    {
        widget.hide ();
    }

    private bool propbox_close_cb (Gtk.Widget widget, Gdk.EventAny event)
    {
        widget.hide ();
        return true;
    }

    private void theme_changed_cb (Gtk.ComboBox widget)
    {
        var tile_set = theme_file_list.get_nth (widget.get_active ());
        settings.set_string ("tileset", tile_set);

        var theme = load_theme_texture (tile_set);
        if (theme == null)
            warning ("Unable to load theme %s", tile_set);
        else
            view.theme = theme;

        view.redraw ();
    }

    private void show_preferences_dialog ()
    {
        var propbox = new Gtk.Dialog.with_buttons (_("Iagno Preferences"),
                                                   window,
                                                   0,
                                                   Gtk.Stock.CLOSE, Gtk.ResponseType.CLOSE,
                                                   null);

        propbox.set_border_width (5);
        var box = (Gtk.Box) propbox.get_content_area ();
        box.set_spacing (2);
        propbox.resizable = false;
        propbox.response.connect (propbox_response_cb);
        propbox.delete_event.connect (propbox_close_cb);

        var notebook = new Gtk.Notebook ();
        notebook.set_border_width (5);
        box.add (notebook);

        var label = new Gtk.Label (_("Game"));

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
        vbox.set_border_width (12);
        notebook.append_page (vbox, label);

        var grid = new Gtk.Grid ();
        grid.set_column_spacing (18);
        vbox.pack_start (grid, false, false, 0);

        var vbox2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        vbox.pack_start (vbox2, false, false, 0);

        var enable_sounds_button = new Gtk.CheckButton.with_mnemonic (_("E_nable sounds"));
        enable_sounds_button.set_active (settings.get_boolean ("sound"));
        enable_sounds_button.toggled.connect (sound_select);
        vbox2.pack_start (enable_sounds_button, false, false, 0);

        var frame = new GnomeGamesSupport.Frame (_("Dark"));
        grid.attach (frame, 0, 0, 1, 1);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        frame.add (vbox);

        var computer_button = new Gtk.RadioButton.with_label (null, _("Human"));
        if (settings.get_int ("black-level") == 0)
            computer_button.set_active (true);
        computer_button.toggled.connect (dark_human_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level one"));
        if (settings.get_int ("black-level") == 1)
            computer_button.set_active (true);
        computer_button.toggled.connect (dark_level_one_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level two"));
        if (settings.get_int ("black-level") == 2)
            computer_button.set_active (true);
        computer_button.toggled.connect (dark_level_two_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level three"));
        if (settings.get_int ("black-level") == 3)
            computer_button.set_active (true);
        computer_button.toggled.connect (dark_level_three_cb);
        vbox.pack_start (computer_button, false, false, 0);

        frame = new GnomeGamesSupport.Frame (_("Light"));
        grid.attach (frame, 1, 0, 1, 1);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        frame.add (vbox);

        computer_button = new Gtk.RadioButton.with_label (null, _("Human"));
        if (settings.get_int ("white-level") == 0)
            computer_button.set_active (true);
        computer_button.toggled.connect (light_human_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level one"));
        if (settings.get_int ("white-level") == 1)
            computer_button.set_active (true);
        computer_button.toggled.connect (light_level_one_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level two"));
        if (settings.get_int ("white-level") == 2)
            computer_button.set_active (true);
        computer_button.toggled.connect (light_level_two_cb);
        vbox.pack_start (computer_button, false, false, 0);

        computer_button = new Gtk.RadioButton.with_label (computer_button.get_group (), _("Level three"));
        if (settings.get_int ("white-level") == 3)
            computer_button.set_active (true);
        computer_button.toggled.connect (light_level_three_cb);
        vbox.pack_start (computer_button, false, false, 0);

        label = new Gtk.Label (_("Appearance"));

        grid = new Gtk.Grid ();
        grid.set_column_spacing (18);
        grid.set_border_width (12);
        notebook.append_page (grid, label);

        frame = new GnomeGamesSupport.Frame (_("Options"));
        grid.attach (frame, 0, 0, 1, 1);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        frame.add (vbox);

        var grid_button = new Gtk.CheckButton.with_mnemonic (_("S_how grid"));
        grid_button.set_active (settings.get_boolean ("show-grid"));
        grid_button.toggled.connect (grid_toggled_cb);
        vbox.pack_start (grid_button, false, false, 0);

        var flip_final_button = new Gtk.CheckButton.with_mnemonic (_("_Flip final results"));
        flip_final_button.set_active (settings.get_boolean ("flip-final-results"));
        flip_final_button.toggled.connect (flip_final_toggled_cb);
        vbox.pack_start (flip_final_button, false, false, 0);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        vbox.pack_start (hbox, false, false, 0);

        label = new Gtk.Label.with_mnemonic (_("_Tile set:"));
        hbox.pack_start (label, false, false, 0);

        theme_file_list = new GnomeGamesSupport.FileList.images (Path.build_filename (DATA_DIRECTORY, "themes"), null);
        theme_file_list.transform_basename ();
        var theme_combo = (Gtk.ComboBox) theme_file_list.create_widget (settings.get_string ("tileset"), GnomeGamesSupport.FILE_LIST_REMOVE_EXTENSION | GnomeGamesSupport.FILE_LIST_REPLACE_UNDERSCORES);

        label.set_mnemonic_widget (theme_combo);
        theme_combo.changed.connect (theme_changed_cb);
        hbox.pack_start (theme_combo, true, true, 0);

        propbox.show_all ();
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var context = new OptionContext ("");
        context.set_translation_domain (GETTEXT_PACKAGE);
        context.add_group (Gtk.get_option_group (true));

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name (_("Iagno"));

        GnomeGamesSupport.stock_init ();

        Gtk.Window.set_default_icon_name ("iagno");

        var app = new Iagno ();

        var result = app.run ();

        return result;
    }
}
