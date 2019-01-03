/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2015 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of a GNOME game.
 *
 * This application is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This application is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this application. If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

[GtkTemplate (ui = "/org/gnome/Iagno/ui/themes.ui")]
public class ThemesDialog : Dialog
{
    private const string PREFIX = "theme-";

    private GameView view;

    [GtkChild]
    private ListBox listbox;

    public ThemesDialog (GLib.Settings settings, GameView view)
    {
        Object (use_header_bar: Gtk.Settings.get_default ().gtk_dialogs_use_header ? 1 : 0);
        this.view = view;
        delete_event.connect (do_not_close);

        /* load themes key files */
        Dir dir;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes", "key"));
            while (true)
            {
                string filename = dir.read_name ();
                if (filename == null)
                    break;

                string path = Path.build_filename (DATA_DIRECTORY, "themes", "key", filename);
                var key = new GLib.KeyFile ();
                string name;
                try
                {
                    key.load_from_file (path, GLib.KeyFileFlags.NONE);
                    name = key.get_locale_string ("Theme", "Name");
                }
                catch (GLib.KeyFileError e)
                {
                    warning ("oops: %s", e.message);
                    continue;
                }

                var row = new ListBoxRow ();
                row.visible = true;
                row.height_request = 50;
                var box = new Box (Orientation.HORIZONTAL, 0);
                box.visible = true;
                var img = new Image ();
                img.visible = true;
                img.width_request = 50;
                img.icon_name = "object-select-symbolic";
                var lbl = new Label (name);
                lbl.visible = true;
                lbl.xalign = 0;
                var data = new Label (filename);
                data.visible = false;

                box.add (img);
                box.add (lbl);
                box.add (data);
                row.add (box);
                listbox.add (row);

                if (filename == settings.get_string ("theme"))
                    listbox.select_row (row);
            }
            // FIXME bug on <ctrl>double-click
            listbox.row_selected.connect ((row) => {
                    view.theme = ((Label) (((Box) row.get_child ()).get_children ().nth_data (2))).label;
                    // TODO BETTER view.theme may have fall back to "default"
                    settings.set_string ("theme", view.theme);
                    queue_draw ();      // try to redraw because there’re sometimes bugs
                });
        }
        catch (FileError e)
        {
            warning ("Failed to load themes: %s", e.message);
        }
    }

    private bool do_not_close (Widget widget, Gdk.EventAny event)
    {
        widget.hide ();
        return true;
    }
}
