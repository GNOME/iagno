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
private class GameHeaderBar : HeaderBar
{
    [CCode (notify = false)] public string window_name   { private get; internal  construct; default = ""; }

    [CCode (notify = false)] public bool show_undo { private get; protected construct; default = false; }
 // [CCode (notify = false)] public bool show_redo { private get; protected construct; default = false; }
 // [CCode (notify = false)] public bool show_hint { private get; protected construct; default = false; }    // TODO something

    [CCode (notify = false)] public bool has_help { private get; protected construct; default = false; }
    [CCode (notify = false)] public bool has_keyboard_shortcuts { private get; protected construct; default = false; }

    [GtkChild] private Button new_game_button;
    [GtkChild] private Button back_button;

    construct
    {
        configure_history_button ();

        if (window_name != "")
         // window_has_name = true;
            set_title (window_name);
    }

    internal GameHeaderBar (string              _window_name,
                            GameWindowFlags     flags,
                            GLib.Menu?          appearance_menu)
    {
        Object (has_keyboard_shortcuts: GameWindowFlags.SHORTCUTS in flags,
                has_help:               GameWindowFlags.SHOW_HELP in flags, // TODO rename show_help
             // show_hint:              GameWindowFlags.SHOW_HINT in flags,
             // show_redo:              GameWindowFlags.SHOW_REDO in flags,
                show_undo:              GameWindowFlags.SHOW_UNDO in flags,
                window_name:            _window_name);

        GLib.MenuModel hamburger_menu = (!) info_button.get_menu_model ();
        if (appearance_menu != null)
        {
            GLib.Menu first_section = (GLib.Menu) (!) hamburger_menu.get_item_link (0, "section");
            /* Translators: hamburger menu entry; "Appearance" submenu (with a mnemonic that appears pressing Alt) */
            first_section.prepend_submenu (_("A_ppearance"), (!) appearance_menu);
        }
        ((GLib.Menu) hamburger_menu).freeze ();
    }

    internal bool back_button_is_focus ()
    {
        return back_button.is_focus;
    }

    internal void finish_game ()
    {
        if (!history_button.active)
            new_game_button.grab_focus ();
        else
            new_game_button.grab_default ();    // FIXME: grab_focus, but without closing the popover...
        set_history_button_label (Player.NONE);
    }

    /*\
    * * showing the stack
    \*/

 // private bool current_view_is_new_game_screen = false;

    internal /* grabs focus */ bool show_new_game_screen (bool game_finished)
    {
     // current_view_is_new_game_screen = true;

        set_subtitle (null);      // TODO save / restore?

        new_game_button.hide ();
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
     // current_view_is_new_game_screen = false;

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

    internal void new_game ()
    {
        back_button.show ();
    }

    /*\
    * * hamburger menu
    \*/

    [GtkChild] private MenuButton info_button;

    internal void toggle_hamburger ()
    {
        info_button.active = !info_button.active;
    }

    /*\
    * * history menu
    \*/

    [GtkChild] private MenuButton history_button;

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
