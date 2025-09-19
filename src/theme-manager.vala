/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2020 Arnaud Bonatti

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

private class ThemeManager : Object
{
    construct
    {
        var style_manager = Adw.StyleManager.get_default ();
        style_manager.notify ["dark"].connect (gtk_theme_changed);
        style_manager.notify ["high-contrast"].connect (gtk_theme_changed);
    }

    internal signal void theme_changed ();

    /*\
    * * theme
    \*/

    internal void gtk_theme_changed ()
    {
        if (!theme_set || _theme == "" || _theme == "default")
            theme = "default";  // yes
    }

    private bool theme_set = false;
    private string _theme;
    [CCode (notify = false)] internal string theme
    {
        private  get { if (!theme_set) assert_not_reached (); return _theme; }
        internal set
        {
            KeyFile key = new KeyFile ();
            if (value == "" || value == "default")
                set_default_theme (ref key);
            else
                try
                {
                    string key_path = Path.build_filename (DATA_DIRECTORY, "themes", "key");
                    string filepath = Path.build_filename (key_path, value);
                    if (Path.get_dirname (filepath) != key_path)
                        throw new FileError.FAILED ("Theme file is not in the \"key\" directory.");

                    key.load_from_file (filepath, GLib.KeyFileFlags.NONE);
                }
                catch (Error e)
                {
                    warning ("Failed to load theme: %s", e.message);
                    set_default_theme (ref key);
                    value = "default";
                }

            load_theme (key);   // FIXME loading could (even partially) fail here also
            _theme = value;
            theme_set = true;

            /* redraw all */
            theme_changed ();
        }
    }

    private void set_default_theme (ref KeyFile key)
    {
        var style_manager = Adw.StyleManager.get_default ();

        string filename;
        if (style_manager.high_contrast)
            filename = "high_contrast.theme";
        else if (style_manager.dark)
            filename = "adwaita.theme";
        else
            filename = "classic.theme";

        string filepath = Path.build_filename (DATA_DIRECTORY, "themes", "key", filename);
        try
        {
            key.load_from_file (filepath, GLib.KeyFileFlags.NONE);
        }
        catch { assert_not_reached (); }
    }

    /*\
    * * theme
    \*/

    private string pieces_file = "";

    [CCode (notify = false)] internal double background_red         { internal get; private set; default = 0.2; }
    [CCode (notify = false)] internal double background_green       { internal get; private set; default = 0.6; }
    [CCode (notify = false)] internal double background_blue        { internal get; private set; default = 0.4; }
    [CCode (notify = false)] internal int    background_radius      { internal get; private set; default = 0;   }

    [CCode (notify = false)] internal double texture_alpha          { internal get; private set; default = 0.25; }
    [CCode (notify = false)] internal bool   apply_texture          { internal get; private set; default = false; }

 // [CCode (notify = false)] internal double mark_red               { internal get; private set; default = 0.2; }
 // [CCode (notify = false)] internal double mark_green             { internal get; private set; default = 0.6; }
 // [CCode (notify = false)] internal double mark_blue              { internal get; private set; default = 0.4; }
 // [CCode (notify = false)] internal int    mark_width             { internal get; private set; default = 2;   }

