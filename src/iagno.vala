/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2010-2013 Robert Ancell
   Copyright 2013-2014 Michael Catanzaro
   Copyright 2014-2020 Arnaud Bonatti

   GNOME Reversi is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME Reversi is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME Reversi.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;

private class Iagno : Gtk.Application
{
    /* Translators: application name, as used in the window manager, the window title, the about dialog... */
    internal const string PROGRAM_NAME = _("Reversi");

    /* Application settings */
    private GLib.Settings settings;
    private static bool fast_mode;
    private static bool print_logs;
    private static bool alternative_start;
    private static bool random_start;
    private static bool usual_start;
    private static bool classic_game;
    private static bool reverse_game;
    private static string? level = null;
    private static int size = 8;
    private static bool? sound = null;
    private static bool two_players = false;
    private static bool? play_first = null;

    /* Seconds */
    private const double QUICK_MOVE_DELAY = 0.4;
    private const double MODERATE_MOVE_DELAY = 1.7;
    private const double SLOW_MOVE_DELAY = 1.9;

    /* Widgets */
    private GameWindow window;
    private ReversiView view;

    private ThemeManager theme_manager = new ThemeManager ();

    /* Computer player (if there is one) */
    internal ComputerPlayer? computer { internal get; private set; default = null; }

    /* Human player */
    internal Player player_one { internal get; private set; }

