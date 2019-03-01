/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2013, 2014 Michael Catanzaro
   Copyright 2014, 2019 Arnaud Bonatti

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

private enum Player
{
    NONE,
    DARK,
    LIGHT;

    internal string to_string ()
    {
        switch (this)
        {
            case LIGHT: return "L";
            case DARK:  return "D";
            case NONE:  return ".";
            default:
                assert_not_reached ();
        }
    }

    internal static Player from_char (char c)
        requires (c == 'L' || c == 'D' || c == '.')
    {
        switch (c)
        {
            case 'L':   return LIGHT;
            case 'D':   return DARK;
            case '.':   return NONE;
            default:
                assert_not_reached ();
        }
    }

    internal static inline Player flip_color (Player p)
        requires (p != Player.NONE)
    {
        return (p == Player.LIGHT) ? Player.DARK : Player.LIGHT;
    }
}

