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

private interface AdaptativeWidget : Object
{ /*
       ╎ extra ╎
       ╎ thin  ╎
  ╶╶╶╶ ┏━━━━━━━┳━━━━━━━┳━━━━━──╴
 extra ┃ PHONE ┃ PHONE ┃ EXTRA
 flat  ┃ _BOTH ┃ _HZTL ┃ _FLAT
  ╶╶╶╶ ┣━━━━━━━╋━━━━━━━╋━━━━╾──╴
       ┃ PHONE ┃       ┃
       ┃ _VERT ┃       ┃
       ┣━━━━━━━┫       ┃
       ┃ EXTRA ┃ QUITE ╿ USUAL
       ╿ _THIN │ _THIN │ _SIZE
       ╵       ╵       ╵
       ╎   quite thin  ╎
                              */

    internal enum WindowSize {
        START_SIZE,
        USUAL_SIZE,
        QUITE_THIN,
        PHONE_VERT,
        PHONE_HZTL,
        PHONE_BOTH,
        EXTRA_THIN,
        EXTRA_FLAT;

        internal static inline bool is_phone_size (WindowSize window_size)
        {
            return (window_size == PHONE_BOTH) || (window_size == PHONE_VERT) || (window_size == PHONE_HZTL);
        }

        internal static inline bool is_extra_thin (WindowSize window_size)
        {
            return (window_size == PHONE_BOTH) || (window_size == PHONE_VERT) || (window_size == EXTRA_THIN);
        }

        internal static inline bool is_extra_flat (WindowSize window_size)
        {
            return (window_size == PHONE_BOTH) || (window_size == PHONE_HZTL) || (window_size == EXTRA_FLAT);
        }

        internal static inline bool is_quite_thin (WindowSize window_size)
        {
            return is_extra_thin (window_size) || (window_size == PHONE_HZTL) || (window_size == QUITE_THIN);
        }
    }

    internal abstract void set_window_size (WindowSize new_size);
}

private const int LARGE_WINDOW_SIZE = 1042;

private abstract class AdaptativeWindow : Adw.ApplicationWindow
{
    construct
    {
        width_request = 350;    // 360px max for Purism Librem 5 portrait, for 648px height; update gschema also
        height_request = 284;   // 288px max for Purism Librem 5 landscape, for 720px width; update gschema also

        notify ["default-width"].connect (size_changed);
        notify ["default-height"].connect (size_changed);
    }

    /*\
    * * callbacks
    \*/

    private void size_changed ()
    {
        update_adaptative_children (default_width, default_height);
    }

    /*\
    * * adaptative stuff
    \*/

    private AdaptativeWidget.WindowSize window_size = AdaptativeWidget.WindowSize.START_SIZE;

    private List<AdaptativeWidget> adaptative_children = new List<AdaptativeWidget> ();
    protected void add_adaptative_child (AdaptativeWidget child)
    {
        adaptative_children.append (child);
    }

    private void update_adaptative_children (int width, int height)
    {
        bool extra_flat = height < 400;
        bool flat       = height < 500;

        if (width < 590)
        {
            if (extra_flat)         change_window_size (AdaptativeWidget.WindowSize.PHONE_BOTH);
            else if (height < 787)  change_window_size (AdaptativeWidget.WindowSize.PHONE_VERT);
            else                    change_window_size (AdaptativeWidget.WindowSize.EXTRA_THIN);
        }
        else if (width < 787)
        {
            if (extra_flat)         change_window_size (AdaptativeWidget.WindowSize.PHONE_HZTL);
            else                    change_window_size (AdaptativeWidget.WindowSize.QUITE_THIN);
        }
        else
        {
            if (extra_flat)         change_window_size (AdaptativeWidget.WindowSize.EXTRA_FLAT);
            else                    change_window_size (AdaptativeWidget.WindowSize.USUAL_SIZE);
        }
    }

    private void change_window_size (AdaptativeWidget.WindowSize new_window_size)
    {
        if (window_size == new_window_size)
            return;
        window_size = new_window_size;
        adaptative_children.@foreach ((adaptative_child) => adaptative_child.set_window_size (new_window_size));
    }
}