    /* The game being played */
    private Game game;
    private bool game_is_set = false;

    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'iagno --help' */
        { "alternative-start", 0, OptionFlags.NONE, OptionArg.NONE, ref alternative_start, N_("Start with an alternative position"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "classic", 0, OptionFlags.NONE, OptionArg.NONE, ref classic_game,                N_("Play Classic Reversi"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "fast-mode", 'f', OptionFlags.NONE, OptionArg.NONE, ref fast_mode,               N_("Reduce delay before AI moves"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "first", 0, OptionFlags.NONE, OptionArg.NONE, null,                              N_("Play first"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "level", 'l', OptionFlags.NONE, OptionArg.STRING, ref level,                     N_("Set the level of the computer’s AI"),

        /* Translators: in the command-line options description, text to indicate the user should specify a level, see 'iagno --help' */
                                                                                           N_("LEVEL") },

        /* Translators: command-line option description, see 'iagno --help' */
        { "mute", 0, OptionFlags.NONE, OptionArg.NONE, null,                               N_("Turn off the sound"), null },

        /* Translators: command-line option description, currently hidden; might appear one day in 'iagno --help' */
        { "print-logs", 0, OptionFlags.HIDDEN, OptionArg.NONE, ref print_logs,             N_("Log the game moves"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "random-start", 0, OptionFlags.NONE, OptionArg.NONE, ref random_start,           N_("Start with a random position"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "reverse", 0, OptionFlags.NONE, OptionArg.NONE, ref reverse_game,                N_("Play Reverse Reversi"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "second", 0, OptionFlags.NONE, OptionArg.NONE, null,                             N_("Play second"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "size", 's', OptionFlags.NONE, OptionArg.INT, ref size,                          N_("Size of the board (debug only)"),

        /* Translators: in the command-line options description, text to indicate the user should specify a size, see 'iagno --help' */
                                                                                           N_("SIZE") },

        /* Translators: command-line option description, see 'iagno --help' */
        { "two-players", 0, OptionFlags.NONE, OptionArg.NONE, null,                        N_("Two-players mode"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "unmute", 0, OptionFlags.NONE, OptionArg.NONE, null,                             N_("Turn on the sound"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "usual-start", 0, OptionFlags.NONE, OptionArg.NONE, ref usual_start,             N_("Start with the usual position"), null },

        /* Translators: command-line option description, see 'iagno --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null,                          N_("Print release version and exit"), null },
        {}
    };

    private const GLib.ActionEntry app_actions [] =
    {
        { "alternate-who-starts", null, null, "false", change_alternate_who_starts },  // need to be able to disable the action, so no settings.create_action()
        { "game-type", change_game_type, "s" },
        { "change-level", change_level_cb, "s" },

        { "set-use-night-mode", set_use_night_mode, "b" },
        { "help", help },
        { "about", about },
        { "quit", quit }
    };

    private static int main (string [] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
        Environment.set_prgname ("org.gnome.Reversi");

        Adw.init ();

        Window.set_default_icon_name ("org.gnome.Reversi");

        return new Iagno ().run (args);
    }

    private Iagno ()
    {
        Object (application_id: "org.gnome.Reversi", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stdout.printf ("%1$s %2$s\n", "iagno", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if ((usual_start && random_start)
         || (random_start && alternative_start)
         || (alternative_start && usual_start))
        {
            /* Translators: command-line error message, displayed when two antagonist arguments are used; try 'iagno --usual-start --alternative-start' */
            stderr.printf ("%s\n", _("The “--alternative-start”, “--random-start” and “--usual-start” arguments are mutually exclusive."));
            return Posix.EXIT_FAILURE;
        }

        if (classic_game && reverse_game)
        {
            /* Translators: command-line error message, displayed when two antagonist arguments are used; try 'iagno --reverse --classic' */
            stderr.printf ("%s\n", _("The “--classic” and “--reverse” arguments are mutually exclusive."));
            return Posix.EXIT_FAILURE;
        }

        if (size < 4)
        {
            /* Translators: command-line error message, displayed for an incorrect game size request; try 'iagno -s 2' */
            stderr.printf ("%s\n", _("Size must be at least 4."));
            return Posix.EXIT_FAILURE;
        }
        if (size > 16)
        {
            /* Translators: command-line error message, displayed for an incorrect game size request; try 'iagno -s 17' */
            stderr.printf ("%s\n", _("Size must not be more than 16."));
            return Posix.EXIT_FAILURE;
        }

        if (options.contains ("mute"))
            sound = false;
        else if (options.contains ("unmute"))
            sound = true;

        if (options.contains ("two-players"))
            two_players = true;
        else if (options.contains ("first"))
            play_first = true;
        else if (options.contains ("second"))
            play_first = false;

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        /* Settings */
        settings = new GLib.Settings ("org.gnome.Reversi");

        /* Actions */
        add_action_entries (app_actions, this);
        set_accels_for_action ("ui.new-game",           {        "<Primary>n"       });
        set_accels_for_action ("ui.start-game",         { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q",
                                                          "<Shift><Primary>q"       });
        set_accels_for_action ("ui.undo",               {        "<Primary>z"       });
     // set_accels_for_action ("ui.redo",               { "<Shift><Primary>z"       });
        set_accels_for_action ("base.escape",           {                 "Escape"  });
        set_accels_for_action ("base.toggle-hamburger", {                 "F10"     });
        set_accels_for_action ("app.help",              {                 "F1"      });
        set_accels_for_action ("app.about",             {          "<Shift>F1"      });
        add_action (settings.create_action ("highlight-playable-tiles"));
        add_action (settings.create_action ("highlight-turnable-tiles"));
        if (!alternative_start && !random_start && !usual_start)
            add_action (settings.create_action ("random-start-position"));
        add_action (settings.create_action ("sound"));
        add_action (settings.create_action ("theme"));

        var css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/Reversi/ui/style.css");

        StyleContext.add_provider_for_display (
            (!) Gdk.Display.get_default (),
            css_provider,
            STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void create_window () {
        bool start_now = (two_players == true) || (play_first != null);
        if ((sound != null) || start_now || (level != null) || classic_game || reverse_game)
        {
            settings.delay ();

            if (classic_game)
                settings.set_string ("type", "classic");
            else if (reverse_game)
                settings.set_string ("type", "reverse");

            if (sound != null)
                settings.set_boolean ("sound", (!) sound);

            if (start_now)
                settings.set_int ("num-players", two_players ? 2 : 1);

            if (play_first != null)
                settings.set_string ("color", ((!) play_first) ? "dark" : "light");

            // TODO start one-player game immediately, if two_players == false
            if (level != null)
            {
                // TODO add a localized text option?
                switch ((!) level)
                {
                    case "1":
                    case "easy":
                    case "one":     settings.set_int ("computer-level", 1); break;

                    case "2":
                    case "medium":
                    case "two":     settings.set_int ("computer-level", 2); break;

                    case "3":
                    case "hard":
                    case "three":   settings.set_int ("computer-level", 3); break;

                    default:
                        /* Translators: command-line error message, displayed for an incorrect level request; try 'iagno -l 5' */
                        stderr.printf ("%s\n", _("Level should be between 1 (easy) and 3 (hard). Settings unchanged."));
                    //  stderr.printf ("%s\n", _("Level should be 1 (easy), 2 (medium) or 3 (hard). Settings unchanged.")); // TODO better?
                        break;
                }
            }
            settings.apply ();
        }

        /* UI parts */
        view = new ReversiView (this, theme_manager);
        view.move.connect (player_move_cb);
        view.clear_impossible_to_move_here_warning.connect (clear_impossible_to_move_here_warning);

        GLib.Menu type_menu = new GLib.Menu ();
        GLib.Menu section = new GLib.Menu ();
        /* Translators: when configuring a new game, in the first menubutton's menu, label of the entry to choose to play first/Dark (with a mnemonic that appears pressing Alt) */
        section.append (_("Play _first (Dark)"),  "app.game-type('dark')");


        /* Translators: when configuring a new game, in the first menubutton's menu, label of the entry to choose to play second/Light (with a mnemonic that appears pressing Alt) */
        section.append (_("Play _second (Light)"), "app.game-type('light')");
        section.freeze ();
        type_menu.append_section (null, section);

        section = new GLib.Menu ();
        /* Translators: when configuring a new game, in the first menubutton's menu, label of the entry to choose to alternate who starts between human and AI (with a mnemonic that appears pressing Alt) */
        section.append (_("_Alternate who starts"), "app.alternate-who-starts");
        section.freeze ();
        type_menu.append_section (null, section);

        section = new GLib.Menu ();
        /* Translators: when configuring a new game, in the first menubutton's menu, label of the entry to choose a two-players game (with a mnemonic that appears pressing Alt) */
        section.append (_("_Two players"), "app.game-type('two')");
        section.freeze ();
        type_menu.append_section (null, section);

        type_menu.freeze ();

        GLib.Menu level_menu = new GLib.Menu ();
        section = new GLib.Menu ();
        /* Translators: when configuring a new game, in the second menubutton's menu, label of the entry to choose an easy-level computer adversary (with a mnemonic that appears pressing Alt) */
        level_menu.append (_("_Easy"),   "app.change-level('1')");


        /* Translators: when configuring a new game, in the second menubutton's menu, label of the entry to choose a medium-level computer adversary (with a mnemonic that appears pressing Alt) */
        level_menu.append (_("_Medium"), "app.change-level('2')");


        /* Translators: when configuring a new game, in the second menubutton's menu, label of the entry to choose a hard-level computer adversary (with a mnemonic that appears pressing Alt) */
        level_menu.append (_("_Hard"),   "app.change-level('3')");
        section.freeze ();
        level_menu.append_section (null, section);


        if (!alternative_start && !random_start && !usual_start)
        {
            section = new GLib.Menu ();
            /* Translators: when configuring a new game, in the second menubutton's menu, label of the entry to choose to use randomly an alternative start position (with a mnemonic that appears pressing Alt) */
            section.append (_("_Vary start position"), "app.random-start-position");
            section.freeze ();
            level_menu.append_section (null, section);
        }
        level_menu.freeze ();

        GLib.Menu appearance_menu = new GLib.Menu ();
        section = new GLib.Menu ();
        /* Translators: hamburger menu "Appearance" submenu entry; a name for the default theme */
        section.append (_("Default"), "app.theme('default')");
        Dir dir;
        string wanted_theme_id = settings.get_string ("theme");
        bool theme_name_found = false;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes", "key"));
            while (true)
            {
                string? filename = dir.read_name ();
                if (filename == null)
                    break;
                if (filename == "default")
                {
                    warning ("There should not be a theme filename named \"default\", ignoring it.");
                    continue;
                }

                string path = Path.build_filename (DATA_DIRECTORY, "themes", "key", (!) filename);
                GLib.KeyFile key = new GLib.KeyFile ();
                string theme_name;
                try
                {
                    key.load_from_file (path, GLib.KeyFileFlags.NONE);
                    theme_name = key.get_locale_string ("Theme", "Name");
                }
                catch (GLib.KeyFileError e)
                {
                    warning ("oops: %s", e.message);
                    continue;
                }
                section.append (theme_name, @"app.theme('$((!) filename)')");

                if (wanted_theme_id == (!) filename)
                {
                    theme_name_found = true;
                    theme_manager.theme = wanted_theme_id;
                }
            }
        }
        catch (FileError e)
        {
            warning ("Failed to load themes: %s", e.message);
        }
        if (!theme_name_found && wanted_theme_id != "default")
        {
            warning (@"Theme $wanted_theme_id not found, using default.");
            settings.set_string ("theme", "default");
            wanted_theme_id = "default";
         // theme_manager.theme defaults on "default" (in fact, on null)
        }
        section.freeze ();
        appearance_menu.append_section (null, section);

        section = new GLib.Menu ();
        /* Translators: hamburger menu "Appearance" submenu entry, in the "Highlight" section; highlight-playable-tiles togglebutton (with a mnemonic that appears pressing Alt) */
        section.append (_("Pla_yable tiles"), "app.highlight-playable-tiles");


        /* Translators: hamburger menu "Appearance" submenu entry, in the "Highlight" section; highlight-capturable-tiles togglebutton (with a mnemonic that appears pressing Alt); these are not the playable tiles, but the one that could be captured by a play */
        section.append (_("_Capturable tiles"), "app.highlight-turnable-tiles");
        section.freeze ();

        /* Translators: hamburger menu "Appearance" submenu section header; the section lists several game helpers that are done by highlighting tiles on the board: "Capturable tiles" and "Playable tiles"; "Highlights" is probably better understood as a noun than as a verb here */
        appearance_menu.append_section (_("Highlights"), section);
        appearance_menu.freeze ();

        /* window */
        window = new GameWindow (start_now, view, appearance_menu);

        window.new_game_screen.update_menubutton_menu (NewGameScreen.MenuButton.ONE, type_menu);
        window.new_game_screen.update_menubutton_menu (NewGameScreen.MenuButton.TWO, level_menu);

        window.history_button1.theme_manager = theme_manager;
        window.history_button2.theme_manager = theme_manager;
        view.notify_final_animation.connect ((undoing) => {
                window.history_button1.set_game_finished (!undoing);
                window.history_button2.set_game_finished (!undoing);
            });

        window.play.connect (start_game);
        window.wait.connect (wait_cb);
        window.back.connect (back_cb);
        window.undo.connect (undo_cb);

        theme_manager.gtk_theme_changed ();

        /* Preferences */
        settings.bind ("highlight-playable-tiles", view,            "show-playable-tiles", SettingsBindFlags.GET);
        settings.bind ("highlight-turnable-tiles", view,            "show-turnable-tiles", SettingsBindFlags.GET);
        settings.bind ("theme",                    theme_manager,   "theme",               SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        /* New-game screen signals */
        alternate_who_starts_action = (SimpleAction) lookup_action ("alternate-who-starts");
        change_level_action         = (SimpleAction) lookup_action ("change-level");

        settings.changed ["alternate-who-starts"].connect ((_settings, key_name) => {
                alternate_who_starts_action.set_state (_settings.get_value (key_name));
            });
        alternate_who_starts_action.set_state (settings.get_value ("alternate-who-starts"));

        settings.changed ["computer-level"].connect (() => {
                if (level_changed)
                    level_changed = false;
                else if (settings.get_int ("num-players") == 1)
                    update_level_button_state (settings.get_int ("computer-level") /* 1 <= level <= 3 */);
            });

        settings.changed ["color"].connect (() => {
                if (game_type_changed_1)
                {
                    game_type_changed_1 = false;
                    return;
                }

                if (settings.get_int ("num-players") == 2)
                    return;
                if (settings.get_string ("color") == "dark")
                    update_game_type_button_label ("dark");
                else
                    update_game_type_button_label ("light");
            });

        settings.changed ["num-players"].connect (() => {
                if (game_type_changed_2)
                {
                    game_type_changed_2 = false;
                    return;
                }

                if (settings.get_int ("num-players") == 2)
                {
                    update_level_button_state (/* "More options" */ 0);
                    update_game_type_button_label ("two");
                }
                else
                {
                    update_level_button_state (settings.get_int ("computer-level"));
                    if (settings.get_string ("color") == "dark")
                        update_game_type_button_label ("dark");
                    else
                        update_game_type_button_label ("light");
                }
            });

        if (settings.get_int ("num-players") == 2)
        {
            update_level_button_state (/* "More options" */ 0);
            update_game_type_button_label ("two");
            alternate_who_starts_action.set_enabled (false);
        }
        else
        {
            update_level_button_state (settings.get_int ("computer-level"));
            if (settings.get_string ("color") == "dark")
                update_game_type_button_label ("dark");
            else
                update_game_type_button_label ("light");
        }

        if (start_now)
            start_game ();

        add_window (window);
    }

    protected override void activate ()
    {
        if (get_active_window () == null)
            create_window ();

        window.present ();
    }

    protected override void shutdown ()
    {
        if (get_active_window () != null)
            window.destroy ();

        base.shutdown ();
    }

    /*\
    * * Night mode
    \*/

    private void set_use_night_mode (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        var style_manager = Adw.StyleManager.get_default ();
        if (((!) gvariant).get_boolean ())
            style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;
        else
            style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
    }

    /*\
    * * Internal calls
    \*/

    private SimpleAction alternate_who_starts_action;
    private void change_alternate_who_starts (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        // the state will be updated in response to the settings change
        settings.set_value ("alternate-who-starts", (!) gvariant);
    }

    private bool game_type_changed_1 = false;
    private bool game_type_changed_2 = false;
    private void change_game_type (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        string type = ((!) gvariant).get_string ();
        update_game_type_button_label (type);
        game_type_changed_1 = true;
        game_type_changed_2 = true;
        switch (type)
        {
            case "two":   settings.set_int    ("num-players", 2); update_level_button_state (/* "More options" */ 0);
                          /* no change to the color of course; */ alternate_who_starts_action.set_enabled (false);  return;
            // DO NOT delay/apply or you lose sync between alternate_who_starts_action and the settings after switching to one-player mode
            case "dark":  settings.set_int    ("num-players", 1); update_level_button_state (settings.get_int ("computer-level"));
                          settings.set_string ("color",  "dark"); alternate_who_starts_action.set_enabled (true);   return;
            // DO NOT delay/apply or you lose sync between alternate_who_starts_action and the settings after switching to one-player mode
            case "light": settings.set_int    ("num-players", 1); update_level_button_state (settings.get_int ("computer-level"));
                          settings.set_string ("color", "light"); alternate_who_starts_action.set_enabled (true);   return;
            default: assert_not_reached ();
        }
    }
    private void update_game_type_button_label (string type)
    {
        switch (type)
        {
            case "two":
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.ONE,
                /* Translators: when configuring a new game, button label if a two-players game is chosen */
                                                         _("Two players"));             return;
            case "dark":
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.ONE,
                /* Translators: when configuring a new game, button label if the player choose to start */
                                                         _("Color: Dark"));             return;
            case "light":
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.ONE,
                /* Translators: when configuring a new game, button label if the player choose let computer start */
                                                         _("Color: Light"));            return;
            default: assert_not_reached ();
        }
    }

    private bool level_changed = false;
    private SimpleAction change_level_action;
    private void change_level_cb (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        if (settings.get_int ("num-players") == 2)
            return; // assert_not_reached() ?

        level_changed = true;
        int level = int.parse (((!) gvariant).get_string ());
        update_level_button_state (level /* 1 <= level <= 3 */);
        settings.set_int ("computer-level", level);
    }
    private void update_level_button_state (int /* 0 <= */ level /* <= 3 */)
    {
        switch (level)
        {
            case 0:
                change_level_action.set_enabled (false);
                if (alternative_start || random_start || usual_start)
                {
                    window.new_game_screen.update_menubutton_sensitivity (NewGameScreen.MenuButton.TWO, false);
                    update_level_button_label ((uint8) settings.get_int ("computer-level"));
                }
                else
                    update_level_button_label (0);                                                      return;

            case 1:
                change_level_action.set_enabled (true);
                window.new_game_screen.update_menubutton_sensitivity (NewGameScreen.MenuButton.TWO, true);
                update_level_button_label (1);                                                          return;

            case 2:
                change_level_action.set_enabled (true);
                window.new_game_screen.update_menubutton_sensitivity (NewGameScreen.MenuButton.TWO, true);
                update_level_button_label (2);                                                          return;

            case 3:
                change_level_action.set_enabled (true);
                window.new_game_screen.update_menubutton_sensitivity (NewGameScreen.MenuButton.TWO, true);
                update_level_button_label (3);                                                          return;

            default: assert_not_reached ();
        }
    }
    private void update_level_button_label (uint8 /* 0 <= */ level /* <= 3 */)
    {
        switch (level)
        {
            case 0:
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.TWO,
                /* Translators: when configuring a new game, second menubutton label, when configuring a two-player game */
                                                         _("More options"));            return;
            case 1:
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.TWO,
                /* Translators: when configuring a new game, button label for the AI level, if easy */
                                                         _("Difficulty: Easy"));        return;
            case 2:
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.TWO,
                /* Translators: when configuring a new game, button label for the AI level, if medium */
                                                         _("Difficulty: Medium"));      return;
            case 3:
                window.new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.TWO,
                /* Translators: when configuring a new game, button label for the AI level, if hard */
                                                         _("Difficulty: Hard"));        return;
            default: assert_not_reached ();
        }
    }

    private void back_cb ()
        requires (game_is_set)
    {
        set_window_title ();
        if (game.current_color != player_one && computer != null && !game.is_complete)
            ((!) computer).move (SLOW_MOVE_DELAY);
        else if (game.is_complete)
            game_complete (/* play sound */ false);
    }

    private void wait_cb ()
    {
        if (computer != null)
            ((!) computer).cancel_move ();
    }

    private void start_game ()
    {
        if (game_is_set)
            SignalHandler.disconnect_by_func (game, null, this);

        if (computer != null)
            ((!) computer).cancel_move ();

        bool two_players = settings.get_int ("num-players") == 2;
        bool even_board = size % 2 == 0;
        bool random_start_settings = settings.get_boolean ("random-start-position");

        Opening opening;
        if (alternative_start)
        {
            if (even_board)
                opening = get_locale_direction () == TextDirection.LTR ? Opening.ALTER_LEFT : Opening.ALTER_RIGHT;
            else
                opening = get_locale_direction () == TextDirection.LTR ? Opening.ALTER_RIGHT : Opening.ALTER_LEFT;
        }
        else if (usual_start)
            opening = Opening.REVERSI;
        else if (two_players
              && random_start_settings
              && !random_start)
            opening = Opening.HUMANS;
        else if (random_start
              || random_start_settings)
        {
            switch (Random.int_range (0, 8))
            {
                case 0: case 1: opening = Opening.REVERSI;      break;
                case 2: case 3: opening = Opening.INVERTED;     break;
                case 4:         opening = Opening.ALTER_TOP;    break;
                case 5:         opening = Opening.ALTER_LEFT;   break;
                case 6:         opening = Opening.ALTER_RIGHT;  break;
                case 7:         opening = Opening.ALTER_BOTTOM; break;
                default: assert_not_reached ();
            }
        }
        else
            opening = Opening.REVERSI;

        bool reverse = settings.get_string ("type") == "reverse";
        game = new Game (reverse, opening, (uint8) size /* 4 <= size <= 16 */, print_logs);
        set_window_title ();
        game_is_set = true;
        game.turn_ended.connect (turn_ended_cb);
        view.game = game;

        window.history_button1.set_player (Player.DARK);
        window.history_button2.set_player (Player.DARK);
        window.history_button1.set_game_finished (false);
        window.history_button2.set_game_finished (false);

        if (two_players)
            computer = null;
        else
        {
            uint8 computer_level = (uint8) settings.get_int ("computer-level");
            if (reverse)
                switch (computer_level)
                {
                    case 1 : computer = new ComputerReverseEasy (game);                break;
                    case 2 : computer = new ComputerReverseHard (game, /* depth */ 1); break;
                    case 3 : computer = new ComputerReverseHard (game, /* depth */ 2); break;
                    default: assert_not_reached ();
                }
            else
                switch (computer_level)
                {
                    case 1 : computer = new ComputerReversiEasy (game);                break;
                    case 2 : computer = new ComputerReversiHard (game, /* depth */ 0); break;
                    case 3 : computer = new ComputerReversiHard (game, /* depth */ 1); break;
                    default: assert_not_reached ();
                }
        }

        if (settings.get_enum ("color") == 1)
            player_one = Player.LIGHT;
        else
            player_one = Player.DARK;

        first_player_is_human = two_players || (player_one == Player.DARK);
        update_ui ();

        if (!two_players)
        {
            if (player_one == Player.DARK)
            {
                if (settings.get_boolean ("alternate-who-starts"))
                    settings.set_string ("color", "light");
            }
            else
            {
                if (settings.get_boolean ("alternate-who-starts"))
                    settings.set_string ("color", "dark");
                ((!) computer).move (MODERATE_MOVE_DELAY);     // TODO MODERATE_MOVE_DELAY = 1.0, but after the sliding animation…
            }
        }
    }

    private bool first_player_is_human = false;
    private void update_ui ()
        requires (game_is_set)
    {
        window.new_turn_start (/* can undo */ first_player_is_human ? (game.number_of_moves >= 1) : (game.number_of_moves >= 2));
    }

    private void undo_cb ()
        requires (game_is_set)
    {
        if (view.undo_final_animation ())
        {
            play_sound (Sound.GAMEOVER);
            return;
        }

        if (computer == null)
        {
            game.undo (1);
            if (!game.current_player_can_move)
                game.undo (1);
        }
        else
        {
            ((!) computer).cancel_move ();

            /* Undo once if the human player just moved, otherwise undo both moves */
            if (game.current_color != player_one)
                game.undo (1);
            else
                game.undo (2);

            /* If forced to pass, undo to last chosen move so the computer doesn't play next */
            while (!game.current_player_can_move)
                game.undo (2);
        }

        update_ui ();
        update_scoreboard ();
    }

    private void turn_ended_cb (bool undoing, bool no_draw)
        requires (game_is_set)
    {
        if (undoing && no_draw)
            return;

        update_ui ();
        if (game.current_player_can_move)
            prepare_move ();
        else if (game.is_complete)
            game_complete (/* play sound */ true);
            // view is updated by connecting to game.notify ["is-complete"]
        else
            pass ();
    }

    private void prepare_move ()
        requires (game_is_set)
    {
        update_scoreboard ();

        /*
         * Get the computer to move after a delay, so it looks like it's
         * thinking. Make it fairly long so the human doesn't feel overwhelmed,
         * but not so long as to become boring.
         */
        if (game.current_color != player_one && computer != null)
            ((!) computer).move (fast_mode ? QUICK_MOVE_DELAY : SLOW_MOVE_DELAY);
    }

    private void pass ()
        requires (game_is_set)
    {
        update_scoreboard ();

        if (!game.pass ())
            assert_not_reached ();

        if (game.current_color == Player.DARK)
        {
            /* Translators: during a game, notification to display when Light has no possible moves */
            window.show_notification (_("Light must pass, Dark’s move"));
        }
        else
        {
            /* Translators: during a game, notification to display when Dark has no possible moves */
            window.show_notification (_("Dark must pass, Light’s move"));
        }
    }

    private void game_complete (bool play_gameover_sound)
        requires (game_is_set)
    {
        window.finish_game ();
        window.history_button1.set_player (Player.NONE);
        window.history_button2.set_player (Player.NONE);

        if ((!game.reverse && game.n_light_tiles > game.n_dark_tiles)
         || ( game.reverse && game.n_light_tiles < game.n_dark_tiles))
            /* Translators: during a game, notification to display when Light has won the game; the %u are replaced with the Light and Dark number of tiles */
            window.show_notification (_("Light wins! (%u-%u)").printf (game.n_light_tiles, game.n_dark_tiles));

        else if ((!game.reverse && game.n_light_tiles < game.n_dark_tiles)
              || ( game.reverse && game.n_light_tiles > game.n_dark_tiles))
            /* Translators: during a game, notification to display when Dark has won the game; the %u are replaced with the Dark and Light number of tiles */
            window.show_notification (_("Dark wins! (%u-%u)").printf (game.n_dark_tiles, game.n_light_tiles));

        else
            /* Translators: during a game, notification to display when the game is a draw */
            window.show_notification (_("The game is draw."));

        if (play_gameover_sound)
            play_sound (Sound.GAMEOVER);
    }

    private void player_move_cb (uint8 x, uint8 y)
        requires (game_is_set)
    {
        /* Ignore if we are waiting for the AI to move or if game is finished */
        if ((game.current_color != player_one && computer != null) || !game.current_player_can_move)
            return;

        /* Place tile if possible, and if so do not do anything else */
        if (game.place_tile (x, y))
            return;

        if (game.opening != Opening.HUMANS)
            /* Translators: during a game, notification to display when the player tries to make an illegal move */
            window.show_notification (_("You can’t move there!"));

        else if (game.current_color == Player.LIGHT
              && game.n_light_tiles == 0
              && (x == game.size / 2 - 1 || x == game.size / 2)
              && (y == game.size / 2 - 1 || y == game.size / 2))
            /* Translators: during the overture (at the start) of a two-players game, when Dark has played, notification displayed if Light clicks at the opposite tile relatively to Dark one */
            window.show_notification (_("In this opening, Light can only play on tiles bordering on Dark one."));

        else
            /* Translators: during the overture (at the start) of a two-players game, notification displayed if the board is clicked elsewhere of the four playable tiles that are highlighted */
            window.show_notification (_("Click on one of the highlighted tiles to move the selected piece there."));
    }

    private void clear_impossible_to_move_here_warning ()
        requires (game_is_set)
    {
    }

    private void update_scoreboard ()
    {
        /* for the move that just ended */
        play_sound (Sound.FLIP);
        window.history_button1.set_player (game.current_color);
        window.history_button2.set_player (game.current_color);
    }

    private void set_window_title ()
    {
        /* Translators: name of one of the games, as displayed in the headerbar when playing */
        window.update_title (game.reverse ? _("Reverse Reversi")

        /* Translators: name of one of the games, as displayed in the headerbar when playing */
                                          : _("Classic Reversi"));
    }

    /*\
    * * Sound
    \*/

    private MediaFile? last_played;

    private enum Sound
    {
        FLIP,
        GAMEOVER;
    }

    private enum SoundContextState
    {
        INITIAL,
        WORKING,
        ERRORED
    }

    private void play_sound (Sound sound)
    {
        if (!settings.get_boolean ("sound"))
            return;

        string name;
        switch (sound)
        {
            case Sound.FLIP:
                name = theme_manager.sound_flip;
                break;
            case Sound.GAMEOVER:
                name = theme_manager.sound_gameover;
                break;
            default:
                return;
        }
        if (name == "")
            assert_not_reached ();

        string path = Path.build_filename (SOUND_DIRECTORY, name);
        var media_file = MediaFile.for_filename (path);
        last_played = media_file;
        media_file.play ();
    }

    private void help (/* SimpleAction action, Variant? variant */)
    {
        show_uri (active_window, "help:iagno", Gdk.CURRENT_TIME);
    }

    private void about (/* SimpleAction action, Variant? path_variant */)
    {
        var about_dialog = new Adw.AboutDialog ();
        about_dialog.set_title (_("About"));
        about_dialog.set_application_icon ("org.gnome.Reversi");
        about_dialog.set_application_name (PROGRAM_NAME);
        about_dialog.set_version (VERSION);
        about_dialog.set_license_type (License.GPL_3_0);    // forced, 1/3
        about_dialog.set_artists ({
            /* Translators: text crediting an artist, in the about dialog */
            _("Masuichi Ito (pieces)"),
            /* Translators: text crediting an artist, in the about dialog */
            _("Arnaud Bonatti (themes)")
        });
        about_dialog.set_developers ({
            /* Translators: text crediting an author, in the about dialog */
            _("Ian Peters"),
            /* Translators: text crediting an author, in the about dialog */
            _("Robert Ancell"),
            /* Translators: text crediting an author, in the about dialog */
            _("Arnaud Bonatti")
        });
        about_dialog.set_comments (
            /* Translators: about dialog text */
            _("A disk flipping game derived from Reversi")
        );
        about_dialog.set_copyright (
            /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
            _("Copyright \xc2\xa9 %u-%u – Ian Peters").printf (1998, 2008) + "\n" +
            /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
            _("Copyright \xc2\xa9 %u-%u – Michael Catanzaro").printf (2013, 2015) + "\n" +
            /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
            _("Copyright \xc2\xa9 %u-%u – Arnaud Bonatti").printf (2014, 2020) + "\n" +
            /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
            _("Copyright \xc2\xa9 %u – Andrey Kutejko").printf (2025)
        );
        about_dialog.set_documenters ({
            /* Translators: text crediting a documenter, in the about dialog */
            _("Tiffany Antopolski")
        });
        about_dialog.set_translator_credits (
            /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
            _("translator-credits")
        );
        about_dialog.set_website ("https://wiki.gnome.org/Apps/Reversi");

        about_dialog.present (active_window);
    }
}

