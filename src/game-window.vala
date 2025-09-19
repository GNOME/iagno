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

[GtkTemplate (ui = "/org/gnome/Reversi/ui/game-window.ui")]
private class GameWindow : AdaptativeWindow, AdaptativeWidget
{
    [GtkChild] private unowned Adw.WindowTitle  window_title;

    [GtkChild] private unowned Button           new_game_button;
    [GtkChild] private unowned Button           back_button;

    [GtkChild] private unowned MenuButton       info_button;

    [GtkChild] private unowned Adw.ToastOverlay toast_overlay;

    [GtkChild] private unowned Stack            game_stack;
    [GtkChild] private unowned Box              game_box;
    [GtkChild] private unowned Button           start_game_button;

    [GtkChild] private unowned Box              action_bar;
    [GtkChild] private unowned Label            game_label;

    [GtkChild] public  unowned NewGameScreen    new_game_screen;
    [GtkChild] public  unowned Box              history_button1_box;
    [GtkChild] public  unowned HistoryButton    history_button1;
    [GtkChild] public  unowned HistoryButton    history_button2;

    private bool game_finished = false;

    /* private widgets */
    private GLib.Menu?      appearance_menu = null;
    private Widget          game_content;

    internal GameWindow (bool start_now, Widget view_content, GLib.Menu? appearance_menu)
    {
        Object (title : Iagno.PROGRAM_NAME);

        window_title.title = Iagno.PROGRAM_NAME;
        game_content = view_content;

        this.appearance_menu = appearance_menu;
        update_hamburger_menu ();

        game_content.hexpand = true;
        game_content.vexpand = true;
        game_content.halign = Align.FILL;
        game_content.valign = Align.FILL;
        game_content.margin_start = 6;
        game_content.margin_end = 6;
        game_content.margin_top = 6;
        game_content.margin_bottom = 6;
        game_box.prepend (game_content);

        add_adaptative_child (this);
        add_adaptative_child (new_game_screen);

        /* window actions */
        install_action_entries ();
        install_ui_action_entries ();

        /* window config */
        set_title (name);

        /* remember window state */
        var settings = new GLib.Settings.with_path ("org.gnome.Reversi.Lib", "/org/gnome/iagno/");
        settings.bind ("window-width", this, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("window-height", this, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-is-maximized", this, "maximized", SettingsBindFlags.DEFAULT);

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    construct
    {
        var style_manager = Adw.StyleManager.get_default ();
        style_manager.notify ["dark"].connect (update_hamburger_menu);
        style_manager.notify ["high-contrast"].connect (update_hamburger_menu);
    }

    /*\
    * * hamburger menu
    \*/

    protected void update_hamburger_menu ()
    {
        GLib.Menu menu = new GLib.Menu ();

        {
            GLib.Menu section = new GLib.Menu ();

            if (appearance_menu != null)
                /* Translators: hamburger menu entry; "Appearance" submenu (with a mnemonic that appears pressing Alt) */
                section.append_submenu (_("A_ppearance"), (!) appearance_menu);

            /* Translators: hamburger menu entry; sound togglebutton (with a mnemonic that appears pressing Alt) */
            section.append (_("_Sound"), "app.sound");

            menu.append_section (null, section);
        }
        {
            GLib.Menu section = new GLib.Menu ();

            append_or_not_night_mode_entry (ref section);
            append_or_not_keyboard_shortcuts_entry (ref section);

            /* Translators: usual menu entry of the hamburger menu (with a mnemonic that appears pressing Alt) */
            section.append (_("_Help"), "app.help");
            /* Translators: hamburger menu entry; open about dialog (with a mnemonic that appears pressing Alt) */
            section.append (_("_About Reversi"), "app.about");

            menu.append_section (null, section);
        }

        info_button.set_menu_model ((MenuModel) menu);
    }

    private void append_or_not_night_mode_entry (ref GLib.Menu section)
    {
        var style_manager = Adw.StyleManager.get_default ();

        if (style_manager.high_contrast)
            return;

        if (style_manager.dark)
            /* Translators: there are three related actions: "use", "reuse" and "pause"; displayed in the hamburger menu at night */
            section.append (_("Pause night mode"), "app.set-use-night-mode(false)");

        else if (style_manager.color_scheme != Adw.ColorScheme.PREFER_DARK)
            /* Translators: there are three related actions: "use", "reuse" and "pause"; displayed in the hamburger menu at night */
            section.append (_("Reuse night mode"), "app.set-use-night-mode(true)");

        else
            /* Translators: there are three related actions: "use", "reuse" and "pause"; displayed in the hamburger menu at night */
            section.append (_("Use night mode"), "app.set-use-night-mode(true)");
    }

    private inline void append_or_not_keyboard_shortcuts_entry (ref GLib.Menu section)
    {
        // TODO something in small windows
        if (!has_a_phone_size)
        {
            /* Translators: usual menu entry of the hamburger menu (with a mnemonic that appears pressing Alt) */
            section.append (_("_Keyboard Shortcuts"), "base.show-shortcuts");
        }
    }

    /*\
    * * adaptative stuff
    \*/

    private bool is_extra_thin = true;
    private bool is_quite_thin = false;
    private bool has_a_phone_size = false;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        is_extra_thin = AdaptativeWidget.WindowSize.is_extra_thin (new_size);
        is_quite_thin = AdaptativeWidget.WindowSize.is_quite_thin (new_size);
        has_a_phone_size = AdaptativeWidget.WindowSize.is_phone_size (new_size);

        update_hamburger_menu ();
    }

    /*\
    * * some public calls
    \*/

    internal void finish_game ()
    {
        game_finished = true;
        if (!history_button1.active)
            new_game_button.grab_focus ();
        else
            set_default_widget (new_game_button);    // FIXME: grab_focus, but without closing the popover...
    }

    private void escape_pressed (/* SimpleAction action, Variant? path_variant */)
    {
        if (!back_action_disabled)
            back_cb ();
    }

    private void back_cb ()
    {
        if (game_content_visible_if_true ())
            return;

        // TODO change back headerbar subtitle?
        configure_transition (StackTransitionType.SLIDE_RIGHT, 800);
        show_view ();

        back ();
    }

    /*\
    * * showing the stack
    \*/

    private void show_new_game_screen ()
    {
        hide_notification ();
        update_title (Iagno.PROGRAM_NAME);
        game_stack.set_visible_child_name ("new-game");
        history_button1_box.visible = false;

        if (!game_finished && back_button.visible)
            back_button.grab_focus ();
        else
            start_game_button.grab_focus ();
    }

    private void show_view ()
    {
        back_button.visible = false;        // TODO transition?
        new_game_button.visible = true;     // TODO transition?
        history_button1_box.visible = true;

        bool grabs_focus;
        if (game_finished)
        {
            new_game_button.grab_focus ();
            grabs_focus = false;
        }
        else
            grabs_focus = true;

        show_game_content (grabs_focus);
        escape_action.set_enabled (false);
    }

    /*\
    * * actions
    \*/

    private SimpleAction escape_action;

    private void install_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (action_entries, this);
        insert_action_group ("base", action_group);

        GLib.Action? tmp_action = action_group.lookup_action ("escape");
        if (tmp_action == null)
            assert_not_reached ();
        escape_action = (SimpleAction) (!) tmp_action;
        escape_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] action_entries =
    {
        { "escape",             escape_pressed      },  // Escape
        { "toggle-hamburger",   toggle_hamburger    },  // F10
        { "show-shortcuts",     show_shortcuts      }
    };

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
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "new-game",           new_game_cb },          // "New game" button or <Shift>n

