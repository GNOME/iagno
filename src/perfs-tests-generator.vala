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

private class PerfsTestsGenerator : Application
{
    private static int main (string [] args)
    {
        Environment.set_application_name ("perfs-tests-generator");

        return new PerfsTestsGenerator ().run (args);
    }

    private PerfsTestsGenerator ()
    {
        Object (application_id: "org.gnome.Reversi.PerfsTestsGenerator", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        string [] environ = Environ.@get ();
        string? source_root = Environ.get_variable (environ, "MESON_SOURCE_ROOT");
        if (source_root == null)
            assert_not_reached ();

        generate_file ((!) source_root, /* reverse */ false);
        generate_file ((!) source_root, /* reverse */ true);

        return Posix.EXIT_SUCCESS;
    }

    private void generate_file (string source_root, bool reverse)
    {
        string file_name = reverse ? "perfs-tests-reverse.vala" : "perfs-tests-reversi.vala";
        FileStream? stream = FileStream.open (Path.build_filename (source_root, "src", file_name), "w");
        if (stream == null)
            assert_not_reached ();

        uint16 rounds = reverse ? 512 : 494;
        string e_or_i = reverse ? "e" : "i";

        ((!) stream).printf ("/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("   This file is part of GNOME Reversi, also known as Iagno.\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("   Copyright 2019 — Arnaud Bonatti\n");
        ((!) stream).printf ("   File updated by `ninja update-perfs-tests`\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("   GNOME Reversi is free software: you can redistribute it and/or modify\n");
        ((!) stream).printf ("   it under the terms of the GNU General Public License as published by\n");
        ((!) stream).printf ("   the Free Software Foundation, either version 3 of the License, or\n");
        ((!) stream).printf ("   (at your option) any later version.\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("   GNOME Reversi is distributed in the hope that it will be useful,\n");
        ((!) stream).printf ("   but WITHOUT ANY WARRANTY; without even the implied warranty of\n");
        ((!) stream).printf ("   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n");
        ((!) stream).printf ("   GNU General Public License for more details.\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("   You should have received a copy of the GNU General Public License\n");
        ((!) stream).printf ("   along with GNOME Reversi.  If not, see <https://www.gnu.org/licenses/>.\n");
        ((!) stream).printf ("*/\n");
        ((!) stream).printf ("\n");
        ((!) stream).printf ("namespace GeneratedTests\n");
        ((!) stream).printf ("{\n");

        ((!) stream).printf (@"    private static void perfs_tests_revers$e_or_i ()\n");
        ((!) stream).printf ( "    {\n");
        ((!) stream).printf ( "        /* crossing start position */\n");
        for (uint16 i = 0; i <= rounds; i++)
        {
            if ((!reverse && i == 232) || (reverse && i == 236))
                ((!) stream).printf ("        /* parallel start position */\n");
            ((!) stream).printf (@"        Test.add_func (\"/Reversi/revers$e_or_i/Complete game $(i + 1)\",\n");
            ((!) stream).printf (@"                            test_complete_revers$(e_or_i)_game_$(i + 1));\n");
            if (i != rounds) ((!) stream).printf ("\n");
        }
        ((!) stream).printf ("    }\n\n    /*\\\n    * * perfs tests\n    \\*/\n");

        uint8 [] game_init = { 0, 0, 0, 0 };
        uint8 [] game_init_max = { 0, 0, 0, 0 };
        for (uint16 i = 0; i <= rounds; i++)
        {
            /* ai1 starts */
            Opening opening = ((!reverse && i < 232) || (reverse && i < 236)) ? Opening.REVERSI : Opening.ALTER_TOP;
            Game game = new Game (reverse, opening, /* size */ 8);
            uint8 depth = reverse ? 2 : 1;

            if ((!reverse && i == 232) || (reverse && i == 236))
                game_init = { 0, 0, 0, 0 };
            for (uint8 j = 0; j <= 3; j++)
            {
                SList<PossibleMove?> moves;
                game.get_possible_moves (out moves);
                game_init_max [j] = (uint8) moves.length ();

                PossibleMove? move = moves.nth_data (game_init [j]);
                if (move == null)
                    assert_not_reached ();
                assert_true (game.place_tile (((!) move).x, ((!) move).y));
            }
            // for next game
            for (uint8 j = 3; j >= 0; j--)
            {
                game_init [j]++;
                if (game_init [j] < game_init_max [j])
                    break;
                game_init [j] = 0;
            }
            string [] initial_game = game.to_string ().split ("\n");
            initial_game = initial_game [1 : initial_game.length - 1];
            ComputerReversi ai;
            if (reverse)
                ai = new ComputerReverseHard (game, depth, /* fixed heuristic */ true);
            else
                ai = new ComputerReversiHard (game, depth, /* fixed heuristic */ true);

            ((!) stream).printf (@"\n    private static inline void test_complete_revers$(e_or_i)_game_$(i + 1) ()\n");
            ((!) stream).printf ( "    {\n");
            ((!) stream).printf ( "                                  /* 0 1 2 3 4 5 6 7 */\n");
            ((!) stream).printf (@"        string [] board = {/* 0 */ \"$(initial_game [0])\",\n");
            for (uint8 n = 1; n < 7; n++)
                ((!) stream).printf (@"                           /* $n */ \"$(initial_game [n])\",\n");
            ((!) stream).printf (@"                           /* 7 */ \"$(initial_game [7])\"};\n\n");

            ((!) stream).printf (@"        Game game = new Game.from_strings (board, Player.DARK, /* reverse */ $reverse);\n");
            ((!) stream).printf (@"        ComputerPlayer ai = new ComputerRevers$(e_or_i)Hard (game, /* depth */ $depth, /* fixed heuristic */ true);\n\n");

            uint8 x;
            uint8 y;
            do
            {
                if (game.current_player_can_move)
                {
                    ai.move_sync (out x, out y);
                    ((!) stream).printf (@"        assert_true (ai_move (ai, $x, $y));\n");
                }
                else if (!game.is_complete)
                {
                    game.pass ();
                    ((!) stream).printf (@"        assert_true (game.pass ());\n");
                }
            }
            while (!game.is_complete);

            ((!) stream).printf ("    }\n");
        }
        ((!) stream).printf ("}\n");
    }
}
