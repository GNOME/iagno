/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2026 Andrey Kutejko

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

[GtkTemplate (ui = "/org/gnome/Reversi/ui/history-button-label.ui")]
private class HistoryButtonLabel : Widget
{
    public Theme theme { get; set; }
    public Player player { get; set; default = Player.NONE; }

    [GtkChild] private unowned Stack stack;
    [GtkChild] private unowned Widget prompt;
    [GtkChild] private unowned Arrow prompt_arrow;
    [GtkChild] private unowned Piece prompt_piece;
    [GtkChild] private unowned Widget end;

    construct
    {
        bind_property ("player", stack, "visible-child", GLib.BindingFlags.SYNC_CREATE,
            (binding, srcval, ref targetval) => {
                targetval.set_object (srcval == Player.NONE ? end : prompt);
                return true;
            });

        bind_property ("theme", prompt_piece, "theme", GLib.BindingFlags.SYNC_CREATE);
        bind_property ("player", prompt_piece, "player", GLib.BindingFlags.SYNC_CREATE);
    }
}
