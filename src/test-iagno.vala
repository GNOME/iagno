/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2013 Michael Catanzaro
 *
 * This file is part of Iagno.
 *
 * Iagno is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * Iagno is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Iagno.  If not, see <http://www.gnu.org/licenses/>.
 */

public class TestIagno : Object
{
    private static void test_undo_after_pass ()
    {
        string[] board = {"    LLLL",
                          "   LLLLD",
                          "  LLLLD ",
                          "  LLLDLL",
                          " LLLDLLL",
                          " LLDDLLL",
                          "LLLLLLLL",
                          "LLLLLLLL"};
        Game game = new Game.from_strings (board, Player.DARK);
        assert (game.place_tile (7, 2) > 0);
        assert (!game.can_move (Player.LIGHT));
        assert (game.can_undo ());
        game.pass ();
        assert (game.can_undo ());
        game.undo (2);
        assert (game.to_string ().strip () == string.joinv ("\n", board).strip ());
        assert (game.place_tile (7, 2) > 0);
        assert (!game.can_move (Player.LIGHT));
        assert (game.can_undo ());
        game.undo (1);
        assert (game.to_string ().strip () == string.joinv ("\n", board).strip ());
    }

    private static void test_undo_at_start ()
    {
        Game game = new Game ();
        assert (!game.can_undo (1));
        assert (!game.can_undo (2));
        game.place_tile (2, 3);
        assert (game.can_undo (1));
        assert (!game.can_undo (2));
        game.place_tile (2, 2);
        assert (game.can_undo (1));
        assert (game.can_undo (2));
    }

    private static void test_current_color_after_pass ()
    {
        string[] board = {"L LLLLLL",
                          "LLLLLLLL",
                          "L LLLLLL",
                          "LDLLLLLL",
                          "LDDLDLLL",
                          "LDLDLLLL",
                          "DDDDDLLL",
                          "DDDDDDDD"};
        Game game = new Game.from_strings (board, Player.DARK);
        assert (game.current_color == Player.DARK);
        assert (game.place_tile (1, 2) > 0);
        assert (game.current_color == Player.LIGHT);
        assert (!game.can_move (Player.LIGHT));
        game.pass ();
        assert (game.current_color == Player.DARK);
    }

    private static void test_ai_search_1 ()
    {
        string[] board = {"L  LLLLL",
                          "LLDDDDDD",
                          "DDDDDLDD",
                          "LDLLLLLL",
                          "LLDLDDLL",
                          "LLDDLLLL",
                          "LLLLLLLL",
                          "LLLLLLLL"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    private static void test_ai_search_2 ()
    {
        string[] board = {"        ",
                          "        ",
                          "   D    ",
                          "   DD   ",
                          "   DLL  ",
                          "  DDD   ",
                          "   D    ",
                          "  D     "};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    private static void test_ai_search_3 ()
    {
        string[] board = {"DL DDDDD",
                          "DLDDDDDD",
                          "DDLDLDDD",
                          "DLDDLDDD",
                          "DDLDLLLD",
                          "DLDDLDLD",
                          "LLLLLDDD",
                          "DDDDDDDD"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        assert (game.get_owner (2, 0) == Player.LIGHT);
    }

    private static void test_ai_search_4 ()
    {
        string[] board = {"  LDDDDD",
                          "DLDLDLDD",
                          "DDDLLDLD",
                          "DDLLDLDD",
                          "DLLLDDDD",
                          "DLDLDLDD",
                          "DDDLLDDD",
                          "DDDLDDDD"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        assert (game.get_owner (1, 0) == Player.LIGHT);
    }

    private static void test_ai_search_5 ()
    {
        string[] board = {"     L  ",
                          "    LL  ",
                          "  LLLL  ",
                          "  LLLL  ",
                          " DDDLLLL",
                          " L DLLLL",
                          " LLLDLLL",
                          "  LLLLLL"};
        Game game = new Game.from_strings (board, Player.LIGHT);
        ComputerPlayer ai = new ComputerPlayer (game);
        ai.move ();
        /* didn't crash */
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func ("/Iagno/Pass then Undo", test_undo_after_pass);
        Test.add_func ("/Iagno/Undo at Start", test_undo_at_start);
        Test.add_func ("/Iagno/Current Color after Pass", test_current_color_after_pass);
        Test.add_func ("/Iagno/AI Search 1", test_ai_search_1);
        Test.add_func ("/Iagno/AI Search 2", test_ai_search_2);
        Test.add_func ("/Iagno/AI Search 3", test_ai_search_3);
        Test.add_func ("/Iagno/AI Search 4", test_ai_search_4);
        Test.add_func ("/Iagno/AI Search 5", test_ai_search_5);
        return Test.run ();
    }
}
