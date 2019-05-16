/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2010-2013 Robert Ancell
   Copyright 2013-2014 Michael Catanzaro
   Copyright 2014-2019 Arnaud Bonatti

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

private abstract class ComputerPlayer : Object
{
    /* Source ID of a pending move timeout */
    private uint pending_move_id = 0;

    /* Indicates the results of the AI's search should be discarded.
     * The mutex is only needed for its memory barrier. */
    private bool _move_pending = false;
    private RecMutex _move_pending_mutex;
    [CCode (notify = false)] protected bool move_pending
    {
        protected get
        {
            _move_pending_mutex.lock ();
            bool result = _move_pending;
            _move_pending_mutex.unlock ();
            return result;
        }

        private set
        {
            _move_pending_mutex.lock ();
            _move_pending = value;
            _move_pending_mutex.unlock ();
        }
    }

    internal void move_sync (out uint8 x, out uint8 y)      // for tests
    {
        move_pending = true;
        PossibleMove best_move;
        run_search (out best_move);
        move_pending = false;
        complete_move (best_move);
        x = best_move.x;
        y = best_move.y;
    }

    internal void move (double delay_seconds = 0.0)
    {
        move_async.begin (delay_seconds);
    }
    private async void move_async (double delay_seconds)
    {
        Timer timer = new Timer ();
        PossibleMove best_move = PossibleMove (0, 0); // garbage

        while (move_pending)
        {
            /* We were called while a previous search was in progress.
             * Wait for that to finish before continuing. */
            Timeout.add (200, move_async.callback);
            yield;
        }

        timer.start ();
        new Thread<void *> ("AI thread", () => {
            move_pending = true;
            run_search (out best_move);
            move_async.callback ();
            return null;
        });
        yield;

        timer.stop ();

        if (!move_pending)
            return;

        if (timer.elapsed () < delay_seconds)
        {
            pending_move_id = Timeout.add ((uint) ((delay_seconds - timer.elapsed ()) * 1000), move_async.callback);
            yield;
        }

        pending_move_id = 0;
        move_pending = false;

        /* complete_move() needs to be called on the UI thread. */
        Idle.add (() => {
            complete_move (best_move);
            return Source.REMOVE;
        });
    }

    internal void cancel_move ()
    {
        if (!move_pending)
            return;

        /* If AI thread has finished and its move is queued, unqueue it. */
        if (pending_move_id != 0)
        {
            Source.remove (pending_move_id);
            pending_move_id = 0;
        }

        /* If AI thread is running, this tells move_async() to ignore its result.
         * If not, it's harmless, so it's safe to call cancel_move() on the human's turn. */
        move_pending = false;
    }

    protected abstract void run_search (out PossibleMove chosen_move);
    protected abstract void complete_move (PossibleMove chosen_move);
}
