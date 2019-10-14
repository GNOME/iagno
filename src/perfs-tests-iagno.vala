/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2019 — Arnaud Bonatti

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

namespace GeneratedTests
{
    private static int main (string [] args)
    {
        Test.init (ref args);

        Test.add_func ("/Reversi/test tests",
                                 test_tests);

        if (Test.perf ())
        {
            perfs_tests_reverse ();
            perfs_tests_reversi ();
        }

        return Test.run ();
    }

    private static void test_tests ()
    {
        assert_true (1 + 1 == 2);
    }

    /*\
    * * utilities
    \*/

    private static bool ai_move (ComputerPlayer ai, uint8 force_x, uint8 force_y)
    {
        uint8 x;
        uint8 y;
        ai.move_sync (out x, out y);

        bool success = (x == force_x)
                    && (y == force_y);

        if (!success)
            print (@"\nwanted: ($force_x, $force_y), result: ($x, $y)");

        return success;
    }
}
