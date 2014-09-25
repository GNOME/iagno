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
    private static int size = 8;
    private static bool begin_with_new_game_screen = false;

    /* Seconds */
    private static const double QUICK_MOVE_DELAY = 0.4;
    private static const double MODERATE_MOVE_DELAY = 1.0;
    private static const double SLOW_MOVE_DELAY = 2.0;

    /* Widgets */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private Gtk.HeaderBar headerbar;
    private GameView view;
    private Gtk.Image mark_icon_dark;
    private Gtk.Image mark_icon_light;
    private Gtk.Label dark_score_label;
    private Gtk.Label light_score_label;
    private Gtk.Dialog propbox;
    private Gtk.Stack main_stack;
    private Gtk.Box game_box;

    private Gtk.Button back_button;
    private Gtk.Button undo_button;

    private SimpleAction back_action;


    /* Computer player (if there is one) */
    private ComputerPlayer? computer = null;

    /* Human player */
    private Player player_one;

    /* The game being played */
    private Game? game = null;

    private static const OptionEntry[] option_entries =
    {
        { "fast-mode", 'f', 0, OptionArg.NONE, ref fast_mode, N_("Reduce delay before AI moves"), null},
        { "first", 0, 0, OptionArg.NONE, null, N_("Play first"), null},
        { "level", 'l', 0, OptionArg.INT, ref computer_level, N_("Set the level of the computer's AI"), null},
        { "mute", 0, 0, OptionArg.NONE, null, N_("Turn off the sound"), null},
        { "second", 0, 0, OptionArg.NONE, null, N_("Play second"), null},
        { "size", 's', 0, OptionArg.INT, ref size, N_("Size of the board (debug only)"), null},
        { "two-players", 0, 0, OptionArg.NONE, null, N_("Two-players mode"), null},
        { "unmute", 0, 0, OptionArg.NONE, null, N_("Turn on the sound"), null},
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null},
        { null }
    };

    private const GLib.ActionEntry app_actions[] =
    {
        /* http://valadoc.org/#!api=gio-2.0/GLib.SimpleActionChangeStateCallback
         * TODO SimpleActionChangeStateCallback is deprecated... */
        {"change-mode", change_mode_cb, "s"},
        {"change-difficulty", change_difficulty_cb, "s"},

        {"new-game", new_game_cb},
        {"start-game", start_game_cb},

        {"undo-move", undo_move_cb},
        {"back", back_cb},

        {"preferences", preferences_cb},
        {"help", help_cb},
        {"about", about_cb},
        {"quit", quit_cb}
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Iagno"));

        Gtk.Window.set_default_icon_name ("iagno");

        return new Iagno ().run (args);
    }

    public Iagno ()
    {
        Object (application_id: "org.gnome.iagno", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "iagno", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (size < 4 || size % 2 != 0)
        {
            /* Console message displayed for an incorrect size */
            stderr.printf ("%s\n", _("Size must be even and at least 4."));
            return Posix.EXIT_FAILURE;
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
                stderr.printf ("%s\n", _("Level should be between 1 (easy) and 3 (hard). Settings unchanged."));
        }

        /* The game mode is set for the next game. */
        if (options.contains ("two-players"))
            settings.set_string ("play-as", "two-players");
        else if (options.contains ("first"))
            settings.set_string ("play-as", "first");
        else if (options.contains ("second"))
            settings.set_string ("play-as", "second");
        else
            begin_with_new_game_screen = true;

        /* Activate */
        return -1;
    }

    protected override void startup()
    {
        base.startup ();
        add_action_entries (app_actions, this);
        set_accels_for_action ("app.undo-move", {"<Primary>z"});

        var builder = new Gtk.Builder.from_resource ("/org/gnome/iagno/ui/iagno.ui");

        window = builder.get_object ("iagno-window") as Gtk.ApplicationWindow;
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();
        add_window (window);
        view = new GameView ();
        view.move.connect (player_move_cb);
        var tile_set = settings.get_string ("tileset");
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", tile_set);
        view.halign = Gtk.Align.FILL;
        view.show ();

        game_box = builder.get_object ("game-box") as Gtk.Box;
        game_box.pack_start (view);

        headerbar = builder.get_object ("headerbar") as Gtk.HeaderBar;
        light_score_label = builder.get_object ("light-score-label") as Gtk.Label;
        dark_score_label = builder.get_object ("dark-score-label") as Gtk.Label;
        mark_icon_dark = builder.get_object ("mark-icon-dark") as Gtk.Image;
        mark_icon_light = builder.get_object ("mark-icon-light") as Gtk.Image;
        main_stack = builder.get_object ("main_stack") as Gtk.Stack;
        back_button = builder.get_object ("back_button") as Gtk.Button;
        undo_button = builder.get_object ("undo_button") as Gtk.Button;

        back_action = (SimpleAction) lookup_action ("back");

        var level_box = builder.get_object ("level-box") as Gtk.Box;

        settings.changed["play-as"].connect (() => {
            var mode = settings.get_string ("play-as");
            level_box.sensitive = (mode == "two-players") ? false : true;
        });

        if (begin_with_new_game_screen)
            show_new_game_screen ();
        else
            start_game ();
    }

    private void change_mode_cb (SimpleAction action, Variant? variant)
    {
        settings.set_string ("play-as", variant.get_string ());
    }

    private void change_difficulty_cb (SimpleAction action, Variant? variant)
    {
        var difficulty = int.parse (variant.get_string ());
        settings.set_int ("computer-level", difficulty);
    }

    protected override void activate ()
    {
        window.present ();
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

    private void start_game_cb ()
    {
        back_button.visible = false;
        start_game ();
    }

    private void back_cb ()
    {
        show_game_board ();
        back_action.set_enabled (false);

        if (game.current_color != player_one && computer != null)
            computer.move_async.begin (SLOW_MOVE_DELAY);
    }

    private void show_game_board ()
    {
        main_stack.set_visible_child_name ("frame");
        back_button.visible = false;
        undo_button.visible = true;
    }

    private void show_new_game_screen ()
    {
        if (computer != null)
            computer.cancel_move ();

        main_stack.set_visible_child_name ("start-box");
        back_button.sensitive = game != null;
        back_button.visible = true;
        undo_button.visible = false;
        back_action.set_enabled (true);
    }

    private void new_game_cb ()
    {
        show_new_game_screen ();
        headerbar.set_subtitle (null);
    }

    private void start_game ()
    {
        if (game != null)
            SignalHandler.disconnect_by_func (game, null, this);

        if (computer != null)
            computer.cancel_move ();

        if (view != null)
            game_box.remove (view);

        show_game_board ();

        game = new Game (size);
        game.move.connect (game_move_cb);
        game.complete.connect (game_complete_cb);
        view.game = game;
        view.show ();
        game_box.pack_start (view);

        var mode = settings.get_string ("play-as");
        if (mode == "two-players")
            computer = null;
        else
            computer = new ComputerPlayer (game, settings.get_int ("computer-level"));

        player_one = (mode == "first") ? Player.DARK : Player.LIGHT;

        update_ui ();

        if (player_one != Player.DARK && computer != null)
            computer.move_async.begin (MODERATE_MOVE_DELAY);
    }

    private void update_ui ()
    {
        headerbar.set_subtitle (null);

        var undo_action = (SimpleAction) lookup_action ("undo-move");
        if (player_one == Player.DARK || computer == null)
            undo_action.set_enabled (game.number_of_moves >= 1);
        else
            undo_action.set_enabled (game.number_of_moves >= 2);

        /* Translators: this is a 2 digit representation of the current score. */
        dark_score_label.set_markup ("<span font_weight='bold'>"+(_("%.2d").printf (game.n_dark_tiles))+"</span>");
        light_score_label.set_markup ("<span font_weight='bold'>"+(_("%.2d").printf (game.n_light_tiles))+"</span>");

        if (game.current_color == Player.DARK)
        {
            mark_icon_light.hide ();
            mark_icon_dark.show ();
        }
        else if (game.current_color == Player.LIGHT)
        {
            mark_icon_dark.hide ();
            mark_icon_light.show ();
        }
    }

    private void undo_move_cb ()
    {
        if (computer == null)
        {
            game.undo (1);
            if (!game.can_move (game.current_color))
                game.undo (1);
        }
        else
        {
            computer.cancel_move ();

            /* Undo once if the human player just moved, otherwise undo both moves */
            if (game.current_color != player_one)
                game.undo (1);
            else
                game.undo (2);

            /* If forced to pass, undo to last chosen move so the computer doesn't play next */
            while (!game.can_move (game.current_color))
                game.undo (2);
        }

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
        if (propbox == null)
            create_preferences_dialog ();
        propbox.show_all ();
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
            if (fast_mode)
                computer.move_async.begin (QUICK_MOVE_DELAY);
            else
                computer.move_async.begin (SLOW_MOVE_DELAY);
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

    private void sound_select (Gtk.ToggleButton widget)
    {
        var play_sounds = widget.get_active ();
        settings.set_boolean ("sound", play_sounds);
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

    private void create_preferences_dialog ()
    {
        var builder = new Gtk.Builder.from_resource ("/org/gnome/iagno/ui/iagno-preferences.ui");

        /* the dialog is not in the ui file for the use-header-bar flag to be switchable */
        propbox = new Gtk.Dialog.with_buttons (_("Preferences"),
                                               window,
                                               Gtk.DialogFlags.USE_HEADER_BAR,
                                               null);
        var box = (Gtk.Box) propbox.get_content_area ();
        propbox.resizable = false;
        propbox.delete_event.connect (propbox_close_cb);
        var grid = builder.get_object ("main-grid") as Gtk.Grid;
        box.pack_start (grid, true, true, 0);

        var theme_combo = builder.get_object ("theme-combo") as Gtk.ComboBox;
        var model = builder.get_object ("liststore-theme") as Gtk.ListStore;
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

        Gtk.TreeIter iter;
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
        theme_combo.changed.connect (theme_changed_cb);

        var enable_sounds_button = builder.get_object ("sound-button") as Gtk.CheckButton;
        settings.changed["sound"].connect (() => {
            enable_sounds_button.set_active (settings.get_boolean ("sound"));
        });
        enable_sounds_button.set_active (settings.get_boolean ("sound"));
        enable_sounds_button.toggled.connect (sound_select);
    }
}
