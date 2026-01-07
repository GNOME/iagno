/*
  This file is part of GNOME Reversi

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

private class GameSelectLabel : Grid
{
    private Label label;
    private Image image;

    public string game_type
    {
        construct
        {
            if (value == "classic")
            {
                /* Translators: when configuring a new game, label of the first big button; name of the usual reversi game, where you try to have more pieces */
                label = new Gtk.Label (_("Classic Reversi"));
                image = new Image.from_resource ("/org/gnome/Reversi/images/reversi.png");
            }
            else if (value == "reverse")
            {
                /* Translators: when configuring a new game, label of the second big button; name of the opposite game, where you try to have less pieces */
                label = new Gtk.Label (_("Reverse Reversi"));
                image = new Image.from_resource ("/org/gnome/Reversi/images/reverse.png");
            }
            else
            {
                assert_not_reached ();
            }
            image.add_css_class ("game-select");
        }
    }

    public bool with_image { get; set; default = true; }

    construct
    {
        margin_top = 6;
        margin_bottom = 6;
        margin_start = 6;
        margin_end = 6;
        row_homogeneous = false;

        label.hexpand = true;
        label.vexpand = false;
        attach (label, 0, 0, 1, 1);

        image.halign = Align.CENTER;
        image.valign = Align.START;
        image.hexpand = true;
        image.vexpand = true;
        attach (image, 0, 1, 1, 1);

        bind_property ("with-image", image, "visible", GLib.BindingFlags.SYNC_CREATE);
        bind_property ("with-image", label, "vexpand", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN);
    }
}
