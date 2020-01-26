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
private class HistoryButton : MenuButton, AdaptativeWidget
{
    [CCode (notify = false)] public ThemeManager theme_manager { private get; protected construct; }

    [GtkChild] private Stack stack;
    [GtkChild] private DrawingArea drawing;

    internal HistoryButton (GLib.Menu menu, ThemeManager theme_manager)
    {
        Object (menu_model: menu, theme_manager: theme_manager);
    }

    construct
    {
        drawing.configure_event.connect (configure_drawing);
        drawing.draw.connect (update_drawing);
        theme_manager.theme_changed.connect (() => {
                if (!drawing_configured)
                    return;
                tiles_pattern = null;
                if (current_player != Player.NONE)
                    drawing.queue_draw ();
            });
    }

    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
    }

    internal void set_player (Player player)
    {
        current_player = player;
        if (player == Player.NONE)
            stack.set_visible_child_name ("label");
        else
        {
            stack.set_visible_child (drawing);
            drawing.queue_draw ();
        }
    }

    internal inline void update_menu (GLib.Menu menu)
    {
        set_menu_model (menu);
    }

    /*\
    * * drawing
    \*/

    private bool drawing_configured = false;
    private int drawing_height      = int.MIN;
    private int drawing_width       = int.MIN;
    private double arrow_half_width = - double.MAX;
    private int board_x             = int.MIN;
    private int board_y             = int.MIN;
    private const int pixbuf_margin = 1;

    private Gdk.Pixbuf tileset_pixbuf;

    private bool configure_drawing ()
    {
        int height          = drawing.get_allocated_height ();
        int width           = drawing.get_allocated_width ();
        int new_height      = (int) double.min (height, width / 2.0);

        drawing_height      = new_height;
        arrow_half_width    = ((double) drawing_height - 2.0 * pixbuf_margin) / 4.0;
        tiles_pattern       = null;

        bool vertical_fill  = height == new_height;
        drawing_width       =  vertical_fill ? (int) (new_height * 2.0) : width;
        board_x             =  vertical_fill ? (int) ((width  - drawing_width)  / 2.0) : 0;
        board_y             = !vertical_fill ? (int) ((height - drawing_height) / 2.0) : 0;

        drawing_configured  = true;
        return true;
    }

    private Cairo.Pattern? tiles_pattern = null;
    private void init_pattern (Cairo.Context cr)    // TODO unduplicate with ReversiView
    {
        Cairo.Surface surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, drawing_height * 8,
                                                                                                        drawing_height * 4);
        Cairo.Context context = new Cairo.Context (surface);
        Rsvg.DimensionData size = theme_manager.tileset_handle.get_dimensions ();
        context.scale ((double) drawing_height * 8.0 / (double) size.width,
                       (double) drawing_height * 4.0 / (double) size.height);
        theme_manager.tileset_handle.render_cairo (context);
        tiles_pattern = new Cairo.Pattern.for_surface (surface);
    }

    private bool update_drawing (Cairo.Context cr)
    {
        if (!drawing_configured)
            return false;

        if (tiles_pattern == null)
            init_pattern (cr);

        draw_arrow (cr);
        draw_piece (cr);
        return true;
    }

    private const double arrow_margin_top = 3.0;
    private void draw_arrow (Cairo.Context cr)
    {
        cr.save ();

        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);

        cr.set_source_rgba (/* red */ 0.5, /* green */ 0.5, /* blue */ 0.5, 1.0);
        cr.set_line_width (/* looks good */ 2.0);

        cr.translate (board_x, board_y);
        cr.move_to (      arrow_half_width, arrow_margin_top);
        cr.line_to (3.0 * arrow_half_width, drawing_height / 2.0);
        cr.line_to (      arrow_half_width, drawing_height - arrow_margin_top);
        cr.stroke ();

        cr.restore ();
    }

    private Player current_player = Player.NONE;
    private void draw_piece (Cairo.Context cr)
    {
        int pixmap;
        switch (current_player)
        {
            case Player.NONE    : return;
            case Player.DARK    : pixmap = 1;   break;
            case Player.LIGHT   : pixmap = 31;  break;
            default: assert_not_reached ();
        }

        cr.save ();
        Cairo.Matrix matrix = Cairo.Matrix.identity ();
        int x = board_x + drawing_width - drawing_height;
        matrix.translate (/* texture x */ (pixmap % 8) * drawing_height - /* x position */ x,
                          /* texture y */ (pixmap / 8) * drawing_height - /* y position */ board_y);
        ((!) tiles_pattern).set_matrix (matrix);
        cr.set_source ((!) tiles_pattern);
        cr.rectangle (x, board_y, drawing_height, drawing_height);

        cr.clip ();
        cr.paint ();
        cr.restore ();
    }
}
