public class Iagno
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
    private Gtk.Action new_game_action;
    private Gtk.Action undo_action;

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

    private const Gtk.ActionEntry actions[] =
    {
        {"GameMenu", null, N_("_Game")},
        {"SettingsMenu", null, N_("_Settings")},
        {"HelpMenu", null, N_("_Help")},
        {"NewGame", GnomeGamesSupport.STOCK_NEW_GAME, null, null, null, new_game_cb},
        {"UndoMove", GnomeGamesSupport.STOCK_UNDO_MOVE, null, null, null, undo_move_cb},
        {"Quit", Gtk.Stock.QUIT, null, null, null, quit_game_cb},
        {"Preferences", Gtk.Stock.PREFERENCES, null, null, null, properties_cb},
        {"Contents", GnomeGamesSupport.STOCK_CONTENTS, null, null, null, help_cb},
        {"About", Gtk.Stock.ABOUT, null, null, null, about_cb}
    };

    private string ui_description =
        "<ui>" +
        "  <menubar name='MainMenu'>" +
        "    <menu action='GameMenu'>" +
        "      <menuitem action='NewGame'/>" +
        "      <separator/>" +
        "      <menuitem action='UndoMove'/>" +
        "      <separator/>" +
        "      <menuitem action='Quit'/>" +
        "    </menu>" +
        "    <menu action='SettingsMenu'>" +
        "      <menuitem action='Preferences'/>" +
        "    </menu>" +
        "    <menu action='HelpMenu'>" +
        "      <menuitem action='Contents'/>" +
        "      <menuitem action='About'/>" +
        "    </menu>" +
        "  </menubar>" +
        "</ui>";

    public Iagno ()
    {
        settings = new Settings ("org.gnome.iagno");

        window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
        window.set_title (_("Iagno"));

        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/iagno/", window);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.show ();
        window.add (vbox);

        var ui_manager = new Gtk.UIManager ();
        var action_group = new Gtk.ActionGroup ("group");

        action_group.set_translation_domain (GETTEXT_PACKAGE);
        action_group.add_actions (actions, this);

        ui_manager.insert_action_group (action_group, 0);
        try
        {
            ui_manager.add_ui_from_string (ui_description, -1);
        }
        catch (Error e)
        {
            warning ("Failed to load UI: %s", e.message);
        }

        window.add_accel_group (ui_manager.get_accel_group ());

        new_game_action = action_group.get_action ("NewGame");
        undo_action = action_group.get_action ("UndoMove");
        undo_action.set_sensitive (false);
        var menubar = (Gtk.MenuBar) ui_manager.get_widget ("/MainMenu");
        vbox.pack_start (menubar, false, false, 0);

        var notebook = new Gtk.Notebook ();
        notebook.show ();
        notebook.set_show_tabs (false);
        notebook.set_show_border (false);

        window.delete_event.connect (window_delete_event_cb);

        view = new GameView ();
        view.game = game;
        view.move.connect (player_move_cb);
        view.show_grid = settings.get_boolean ("show-grid");
        view.tile_set = settings.get_string ("tileset");
        view.show ();

        notebook.append_page (view, null);
        notebook.set_current_page (0);
        vbox.pack_start (notebook, false, false, 0);

        statusbar = new Gtk.Statusbar ();
        statusbar.show ();
        vbox.pack_start (statusbar, false, false, 0);

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

        window.set_resizable (false);

        statusbar_id = statusbar.get_context_id ("iagno");

        GnomeGamesSupport.sound_enable (settings.get_boolean ("sound"));

        start_game ();
    }

    private void show ()
    {
        window.show ();
    }

    private void quit_game_cb ()
    {
        Gtk.main_quit ();
    }

    private bool window_delete_event_cb (Gtk.Widget widget, Gdk.EventAny event)
    {
        Gtk.main_quit ();
        return true;
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
            undo_action.set_sensitive (false);
        else
            undo_action.set_sensitive (game.can_undo);

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

    private void about_cb (Gtk.Action action)
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
                               "logo-icon-name", "gnome-iagno",
                               "website-label", _("GNOME Games web site"),
                               "website", "http://www.gnome.org/projects/gnome-games/",
                               "wrap-license", true,
                               null);
    }

    private void properties_cb ()
    {
        show_properties_dialog ();
    }

    private void show_message (string message)
    {
        statusbar.pop (statusbar_id);
        statusbar.push (statusbar_id, message);
    }

    private void help_cb (Gtk.Action action)
    {
        GnomeGamesSupport.help_display (window, "iagno", null);
    }

    private void game_move_cb ()
    {
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

        GnomeGamesSupport.sound_play ("gameover");
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
        GnomeGamesSupport.sound_enable (play_sounds);
    }

    private void grid_select (Gtk.ToggleButton widget)
    {
        view.show_grid = widget.get_active ();
        settings.set_boolean ("show-grid", view.show_grid);
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

    private void set_selection (Gtk.ComboBox widget)
    {
        view.tile_set = theme_file_list.get_nth (widget.get_active ());
        settings.set_string ("tileset", view.tile_set);
        view.redraw ();
    }

    private void show_properties_dialog ()
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
        grid_button.toggled.connect (grid_select);
        vbox.pack_start (grid_button, false, false, 0);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        vbox.pack_start (hbox, false, false, 0);

        label = new Gtk.Label.with_mnemonic (_("_Tile set:"));
        hbox.pack_start (label, false, false, 0);

        var dir = GnomeGamesSupport.runtime_get_directory (GnomeGamesSupport.RuntimeDirectory.GAME_PIXMAP_DIRECTORY);
        theme_file_list = new GnomeGamesSupport.FileList.images (dir, null);
        theme_file_list.transform_basename ();
        var option_menu = (Gtk.ComboBox) theme_file_list.create_widget (view.tile_set, GnomeGamesSupport.FILE_LIST_REMOVE_EXTENSION | GnomeGamesSupport.FILE_LIST_REPLACE_UNDERSCORES);

        label.set_mnemonic_widget (option_menu);
        option_menu.changed.connect (set_selection);
        hbox.pack_start (option_menu, true, true, 0);


        propbox.show_all ();
    }

    public static int main (string[] args)
    {
        if (!GnomeGamesSupport.runtime_init ("iagno"))
            return Posix.EXIT_FAILURE;

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

        Gtk.Window.set_default_icon_name ("gnome-iagno");

        var app = new Iagno ();
        app.show ();

        Gtk.main ();

        GnomeGamesSupport.runtime_shutdown ();

        return Posix.EXIT_SUCCESS;
    }
}