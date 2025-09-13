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

private class GameSelectButton : ToggleButton
{
    private Box box;
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
            set_detailed_action_name ("app.type('" + value + "')");
        }
    }

    private bool _with_image = true;
    public bool with_image
    {
        get
        {
            return _with_image;
        }
        set
        {
            _with_image = value;
            label.vexpand = !_with_image;
            image.visible = _with_image;
        }
    }

    construct
    {
        box = new Box (Orientation.VERTICAL, 0);
        set_child (box);
        box.append (label);
        image.vexpand = true;
        image.width_request = 210;
        image.height_request = 210;
        box.append (image);
    }
}
