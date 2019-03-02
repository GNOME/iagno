/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2015, 2016, 2019 Arnaud Bonatti

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

[Flags]
private enum GameWindowFlags {
    SHORTCUTS,
    SHOW_HELP,
    SHOW_HINT,
    SHOW_REDO,
    SHOW_UNDO,
    SHOW_START_BUTTON;
}

[GtkTemplate (ui = "/org/gnome/Reversi/ui/game-window.ui")]
private class GameWindow : ApplicationWindow
{
    private bool game_finished = false;

    /* settings */
    private bool window_is_tiled;
    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private int window_width;
    private int window_height;

    /* private widgets */
    [GtkChild] private Overlay main_overlay;
    [GtkChild] private Button unfullscreen_button;

    private GameHeaderBar   headerbar;
    private GameView        game_view;

    internal GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget _view, GLib.Menu? appearance_menu)
    {
        if (css_resource != null)
        {
            CssProvider css_provider = new CssProvider ();
            css_provider.load_from_resource ((!) css_resource);
            Gdk.Screen? gdk_screen = Gdk.Screen.get_default ();
            if (gdk_screen != null) // else..?
                StyleContext.add_provider_for_screen ((!) gdk_screen, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        /* window config */
        install_ui_action_entries ();
        set_title (name);

        headerbar = new GameHeaderBar (name, flags, appearance_menu);
        headerbar.show ();
        set_titlebar (headerbar);

        ((ReversiView) _view).notify_final_animation.connect ((undoing) => { headerbar.update_history_button (!undoing); });

        game_view = new GameView (flags, new_game_screen, _view);
        game_view.show ();
        main_overlay.add (game_view);

        set_default_size (width, height);
        if (maximized)
            maximize ();

        size_allocate.connect (size_allocate_cb);
        window_state_event.connect (window_state_event_cb);

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    internal void finish_game ()
    {
        game_finished = true;
        headerbar.finish_game ();
    }

    /*\
    * * Showing the Stack
    \*/

    private void show_new_game_screen ()
    {
        bool grabs_focus = headerbar.show_new_game_screen (game_finished);
        game_view.show_new_game_box (/* grab focus */ !grabs_focus);
    }

    private void show_view ()
    {
        bool grabs_focus = headerbar.show_view (game_finished);
        game_view.show_game_content (/* grab focus */ !grabs_focus);
    }

    /*\
    * * actions
    \*/

    internal signal void play ();
    internal signal void wait ();
    internal signal void back ();

    internal signal void restart ();
    internal signal void undo ();
    internal signal void redo ();
    internal signal void hint ();

 // private SimpleAction restart_action;
    private SimpleAction    undo_action;
    private SimpleAction    redo_action;
 // private SimpleAction    hint_action;

    private bool back_action_disabled = true;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

     // restart_action = (SimpleAction) action_group.lookup_action ("restart");
           undo_action = (SimpleAction) action_group.lookup_action ("undo");
           redo_action = (SimpleAction) action_group.lookup_action ("redo");
     //    hint_action = (SimpleAction) action_group.lookup_action ("hint");

     // restart_action.set_enabled (false);
           undo_action.set_enabled (false);
           redo_action.set_enabled (false);
     //    hint_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "new-game",           new_game_cb },          // "New game" button or <Shift>n

        { "start-game", start_game_cb },
        { "back", back_cb },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb },

        { "toggle-hamburger", toggle_hamburger },
        { "unfullscreen", unfullscreen }
    };

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
     // if (game_view.is_in_in_window_mode ())
     //     return;
        if (!game_view.game_content_visible_if_true ())
            return;

        new_game ();
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
     // if (game_view.is_in_in_window_mode ())
     //     return;
        if (!game_view.game_content_visible_if_true ())
        {
            if (!back_action_disabled)
                back_cb ();
            return;
        }

        game_finished = false;
     // hide_notification ();

        game_view.show_game_content (/* grab focus */ true);
     // redo_action.set_enabled (true);
        undo ();
    }

    private void redo_cb (/* SimpleAction action, Variant? variant */)
    {
     // if (game_view.is_in_in_window_mode ())
     //     return;
        if (!game_view.game_content_visible_if_true ())
            return;

        game_view.show_game_content (/* grab focus */ true);
     // restart_action.set_enabled (true);
        undo_action.set_enabled (true);

        redo ();
    }

    private void hint_cb (/* SimpleAction action, Variant? variant */)
    {
     // if (game_view.is_in_in_window_mode ())
     //     return;
        if (!game_view.game_content_visible_if_true ())
            return;

        hint ();
    }

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        headerbar.toggle_hamburger ();
    }

    /*\
    * * Window events
    \*/

    private void size_allocate_cb ()
    {
        if (window_is_maximized || window_is_tiled || window_is_fullscreen)
            return;
        get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            window_is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        /* fullscreen: saved as maximized */
        bool window_was_fullscreen = window_is_fullscreen;
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            window_is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
        if (window_was_fullscreen && !window_is_fullscreen)
            unfullscreen_button.hide ();
        else if (!window_was_fullscreen && window_is_fullscreen)
            unfullscreen_button.show ();

        /* tiled: not saved, but should not change saved window size */
        Gdk.WindowState tiled_state = Gdk.WindowState.TILED
                                    | Gdk.WindowState.TOP_TILED
                                    | Gdk.WindowState.BOTTOM_TILED
                                    | Gdk.WindowState.LEFT_TILED
                                    | Gdk.WindowState.RIGHT_TILED;
        if ((event.changed_mask & tiled_state) != 0)
            window_is_tiled = (event.new_window_state & tiled_state) != 0;

        return false;
    }

    internal void shutdown (GLib.Settings settings)
    {
        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", window_is_maximized || window_is_fullscreen);
        settings.apply ();
        destroy ();
    }

    /*\
    * * Some internal calls
    \*/

    internal void cannot_undo_more ()
    {
        undo_action.set_enabled (false);
        game_view.show_game_content (/* grab focus */ true);
    }

    internal void new_turn_start (bool can_undo)
    {
        undo_action.set_enabled (can_undo);
        headerbar.set_subtitle (null);
    }

    internal void set_subtitle (string subtitle)
    {
        headerbar.set_subtitle (subtitle);
    }

    internal void clear_subtitle ()
    {
        headerbar.set_subtitle (null);
    }

    internal void set_history_button_label (Player player)
    {
        headerbar.set_history_button_label (player);
    }

    /*\
    * * actions helper
    \*/

    private void new_game ()
    {
        wait ();

        game_view.configure_transition (StackTransitionType.SLIDE_LEFT, 800);

        headerbar.new_game ();
        back_action_disabled = false;
        show_new_game_screen ();
    }

    private void start_game_cb ()
    {
        if (game_view.game_content_visible_if_true ())
            return;

        game_finished = false;

        undo_action.set_enabled (false);
     // redo_action.set_enabled (false);

        headerbar.history_button_new_game ();

        play ();        // FIXME lag (see in Taquin…)

        game_view.configure_transition (StackTransitionType.SLIDE_DOWN, 1000);
        show_view ();
    }

    private void back_cb ()
    {
        if (game_view.game_content_visible_if_true ())
            return;
        // TODO change back headerbar subtitle?
        game_view.configure_transition (StackTransitionType.SLIDE_RIGHT, 800);
        show_view ();

        back ();
    }
}
