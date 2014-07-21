/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Iagno : Gtk.Application
{
    /* Application settings */
    private Settings settings;
    private bool is_fullscreen;
    private bool is_maximized;
    private static bool fast_mode;
    private static int computer_level = 0;

    /* Widgets */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private Gtk.HeaderBar headerbar;
    private GameView view;
    private Gtk.Button new_game_button;
    private Gtk.Label dark_label;
    private Gtk.Label dark_score_label;
    private Gtk.Label light_label;
    private Gtk.Label light_score_label;

    /* Computer player (if there is one) */
    private ComputerPlayer? computer = null;

    /* Human player */
    private Player player_one;

    /* Timer to delay computer moves */
    private uint computer_timer = 0;

    /* The game being played */
    private Game? game = null;

    private static const OptionEntry[] option_entries =
    {
        { "fast-mode", 'f', 0, OptionArg.NONE, ref fast_mode, N_("Reduce delay before AI moves"), null},
        { "first", 0, 0, OptionArg.NONE, null, N_("Play first"), null},
        { "level", 'l', 0, OptionArg.INT, ref computer_level, N_("Set the level of the computer's AI"), null},
        { "mute", 0, 0, OptionArg.NONE, null, N_("Turn off the sound"), null},
        { "second", 0, 0, OptionArg.NONE, null, N_("Play second"), null},
        { "two-players", 0, 0, OptionArg.NONE, null, N_("Two-players mode"), null},
        { "unmute", 0, 0, OptionArg.NONE, null, N_("Turn on the sound"), null},
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null},
        { null }
    };

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
    }

    public Iagno ()
    {
        Object (application_id: "org.gnome.iagno", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override void activate ()
    {
        if (window != null)
        {
            window.show ();
            return;
        }

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
        window = new Gtk.ApplicationWindow (this);
        window.set_border_width (25);
        window.set_title (_("Iagno"));
        window.icon_name = "iagno";
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        var image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.BUTTON;
        if (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL)
            image.icon_name = "edit-undo-rtl-symbolic";
        else
            image.icon_name = "edit-undo-symbolic";

        var undo_button = new Gtk.Button ();
        undo_button.image = image;
        undo_button.valign = Gtk.Align.CENTER;
        undo_button.action_name = "app.undo-move";
        undo_button.tooltip_text = _("Undo your most recent move");
        undo_button.show ();

        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_title (_("Iagno"));
        headerbar.pack_start (undo_button);
        headerbar.show ();
        window.set_titlebar (headerbar);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.halign = Gtk.Align.CENTER;
        hbox.show ();
        window.add (hbox);

        view = new GameView ();
        view.game = game;
        view.move.connect (player_move_cb);
        var tile_set = settings.get_string ("tileset");
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", tile_set);
        view.show ();
        hbox.pack_start (view, true, true, 0);

        var side_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        side_box.show ();
        hbox.pack_start (side_box, true, true, 20);

        var grid = new Gtk.Grid ();
        grid.halign = Gtk.Align.CENTER;
        grid.vexpand = true;
        grid.hexpand = true;
        grid.set_column_spacing (8);
        grid.show ();
        side_box.pack_start (grid, false, true, 0);

        dark_label = new Gtk.Label (_("Dark:"));
        dark_label.show ();
        grid.attach (dark_label, 1, 0, 1, 1);

        dark_score_label = new Gtk.Label ("00");
        dark_score_label.show ();
        grid.attach (dark_score_label, 2, 0, 1, 1);

        light_label = new Gtk.Label (_("Light:"));
        light_label.show ();
        grid.attach (light_label, 1, 1, 1, 1);

        light_score_label = new Gtk.Label ("00");
        light_score_label.show ();
        grid.attach (light_score_label, 2, 1, 1, 1);

        new_game_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic", Gtk.IconSize.DIALOG);
        new_game_button.halign = Gtk.Align.CENTER;
        new_game_button.valign = Gtk.Align.CENTER;
        new_game_button.relief = Gtk.ReliefStyle.NONE;
        new_game_button.action_name = "app.new-game";
        new_game_button.tooltip_text = _("Start a new game");
        side_box.pack_end (new_game_button, false, false, 0);

        start_game ();

        window.show ();
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "iagno", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        /* WARNING: Don't forget that changing at this moment settings
        could interfere badly with a running instance of the game. */
        settings = new Settings ("org.gnome.iagno");

        /* Sound can be turned on/off via command-line while playing. */
        if (options.contains ("unmute"))
            settings.set_boolean ("sound", true);
        if (options.contains ("mute"))
            settings.set_boolean ("sound", false);

        /* The computer's AI level is set for the next game. */
        if (computer_level > 0)
        {
            if (computer_level <= 3)
                settings.set_int ("computer-level", computer_level);
            else
                stderr.printf ("%1$s\n", _("Level should be between 1 (easy) and 3 (hard). Settings unchanged."));
        }

        /* The game mode is set for the next game. */
        if (options.contains ("second"))
            settings.set_string ("play-as", "second");
        if (options.contains ("first"))
            settings.set_string ("play-as", "first");
        if (options.contains ("two-players"))
            settings.set_string ("play-as", "two-players");

        /* Activate */
        return -1;
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
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
        cancel_pending_computer_moves ();

        if (game != null)
            SignalHandler.disconnect_by_func (game, null, this);

        game = new Game ();
        game.move.connect (game_move_cb);
        game.complete.connect (game_complete_cb);
        view.game = game;

        new_game_button.hide ();

        var mode = settings.get_string ("play-as");
        if (mode == "two-players")
            computer = null;
        else
            computer = new ComputerPlayer (game, settings.get_int ("computer-level"));

        player_one = (mode == "first") ? Player.DARK : Player.LIGHT;

        update_ui ();

        /*
         * Get the computer to move after a delay (so it looks like it's
         * thinking - but only a short delay for the first move)
         */
        if (player_one != Player.DARK && computer != null)
            computer_timer = Timeout.add_seconds (1, computer_move_cb);
    }

    private void update_ui ()
    {
        headerbar.set_subtitle (null);

        var undo_action = (SimpleAction) lookup_action ("undo-move");
        undo_action.set_enabled (game.can_undo ());

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

    private void undo_move_cb ()
    {
        cancel_pending_computer_moves ();

        /* Undo once if the human player just moved, otherwise undo both moves */
        if (game.current_color != player_one && computer != null)
            game.undo (1);
        else
            game.undo (2);

        /* If forced to pass, undo to last chosen move */
        while (!game.can_move (game.current_color))
            game.undo (2);

        /* For undo after the end of the game */
        new_game_button.hide ();

        game_move_cb ();
    }

    private void about_cb ()
    {
        string[] authors = { "Ian Peters", "Robert Ancell", null };
        string[] documenters = { "Tiffany Antopolski", null };

        Gtk.show_about_dialog (window,
                               "name", _("Iagno"),
                               "version", VERSION,
                               "copyright",
                               "Copyright © 1998–2008 Ian Peters\nCopyright © 2013–2014 Michael Catanzaro",
                               "license-type", Gtk.License.GPL_2_0,
                               "comments", _("A disk flipping game derived from Reversi\n\nIagno is a part of GNOME Games."),
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "iagno",
                               "website", "https://wiki.gnome.org/Apps/Iagno",
                               null);
    }

    private void preferences_cb ()
    {
        show_preferences_dialog ();
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

        if (!game.can_move (game.current_color))
        {
            game.pass ();
            if (game.current_color == Player.DARK)
            {
                /* Message to display when Light has no possible moves */
                headerbar.set_subtitle (_("Light must pass, Dark’s move"));
            }
            else
            {
                /* Message to display when Dark has no possible moves */
                headerbar.set_subtitle (_("Dark must pass, Light’s move"));
            }
            return;
        }

        update_ui ();

        /*
         * Get the computer to move after a delay, so it looks like it's
         * thinking. Make it fairly long so the human doesn't feel overwhelmed,
         * but not so long as to become boring.
         */
        if (game.current_color != player_one && computer != null)
        {
            if (game.n_tiles == 63 || fast_mode)
                computer_timer = Timeout.add (400, computer_move_cb);
            else
                computer_timer = Timeout.add_seconds (2, computer_move_cb);
        }
    }

    private bool computer_move_cb ()
    {
        cancel_pending_computer_moves ();
        if (game.current_color != player_one)
            computer.move ();
        return false;
    }

    private void cancel_pending_computer_moves ()
    {
        if (computer_timer != 0)
        {
            Source.remove (computer_timer);
            computer_timer = 0;
        }
    }

    private void game_complete_cb ()
    {
        update_ui ();

        if (game.n_light_tiles > game.n_dark_tiles)
        {
            /* Message to display when Light has won the game */
            headerbar.set_subtitle (_("Light wins!"));
        }
        else if (game.n_dark_tiles > game.n_light_tiles)
        {
            /* Message to display when Dark has won the game */
            headerbar.set_subtitle (_("Dark wins!"));
        }
        else if (game.n_light_tiles == game.n_dark_tiles)
        {
            /* Message to display when the game is a draw */
            headerbar.set_subtitle (_("The game is draw."));
        }
        else assert_not_reached ();

        play_sound ("gameover");
        new_game_button.show ();
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
        if (game.current_color != player_one && computer != null)
            return;

        if (game.place_tile (x, y) == 0)
        {
            /* Message to display when the player tries to make an illegal move */
            headerbar.set_subtitle (_("You can’t move there!"));
        }
    }

    private void computer_level_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        combo.get_active_iter (out iter);
        int level;
        combo.model.get (iter, 1, out level);
        settings.set_int ("computer-level", level);
    }

    private void mode_changed_cb (Gtk.ComboBox combo, Gtk.ComboBox level_combo)
    {
        Gtk.TreeIter iter;
        combo.get_active_iter (out iter);
        string mode;
        combo.model.get (iter, 1, out mode);
        settings.set_string ("play-as", mode);
        level_combo.sensitive = (mode == "two-players") ? false : true;
    }

    private void sound_select (Gtk.ToggleButton widget)
    {
        var play_sounds = widget.get_active ();
        settings.set_boolean ("sound", play_sounds);
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
        var propbox = new Gtk.Dialog.with_buttons (_("Preferences"),
                                                   window,
                                                   Gtk.DialogFlags.USE_HEADER_BAR,
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

        var combo = new Gtk.ComboBox ();
        var level_combo = new Gtk.ComboBox ();
        combo.changed.connect (() => mode_changed_cb (combo, level_combo));

        var label = new Gtk.Label (_("Game mode:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 0, 1, 1);
        var renderer = new Gtk.CellRendererText ();
        combo.pack_start (renderer, true);
        combo.add_attribute (renderer, "text", 0);
        var model = new Gtk.ListStore (2, typeof (string), typeof (string));
        combo.model = model;
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 0, _("Play first (Dark)"), 1, "first");
        model.append (out iter);
        model.set (iter, 0, _("Play second (Light)"), 1, "second");
        model.append (out iter);
        model.set (iter, 0, _("Two players"), 1, "two-players");
        combo.set_id_column (1);
        settings.changed["play-as"].connect (() => {
            var mode = settings.get_string ("play-as");
            combo.set_active_id (mode);
            level_combo.sensitive = (mode == "two-players") ? false : true;
        });
        var mode = settings.get_string ("play-as");
        combo.set_active_id (mode);
        level_combo.sensitive = (mode == "two-players") ? false : true;
        grid.attach (combo, 1, 0, 1, 1);

        label = new Gtk.Label (_("Computer:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 1, 1, 1);
        level_combo.changed.connect (computer_level_changed_cb);
        renderer = new Gtk.CellRendererText ();
        level_combo.pack_start (renderer, true);
        level_combo.add_attribute (renderer, "text", 0);
        model = new Gtk.ListStore (2, typeof (string), typeof (int));
        level_combo.model = model;
        model.append (out iter);
        model.set (iter, 0, _("Level one"), 1, 1);
        model.append (out iter);
        model.set (iter, 0, _("Level two"), 1, 2);
        model.append (out iter);
        model.set (iter, 0, _("Level three"), 1, 3);
        settings.changed["computer-level"].connect (() => {
            level_combo.set_active (settings.get_int ("computer-level") - 1);
        });
        level_combo.set_active (settings.get_int ("computer-level") - 1);
        grid.attach (level_combo, 1, 1, 1, 1);

        label = new Gtk.Label.with_mnemonic (_("_Tile set:"));
        label.set_alignment (0.0f, 0.5f);
        label.expand = true;
        grid.attach (label, 0, 2, 1, 1);

        var theme_combo = new Gtk.ComboBox ();
        renderer = new Gtk.CellRendererText ();
        theme_combo.pack_start (renderer, true);
        theme_combo.add_attribute (renderer, "text", 0);
        model = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = model;
        Dir dir;
        List<string> dirlist = new List<string> ();

        /* get sorted list of filenames in the themes directory */
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes"));
            while (true)
            {
                var filename = dir.read_name ();
                if (filename == null)
                    break;
                dirlist.insert_sorted (filename, strcmp);
            }
        }
        catch (FileError e)
        {
            warning ("Failed to load themes: %s", e.message);
        }

        foreach (string filename in dirlist)
        {
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

        label.set_mnemonic_widget (theme_combo);
        theme_combo.changed.connect (theme_changed_cb);
        grid.attach (theme_combo, 1, 2, 1, 1);

        var enable_sounds_button = new Gtk.CheckButton.with_mnemonic (_("E_nable sounds"));
        settings.changed["sound"].connect (() => {
            enable_sounds_button.set_active (settings.get_boolean ("sound"));
        });
        enable_sounds_button.set_active (settings.get_boolean ("sound"));
        enable_sounds_button.toggled.connect (sound_select);
        grid.attach (enable_sounds_button, 0, 3, 2, 1);

        propbox.show_all ();
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Iagno"));

        Gtk.Window.set_default_icon_name ("iagno");

        var app = new Iagno ();

        var result = app.run (args);

        return result;
    }
}
