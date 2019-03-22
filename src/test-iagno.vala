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

private class TestIagno : Object
{
    private static int main (string [] args)
    {
        Test.init (ref args);

        Test.add_func ("/Iagno/test tests",
                            test_tests);

        // if meson is configured with -Dperfs_tests=true,
        // both tests are performed, else only short_tests
        if (Test.perf ())
            perfs_tests ();
        else
            short_tests ();

        return Test.run ();
    }

    private static void short_tests ()
    {
        Test.add_func ("/Iagno/Pass then Undo",
                            test_undo_after_pass);
        Test.add_func ("/Iagno/Undo at Start",
                            test_undo_at_start);
        Test.add_func ("/Iagno/Current Color after Pass",
                            test_current_color_after_pass);
        Test.add_func ("/Iagno/AI Search 1",
                            test_ai_search_1);
        Test.add_func ("/Iagno/AI Search 2",
                            test_ai_search_2);
        Test.add_func ("/Iagno/AI Search 3",
                            test_ai_search_3);
        Test.add_func ("/Iagno/AI Search 4",
                            test_ai_search_4);
        Test.add_func ("/Iagno/AI Search 5",
                            test_ai_search_5);
    }

    private static void perfs_tests ()
    {
        Test.add_func ("/Iagno/Complete game 1",
                            test_complete_game_1);
        Test.add_func ("/Iagno/Complete game 2",
                            test_complete_game_2);
        Test.add_func ("/Iagno/Complete game 3",
                            test_complete_game_3);
        Test.add_func ("/Iagno/Complete game 4",
                            test_complete_game_4);
    }

    private static void test_tests ()
    {
        assert_true (1 + 1 == 2);
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
        assert_true (!game.current_player_can_move);
        game.pass ();
        assert_true (game.number_of_moves == 2);
        game.undo (2);
        assert_true (game.number_of_moves == 0);
        assert_true (game.to_string ().strip () == string.joinv ("\n", board).strip ());
        assert_true (game.place_tile (7, 2));
        assert_true (game.number_of_moves == 1);
        assert_true (!game.current_player_can_move);
        game.undo (1);
        assert_true (game.number_of_moves == 0);
        assert_true (game.to_string ().strip () == string.joinv ("\n", board).strip ());
    }

