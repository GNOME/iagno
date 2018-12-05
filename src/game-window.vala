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
public enum GameWindowFlags {
    SHOW_UNDO,
    SHOW_REDO,
    SHOW_HINT,
    SHOW_START_BUTTON;
}

[GtkTemplate (ui = "/org/gnome/iagno/ui/game-window.ui")]
public class GameWindow : ApplicationWindow
{
    /* settings */
    private bool tiled_state;
    private bool maximized_state;
    private int window_width;
    private int window_height;

    private bool game_finished = false;

    /* private widgets */
    [GtkChild]
    private HeaderBar headerbar;
    [GtkChild]
    private Stack stack;

    private Button? start_game_button = null;
    [GtkChild]
    private Button new_game_button;
    [GtkChild]
    private Button back_button;

    [GtkChild]
    private Box controls_box;
    [GtkChild]
    private Box game_box;
    [GtkChild]
    private Box new_game_box;
    [GtkChild]
    private Box side_box;

    private Widget view;

    /* signals */
    public signal void play ();
    public signal void wait ();
    public signal void back ();

    public signal void undo ();
    public signal void redo ();
    public signal void hint ();

    /* actions */
    private const GLib.ActionEntry win_actions[] =
    {
        { "new-game", new_game_cb },
        { "start-game", start_game_cb },
        { "back", back_cb },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb }
    };

    private SimpleAction back_action;

    public SimpleAction undo_action;
    public SimpleAction redo_action;

    public GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget _view)
    {
        if (css_resource != null)
        {
            CssProvider css_provider = new CssProvider ();
            css_provider.load_from_resource (css_resource);
            StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
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

        var menu = new GLib.Menu ();
        var section = new GLib.Menu ();
        menu.append_section (null, section);
        section.append (_("A_ppearance"), "app.theme");
        section.append (_("_Sound"), "app.sound");
        section = new GLib.Menu ();
        menu.append_section (null, section);
        section.append (_("_Help"), "app.help");
        section.append (_("_About Iagno"), "app.about");
        var menu_button = new Gtk.MenuButton ();
        menu_button.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.BUTTON));
        menu_button.show ();
        menu_button.set_menu_model (menu);
        headerbar.pack_end(menu_button);

        set_default_size (width, height);
        if (maximized)
            maximize ();

        size_allocate.connect (size_allocate_cb);
        window_state_event.connect (window_state_event_cb);

        /* add widgets */
        new_game_box.pack_start (new_game_screen, true, true, 0);
        if (GameWindowFlags.SHOW_START_BUTTON in flags)
        {
            start_game_button = new Button.with_mnemonic (_("_Start Game"));
            // start_game_button.set_tooltip_text (_("Start a new game as configured"));
            start_game_button.width_request = 222;
            start_game_button.height_request = 60;
            start_game_button.halign = Align.CENTER;
            start_game_button.set_action_name ("win.start-game");
            ((StyleContext) start_game_button.get_style_context ()).add_class ("suggested-action");
            start_game_button.show ();
            new_game_box.pack_end (start_game_button, false, false, 0);
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
            undo_button.set_tooltip_text (_("Undo your most recent move"));
            undo_button.valign = Align.CENTER;
            undo_button.show ();
            history_box.pack_start (undo_button, true, true, 0);

            /* if (GameWindowFlags.SHOW_REDO in flags)
            {
                Button redo_button = new Button.from_icon_name ("edit-redo-symbolic", Gtk.IconSize.BUTTON);
                redo_button.action_name = "app.redo";
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
        if (maximized_state || tiled_state)
            return;
        get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            maximized_state = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            tiled_state = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    public void shutdown (GLib.Settings settings)
    {
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", maximized_state);
        destroy ();
    }

    /*\
    * * Some public calls
    \*/

    public void add_to_sidebox (Widget widget)
    {
        side_box.pack_start (widget, false, false, 0);
    }

    public void cannot_undo_more ()
    {
        undo_action.set_enabled (false);
        view.grab_focus ();
    }

    public void set_subtitle (string? subtitle)
    {
        headerbar.set_subtitle (subtitle);
    }

    public void finish_game ()
    {
        game_finished = true;
        new_game_button.grab_focus ();
    }

    /* public void about ()
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
            start_game_button.grab_focus ();
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
        if (stack.get_visible_child_name () != "frame")
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
        if (stack.get_visible_child_name () != "start-box")
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
        if (stack.get_visible_child_name () != "start-box")
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
        if (stack.get_visible_child_name () != "frame")
            return;

        game_finished = false;

        if (new_game_button.is_focus)
            view.grab_focus();
        redo_action.set_enabled (true);
        undo ();
    }

    private void redo_cb ()
    {
        if (stack.get_visible_child_name () != "frame")
            return;

        if (new_game_button.is_focus)
            view.grab_focus();
        undo_action.set_enabled (true);
        redo ();
    }

    private void hint_cb ()
    {
        if (stack.get_visible_child_name () != "frame")
            return;
        hint ();
    }
}
