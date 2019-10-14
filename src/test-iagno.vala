/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

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

namespace TestReversi
{
    private static int main (string [] args)
    {
        Test.init (ref args);

        Test.add_func ("/Reversi/test tests",
                                 test_tests);

        short_tests ();

        return Test.run ();
    }

    private static void short_tests ()
    {
        Test.add_func ("/Reversi/Pass then Undo",
                            test_undo_after_pass);
        Test.add_func ("/Reversi/Undo at Start",
                            test_undo_at_start);
        Test.add_func ("/Reversi/Current Color after Pass",
                            test_current_color_after_pass);
        Test.add_func ("/Reversi/AI Search 1",
                            test_ai_search_1);
        Test.add_func ("/Reversi/AI Search 2",
                            test_ai_search_2);
        Test.add_func ("/Reversi/AI Search 3",
                            test_ai_search_3);
        Test.add_func ("/Reversi/AI Search 4",
                            test_ai_search_4);
        Test.add_func ("/Reversi/AI Search 5",
                            test_ai_search_5);
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

    /*\
    * * short tests
    \*/

    private static void test_undo_after_pass ()
    {
        string [] board = { " . . . . L L L L",
                            " . . . L L L L D",
                            " . . L L L L D .",
                            " . . L L L D L L",
                            " . L L L D L L L",
                            " . L L D D L L L",
                            " L L L L L L L L",
                            " L L L L L L L L" };
        Game game = new Game.from_strings (board, Player.DARK);
        assert_true (game.number_of_moves == 0);
        assert_true (game.place_tile (7, 2));
        assert_true (game.number_of_moves == 1);
        assert_true (game.pass ());
        assert_true (game.number_of_moves == 2);
        game.undo (2);
        assert_true (game.number_of_moves == 0);
        string? [] board2 = (string? []) board; // TODO report bug
        assert_true (game.to_string ().strip () == string.joinv ("\n", board2).strip ());
        assert_true (game.place_tile (7, 2));
        assert_true (game.number_of_moves == 1);
        assert_true (!game.current_player_can_move);
        game.undo (1);
        assert_true (game.number_of_moves == 0);
        assert_true (game.to_string ().strip () == string.joinv ("\n", board2).strip ());
    }

    private static void test_undo_at_start ()
    {
        Game game = new Game (/* reverse */ false);
        assert_true (game.number_of_moves == 0);
        assert_true (game.place_tile (2, 3));
        assert_true (game.number_of_moves == 1);
        assert_true (game.place_tile (2, 2));
        assert_true (game.number_of_moves == 2);
    }

    private static void test_current_color_after_pass ()
    {
        string [] board = { " L . L L L L L L",
                            " L L L L L L L L",
                            " L . L L L L L L",
                            " L D L L L L L L",
                            " L D D L D L L L",
                            " L D L D L L L L",
                            " D D D D D L L L",
                            " D D D D D D D D" };
        Game game = new Game.from_strings (board, Player.DARK);
        assert_true (game.current_color == Player.DARK);
        assert_true (game.place_tile (1, 2));
        assert_true (game.current_color == Player.LIGHT);
        assert_true (game.pass ());
        assert_true (game.current_color == Player.DARK);
    }

    private static void test_ai_search_1 ()
    {
        string [] board = { " L . . L L L L L",
                            " L L D D D D D D",
                            " D D D D D L D D",
                            " L D L L L L L L",
                            " L L D L D D L L",
                            " L L D D L L L L",
                            " L L L L L L L L",
                            " L L L L L L L L" };
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerReversiEasy (game);
        assert_true (ai_move (ai, 2, 0));
        /* didn't crash */
    }

    private static void test_ai_search_2 ()
    {
        string [] board = { " . . . . . . . .",
                            " . . . . . . . .",
                            " . . . D . . . .",
                            " . . . D D . . .",
                            " . . . D L L . .",
                            " . . D D D . . .",
                            " . . . D . . . .",
                            " . . D . . . . ." };
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerReversiEasy (game);
        assert_true (ai_move (ai, 4, 6));
        /* didn't crash */
    }

    private static void test_ai_search_3 ()
    {
        string [] board = { " D L . D D D D D",
                            " D L D D D D D D",
                            " D D L D L D D D",
                            " D L D D L D D D",
                            " D D L D L L L D",
                            " D L D D L D L D",
                            " L L L L L D D D",
                            " D D D D D D D D" };
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerReversiEasy (game);
        assert_true (ai_move (ai, 2, 0));
        assert_true (game.get_owner (2, 0) == Player.LIGHT);
    }

    private static void test_ai_search_4 ()
    {
        string [] board = { " . . L D D D D D",
                            " D L D L D L D D",
                            " D D D L L D L D",
                            " D D L L D L D D",
                            " D L L L D D D D",
                            " D L D L D L D D",
                            " D D D L L D D D",
                            " D D D L D D D D" };
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerReversiEasy (game);
        assert_true (ai_move (ai, 1, 0));
        assert_true (game.get_owner (1, 0) == Player.LIGHT);
    }

    private static void test_ai_search_5 ()
    {
        string [] board = { " . . . . . L . .",
                            " . . . . L L . .",
                            " . . L L L L . .",
                            " . . L L L L . .",
                            " . D D D L L L L",
                            " . L . D L L L L",
                            " . L L L D L L L",
                            " . . L L L L L L" };
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerReversiEasy (game);
        assert_true (ai_move (ai, 0, 5));
        /* didn't crash */
    }
}