        { "start-game", start_game_cb },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb }
    };

    /*\
    * * keyboard open menus actions
    \*/

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        info_button.active = !info_button.active;
    }

    private void show_shortcuts (/* SimpleAction action, Variant? variant */)
    {
        Gtk.Builder builder = new Gtk.Builder.from_resource ("/org/gnome/Reversi/ui/help-overlay.ui");
        Adw.Dialog dialog = (Adw.Dialog) builder.get_object ("help_overlay");
        dialog.present (this);
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_content_visible_if_true ())
            return;

        new_game ();
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_content_visible_if_true ())
        {
            if (!back_action_disabled)
                back_cb ();     // FIXME not reached if undo_action is disabled, so at game start or finish
            return;
        }

        game_finished = false;

        show_game_content (/* grab focus */ true);
     // redo_action.set_enabled (true);

        undo ();
    }

    private void redo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_content_visible_if_true ())
            return;

        show_game_content (/* grab focus */ true);
     // restart_action.set_enabled (true);
        undo_action.set_enabled (true);

        redo ();
    }

    private void hint_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_content_visible_if_true ())
            return;

        hint ();
    }

    /*\
    * * Some internal calls
    \*/

    internal void new_turn_start (bool can_undo)
    {
        undo_action.set_enabled (can_undo);
        hide_notification ();
    }

    internal void update_title (string new_title)
    {
        window_title.title = new_title;
        game_label.set_label (new_title);
    }

    /*\
    * * actions helper
    \*/

    private void new_game ()
    {
        wait ();

        configure_transition (StackTransitionType.SLIDE_LEFT, 800);

        back_button.visible = true;
        new_game_button.visible = false;        // TODO transition?

        back_action_disabled = false;
        escape_action.set_enabled (true);
        show_new_game_screen ();
    }

    private void start_game_cb ()
    {
        if (game_content_visible_if_true ())
            return;

        game_finished = false;

        undo_action.set_enabled (false);
     // redo_action.set_enabled (false);

        play ();        // FIXME lag (see in Taquin…)

        if (is_quite_thin)
            configure_transition (StackTransitionType.SLIDE_DOWN, 1000);
        else
            configure_transition (StackTransitionType.OVER_DOWN_UP, 1000);
        show_view ();
    }

    /*\
    * * notifications
    \*/

    internal void show_notification (string notification)
    {
        toast_overlay.add_toast (new Adw.Toast (notification));
    }

    internal void hide_notification ()
    {
        toast_overlay.dismiss_all ();
    }

    /*\
    * * some internal calls
    \*/

    internal void show_game_content (bool grab_focus)
    {
        game_stack.set_visible_child_name ("game");
        if (grab_focus)
            game_content.grab_focus ();
    }

    internal bool game_content_visible_if_true ()
    {
        return game_stack.get_visible_child_name () == "game";
    }

    internal void configure_transition (StackTransitionType transition_type,
                                        uint                transition_duration)
    {
        game_stack.set_transition_type (transition_type);
        game_stack.set_transition_duration (transition_duration);
    }
}
