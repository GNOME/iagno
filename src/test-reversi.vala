/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2013 Michael Catanzaro
 *
 * This file is part of Reversi.
 *
 * Reversi is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Reversi is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Reversi. If not, see <http://www.gnu.org/licenses/>.
 */

public class TestReversi : Object
{
    private static void test_undo_after_pass ()
    {
        string[] board = {" . . . . L L L L",
                          " . . . L L L L D",
                          " . . L L L L D .",
                          " . . L L L D L L",
                          " . L L L D L L L",
                          " . L L D D L L L",
                          " L L L L L L L L",
                          " L L L L L L L L"};
        Game game = new Game.from_strings (board, Player.DARK);
        assert (game.number_of_moves == 0);
        assert (game.place_tile (7, 2) > 0);
        assert (game.number_of_moves == 1);
        assert (!game.current_player_can_move);
        game.pass ();
        assert (game.number_of_moves == 2);
        game.undo (2);
        assert (game.number_of_moves == 0);
        assert (game.to_string ().strip () == string.joinv ("\n", board).strip ());
        assert (game.place_tile (7, 2) > 0);
        assert (game.number_of_moves == 1);
        assert (!game.current_player_can_move);
        game.undo (1);
        assert (game.number_of_moves == 0);
        assert (game.to_string ().strip () == string.joinv ("\n", board).strip ());
    }

    private static void test_undo_at_start ()
    {
        Game game = new Game ();
        assert (game.number_of_moves == 0);
        game.place_tile (2, 3);
        assert (game.number_of_moves == 1);
        game.place_tile (2, 2);
        assert (game.number_of_moves == 2);
    }

    private static void test_current_color_after_pass ()
    {
        string[] board = {" L . L L L L L L",
                          " L L L L L L L L",
                          " L . L L L L L L",
                          " L D L L L L L L",
                          " L D D L D L L L",
                          " L D L D L L L L",
                          " D D D D D L L L",
                          " D D D D D D D D"};
        Game game = new Game.from_strings (board, Player.DARK);
        assert (game.current_color == Player.DARK);
        assert (game.place_tile (1, 2) > 0);
        assert (game.current_color == Player.LIGHT);
        assert (!game.current_player_can_move);
        game.pass ();
        assert (game.current_color == Player.DARK);
    }

    private static void test_ai_search_1 ()
    {
        string[] board = {" L . . L L L L L",
                          " L L D D D D D D",
                          " D D D D D L D D",
                          " L D L L L L L L",
                          " L L D L D D L L",
                          " L L D D L L L L",
                          " L L L L L L L L",
                          " L L L L L L L L"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    private static void test_ai_search_2 ()
    {
        string[] board = {" . . . . . . . .",
                          " . . . . . . . .",
                          " . . . D . . . .",
                          " . . . D D . . .",
                          " . . . D L L . .",
                          " . . D D D . . .",
                          " . . . D . . . .",
                          " . . D . . . . ."};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    private static void test_ai_search_3 ()
    {
        string[] board = {" D L . D D D D D",
                          " D L D D D D D D",
                          " D D L D L D D D",
                          " D L D D L D D D",
                          " D D L D L L L D",
                          " D L D D L D L D",
                          " L L L L L D D D",
                          " D D D D D D D D"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        assert (game.get_owner (2, 0) == Player.LIGHT);
    }

    private static void test_ai_search_4 ()
    {
        string[] board = {" . . L D D D D D",
                          " D L D L D L D D",
                          " D D D L L D L D",
                          " D D L L D L D D",
                          " D L L L D D D D",
                          " D L D L D L D D",
                          " D D D L L D D D",
                          " D D D L D D D D"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        assert (game.get_owner (1, 0) == Player.LIGHT);
    }

    private static void test_ai_search_5 ()
    {
        string[] board = {" . . . . . L . .",
                          " . . . . L L . .",
                          " . . L L L L . .",
                          " . . L L L L . .",
                          " . D D D L L L L",
                          " . L . D L L L L",
                          " . L L L D L L L",
                          " . . L L L L L L"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func ("/Reversi/Pass then Undo", test_undo_after_pass);
        Test.add_func ("/Reversi/Undo at Start", test_undo_at_start);
        Test.add_func ("/Reversi/Current Color after Pass", test_current_color_after_pass);
        Test.add_func ("/Reversi/AI Search 1", test_ai_search_1);
        Test.add_func ("/Reversi/AI Search 2", test_ai_search_2);
        Test.add_func ("/Reversi/AI Search 3", test_ai_search_3);
        Test.add_func ("/Reversi/AI Search 4", test_ai_search_4);
        Test.add_func ("/Reversi/AI Search 5", test_ai_search_5);
        return Test.run ();
    }
}
