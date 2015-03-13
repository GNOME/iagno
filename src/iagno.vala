/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This file is part of Iagno.
 *
 * Iagno is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Iagno is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Iagno. If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class Iagno : Gtk.Application
{
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
    private static const double QUICK_MOVE_DELAY = 0.4;
    private static const double MODERATE_MOVE_DELAY = 1.0;
    private static const double SLOW_MOVE_DELAY = 2.0;

    /* Widgets */
    private GameWindow window;
    private GameView view;
    private Label dark_score_label;
    private Label light_score_label;
    private ThemesDialog themes_dialog;

    /* Computer player (if there is one) */
    private ComputerPlayer? computer = null;

    /* Human player */
    private Player player_one;

    /* The game being played */
    private Game? game = null;

    private static const OptionEntry[] option_entries =
    {
        { "alternative-start", 0, 0, OptionArg.NONE, ref alternative_start, N_("Start with an alternative position"), null},
        { "fast-mode", 'f', 0, OptionArg.NONE, ref fast_mode, N_("Reduce delay before AI moves"), null},
        { "first", 0, 0, OptionArg.NONE, null, N_("Play first"), null},
        { "level", 'l', 0, OptionArg.STRING, ref level, N_("Set the level of the computer's AI"), "LEVEL"},
        { "mute", 0, 0, OptionArg.NONE, null, N_("Turn off the sound"), null},
        { "second", 0, 0, OptionArg.NONE, null, N_("Play second"), null},
        { "size", 's', 0, OptionArg.INT, ref size, N_("Size of the board (debug only)"), "SIZE"},
        { "two-players", 0, 0, OptionArg.NONE, null, N_("Two-players mode"), null},
        { "unmute", 0, 0, OptionArg.NONE, null, N_("Turn on the sound"), null},
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null},
        { null }
    };

    private const GLib.ActionEntry app_actions[] =
    {
        {"theme", theme_cb},
        {"help", help_cb},
        {"about", about_cb},
        {"quit", quit}
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Iagno"));
        Window.set_default_icon_name ("iagno");

        return new Iagno ().run (args);
    }

    private Iagno ()
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

        if (size < 4)
        {
            /* Console message displayed for an incorrect size */
            stderr.printf ("%s\n", _("Size must be at least 4."));
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
        settings = new GLib.Settings ("org.gnome.iagno");

        if (sound != null)
            settings.set_boolean ("sound", sound);

        bool start_now = (two_players == true) || (play_first != null);
        if (start_now)
            settings.set_int ("num-players", two_players ? 2 : 1);
        else /* hack, part 1 of 4 */
            two_players = (settings.get_int ("num-players") == 2);

        string color;
        if (play_first != null)
        {
            color = play_first ? "dark" : "light";
            settings.set_string ("color", color);
        }
        else /* hack, part 2 of 4 */
            color = settings.get_string ("color");

        int computer_level;
        if (level == "1" || level == "2" || level == "3")
        {
            computer_level = int.parse (level);
            settings.set_int ("computer-level", computer_level);
        }
        else
        {
            if (level != null)
                stderr.printf ("%s\n", _("Level should be between 1 (easy) and 3 (hard). Settings unchanged."));
            /* hack, part 3 of 4 */
            computer_level = settings.get_int ("computer-level");
        }

        /* UI parts */
        Builder builder = new Builder.from_resource ("/org/gnome/iagno/ui/iagno-screens.ui");

        view = new GameView ();
        view.move.connect (player_move_cb);

        DrawingArea scoredrawing = (DrawingArea) builder.get_object ("scoredrawing");
        view.scoreboard = scoredrawing;
        view.theme = settings.get_string ("theme");

        /* Window */
        window = new GameWindow ("/org/gnome/iagno/ui/iagno.css",
                                 _("Iagno"),
                                 settings.get_int ("window-width"),
                                 settings.get_int ("window-height"),
                                 settings.get_boolean ("window-is-maximized"),
                                 start_now,
                                 GameWindowFlags.SHOW_UNDO,
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
        set_accels_for_action ("win.new-game", {"<Primary>n"});
        set_accels_for_action ("win.start-game", {"<Primary><Shift>n"});
        set_accels_for_action ("win.undo", {"<Primary>z"});
        set_accels_for_action ("win.redo", {"<Primary><Shift>z"});
        set_accels_for_action ("win.back", {"Escape"});
        add_action (settings.create_action ("sound"));
        /* TODO bugs when changing manually the gsettings key (not for sound);
         * solving this bug may remove the need of the hack in four parts */
        add_action (settings.create_action ("color"));
        add_action (settings.create_action ("num-players"));
        add_action (settings.create_action ("computer-level"));

        var level_box = (Box) builder.get_object ("difficulty-box");
        var color_box = (Box) builder.get_object ("color-box");
        settings.changed["num-players"].connect (() => {
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

        /* Hack for restoring radiobuttons settings, part 4 of 4.
         * When you add_window(), settings are initialized with the value
         * of the first radiobutton of the group found in the UI file. */
        GLib.Settings.sync ();
        settings.set_string ("color", color);
        settings.set_int ("computer-level", computer_level);
        settings.set_int ("num-players", two_players ? 2 : 1);
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
        if (themes_dialog == null)
        {
            themes_dialog = new ThemesDialog (settings, view);
            themes_dialog.set_transient_for (window);
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
        string[] authors = { "Ian Peters", "Robert Ancell", null };
        string[] documenters = { "Tiffany Antopolski", null };

        show_about_dialog (window,
                           "name", _("Iagno"),
                           "version", VERSION,
                           "copyright",
                             "Copyright © 1998–2008 Ian Peters\n"+
                             "Copyright © 2013–2015 Michael Catanzaro\n"+
                             "Copyright © 2014–2015 Arnaud Bonatti",
                           "license-type", License.GPL_3_0,
                           "comments",
                             _("A disk flipping game derived from Reversi"),
                           "authors", authors,
                           "documenters", documenters,
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "iagno",
                           "website", "https://wiki.gnome.org/Apps/Iagno",
                           null);
    }

    /*\
    * * Internal calls
    \*/

    private void back_cb ()
    {
        if (game.current_color != player_one && computer != null && !game.is_complete)
            computer.move_async.begin (SLOW_MOVE_DELAY);
        else if (game.is_complete)
            game_complete (false);
    }

    private void wait_cb ()
    {
        if (computer != null)
            computer.cancel_move ();
    }

    private void start_game ()
    {
        if (game != null)
            SignalHandler.disconnect_by_func (game, null, this);

        if (computer != null)
            computer.cancel_move ();

        game = new Game (alternative_start, size);
        game.turn_ended.connect (turn_ended_cb);
        view.game = game;

        if (settings.get_int ("num-players") == 2)
            computer = null;
        else
            computer = new ComputerPlayer (game, settings.get_int ("computer-level"));

        if (settings.get_enum ("color") == 1)
            player_one = Player.LIGHT;
        else
            player_one = Player.DARK;

        update_ui ();

        if (player_one != Player.DARK && computer != null)
            computer.move_async.begin (MODERATE_MOVE_DELAY);
    }

    private void update_ui ()
    {
        window.set_subtitle (null);

        if (player_one == Player.DARK || computer == null)
            window.undo_action.set_enabled (game.number_of_moves >= 1);
        else
            window.undo_action.set_enabled (game.number_of_moves >= 2);

        /* Translators: this is a 2 digit representation of the current score. */
        dark_score_label.set_text (_("%.2d").printf (game.n_dark_tiles));
        light_score_label.set_text (_("%.2d").printf (game.n_light_tiles));
    }

    private void undo_cb ()
    {
        if (computer == null)
        {
            game.undo (1);
            if (!game.current_player_can_move)
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
            while (!game.current_player_can_move)
                game.undo (2);
        }

        update_ui ();
        play_sound (Sound.FLIP);
        view.update_scoreboard ();
    }

    private void turn_ended_cb ()
    {
        update_ui ();
        if (game.current_player_can_move)
            prepare_move ();
        else if (game.is_complete)
            game_complete ();
        else
            pass ();
    }

    private void prepare_move ()
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
        {
            if (fast_mode)
                computer.move_async.begin (QUICK_MOVE_DELAY);
            else
                computer.move_async.begin (SLOW_MOVE_DELAY);
        }
    }

    private void pass ()
    {
        /* for the move that just ended */
        play_sound (Sound.FLIP);
        view.update_scoreboard ();

        game.pass ();
        if (game.current_color == Player.DARK)
        {
            /* Message to display when Light has no possible moves */
            window.set_subtitle (_("Light must pass, Dark’s move"));
        }
        else
        {
            /* Message to display when Dark has no possible moves */
            window.set_subtitle (_("Dark must pass, Light’s move"));
        }
    }

    private void game_complete (bool play_gameover_sound = true)
    {
        window.finish_game ();

        if (game.n_light_tiles > game.n_dark_tiles)
        {
            /* Message to display when Light has won the game */
            window.set_subtitle (_("Light wins!"));
        }
        else if (game.n_dark_tiles > game.n_light_tiles)
        {
            /* Message to display when Dark has won the game */
            window.set_subtitle (_("Dark wins!"));
        }
        else
        {
            /* Message to display when the game is a draw */
            window.set_subtitle (_("The game is draw."));
        }

        if (play_gameover_sound)
            play_sound (Sound.GAMEOVER);
    }

    private void player_move_cb (int x, int y)
    {
        /* Ignore if we are waiting for the AI to move or if game is finished */
        if ((game.current_color != player_one && computer != null) || !game.current_player_can_move)
            return;

        if (game.place_tile (x, y) == 0)
        {
            /* Message to display when the player tries to make an illegal move */
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
        if (!settings.get_boolean ("sound"))
            return;

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
            warning ("Error playing file: %s\nfilepath should be:%s\n", name, path);
    }
}
