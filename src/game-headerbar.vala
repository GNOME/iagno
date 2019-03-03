/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2019 Arnaud Bonatti

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

[GtkTemplate (ui = "/org/gnome/Reversi/ui/game-headerbar.ui")]
private class GameHeaderBar : BaseHeaderBar, AdaptativeWidget
{
    [GtkChild] private MenuButton   history_button;
    [GtkChild] private Button       new_game_button;
    [GtkChild] private Button       back_button;

    [CCode (notify = false)] public bool window_has_name { private get; protected construct; default = false; }
    [CCode (notify = false)] public string window_name   { private get; internal  construct; default = ""; }

    [CCode (notify = false)] public bool has_sound { private get; protected construct; default = false; }
    [CCode (notify = false)] public bool show_undo { private get; protected construct; default = false; }
    [CCode (notify = false)] public bool show_redo { private get; protected construct; default = false; }
    [CCode (notify = false)] public bool show_hint { private get; protected construct; default = false; }    // TODO something

    construct
    {
        configure_history_button ();

        init_modes ();

        if (window_name != "")
            window_has_name = true;
    }

    internal GameHeaderBar (string              _window_name,
                            string              _about_action_label,
                            GameWindowFlags     flags,
                            GLib.Menu?          _appearance_menu,
                            NightLightMonitor   _night_light_monitor)
    {
        Object (about_action_label:     _about_action_label,
                night_light_monitor:    _night_light_monitor,
                has_keyboard_shortcuts: GameWindowFlags.SHORTCUTS in flags,
                has_sound:              GameWindowFlags.HAS_SOUND in flags,
                has_help:               GameWindowFlags.SHOW_HELP in flags, // TODO rename show_help
                show_hint:              GameWindowFlags.SHOW_HINT in flags,
                show_redo:              GameWindowFlags.SHOW_REDO in flags,
                show_undo:              GameWindowFlags.SHOW_UNDO in flags,
                appearance_menu:        _appearance_menu,
                window_name:            _window_name);
    }

    /*\
    * * adaptative stuff
    \*/

    private bool is_extra_thin = true;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        base.set_window_size (new_size);

        if (!window_has_name)
            return;

