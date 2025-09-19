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
private class HistoryButton : Widget
{
    [CCode (notify = false)] public ThemeManager theme_manager
    {
        get { return drawing.theme_manager; }
        set { drawing.theme_manager = value; }
    }

    [GtkChild] private unowned MenuButton menu_button;
    [GtkChild] private unowned Stack stack;
    [GtkChild] private unowned HistoryButtonLabel drawing;

    private GLib.Menu history_menu;
    private GLib.Menu finish_menu;

    construct
    {
        layout_manager = new BinLayout ();

        history_menu = new GLib.Menu ();
        /* Translators: history menu entry (with a mnemonic that appears pressing Alt) */
        history_menu.append (_("_Undo last move"), "ui.undo");
        history_menu.freeze ();

        finish_menu = new GLib.Menu ();
        /* Translators: history menu entry, when game is finished, after final animation; undoes the animation (with a mnemonic that appears pressing Alt) */
        finish_menu.append (_("_Show final board"), "ui.undo");
        finish_menu.freeze ();

        menu_button.menu_model = history_menu;
    }

    internal void set_player (Player player)
    {
        if (player == Player.NONE)
            stack.set_visible_child_name ("label");
        else
        {
            stack.set_visible_child (drawing);
            drawing.current_player = player;
            drawing.queue_draw ();
        }
    }

    public void set_game_finished (bool finished)
    {
        menu_button.set_menu_model (finished ? finish_menu : history_menu);
    }

    public bool active
    {
        get { return menu_button.active; }
    }
}

private class HistoryButtonLabel : Widget
{
    private ThemeManager _theme_manager;
    [CCode (notify = false)] public ThemeManager theme_manager
    {
        get { return _theme_manager; }
        set
        {
            _theme_manager = value;
            _theme_manager.theme_changed.connect (() => {
                queue_draw ();
            });
        }
    }

    public Player current_player = Player.NONE;

    private const int pixbuf_margin = 1;
    private const float arrow_margin_top = 3.0f;

    private Gdk.Texture? tiles_pattern = null;

    protected override void snapshot (Gtk.Snapshot snapshot)
    {
        int height = get_height ();
        int width = get_width ();
        int new_height = (int) double.min (height, width / 2.0);

        int drawing_height = new_height;

        bool vertical_fill  = height == new_height;
        int drawing_width   =  vertical_fill ? (int) (new_height * 2.0) : width;
        int board_x         =  vertical_fill ? (int) ((width  - drawing_width)  / 2.0) : 0;
        int board_y         = !vertical_fill ? (int) ((height - drawing_height) / 2.0) : 0;

        if (tiles_pattern == null || ((!) tiles_pattern).get_height () != drawing_height * 4)
            tiles_pattern = theme_manager.tileset_for_size (drawing_height);

        snapshot.save ();
        snapshot.translate (Graphene.Point () {
            x = board_x,
            y = board_y
        });
        draw_arrow (snapshot, drawing_height);
        snapshot.restore ();

        snapshot.save ();
        snapshot.translate (Graphene.Point () {
            x = board_x + drawing_width - drawing_height,
            y = board_y
        });
        draw_piece (snapshot, drawing_height);
        snapshot.restore ();
    }

    private void draw_arrow (Gtk.Snapshot snapshot, int drawing_height)
    {
        snapshot.save ();

        float arrow_half_width = ((float) drawing_height - 2.0f * pixbuf_margin) / 4.0f;

        var builder = new Gsk.PathBuilder ();
        builder.move_to (      arrow_half_width, arrow_margin_top);
        builder.line_to (3.0f * arrow_half_width, drawing_height / 2.0f);
        builder.line_to (      arrow_half_width, drawing_height - arrow_margin_top);
        var path = builder.to_path ();

        var stroke = new Gsk.Stroke (2);
        stroke.set_line_cap (Gsk.LineCap.ROUND);
        stroke.set_line_join (Gsk.LineJoin.ROUND);

        snapshot.append_stroke (
            path,
            stroke,
            Gdk.RGBA () { red = 0.5f, green = 0.5f, blue = 0.5f, alpha = 1.0f });

        snapshot.restore ();
    }

    private void draw_piece (Gtk.Snapshot snapshot, int drawing_height)
    {
        if (tiles_pattern == null)
            return;
        var texture = (!) tiles_pattern;

        int pixmap;
        switch (current_player)
        {
            case Player.NONE    : return;
            case Player.DARK    : pixmap = 1;   break;
            case Player.LIGHT   : pixmap = 31;  break;
            default: assert_not_reached ();
        }

        var tile_rect = Graphene.Rect () {
            origin = { x: 0, y: 0 },
            size = {
                width:  (float) drawing_height,
                height: (float) drawing_height
            }
        };

        snapshot.push_clip (tile_rect);
        snapshot.save();
        snapshot.translate(Graphene.Point () {
            x = - /* texture x */ (pixmap % 8) * drawing_height,
            y = - /* texture y */ (pixmap / 8) * drawing_height
        });
        texture.snapshot (snapshot, texture.get_width (), texture.get_height ());
        snapshot.restore();
        snapshot.pop();
    }
}