    private static void test_undo_at_start ()
    {
        Game game = new Game ();
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
        assert_true (!game.current_player_can_move);
        game.pass ();
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
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
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
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
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
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
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
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
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
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    /*\
    * * perfs tests
    \*/

    private static void test_complete_game_1 ()
    {
        /* human starts              0 1 2 3 4 5 6 7 */
        string [] board = {/* 0 */ " . . . . . . . .",
                           /* 1 */ " . . . L . . . .",
                           /* 2 */ " . . . . L . . .",
                           /* 3 */ " . . . L D L . .",
                           /* 4 */ " . . . D D D . .",
                           /* 5 */ " . . . . . . . .",
                           /* 6 */ " . . . . . . . .",
                           /* 7 */ " . . . . . . . ." };

        Game game = new Game.from_strings (board, Player.DARK);
        ComputerPlayer ai = new ComputerPlayer (game, /* AI level */ 3);

        assert_true (game.place_tile (4, 1));
        assert_true (ai.force_moving (5, 5));
        assert_true (game.place_tile (4, 5));
        assert_true (ai.force_moving (3, 5));
        assert_true (game.place_tile (2, 5));
        assert_true (ai.force_moving (2, 4));
        assert_true (game.place_tile (4, 6));
        assert_true (ai.force_moving (2, 6));
        assert_true (game.place_tile (1, 4));
        assert_true (ai.force_moving (0, 4));
        assert_true (game.place_tile (2, 3));
        assert_true (ai.force_moving (1, 3));
        assert_true (game.place_tile (1, 5));
        assert_true (ai.force_moving (2, 2));
        assert_true (game.place_tile (3, 2));
        assert_true (ai.force_moving (5, 2));
        assert_true (game.place_tile (6, 4));
        assert_true (ai.force_moving (5, 6));
        assert_true (game.place_tile (3, 0));
        assert_true (ai.force_moving (0, 5));
        assert_true (game.place_tile (3, 6));
        assert_true (ai.force_moving (5, 7));
        assert_true (game.place_tile (0, 3));
        assert_true (ai.force_moving (0, 2));
        assert_true (game.place_tile (6, 5));
        assert_true (ai.force_moving (1, 2));
        assert_true (game.place_tile (3, 7));
        assert_true (ai.force_moving (2, 7));
        assert_true (game.place_tile (4, 7));
        assert_true (ai.force_moving (6, 6));
        assert_true (game.place_tile (2, 1));
        assert_true (ai.force_moving (2, 0));
        assert_true (game.place_tile (1, 0));
        assert_true (ai.force_moving (1, 1));
        assert_true (game.place_tile (6, 2));
        assert_true (ai.force_moving (4, 0));
        assert_true (game.place_tile (5, 0));
        assert_true (ai.force_moving (7, 3));
        assert_true (game.place_tile (6, 3));
        assert_true (ai.force_moving (7, 2));
        assert_true (game.place_tile (5, 1));
        assert_true (ai.force_moving (6, 1));
        assert_true (game.place_tile (7, 4));
        assert_true (ai.force_moving (7, 5));
        assert_true (game.place_tile (7, 1));
        assert_true (ai.force_moving (7, 0));
        assert_true (game.place_tile (7, 7));
        assert_true (ai.force_moving (6, 7));
        assert_true (game.place_tile (7, 6));
        assert_true (ai.force_moving (6, 0));
        assert_true (game.place_tile (0, 0));
        assert_true (ai.force_moving (0, 1));
        assert_true (game.place_tile (0, 6));
        assert_true (ai.force_moving (1, 6));
        assert_true (game.place_tile (1, 7));
        assert_true (ai.force_moving (0, 7));
    }

    private static void test_complete_game_2 ()
    {
        /* human starts              0 1 2 3 4 5 6 7 */
        string [] board = {/* 0 */ " . . . . . . . .",
                           /* 1 */ " . . . . . . . .",
                           /* 2 */ " . . . D . . . .",
                           /* 3 */ " . . L L L L . .",
                           /* 4 */ " . . . D D D . .",
                           /* 5 */ " . . . . . . . .",
                           /* 6 */ " . . . . . . . .",
                           /* 7 */ " . . . . . . . ." };

        Game game = new Game.from_strings (board, Player.DARK);
        ComputerPlayer ai = new ComputerPlayer (game, /* AI level */ 3);

        assert_true (game.place_tile (4, 2));
        assert_true (ai.force_moving (5, 5));
        assert_true (game.place_tile (6, 4));
        assert_true (ai.force_moving (5, 2));
        assert_true (game.place_tile (6, 5));
        assert_true (ai.force_moving (2, 2));
        assert_true (game.place_tile (3, 1));
        assert_true (ai.force_moving (4, 5));
        assert_true (game.place_tile (3, 5));
        assert_true (ai.force_moving (6, 3));
        assert_true (game.place_tile (2, 4));
        assert_true (ai.force_moving (3, 6));
        assert_true (game.place_tile (7, 3));
        assert_true (ai.force_moving (2, 5));
        assert_true (game.place_tile (3, 7));
        assert_true (ai.force_moving (7, 5));
        assert_true (game.place_tile (5, 6));
        assert_true (ai.force_moving (5, 7));
        assert_true (game.place_tile (6, 2));
        assert_true (ai.force_moving (4, 6));
        assert_true (game.place_tile (4, 7));
        assert_true (ai.force_moving (2, 7));
        assert_true (game.place_tile (1, 3));
        assert_true (ai.force_moving (1, 2));
        assert_true (game.place_tile (0, 2));
        assert_true (ai.force_moving (2, 1));
        assert_true (game.place_tile (2, 0));
        assert_true (ai.force_moving (1, 1));
        assert_true (game.place_tile (2, 6));
        assert_true (ai.force_moving (1, 7));
        assert_true (game.place_tile (4, 1));
        assert_true (ai.force_moving (7, 4));
        assert_true (game.place_tile (7, 6));
        assert_true (ai.force_moving (0, 4));
        assert_true (game.place_tile (0, 3));
        assert_true (ai.force_moving (0, 1));
        assert_true (game.place_tile (1, 4));
        assert_true (ai.force_moving (6, 6));
        assert_true (game.place_tile (1, 6));
        assert_true (ai.force_moving (4, 0));
        assert_true (game.place_tile (3, 0));
        assert_true (ai.force_moving (1, 0));
        assert_true (game.place_tile (5, 1));
        assert_true (ai.force_moving (7, 2));
        assert_true (game.place_tile (7, 7));
        assert_true (ai.force_moving (6, 0));
        assert_true (game.place_tile (6, 1));
        assert_true (ai.force_moving (6, 7));
        assert_true (game.place_tile (0, 7));
        assert_true (ai.force_moving (5, 0));
        assert_true (game.place_tile (0, 0));
        assert_true (ai.force_moving (0, 6));
        assert_true (game.place_tile (0, 5));
        assert_true (ai.force_moving (1, 5));
        assert_true (game.place_tile (7, 0));
        assert_true (ai.force_moving (7, 1));
    }

    private static void test_complete_game_3 ()
    {
        /* AI starts                 0 1 2 3 4 5 6 7 */
        string [] board = {/* 0 */ " . . . . . . . .",
                           /* 1 */ " . . . . . . . .",
                           /* 2 */ " . . . . . D . .",
                           /* 3 */ " . . . L D D . .",
                           /* 4 */ " . . . D L D . .",
                           /* 5 */ " . . . . . L . .",
                           /* 6 */ " . . . . . . . .",
                           /* 7 */ " . . . . . . . ." };

        Game game = new Game.from_strings (board, Player.DARK);
        ComputerPlayer ai = new ComputerPlayer (game, /* AI level */ 3);

        assert_true (ai.force_moving (3, 5));
        assert_true (game.place_tile (6, 3));
        assert_true (ai.force_moving (3, 2));
        assert_true (game.place_tile (2, 3));
        assert_true (ai.force_moving (1, 4));
        assert_true (game.place_tile (4, 5));
        assert_true (ai.force_moving (6, 5));
        assert_true (game.place_tile (2, 6));
        assert_true (ai.force_moving (2, 5));
        assert_true (game.place_tile (3, 6));
        assert_true (ai.force_moving (2, 2));
        assert_true (game.place_tile (0, 3));
        assert_true (ai.force_moving (6, 2));
        assert_true (game.place_tile (1, 3));
        assert_true (ai.force_moving (0, 5));
        assert_true (game.place_tile (4, 1));
        assert_true (ai.force_moving (5, 1));
        assert_true (game.place_tile (6, 4));
        assert_true (ai.force_moving (1, 5));
        assert_true (game.place_tile (5, 0));
        assert_true (ai.force_moving (7, 3));
        assert_true (game.place_tile (2, 4));
        assert_true (ai.force_moving (3, 0));
        assert_true (game.place_tile (4, 2));
        assert_true (ai.force_moving (3, 1));
        assert_true (game.place_tile (0, 4));
        assert_true (ai.force_moving (0, 2));
        assert_true (game.place_tile (1, 2));
        assert_true (ai.force_moving (4, 7));
        assert_true (game.place_tile (2, 7));
        assert_true (ai.force_moving (0, 6));
        assert_true (game.place_tile (4, 6));
        assert_true (ai.force_moving (5, 7));
        assert_true (game.place_tile (5, 6));
        assert_true (ai.force_moving (2, 1));
        assert_true (game.place_tile (2, 0));
        assert_true (ai.force_moving (1, 0));
        assert_true (game.place_tile (7, 5));
        assert_true (ai.force_moving (6, 7));
        assert_true (game.place_tile (7, 2));
        assert_true (ai.force_moving (7, 6));
        assert_true (game.place_tile (7, 7));
        assert_true (ai.force_moving (3, 7));
        assert_true (game.place_tile (7, 4));
        assert_true (ai.force_moving (1, 1));
        assert_true (game.place_tile (6, 6));
        assert_true (ai.force_moving (6, 1));
        assert_true (game.place_tile (0, 0));
        assert_true (ai.force_moving (1, 7));
        assert_true (game.place_tile (4, 0));
        assert_true (ai.force_moving (6, 0));
        assert_true (game.place_tile (0, 7));
        assert_true (ai.force_moving (0, 1));
        assert_true (game.place_tile (1, 6));
        assert_true (ai.force_moving (7, 1));
        assert_true (game.place_tile (7, 0));
    }

    private static void test_complete_game_4 ()
    {
        /* AI starts                 0 1 2 3 4 5 6 7 */
        string [] board = {/* 0 */ " . . . . . . . .",
                           /* 1 */ " . . . . . . . .",
                           /* 2 */ " . . . D . L . .",
                           /* 3 */ " . . . D L . . .",
                           /* 4 */ " . . L L D . . .",
                           /* 5 */ " . . . . D . . .",
                           /* 6 */ " . . . . . . . .",
                           /* 7 */ " . . . . . . . ." };

        Game game = new Game.from_strings (board, Player.DARK);
        ComputerPlayer ai = new ComputerPlayer (game, /* AI level */ 3);

        assert_true (ai.force_moving (5, 4));
        assert_true (game.place_tile (6, 4));
        assert_true (ai.force_moving (1, 5));
        assert_true (game.place_tile (2, 2));
        assert_true (ai.force_moving (3, 5));
        assert_true (game.place_tile (1, 4));
        assert_true (ai.force_moving (6, 3));
        assert_true (game.place_tile (4, 2));
        assert_true (ai.force_moving (4, 1));
        assert_true (game.place_tile (5, 5));
        assert_true (ai.force_moving (2, 3));
        assert_true (game.place_tile (4, 0));
        assert_true (ai.force_moving (5, 6));
        assert_true (game.place_tile (2, 6));
        assert_true (ai.force_moving (2, 5));
        assert_true (game.place_tile (0, 4));
        assert_true (ai.force_moving (0, 6));
        assert_true (game.place_tile (1, 3));
        assert_true (ai.force_moving (5, 1));
        assert_true (game.place_tile (6, 7));
        assert_true (ai.force_moving (3, 6));
        assert_true (game.place_tile (3, 7));
        assert_true (ai.force_moving (5, 0));
        assert_true (game.place_tile (6, 5));
        assert_true (ai.force_moving (3, 0));
        assert_true (game.place_tile (3, 1));
        assert_true (ai.force_moving (0, 2));
        assert_true (game.place_tile (5, 3));
        assert_true (ai.force_moving (7, 4));
        assert_true (game.place_tile (7, 2));
        assert_true (ai.force_moving (7, 5));
        assert_true (game.place_tile (4, 6));
        assert_true (ai.force_moving (1, 2));
        assert_true (game.place_tile (7, 3));
        assert_true (ai.force_moving (6, 2));
        assert_true (game.place_tile (7, 6));
        assert_true (ai.force_moving (2, 7));
        assert_true (game.place_tile (1, 7));
        assert_true (ai.force_moving (2, 0));
        assert_true (game.place_tile (7, 1));
        assert_true (ai.force_moving (6, 6));
        assert_true (game.place_tile (0, 3));
        assert_true (ai.force_moving (0, 5));
        assert_true (game.place_tile (7, 7));
        assert_true (ai.force_moving (6, 1));
        assert_true (game.place_tile (7, 0));
        assert_true (ai.force_moving (6, 0));
        assert_true (game.place_tile (1, 0));
        assert_true (ai.force_moving (1, 6));
        assert_true (game.place_tile (2, 1));
        game.pass ();
        assert_true (game.place_tile (0, 7));
        game.pass ();
        assert_true (game.place_tile (0, 1));
        assert_true (ai.force_moving (1, 1));
        assert_true (game.place_tile (0, 0));
        game.pass ();
        assert_true (game.place_tile (4, 7));
        assert_true (ai.force_moving (5, 7));
    }
}
