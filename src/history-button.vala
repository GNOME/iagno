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

[GtkTemplate (ui = "/org/gnome/Reversi/ui/history-button.ui")]
private class HistoryButton : MenuButton
{
    [CCode (notify = false)] internal bool is_extra_thin { private get; internal set; default = true; }

    private GLib.Menu history_menu;
    private GLib.Menu finish_menu;

    private string history_button_light_label;
    private string history_button_dark_label;

    construct
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

        new_game ();
    }

    /*\
    * * internal calls
    \*/

    internal inline void update_menu (bool finish_animation)
    {
        set_menu_model (finish_animation ? finish_menu : history_menu);
    }

    internal inline void new_game ()
    {
        update_label (Player.DARK);
        update_menu (/* final animation */ false);
    }

    internal void update_label (Player player)
    {
        switch (player)
        {
            case Player.LIGHT:
                    set_label (history_button_light_label);  break;
            case Player.DARK:
                    set_label (history_button_dark_label);   break;
            case Player.NONE:
                if (is_extra_thin)
                    /* Translators: label of the game status button (in the headerbar, next to the hamburger button), at the end of the game; this string is for when the window is really small, so keep the string as small as possible (3~5 characters) */
                    set_label (_("End!"));

                else
                    /* Translators: label of the game status button (in the headerbar, next to the hamburger button), at the end of the game, if the window is not too thin */
                    set_label (_("Finished!"));              break;
            default: assert_not_reached ();
        }

        Widget? history_label = get_child ();
        if (history_label != null && (!) history_label is Label)
            ((Label) (!) history_label).set_ellipsize (Pango.EllipsizeMode.END);
    }
}
