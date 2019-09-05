/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2010-2013 Robert Ancell
   Copyright 2013-2014 Michael Catanzaro
   Copyright 2014-2019 Arnaud Bonatti

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

private class Iagno : Gtk.Application, BaseApplication
{
    /* Translators: application name, as used in the window manager, the window title, the about dialog... */
    internal const string PROGRAM_NAME = _("Iagno");

    /* Application settings */
    private GLib.Settings settings;
    private static bool fast_mode;
    private static bool alternative_start;
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
    private NewGameScreen new_game_screen;

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
        { "alternative-start", 0, 0, OptionArg.NONE, ref alternative_start, N_("Start with an alternative position"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "fast-mode", 'f', 0, OptionArg.NONE, ref fast_mode,               N_("Reduce delay before AI moves"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "first", 0, 0, OptionArg.NONE, null,                              N_("Play first"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "level", 'l', 0, OptionArg.STRING, ref level,                     N_("Set the level of the computer’s AI"), "LEVEL"},

        /* Translators: command-line option description, see 'iagno --help' */
        { "mute", 0, 0, OptionArg.NONE, null,                               N_("Turn off the sound"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "second", 0, 0, OptionArg.NONE, null,                             N_("Play second"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "size", 's', 0, OptionArg.INT, ref size,                          N_("Size of the board (debug only)"), "SIZE"},

        /* Translators: command-line option description, see 'iagno --help' */
        { "two-players", 0, 0, OptionArg.NONE, null,                        N_("Two-players mode"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "unmute", 0, 0, OptionArg.NONE, null,                             N_("Turn on the sound"), null},

        /* Translators: command-line option description, see 'iagno --help' */
        { "version", 'v', 0, OptionArg.NONE, null,                          N_("Print release version and exit"), null},
        {}
    };

    private const GLib.ActionEntry app_actions [] =
    {
        { "game-type", null, "s", "'dark'", change_game_type },
        { "set-use-night-mode", set_use_night_mode, "b" },

        { "quit", quit }
    };

    private static int main (string [] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
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

        bool start_now = (two_players == true) || (play_first != null);
        if ((sound != null) || start_now || (level != null))
        {
            settings.delay ();
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
        view = new ReversiView (this);
        view.move.connect (player_move_cb);
        view.clear_impossible_to_move_here_warning.connect (clear_impossible_to_move_here_warning);

        new_game_screen = new NewGameScreen ();

        if (settings.get_boolean ("sound"))
            init_sound ();

        GLib.Menu appearance_menu = new GLib.Menu ();
        GLib.Menu section = new GLib.Menu ();
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
                    view.theme = wanted_theme_id;
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
         // view.theme defaults on "default" (in fact, on null)
        }
        section.freeze ();
        appearance_menu.append_section (null, section);

        section = new GLib.Menu ();
        /* Translators: hamburger menu "Appearance" submenu entry; highlight-turnable-tiles togglebutton (with a mnemonic that appears pressing Alt); these are not the playable tiles, but the one that could be captured by a play */
        section.append (_("Highlight _turnable tiles"), "app.highlight-turnable-tiles");
        section.freeze ();
        appearance_menu.append_section (null, section);
        appearance_menu.freeze ();

        /* Window */
        init_night_mode ();
        window = new GameWindow ("/org/gnome/Reversi/ui/iagno.css",
                                 PROGRAM_NAME,
                                 /* Translators: hamburger menu entry; open about dialog (with a mnemonic that appears pressing Alt) */
                                 _("About Iagno"),
                                 start_now,
                                 GameWindowFlags.SHOW_START_BUTTON
                                 | GameWindowFlags.HAS_SOUND
                                 | GameWindowFlags.SHORTCUTS
                                 | GameWindowFlags.SHOW_HELP
                                 | GameWindowFlags.SHOW_UNDO,
                                 (Box) new_game_screen,
                                 view,
                                 appearance_menu,
                                 night_light_monitor);

        window.play.connect (start_game);
        window.wait.connect (wait_cb);
        window.back.connect (back_cb);
        window.undo.connect (undo_cb);

        window.gtk_theme_changed.connect (view.theme_changed);

        /* Actions and preferences */
        add_action_entries (app_actions, this);
        set_accels_for_action ("ui.new-game",           {        "<Primary>n"       });
        set_accels_for_action ("ui.start-game",         { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q",
                                                          "<Shift><Primary>q"       });
        set_accels_for_action ("ui.undo",               {        "<Primary>z"       });
     // set_accels_for_action ("ui.redo",               { "<Shift><Primary>z"       });
        set_accels_for_action ("base.escape",           {                 "Escape"  });
        set_accels_for_action ("base.toggle-hamburger", {                 "F10"     });
     // set_accels_for_action ("app.help",              {                 "F1"      });
     // set_accels_for_action ("base.about",            {          "<Shift>F1"      });
        add_action (settings.create_action ("sound"));
        add_action (settings.create_action ("color"));
        add_action (settings.create_action ("num-players"));
        add_action (settings.create_action ("computer-level"));
        add_action (settings.create_action ("highlight-turnable-tiles"));
        add_action (settings.create_action ("theme"));

        settings.bind ("highlight-turnable-tiles", view, "show-turnable-tiles", SettingsBindFlags.GET);
        settings.bind ("theme",                    view, "theme",               SettingsBindFlags.GET);

        game_type_action = (SimpleAction) lookup_action ("game-type");

        settings.changed ["color"].connect (() => {
                if (settings.get_int ("num-players") == 2)
                    return;
                if (settings.get_string ("color") == "dark")
                    game_type_action.set_state (new Variant.string ("dark"));
                else
                    game_type_action.set_state (new Variant.string ("light"));
            });

        settings.changed ["num-players"].connect (() => {
                bool solo = settings.get_int ("num-players") == 1;
                new_game_screen.update_sensitivity (solo);
                if (!solo)
                    game_type_action.set_state (new Variant.string ("two"));
                else if (settings.get_string ("color") == "dark")
                    game_type_action.set_state (new Variant.string ("dark"));
                else
                    game_type_action.set_state (new Variant.string ("light"));
            });
        bool solo = settings.get_int ("num-players") == 1;
        new_game_screen.update_sensitivity (solo);

        if (settings.get_int ("num-players") == 2)
            game_type_action.set_state (new Variant.string ("two"));
        else if (settings.get_string ("color") == "dark")
            game_type_action.set_state (new Variant.string ("dark"));
        else
            game_type_action.set_state (new Variant.string ("light"));

        if (start_now)
            start_game ();

        add_window (window);
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        window.destroy ();
        base.shutdown ();
    }

    /*\
    * * Night mode
    \*/

    NightLightMonitor night_light_monitor;  // keep it here or it is unrefed

    private void init_night_mode ()
    {
        night_light_monitor = new NightLightMonitor ("/org/gnome/iagno/");
    }

    private void set_use_night_mode (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        night_light_monitor.set_use_night_mode (((!) gvariant).get_boolean ());
        view.theme_changed ();
    }

    /*\
    * * Internal calls
    \*/

    private SimpleAction game_type_action;
    private void change_game_type (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        string type = ((!) gvariant).get_string ();
//        game_type_action.set_state ((!) gvariant);
        switch (type)
        {
            case "dark":  settings.set_int    ("num-players", 1); new_game_screen.update_sensitivity (true);
                          settings.set_string ("color",  "dark");                                             return;
            case "light": settings.set_int    ("num-players", 1); new_game_screen.update_sensitivity (true);
                          settings.set_string ("color", "light");                                             return;
            case "two":   settings.set_int    ("num-players", 2); new_game_screen.update_sensitivity (false); return;
            default: assert_not_reached ();
        }
    }

    private void back_cb ()
        requires (game_is_set)
    {
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

        game = new Game (alternative_start, (uint8) size /* 4 <= size <= 16 */);
        game_is_set = true;
        game.turn_ended.connect (turn_ended_cb);
        view.game = game;

        if (settings.get_int ("num-players") == 2)
            computer = null;
        else
        {
            uint8 computer_level = (uint8) settings.get_int ("computer-level");
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

        first_player_is_human = (player_one == Player.DARK) || (computer == null);
        update_ui ();

        if (player_one != Player.DARK && computer != null)
            ((!) computer).move (MODERATE_MOVE_DELAY);     // TODO MODERATE_MOVE_DELAY = 1.0, but after the sliding animation…
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

        if (game.n_light_tiles > game.n_dark_tiles)
            /* Translators: during a game, notification to display when Light has won the game; the %u are replaced with the Light and Dark number of tiles */
            window.show_notification (_("Light wins! (%u-%u)").printf (game.n_light_tiles, game.n_dark_tiles));

        else if (game.n_dark_tiles > game.n_light_tiles)
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

        if (!game.place_tile (x, y))
        {
            /* Translators: during a game, notification to display when the player tries to make an illegal move */
            window.show_notification (_("You can’t move there!"));
        }
    }

    private void clear_impossible_to_move_here_warning ()
        requires (game_is_set)
    {
        window.clear_subtitle ();
    }

    private void update_scoreboard ()
    {
        /* for the move that just ended */
        play_sound (Sound.FLIP);
        window.set_history_button_label (game.current_color);
    }

    /*\
    * * Sound
    \*/

    private GSound.Context sound_context;
    private SoundContextState sound_context_state = SoundContextState.INITIAL;

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

    private void init_sound ()
     // requires (sound_context_state == SoundContextState.INITIAL)
    {
        try
        {
            sound_context = new GSound.Context ();
            sound_context_state = SoundContextState.WORKING;
        }
        catch (Error e)
        {
            warning (e.message);
            sound_context_state = SoundContextState.ERRORED;
        }
    }

    private void play_sound (Sound sound)
    {
        if (settings.get_boolean ("sound"))
        {
            if (sound_context_state == SoundContextState.INITIAL)
                init_sound ();
            if (sound_context_state == SoundContextState.WORKING)
                _play_sound (sound, sound_context, ref view);
        }
    }

    private static void _play_sound (Sound sound, GSound.Context sound_context, ref ReversiView view)
     // requires (sound_context_state == SoundContextState.WORKING)
    {
        string name;
        switch (sound)
        {
            case Sound.FLIP:
                name = view.sound_flip;
                break;
            case Sound.GAMEOVER:
                name = view.sound_gameover;
                break;
            default:
                return;
        }
        string path = Path.build_filename (SOUND_DIRECTORY, name);
        try
        {
            sound_context.play_simple (null, GSound.Attribute.MEDIA_NAME, name,
                                             GSound.Attribute.MEDIA_FILENAME, path);
        }
        catch (Error e)
        {
            warning (e.message);
        }
    }

    /*\
    * * Copy action
    \*/

    internal void copy (string text)
    {
        Gdk.Display? display = Gdk.Display.get_default ();
        if (display == null)
            return;

        Gtk.Clipboard clipboard = Gtk.Clipboard.get_default ((!) display);
        clipboard.set_text (text, text.length);
    }

    /*\
    * * about dialog infos
    \*/

    internal void get_about_dialog_infos (out string [] artists,
                                          out string [] authors,
                                          out string    comments,
                                          out string    copyright,
                                          out string [] documenters,
                                          out string    logo_icon_name,
                                          out string    program_name,
                                          out string    translator_credits,
                                          out string    version,
                                          out string    website,
                                          out string    website_label)
    {
        /* Translators: about dialog text */
        comments = _("A disk flipping game derived from Reversi");

        artists = {
        /* Translators: text crediting an artist, in the about dialog */
            _("Masuichi Ito (pieces)"),


        /* Translators: text crediting an artist, in the about dialog */
            _("Arnaud Bonatti (themes)")
        };

        authors = {
        /* Translators: text crediting an author, in the about dialog */
            _("Ian Peters"),


        /* Translators: text crediting an author, in the about dialog */
            _("Robert Ancell"),


        /* Translators: text crediting an author, in the about dialog */
            _("Arnaud Bonatti")
        };


        /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
        copyright = _("Copyright \xc2\xa9 %u-%u – Ian Peters").printf (1998, 2008) + "\n" +


        /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
                    _("Copyright \xc2\xa9 %u-%u – Michael Catanzaro").printf (2013, 2015) + "\n" +


        /* Translators: text crediting a maintainer, in the about dialog text; the %u are replaced with the years of start and end */
                    _("Copyright \xc2\xa9 %u-%u – Arnaud Bonatti").printf (2014, 2019);


        /* Translators: text crediting a documenter, in the about dialog */
        documenters = { _("Tiffany Antopolski") };
        logo_icon_name = "org.gnome.Reversi";
        program_name = PROGRAM_NAME;

        /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
        translator_credits = _("translator-credits");
        version = VERSION;

        website = "https://wiki.gnome.org/Apps/Iagno";
        /* Translators: about dialog text; label of the website link */
        website_label = _("Page on GNOME wiki");
    }
}
