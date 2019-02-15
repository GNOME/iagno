/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2015 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of a GNOME game.
 *
 * This application is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This application is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this application. If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

[Flags]
private enum GameWindowFlags {
    SHOW_UNDO,
    SHOW_REDO,
    SHOW_HINT,
    SHOW_START_BUTTON;
}

[GtkTemplate (ui = "/org/gnome/Reversi/ui/game-window.ui")]
private class GameWindow : ApplicationWindow
{
    /* settings */
    private bool window_is_tiled;
    private bool window_is_maximized;
    private int window_width;
    private int window_height;

    private bool game_finished = false;

    /* private widgets */
    [GtkChild] private HeaderBar headerbar;
    [GtkChild] private Stack stack;

    private Button? start_game_button = null;
    [GtkChild] private Button new_game_button;
    [GtkChild] private Button back_button;

    [GtkChild] private Box controls_box;
    [GtkChild] private Box game_box;
    [GtkChild] private Box new_game_box;
    [GtkChild] private Box side_box;

    private Widget view;

    /* signals */
    internal signal void play ();
    internal signal void wait ();
    internal signal void back ();

    internal signal void undo ();
    internal signal void redo ();
    internal signal void hint ();

    /* actions */
    private const GLib.ActionEntry win_actions[] =
    {
        { "new-game", new_game_cb },
        { "start-game", start_game_cb },
        { "back", back_cb },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb },

        { "toggle-hamburger", toggle_hamburger }
    };

    private SimpleAction back_action;

    internal SimpleAction undo_action;
    internal SimpleAction redo_action;

    internal GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget _view)
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

        /* window actions */
        add_action_entries (win_actions, this);

        back_action = (SimpleAction) lookup_action ("back");
        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");

        back_action.set_enabled (false);
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        /* window config */
        set_title (name);
        headerbar.set_title (name);

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
            _start_game_button.set_action_name ("win.start-game");
            /* Translators: when configuring a new game, tooltip text of the blue Start button */
            // _start_game_button.set_tooltip_text (_("Start a new game as configured"));
            ((StyleContext) _start_game_button.get_style_context ()).add_class ("suggested-action");
            _start_game_button.show ();
            new_game_box.pack_end (_start_game_button, false, false, 0);
            start_game_button = _start_game_button;
        }

        game_box.pack_start (view, true, true, 0);
        game_box.set_focus_child (view);            // TODO test if necessary; note: view could grab focus from application
        view.halign = Align.FILL;
        view.can_focus = true;
        view.show ();

        /* add controls */
        if (GameWindowFlags.SHOW_UNDO in flags)
        {
            Box history_box = new Box (Orientation.HORIZONTAL, 0);
            history_box.get_style_context ().add_class ("linked");

            Button undo_button = new Button.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.BUTTON);
            undo_button.action_name = "win.undo";
            /* Translators: during a game, tooltip text of the Undo button */
            undo_button.set_tooltip_text (_("Undo your most recent move"));
            undo_button.valign = Align.CENTER;
            undo_button.show ();
            history_box.pack_start (undo_button, true, true, 0);

            /* if (GameWindowFlags.SHOW_REDO in flags)
            {
                Button redo_button = new Button.from_icon_name ("edit-redo-symbolic", Gtk.IconSize.BUTTON);
                redo_button.action_name = "app.redo";
                / Translators: during a game, tooltip text of the Redo button /
                redo_button.set_tooltip_text (_("Redo your most recent undone move"));
                redo_button.valign = Align.CENTER;
                redo_button.show ();
                history_box.pack_start (redo_button, true, true, 0);
            } */

            history_box.show ();
            controls_box.pack_start (history_box, true, true, 0);
        }
        /* if (GameWindowFlags.SHOW_HINT in flags)
        {
            Button hint_button = new Button.from_icon_name ("dialog-question-symbolic", Gtk.IconSize.BUTTON);
            hint_button.action_name = "app.hint";
            / Translators: during a game, tooltip text of the Hint button /
            hint_button.set_tooltip_text (_("Receive a hint for your next move"));
            hint_button.valign = Align.CENTER;
            hint_button.show ();
            controls_box.pack_start (hint_button, true, true, 0);
        } */

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    /*\
    * * Window events
    \*/

    private void size_allocate_cb ()
    {
        if (window_is_maximized || window_is_tiled)
            return;
        get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            window_is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        /* We don’t save this state, but track it for saving size allocation */
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
        settings.set_boolean ("window-is-maximized", window_is_maximized);
        settings.apply ();
        destroy ();
    }

    /*\
    * * Some internal calls
    \*/

    internal void add_to_sidebox (Widget widget)
    {
        side_box.pack_start (widget, false, false, 0);
    }

    internal void cannot_undo_more ()
    {
        undo_action.set_enabled (false);
        view.grab_focus ();
    }

    internal void set_subtitle (string? subtitle)
    {
        headerbar.set_subtitle (subtitle);
    }

    internal void finish_game ()
    {
        game_finished = true;
        new_game_button.grab_focus ();
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
        headerbar.set_subtitle (null);      // TODO save / restore?

        stack.set_visible_child_name ("start-box");
        controls_box.hide ();

        if (!game_finished && back_button.visible)
            back_button.grab_focus ();
        else if (start_game_button != null)
            ((!) start_game_button).grab_focus ();
    }

    private void show_view ()
    {
        stack.set_visible_child_name ("frame");
        back_button.hide ();        // TODO transition?
        controls_box.show ();

        if (game_finished)
            new_game_button.grab_focus ();
        else
            view.grab_focus ();
    }

    /*\
    * * Switching the Stack
    \*/

    private void new_game_cb ()
    {
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "frame")
            return;

        wait ();

        stack.set_transition_type (StackTransitionType.SLIDE_LEFT);
        stack.set_transition_duration (800);

        back_button.show ();
        back_action.set_enabled (true);

        show_new_game_screen ();
    }

    private void start_game_cb ()
    {
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "start-box")
            return;

        game_finished = false;

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        play ();        // FIXME lag (see in Taquin…)

        stack.set_transition_type (StackTransitionType.SLIDE_DOWN);
        stack.set_transition_duration (1000);
        show_view ();
    }

    private void back_cb ()
    {
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "start-box")
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
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "frame")
            return;

        game_finished = false;

        if (new_game_button.is_focus)
            view.grab_focus();
        redo_action.set_enabled (true);
        undo ();
    }

    private void redo_cb ()
    {
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "frame")
            return;

        if (new_game_button.is_focus)
            view.grab_focus();
        undo_action.set_enabled (true);
        redo ();
    }

    private void hint_cb ()
    {
        string? stack_child = stack.get_visible_child_name ();
        if (stack_child == null || (!) stack_child != "frame")
            return;
        hint ();
    }

    /*\
    * * hamburger menu
    \*/

    [GtkChild] private MenuButton info_button;

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        info_button.active = !info_button.active;
    }
}
