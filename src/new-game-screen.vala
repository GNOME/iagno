/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2010-2013 Robert Ancell
   Copyright 2013-2014 Michael Catanzaro
   Copyright 2014-2019 Arnaud Bonatti

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

[GtkTemplate (ui = "/org/gnome/Reversi/ui/iagno-screens.ui")]
private class NewGameScreen : Box, AdaptativeWidget
{
    [GtkChild] private Box infos_section;
    [GtkChild] private Box users_section;
    [GtkChild] private Box color_section;

    [GtkChild] private Box users_box;
    [GtkChild] private Box level_box;
    [GtkChild] private Box color_box;

    internal void update_sensitivity (bool new_sensitivity)
    {
        level_box.sensitive = new_sensitivity;
        color_box.sensitive = new_sensitivity;
    }

    private bool quite_thin = false;
    private bool extra_thin = true;     // extra_thin && !quite_thin is impossible, so it will not return in next method the first time
    private bool extra_flat = false;
    private void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        bool _quite_thin = WindowSize.is_quite_thin (new_size);
        bool _extra_thin = WindowSize.is_extra_thin (new_size);
        bool _extra_flat = WindowSize.is_extra_flat (new_size);

        if ((_quite_thin == quite_thin)
         && (_extra_thin == extra_thin)
         && (_extra_flat == extra_flat))
            return;
        quite_thin = _quite_thin;
        extra_thin = _extra_thin;
        extra_flat = _extra_flat;

        if (extra_thin)
        {
            set_orientation (Orientation.VERTICAL);
            spacing = 18;
            homogeneous = false;
            height_request = 360;
            width_request = 250;
            margin_bottom = 22;

            users_section.hide ();
            color_section.hide ();
            infos_section.show ();

            level_box.set_orientation (Orientation.VERTICAL);

            users_box.set_spacing (0);
            level_box.set_spacing (0);
            color_box.set_spacing (0);

            users_box.get_style_context ().add_class ("linked");
            level_box.get_style_context ().add_class ("linked");
            color_box.get_style_context ().add_class ("linked");
        }
        else if (extra_flat)
        {
            set_orientation (Orientation.HORIZONTAL);
            homogeneous = true;
            height_request = 113;
            margin_bottom = 6;
            if (quite_thin)
            {
                spacing = 21;
                width_request = 420;
            }
            else
            {
                spacing = 24;
                width_request = 450;
            }

            users_section.hide ();
            color_section.hide ();
            infos_section.show ();

            level_box.set_orientation (Orientation.VERTICAL);

            users_box.set_spacing (0);
            level_box.set_spacing (0);
            color_box.set_spacing (0);

            users_box.get_style_context ().add_class ("linked");
            level_box.get_style_context ().add_class ("linked");
            color_box.get_style_context ().add_class ("linked");
        }
        else
        {
            set_orientation (Orientation.VERTICAL);
            spacing = 18;
            height_request = 263;
            int boxes_spacing;
            if (quite_thin)
            {
                boxes_spacing = 10;
                width_request = 380;
            }
            else
            {
                boxes_spacing = 12;
                width_request = 400;
            }
            margin_bottom = 22;

            infos_section.hide ();
            users_section.show ();
            color_section.show ();

            level_box.set_orientation (Orientation.HORIZONTAL);

            users_box.get_style_context ().remove_class ("linked");
            level_box.get_style_context ().remove_class ("linked");
            color_box.get_style_context ().remove_class ("linked");

            users_box.set_spacing (boxes_spacing);
            level_box.set_spacing (boxes_spacing);
            color_box.set_spacing (boxes_spacing);

            homogeneous = true;
        }
        queue_allocate ();
    }
}