    [CCode (notify = false)] internal double border_red             { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal double border_green           { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal double border_blue            { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal int    border_width           { internal get; private set; default = 3;   }
    [CCode (notify = false)] internal double half_border_width      { internal get; private set; default = 1.5; }

    [CCode (notify = false)] internal double spacing_red            { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal double spacing_green          { internal get; private set; default = 0.3; }
    [CCode (notify = false)] internal double spacing_blue           { internal get; private set; default = 0.2; }
    [CCode (notify = false)] internal int    spacing_width          { internal get; private set; default = 2;   }

    [CCode (notify = false)] internal double highlight_hard_red     { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal double highlight_hard_green   { internal get; private set; default = 0.3; }
    [CCode (notify = false)] internal double highlight_hard_blue    { internal get; private set; default = 0.2; }
    [CCode (notify = false)] internal double highlight_hard_alpha   { internal get; private set; default = 0.4; }

    [CCode (notify = false)] internal double highlight_soft_red     { internal get; private set; default = 0.1; }
    [CCode (notify = false)] internal double highlight_soft_green   { internal get; private set; default = 0.3; }
    [CCode (notify = false)] internal double highlight_soft_blue    { internal get; private set; default = 0.2; }
    [CCode (notify = false)] internal double highlight_soft_alpha   { internal get; private set; default = 0.2; }

 // [CCode (notify = false)] internal int    margin_width           { internal get; private set; default = 0; }

    [CCode (notify = false)] internal string sound_flip             { internal get; private set; default = ""; }
    [CCode (notify = false)] internal string sound_gameover         { internal get; private set; default = ""; }

    private inline void load_theme (GLib.KeyFile key)
    {
        try
        {
            string svg_path = Path.build_filename (DATA_DIRECTORY, "themes", "svg");
            pieces_file = Path.build_filename (svg_path, key.get_string ("Pieces", "File"));
            if (Path.get_dirname (pieces_file) != svg_path)
                pieces_file = Path.build_filename (svg_path, "black_and_white.svg");
            load_handle ();

            background_red       = key.get_double  ("Background", "Red");
            background_green     = key.get_double  ("Background", "Green");
            background_blue      = key.get_double  ("Background", "Blue");
            background_radius    = key.get_integer ("Background", "Radius");

            texture_alpha        = key.get_double  ("Background", "TextureAlpha");
            apply_texture        = (texture_alpha > 0.0) && (texture_alpha <= 1.0);

         // mark_red             = key.get_double  ("Mark", "Red");
         // mark_green           = key.get_double  ("Mark", "Green");
         // mark_blue            = key.get_double  ("Mark", "Blue");
         // mark_width           = key.get_integer ("Mark", "Width");

            border_red           = key.get_double  ("Border", "Red");
            border_green         = key.get_double  ("Border", "Green");
            border_blue          = key.get_double  ("Border", "Blue");
            border_width         = key.get_integer ("Border", "Width");
            half_border_width    = (double) border_width / 2.0;

            spacing_red          = key.get_double  ("Spacing", "Red");
            spacing_green        = key.get_double  ("Spacing", "Green");
            spacing_blue         = key.get_double  ("Spacing", "Blue");
            spacing_width        = key.get_integer ("Spacing", "Width");

            highlight_hard_red   = key.get_double  ("Highlight hard", "Red");
            highlight_hard_green = key.get_double  ("Highlight hard", "Green");
            highlight_hard_blue  = key.get_double  ("Highlight hard", "Blue");
            highlight_hard_alpha = key.get_double  ("Highlight hard", "Alpha");

            highlight_soft_red   = key.get_double  ("Highlight soft", "Red");
            highlight_soft_green = key.get_double  ("Highlight soft", "Green");
            highlight_soft_blue  = key.get_double  ("Highlight soft", "Blue");
            highlight_soft_alpha = key.get_double  ("Highlight soft", "Alpha");

         // margin_width         = key.get_integer ("Margin", "Width");

            sound_flip           = key.get_string  ("Sound", "Flip");
            sound_gameover       = key.get_string  ("Sound", "GameOver");
        }
        catch (KeyFileError e)      // TODO better
        {
            warning ("Errors when loading theme: %s", e.message);
        }
    }

    /*\
    * * loading handle
    \*/

    private bool handle_loaded = false;
    [CCode (notify = false)] internal Rsvg.Handle tileset_handle { internal get { if (!handle_loaded) assert_not_reached (); return _tileset_handle; }}

    private Rsvg.Handle _tileset_handle;

    private string old_pieces_file = "";
    private inline void load_handle ()
    {
        if (handle_loaded && old_pieces_file == pieces_file)
            return;

        try
        {
            _tileset_handle = new Rsvg.Handle.from_file (pieces_file);
        }
        catch (Error e)
        {
            assert_not_reached ();
        }

        old_pieces_file = pieces_file;
        handle_loaded = true;
    }

    public Gdk.MemoryTexture? tileset_for_size (int tile_size)
    {
        try
        {
            var width  = tile_size * 8;
            var height = tile_size * 4;

            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var context = new Cairo.Context (surface);
            tileset_handle.render_document (context, Rsvg.Rectangle () { x = 0, y = 0, width = width, height = height });
            surface.flush ();

            unowned uchar[] data = surface.get_data ();
            data.length = surface.get_height () * surface.get_stride ();
            var bytes = new Bytes (data);

            return new Gdk.MemoryTexture (
                surface.get_width (),
                surface.get_height (),
                Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,
                bytes,
                surface.get_stride ());
        }
        catch (Error e)
        {
            warning (e.message);
            return null;
        }
    }
}
