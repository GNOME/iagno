/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
   This file is part of GNOME Reversi, also known as Iagno.

   Copyright 2020 Arnaud Bonatti
   Copyright 2026 Andrey Kutejko

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

        _themes = load_themes ();
        theme_name = "default";
    }

    private void gtk_theme_changed ()
    {
        if (!theme_set || _theme_name == "default")
            theme_name = "default";  // yes
    }

    private GenericArray<Theme> _themes;

    private bool theme_set = false;
    private string _theme_name;
    private Theme _theme;

    public Theme theme
    {
        get { if (!theme_set) assert_not_reached (); return _theme; }
        set
        {
            _theme = value;
            _theme_name = value.name;
            theme_set = true;
        }
    }

    [CCode (notify = false)] internal string theme_name
    {
        private  get { if (!theme_set) assert_not_reached (); return _theme_name; }
        internal set
        {
            string name;
            string filename;
            if (value == "" || value == "default")
            {
                name = "default";
                filename = default_theme_file ();
            }
            else
            {
                name = value;
                filename = value;
            }

            foreach (var t in get_themes ())
                if (t.filename == filename)
                {
                    theme = t;
                    _theme_name = name;
                    return;
                }

            warning ("Failed to load theme: %s", value);
        }
    }

    private string default_theme_file ()
    {
        var style_manager = Adw.StyleManager.get_default ();
        if (style_manager.high_contrast)
            return "high_contrast.theme";
        else if (style_manager.dark)
            return "adwaita.theme";
        else
            return "classic.theme";
    }

    private static GenericArray<Theme> load_themes ()
    {
        var themes = new GenericArray<Theme> ();
        try
        {
            string key_path = Path.build_filename (DATA_DIRECTORY, "themes", "key");

            Dir dir = Dir.open (key_path);
            while (true)
            {
                string? filename = dir.read_name ();
                if (filename == null)
                    break;
                if (filename == "default")
                {
                    warning ("There should not be a theme filename named \"default\", ignoring it.");
                    continue;
                }

                try
                {
                    var filepath = Path.build_filename (key_path, (!) filename);
                    var theme = Theme.from_file (filepath);
                    themes.add (theme);
                }
                catch (Error e)
                {
                    warning ("Failed to load theme %s: %s", (!) filename, e.message);
                }
            }
        }
        catch (FileError e)
        {
            warning ("Failed to load themes: %s", e.message);
        }
        return themes;
    }

    public GenericArray<Theme> get_themes()
    {
        return _themes;
    }
}

private class Theme : Object
{
    public string filename;
    public string name;

    private Gly.Image image;

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

    public static Theme from_file (string filepath) throws Error
    {
        KeyFile key = new KeyFile ();
        key.load_from_file (filepath, GLib.KeyFileFlags.NONE);

        Theme theme = new Theme ();

        theme.filename             = Path.get_basename (filepath);
        theme.name                 = key.get_locale_string ("Theme", "Name");
        theme.image                = load_image (key.get_string ("Pieces", "File"));

        theme.background_red       = key.get_double  ("Background", "Red");
        theme.background_green     = key.get_double  ("Background", "Green");
        theme.background_blue      = key.get_double  ("Background", "Blue");
        theme.background_radius    = key.get_integer ("Background", "Radius");

        theme.texture_alpha        = key.get_double  ("Background", "TextureAlpha");
        theme.apply_texture        = (theme.texture_alpha > 0.0) && (theme.texture_alpha <= 1.0);

        // theme.mark_red             = key.get_double  ("Mark", "Red");
        // theme.mark_green           = key.get_double  ("Mark", "Green");
        // theme.mark_blue            = key.get_double  ("Mark", "Blue");
        // theme.mark_width           = key.get_integer ("Mark", "Width");

        theme.border_red           = key.get_double  ("Border", "Red");
        theme.border_green         = key.get_double  ("Border", "Green");
        theme.border_blue          = key.get_double  ("Border", "Blue");
        theme.border_width         = key.get_integer ("Border", "Width");

        theme.spacing_red          = key.get_double  ("Spacing", "Red");
        theme.spacing_green        = key.get_double  ("Spacing", "Green");
        theme.spacing_blue         = key.get_double  ("Spacing", "Blue");
        theme.spacing_width        = key.get_integer ("Spacing", "Width");

        theme.highlight_hard_red   = key.get_double  ("Highlight hard", "Red");
        theme.highlight_hard_green = key.get_double  ("Highlight hard", "Green");
        theme.highlight_hard_blue  = key.get_double  ("Highlight hard", "Blue");
        theme.highlight_hard_alpha = key.get_double  ("Highlight hard", "Alpha");

        theme.highlight_soft_red   = key.get_double  ("Highlight soft", "Red");
        theme.highlight_soft_green = key.get_double  ("Highlight soft", "Green");
        theme.highlight_soft_blue  = key.get_double  ("Highlight soft", "Blue");
        theme.highlight_soft_alpha = key.get_double  ("Highlight soft", "Alpha");

        // margin_width         = key.get_integer ("Margin", "Width");

        theme.sound_flip           = key.get_string  ("Sound", "Flip");
        theme.sound_gameover       = key.get_string  ("Sound", "GameOver");

        return theme;
    }

    private static Gly.Image load_image (string name)
    {
        string svg_path = Path.build_filename (DATA_DIRECTORY, "themes", "svg");
        string pieces_file = Path.build_filename (svg_path, name);
        if (Path.get_dirname (pieces_file) != svg_path)
            pieces_file = Path.build_filename (svg_path, "black_and_white.svg");

        var file = File.new_for_path (pieces_file);
        var loader = new Gly.Loader (file);
        return loader.load ();
    }

    public Gdk.Texture? tileset_for_size (int tile_size)
    {
        try
        {
            var width  = tile_size * 8;
            var height = tile_size * 4;

            var request = new Gly.FrameRequest ();
            request.set_scale (width, height);

            var frame = image.get_specific_frame (request);

            return GlyGtk4.frame_get_texture (frame);
        }
        catch (Error e)
        {
            warning (e.message);
            return null;
        }
    }
}
