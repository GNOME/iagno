project('iagno', ['vala', 'c'],
    version: '3.32.0')


project_id = 'org.gnome.Reversi'
i18n = import('i18n')
# used to install help
gnome = import('gnome')
# used to run post install script
python3 = import('python3')


canberra_dependency = dependency('libcanberra')
canberra_gtk3_dependency = dependency('libcanberra-gtk3', version: '>= 0.26')
gio_dependency = dependency('gio-2.0', version: '>= 2.40.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.40.0')
gtk_dependency = dependency('gtk+-3.0', version: '>= 3.22.23')
posix_dependency = meson.get_compiler('vala').find_library('posix')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')

# Set gettext package name
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

localedir   = join_paths(get_option('prefix'), get_option('localedir'))
datadir     = join_paths(get_option('prefix'), get_option('datadir'))
icondir     = join_paths(datadir, 'icons', 'hicolor')
pkgdatadir  = join_paths(datadir, meson.project_name())
soundsdir   = join_paths(pkgdatadir, 'sounds')
schemadir   = join_paths(datadir, 'glib-2.0', 'schemas')
appsdir     = join_paths(datadir, 'applications')

conf = configuration_data ()
conf.set_quoted ('VERSION', meson.project_version())
conf.set_quoted ('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted ('DATA_DIRECTORY', pkgdatadir)
conf.set_quoted ('SOUND_DIRECTORY', soundsdir)
conf.set_quoted ('LOCALEDIR', localedir)

configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

subdir('data')
subdir('po')
subdir('help')
subdir('src')

meson.add_install_script(python3.find_python().path(),
                         join_paths(meson.source_root(), 'build-aux', 'meson_post_install.py'),
                         icondir,
                         schemadir,
                         appsdir)
