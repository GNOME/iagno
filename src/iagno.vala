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

private class Iagno : Gtk.Application
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
    private const double SLOW_MOVE_DELAY = 2.0;

    /* Widgets */
    private GameWindow window;
    private GameView view;
    private Label dark_score_label;
    private Label light_score_label;

    private bool should_init_themes_dialog = true;
    private ThemesDialog themes_dialog;

    /* Computer player (if there is one) */
    private ComputerPlayer? computer = null;

    /* Human player */
    private Player player_one;

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
        {"theme", theme_cb},
        {"help", help_cb},
        {"about", about_cb},
        {"quit", quit}
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
        Builder builder = new Builder.from_resource ("/org/gnome/Reversi/ui/iagno-screens.ui");

        view = new GameView ();
        view.move.connect (player_move_cb);

        DrawingArea scoredrawing = (DrawingArea) builder.get_object ("scoredrawing");
        view.scoreboard = scoredrawing;
        view.theme = settings.get_string ("theme");

        /* Window */
        window = new GameWindow ("/org/gnome/Reversi/ui/iagno.css",
                                 PROGRAM_NAME,
                                 settings.get_int ("window-width"),
                                 settings.get_int ("window-height"),
                                 settings.get_boolean ("window-is-maximized"),
                                 start_now,
                                 GameWindowFlags.SHOW_UNDO | GameWindowFlags.SHOW_START_BUTTON,
                                 (Box) builder.get_object ("new-game-screen"),
                                 view);

        Widget scoregrid = (Widget) builder.get_object ("scoregrid");
        window.add_to_sidebox (scoregrid);

        window.play.connect (start_game);
        window.wait.connect (wait_cb);
        window.back.connect (back_cb);
        window.undo.connect (undo_cb);

        /* Actions and preferences */
        add_action_entries (app_actions, this);
        set_accels_for_action ("ui.new-game",           {        "<Primary>n"       });
        set_accels_for_action ("ui.start-game",         { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q"       });
        set_accels_for_action ("ui.undo",               {        "<Primary>z"       });
     // set_accels_for_action ("ui.redo",               { "<Shift><Primary>z"       });
        set_accels_for_action ("ui.back",               {                 "Escape"  });
        set_accels_for_action ("ui.toggle-hamburger",   {                 "F10"     });
        set_accels_for_action ("app.help",              {                 "F1"      });
        set_accels_for_action ("app.about",             {          "<Shift>F1"      });
        add_action (settings.create_action ("sound"));
        add_action (settings.create_action ("color"));
        add_action (settings.create_action ("num-players"));
        add_action (settings.create_action ("computer-level"));

        Box level_box = (Box) builder.get_object ("difficulty-box");
        Box color_box = (Box) builder.get_object ("color-box");
        settings.changed ["num-players"].connect (() => {
            bool solo = settings.get_int ("num-players") == 1;
            level_box.sensitive = solo;
            color_box.sensitive = solo;
        });
        bool solo = settings.get_int ("num-players") == 1;
        level_box.sensitive = solo;
        color_box.sensitive = solo;

        /* Information widgets */
        light_score_label = (Label) builder.get_object ("light-score-label");
        dark_score_label = (Label) builder.get_object ("dark-score-label");

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
        window.shutdown (settings);
        base.shutdown ();
    }

    /*\
    * * App-menu callbacks
    \*/

    private void theme_cb ()
    {
        /* Don’t permit to open more than one dialog */
        if (should_init_themes_dialog)
        {
            themes_dialog = new ThemesDialog (settings, view);
            themes_dialog.set_transient_for (window);
            should_init_themes_dialog = false;
        }
        themes_dialog.present ();
    }

    private void help_cb ()
    {
        try
        {
            show_uri (window.get_screen (), "help:iagno", get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void about_cb ()
    {
        string [] authors = { "Ian Peters", "Robert Ancell" };
        string [] documenters = { "Tiffany Antopolski" };

        show_about_dialog (window,
                           "name", PROGRAM_NAME,
                           "version", VERSION,
                           "copyright",
                             "Copyright © 1998–2008 Ian Peters\n"+
                             "Copyright © 2013–2015 Michael Catanzaro\n"+
                             "Copyright © 2014–2019 Arnaud Bonatti",
                           "license-type", License.GPL_3_0,
                           "comments",
                             /* Translators: about dialog text */
                             _("A disk flipping game derived from Reversi"),
                           "authors", authors,
                           "documenters", documenters,
                           /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "org.gnome.Reversi",
                           "website", "https://wiki.gnome.org/Apps/Iagno",
                           null);
    }

    /*\
    * * Internal calls
    \*/

    private void back_cb ()
        requires (game_is_set)
    {
        if (game.current_color != player_one && computer != null && !game.is_complete)
            ((!) computer).move_async.begin (SLOW_MOVE_DELAY);
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
            computer = new ComputerPlayer (game, (uint8) settings.get_int ("computer-level"));

        if (settings.get_enum ("color") == 1)
            player_one = Player.LIGHT;
        else
            player_one = Player.DARK;

        first_player_is_human = (player_one == Player.DARK) || (computer == null);
        update_ui ();

        if (player_one != Player.DARK && computer != null)
            ((!) computer).move_async.begin (MODERATE_MOVE_DELAY);     // TODO MODERATE_MOVE_DELAY = 1.0, but after the sliding animation…
    }

    private bool first_player_is_human = false;
    private void update_ui ()
        requires (game_is_set)
    {
        window.new_turn_start (/* can undo */ first_player_is_human ? (game.number_of_moves >= 1) : (game.number_of_moves >= 2));

        /* Translators: this is a 2 digit representation of the current score. */
        dark_score_label.set_text (_("%.2d").printf (game.n_dark_tiles));
        light_score_label.set_text (_("%.2d").printf (game.n_light_tiles));
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
        play_sound (Sound.FLIP);
        view.update_scoreboard ();
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
        /* for the move that just ended */
        play_sound (Sound.FLIP);
        view.update_scoreboard ();

        /*
         * Get the computer to move after a delay, so it looks like it's
         * thinking. Make it fairly long so the human doesn't feel overwhelmed,
         * but not so long as to become boring.
         */
        if (game.current_color != player_one && computer != null)
            ((!) computer).move_async.begin (fast_mode ? QUICK_MOVE_DELAY : SLOW_MOVE_DELAY);
    }

    private void pass ()
        requires (game_is_set)
    {
        /* for the move that just ended */
        play_sound (Sound.FLIP);
        view.update_scoreboard ();

        game.pass ();
        if (game.current_color == Player.DARK)
        {
            /* Translators: during a game, notification to display when Light has no possible moves */
            window.set_subtitle (_("Light must pass, Dark’s move"));
        }
        else
        {
            /* Translators: during a game, notification to display when Dark has no possible moves */
            window.set_subtitle (_("Dark must pass, Light’s move"));
        }
    }

    private void game_complete (bool play_gameover_sound)
        requires (game_is_set)
    {
        window.finish_game ();

        if (game.n_light_tiles > game.n_dark_tiles)
        {
            /* Translators: during a game, notification to display when Light has won the game */
            window.set_subtitle (_("Light wins!"));
        }
        else if (game.n_dark_tiles > game.n_light_tiles)
        {
            /* Translators: during a game, notification to display when Dark has won the game */
            window.set_subtitle (_("Dark wins!"));
        }
        else
        {
            /* Translators: during a game, notification to display when the game is a draw */
            window.set_subtitle (_("The game is draw."));
        }

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
            window.set_subtitle (_("You can’t move there!"));
        }
    }

    /*\
    * * Sound
    \*/

    private enum Sound
    {
        FLIP,
        GAMEOVER;
    }

    private void play_sound (Sound sound)
    {
        if (settings.get_boolean ("sound"))
            _play_sound (sound, ref view);
    }

    private static void _play_sound (Sound sound, ref GameView view)
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
        int r = CanberraGtk.play_for_widget (view, 0,
                                             Canberra.PROP_MEDIA_NAME, name,
                                             Canberra.PROP_MEDIA_FILENAME, path);
        if (r != 0)
        {
            string? error = Canberra.strerror (r);
            warning ("Error playing %s: %s", path, error ?? "unknown error");
        }
    }
}