        bool _is_extra_thin = AdaptativeWidget.WindowSize.is_extra_thin (new_size);
        if (_is_extra_thin == is_extra_thin)
            return;
        is_extra_thin = _is_extra_thin;
        set_default_widgets_default_states (this);
    }

    protected override void set_default_widgets_default_states (BaseHeaderBar _this)
    {
        string? headerbar_label_text;
        if (((GameHeaderBar) _this).is_extra_thin)
            headerbar_label_text = null;
        else
            headerbar_label_text = ((GameHeaderBar) _this).window_name;
        _this.set_default_widgets_states (/* title_label text or null */ headerbar_label_text,
                                          /* show go_back_button      */ false,
                                          /* show ltr_left_separator  */ false,
                                          /* show info_button         */ true,
                                          /* show ltr_right_separator */ _this.disable_action_bar,
                                          /* show quit_button_stack   */ _this.disable_action_bar);
    }

    /*\
    * * showing the stack
    \*/

    private bool current_view_is_new_game_screen = false;

    internal /* grabs focus */ bool show_new_game_screen (bool game_finished)
    {
        current_view_is_new_game_screen = true;

     // new_game_button.hide ();
        history_button.hide ();

        if (!game_finished && back_button.visible)
        {
            back_button.grab_focus ();
            return true;
        }
        else
            return false;
    }

    internal /* grabs focus */ bool show_view (bool game_finished)
    {
        current_view_is_new_game_screen = false;

        back_button.hide ();        // TODO transition?
        new_game_button.show ();    // TODO transition?
        history_button.show ();

        if (game_finished)
        {
            new_game_button.grab_focus ();
            return true;
        }
        else
            return false;
    }

    /*\
    * * switching the stack
    \*/

    private bool game_created = false;

    internal void new_game ()
    {
        game_created = true;
        back_button.show ();
        new_game_button.hide ();        // TODO transition?
    }

    /*\
    * * some public calls
    \*/

 // internal void new_game_button_grab_focus ()
 // {
 //     new_game_button.grab_focus ();
 // }

    internal void finish_game ()
    {
        if (!history_button.active)
            new_game_button.grab_focus ();
        else
            new_game_button.grab_default ();    // FIXME: grab_focus, but without closing the popover...
        set_history_button_label (Player.NONE);
    }

    /*\
    * * hamburger menu
    \*/

    public GLib.Menu? appearance_menu { private get; protected construct; default = null; }
    protected override void populate_menu (ref GLib.Menu menu)
    {
        append_options_section (ref menu, appearance_menu, has_sound);
    }

    private static inline void append_options_section (ref GLib.Menu menu, GLib.Menu? appearance_menu, bool has_sound)
    {
        GLib.Menu section = new GLib.Menu ();

        if (appearance_menu != null)
            /* Translators: hamburger menu entry; "Appearance" submenu (with a mnemonic that appears pressing Alt) */
            section.append_submenu (_("A_ppearance"), (!) appearance_menu);

        if (has_sound)
            /* Translators: hamburger menu entry; sound togglebutton (with a mnemonic that appears pressing Alt) */
            section.append (_("_Sound"), "app.sound");

        section.freeze ();
        menu.append_section (null, section);
    }

    /*\
    * * modes
    \*/

    private void init_modes ()
    {
        this.change_mode.connect (mode_changed_game);
    }

    private static void mode_changed_game (BaseHeaderBar _this, uint8 mode_id)
    {
        GameHeaderBar real_this = (GameHeaderBar) _this;
        if (mode_id == default_mode_id)
        {
            if (real_this.current_view_is_new_game_screen)
            {
                if (real_this.game_created)
                    real_this.back_button.show ();
            }
            else
            {
                real_this.history_button.show ();
                real_this.new_game_button.show ();
            }
        }
        else
        {
            real_this.back_button.hide ();
            real_this.history_button.hide ();
            real_this.new_game_button.hide ();
        }
    }

    /*\
    * * history menu
    \*/

    private GLib.Menu history_menu;
    private GLib.Menu finish_menu;

    private string history_button_light_label;
    private string history_button_dark_label;

    private void configure_history_button ()
    {
        history_menu = new GLib.Menu ();
        /* Translators: history menu entry (with a mnemonic that appears pressing Alt) */
        history_menu.append (_("_Undo last move"), "ui.undo");
        history_menu.freeze ();

        finish_menu = new GLib.Menu ();
        /* Translators: history menu entry, when game is finished, after final animation; undoes the animation (with a mnemonic that appears pressing Alt) */
        finish_menu.append (_("_Show final board"), "ui.undo");
        finish_menu.freeze ();

        bool dir_is_ltr = get_locale_direction () == TextDirection.LTR;
        history_button_light_label = dir_is_ltr ? "‎⮚ ⚪" : /* yes */ "‏⮘ ⚪";    /* both have an LTR/RTL mark */
        history_button_dark_label  = dir_is_ltr ? "‎⮚ ⚫" : /* yes */ "‏⮘ ⚫";    /* both have an LTR/RTL mark */

        history_button_new_game ();
    }

    internal inline void update_history_button (bool finish_animation)
    {
        history_button.set_menu_model (finish_animation ? finish_menu : history_menu);
    }

    internal inline void history_button_new_game ()
    {
        set_history_button_label (Player.DARK);
        update_history_button (/* final animation */ false);
    }

    internal void set_history_button_label (Player player)
    {
        switch (player)
        {
            case Player.LIGHT:  history_button.set_label (history_button_light_label);  return;
            case Player.DARK:   history_button.set_label (history_button_dark_label);   return;
            case Player.NONE:   history_button.set_label (_("Finished!"));              return;
            default: assert_not_reached ();
        }
    }
}
