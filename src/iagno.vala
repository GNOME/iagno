public class Iagno : Gtk.Application
{
    /* Application settings */
    private Settings settings;

    /* Widgets */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_fullscreen;
    private bool is_maximized;
    private Gtk.InfoBar infobar;
    private Gtk.Statusbar statusbar;
    private uint statusbar_id;
    private GameView view;
    private Gtk.Label infobar_label;
    private Gtk.Label dark_label;
    private Gtk.Label light_label;
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
        var top_grid = builder.get_object ("grid") as Gtk.Grid;
        window.set_title (_("Iagno"));
        window = builder.get_object ("window") as Gtk.Window;
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));        
        if (settings.get_boolean ("window-is-fullscreen"))
            window.fullscreen ();
        else if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

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
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", tile_set);
        view.show ();
        top_grid.attach (view, 0, 3, 1, 1);

        infobar = new Gtk.InfoBar ();
        top_grid.attach (infobar, 0, 2, 1, 1);
        infobar_label = new Gtk.Label ("");
        infobar_label.show ();
        infobar.add (infobar_label);

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

        dark_label = new Gtk.Label (_("Dark:"));
        dark_label.show ();
        grid.attach (dark_label, 1, 0, 1, 1);

        dark_score_label = new Gtk.Label ("00");
        dark_score_label.show ();
        grid.attach (dark_score_label, 2, 0, 1, 1);

        light_label = new Gtk.Label (_("Light:"));
        light_label.show ();
        grid.attach (light_label, 4, 0, 1, 1);

        light_score_label = new Gtk.Label ("00");
        light_score_label.show ();
        grid.attach (light_score_label, 5, 0, 1, 1);

        statusbar_id = statusbar.get_context_id ("iagno");

        start_game ();

        window.show ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.set_boolean ("window-is-fullscreen", is_fullscreen);
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !is_fullscreen)
        {
            window_width = event.width;
            window_height = event.height;
        }

        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
        return false;
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
        infobar.hide ();
        /* Can't undo when running two computer players */
        if (light_computer != null && dark_computer != null)
            undo_action.set_enabled (false);
        else
            undo_action.set_enabled (game.can_undo);

        if (was_pass)
        {
            if (game.current_color == Player.DARK)
                show_message (_("Light must pass, Dark's move"), Gtk.MessageType.INFO);
            else
                show_message (_("Dark must pass, Light's move"), Gtk.MessageType.INFO);
        }
        else
        {
            if (game.current_color == Player.DARK)
            {
                dark_label.set_markup ("<span font_weight='bold'>"+_("Dark:")+"</span>");
                light_label.set_markup ("<span font_weight='normal'>"+_("Light:")+"</span>");
                /* Translators: this is a 2 digit representation of the current score. */
                dark_score_label.set_markup ("<span font_weight='bold'>"+(_("%.2d").printf (game.n_dark_tiles))+"</span>");
                light_score_label.set_markup ("<span font_weight='normal'>"+(_("%.2d").printf (game.n_light_tiles))+"</span>");
            }
            else if (game.current_color == Player.LIGHT)
            {
                dark_label.set_markup ("<span font_weight='normal'>"+_("Dark:")+"</span>");
                light_label.set_markup ("<span font_weight='bold'>"+_("Light:")+"</span>");
                /* Translators: this is a 2 digit representation of the current score. */
                dark_score_label.set_markup ("<span font_weight='normal'>"+(_("%.2d").printf (game.n_dark_tiles))+"</span>");
                light_score_label.set_markup ("<span font_weight='bold'>"+(_("%.2d").printf (game.n_light_tiles))+"</span>");
            }
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
        var license = "Iagno is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\nIagno is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with Iagno; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA";

        Gtk.show_about_dialog (window,
                               "name", _("Iagno"),
                               "version", VERSION,
                               "copyright",
                               "Copyright \xc2\xa9 1998-2008 Ian Peters",
                               "license", license,
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

    private void show_message (string message, Gtk.MessageType type)
    {
        infobar.message_type = type;
        infobar_label.set_label (message);
        infobar.show ();
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
            show_message (_("Light player wins!"), Gtk.MessageType.INFO);
        if (game.n_dark_tiles > game.n_light_tiles)
            show_message (_("Dark player wins!"), Gtk.MessageType.INFO);
        if (game.n_light_tiles == game.n_dark_tiles)
            show_message (_("The game was a draw."), Gtk.MessageType.INFO);

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
            show_message (_("Invalid move."), Gtk.MessageType.ERROR);
    }

    private void dark_level_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        combo.get_active_iter (out iter);
        int level;
        combo.model.get (iter, 1, out level);
        settings.set_int ("black-level", level);
    }

    private void light_level_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        combo.get_active_iter (out iter);
        int level;
        combo.model.get (iter, 1, out level);
        settings.set_int ("white-level", level);
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
        var model = widget.get_model ();
        Gtk.TreeIter iter;
        if (!widget.get_active_iter (out iter))
            return;
        string tile_set;
        model.get (iter, 1, out tile_set);
        settings.set_string ("tileset", tile_set);
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", tile_set);
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

        var grid = new Gtk.Grid ();
        grid.border_width = 6;
        grid.set_row_spacing (6);
        grid.set_column_spacing (18);
        box.add (grid);

        var label = new Gtk.Label (_("Dark Player:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 0, 1, 1);
        var combo = new Gtk.ComboBox ();
        combo.changed.connect (dark_level_changed_cb);
        var renderer = new Gtk.CellRendererText ();
        combo.pack_start (renderer, true);
        combo.add_attribute (renderer, "text", 0);
        var model = new Gtk.ListStore (2, typeof (string), typeof (int));
        combo.model = model;
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 0, _("Human"), 1, 0);
        if (settings.get_int ("black-level") == 0)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level one"), 1, 1);
        if (settings.get_int ("black-level") == 1)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level two"), 1, 2);
        if (settings.get_int ("black-level") == 2)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level three"), 1, 3);
        if (settings.get_int ("black-level") == 3)
            combo.set_active_iter (iter);
        grid.attach (combo, 1, 0, 1, 1);

        label = new Gtk.Label (_("Light Player:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 1, 1, 1);
        combo = new Gtk.ComboBox ();
        combo.changed.connect (light_level_changed_cb);
        renderer = new Gtk.CellRendererText ();
        combo.pack_start (renderer, true);
        combo.add_attribute (renderer, "text", 0);
        model = new Gtk.ListStore (2, typeof (string), typeof (int));
        combo.model = model;
        model.append (out iter);
        model.set (iter, 0, _("Human"), 1, 0);
        if (settings.get_int ("white-level") == 0)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level one"), 1, 1);
        if (settings.get_int ("white-level") == 1)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level two"), 1, 2);
        if (settings.get_int ("white-level") == 2)
            combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Level three"), 1, 3);
        if (settings.get_int ("white-level") == 3)
            combo.set_active_iter (iter);
        grid.attach (combo, 1, 1, 1, 1);

        var enable_sounds_button = new Gtk.CheckButton.with_mnemonic (_("E_nable sounds"));
        enable_sounds_button.set_active (settings.get_boolean ("sound"));
        enable_sounds_button.toggled.connect (sound_select);
        grid.attach (enable_sounds_button, 0, 2, 2, 1);

        var grid_button = new Gtk.CheckButton.with_mnemonic (_("S_how grid"));
        grid_button.set_active (settings.get_boolean ("show-grid"));
        grid_button.toggled.connect (grid_toggled_cb);
        grid.attach (grid_button, 0, 3, 2, 1);

        var flip_final_button = new Gtk.CheckButton.with_mnemonic (_("_Flip final results"));
        flip_final_button.set_active (settings.get_boolean ("flip-final-results"));
        flip_final_button.toggled.connect (flip_final_toggled_cb);
        grid.attach (flip_final_button, 0, 4, 2, 1);

        label = new Gtk.Label.with_mnemonic (_("_Tile set:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 5, 1, 1);

        var theme_combo = new Gtk.ComboBox ();
        renderer = new Gtk.CellRendererText ();
        theme_combo.pack_start (renderer, true);
        theme_combo.add_attribute (renderer, "text", 0);
        model = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = model;
        Dir dir;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes"));
            while (true)
            {
                var filename = dir.read_name ();
                if (filename == null)
                    break;
                model.append (out iter);
                
                /* Create label by replacing underscores with space and stripping extension */
                var label_text = filename;
                label_text = label_text.replace ("_", " ");
                var extension_index = label_text.last_index_of_char ('.');
                if (extension_index > 0)
                    label_text = label_text.substring (0, extension_index);

                model.set (iter, 0, label_text, 1, filename);
                if (filename == settings.get_string ("tileset"))
                    theme_combo.set_active_iter (iter);
            }
        }
        catch (FileError e)
        {
            warning ("Failed to load themes: %s", e.message);
        }
        label.set_mnemonic_widget (theme_combo);
        theme_combo.changed.connect (theme_changed_cb);
        grid.attach (theme_combo, 1, 5, 1, 1);

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

        Gtk.Window.set_default_icon_name ("iagno");

        var app = new Iagno ();

        var result = app.run ();

        return result;
    }
}
