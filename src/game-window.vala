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
    SHOW_UNDO,
 // SHOW_REDO,
 // SHOW_HINT,
    SHOW_START_BUTTON;
}

[GtkTemplate (ui = "/org/gnome/Reversi/ui/game-window.ui")]
private class GameWindow : ApplicationWindow
{
    /* settings */
    private bool window_is_tiled;
    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private int window_width;
    private int window_height;

    private bool game_finished = false;

    /* private widgets */
    [GtkChild] private Stack stack;
    [GtkChild] private Box new_game_box;
    [GtkChild] private Box view_box;
    [GtkChild] private Button unfullscreen_button;

    private GameHeaderBar headerbar;
    private Button? start_game_button = null;
    private Widget view;

    /* signals */
    internal signal void play ();
    internal signal void wait ();
    internal signal void back ();

    internal signal void undo ();
 // internal signal void redo ();
 // internal signal void hint ();

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

        view = _view;

        /* window config */
        install_ui_action_entries ();
        set_title (name);

        headerbar = new GameHeaderBar (name, flags, appearance_menu);
        headerbar.show ();
        set_titlebar (headerbar);

        ((ReversiView) view).notify_final_animation.connect ((undoing) => { headerbar.update_history_button (!undoing); });

        set_default_size (width, height);
        if (maximized)
            maximize ();

        size_allocate.connect (size_allocate_cb);
        window_state_event.connect (window_state_event_cb);

        /* add widgets */
        new_game_box.pack_start (new_game_screen, true, true, 0);
        if (GameWindowFlags.SHOW_START_BUTTON in flags)
        {
            /* Translators: when configuring a new game, label of the blue Start button (with a mnemonic that appears pressing Alt) */
            Button _start_game_button = new Button.with_mnemonic (_("_Start Game"));
            _start_game_button.width_request = 222;
            _start_game_button.height_request = 60;
            _start_game_button.halign = Align.CENTER;
            _start_game_button.set_action_name ("ui.start-game");
            /* Translators: when configuring a new game, tooltip text of the blue Start button */
            // _start_game_button.set_tooltip_text (_("Start a new game as configured"));
            ((StyleContext) _start_game_button.get_style_context ()).add_class ("suggested-action");
            _start_game_button.show ();
            new_game_box.pack_end (_start_game_button, false, false, 0);
            start_game_button = _start_game_button;
        }

        view_box.add (view);
        stack.set_visible_child (view_box);
        view.halign = Align.FILL;
        view.can_focus = true;
        view.show ();

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    /*\
    * * actions
    \*/

    private SimpleAction back_action;
    private SimpleAction undo_action;
 // private SimpleAction redo_action;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

        back_action = (SimpleAction) action_group.lookup_action ("back");
        undo_action = (SimpleAction) action_group.lookup_action ("undo");
     // redo_action = (SimpleAction) lookup_action ("redo");

        back_action.set_enabled (false);
        undo_action.set_enabled (false);
     // redo_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "new-game", new_game_cb },
        { "start-game", start_game_cb },
        { "back", back_cb },

        { "undo", undo_cb },
     // { "redo", redo_cb },
     // { "hint", hint_cb },

        { "toggle-hamburger", toggle_hamburger },
        { "unfullscreen", unfullscreen }
    };

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
        view.grab_focus ();
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

    internal void finish_game ()
    {
        game_finished = true;
        headerbar.finish_game ();
    }

    internal void set_history_button_label (Player player)
    {
        headerbar.set_history_button_label (player);
    }

    /* internal void about ()
    {
        TODO
    } */

    /*\
    * * Showing the Stack
    \*/

    private void show_new_game_screen ()
    {
        stack.set_visible_child (new_game_box);

        bool headerbar_grabbed_focus = headerbar.show_new_game_screen (game_finished);
        if (!headerbar_grabbed_focus && start_game_button != null)
            ((!) start_game_button).grab_focus ();
    }

    private void show_view ()
    {
        stack.set_visible_child (view_box);

        headerbar.show_view (game_finished);
        if (!game_finished)
            view.grab_focus ();
    }

    /*\
    * * Switching the Stack
    \*/

    private void new_game_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null || (!) stack_child != view_box)
            return;

        wait ();

        stack.set_transition_type (StackTransitionType.SLIDE_LEFT);
        stack.set_transition_duration (800);

        headerbar.new_game ();
        back_action.set_enabled (true);

        show_new_game_screen ();
    }

    private void start_game_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null || (!) stack_child != new_game_box)
            return;

        game_finished = false;

        undo_action.set_enabled (false);
     // redo_action.set_enabled (false);

        headerbar.history_button_new_game ();

        play ();        // FIXME lag (see in Taquin…)

        stack.set_transition_type (StackTransitionType.SLIDE_DOWN);
        stack.set_transition_duration (1000);
        show_view ();
    }

    private void back_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null || (!) stack_child != new_game_box)
            return;
        // TODO change back headerbar subtitle?
        stack.set_transition_type (StackTransitionType.SLIDE_RIGHT);
        stack.set_transition_duration (800);
        show_view ();

        back ();
    }

    /*\
    * * Controls_box actions
    \*/

    private void undo_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null)
            return;
        if ((!) stack_child != view_box)
        {
            if (back_action.get_enabled ())
                back_cb ();
            return;
        }

        game_finished = false;

        if (!headerbar.back_button_is_focus ())
            view.grab_focus();
     // redo_action.set_enabled (true);
        undo ();
    }

/*    private void redo_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null || (!) stack_child != view_box)
            return;

        if (!headerbar.back_button_is_focus ())
            view.grab_focus();
        undo_action.set_enabled (true);
        redo ();
    } */

/*    private void hint_cb ()
    {
        Widget? stack_child = stack.get_visible_child ();
        if (stack_child == null || (!) stack_child != view_box)
            return;
        hint ();
    } */

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        headerbar.toggle_hamburger ();
    }
}
