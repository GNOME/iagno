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

private class Arrow : Object, Gdk.Paintable
{
    private const float arrow_margin_top = 3.0f;

    protected void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height)
    {
        var snapshot = (Gtk.Snapshot) gdk_snapshot;

        snapshot.save ();

        float arrow_half_width = (float) width / 4.0f;

        var builder = new Gsk.PathBuilder ();
        builder.move_to (       arrow_half_width, arrow_margin_top);
        builder.line_to (3.0f * arrow_half_width, (float) height / 2.0f);
        builder.line_to (       arrow_half_width, (float) height - arrow_margin_top);
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
}
