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

private class Piece : Object, Gdk.Paintable
{
    public Theme?           theme { get; set; }
    public Player           player { get; set; default = Player.NONE; }

    private Gdk.Texture?    texture = null;

    construct
    {
        notify ["theme"].connect (() => { texture = null; invalidate_contents (); });
        notify ["player"].connect (() => invalidate_contents ());
    }

    protected void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height)
    {
        var snapshot = (Gtk.Snapshot) gdk_snapshot;

        var tile_size = (int) double.min (width, height);
        if (texture == null || ((!) texture).get_height () != tile_size * 4)
        {
            texture = null;
            if (theme != null)
                texture = ((!) theme).tileset_for_size (tile_size);
        }

        if (texture == null)
        {
            warning ("No piece texture for a size %d", tile_size);
            return;
        }
        var texture_ = (!) texture;

        int pixmap;
        switch (player)
        {
            case Player.NONE    : return;
            case Player.DARK    : pixmap = 1;   break;
            case Player.LIGHT   : pixmap = 31;  break;
            default: assert_not_reached ();
        }

        var tile_rect = Graphene.Rect () {
            origin = { x: 0, y: 0 },
            size = {
                width:  (float) tile_size,
                height: (float) tile_size
            }
        };

        snapshot.push_clip (tile_rect);
        snapshot.save();
        snapshot.translate(Graphene.Point () {
            x = - /* texture x */ (pixmap % 8) * tile_size,
            y = - /* texture y */ (pixmap / 8) * tile_size
        });
        texture_.snapshot (snapshot, texture_.get_width (), texture_.get_height ());
        snapshot.restore();
        snapshot.pop();
    }
}
