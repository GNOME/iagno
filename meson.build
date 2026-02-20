project('iagno', ['vala', 'c'],
        version: '50.alpha')

app_id = 'org.gnome.Reversi' + get_option('app_id_suffix')

# used to install help
gnome = import('gnome')
# used for internationalization
i18n = import('i18n')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

gio_dependency = dependency('gio-2.0', version: '>= 2.78.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.78.0')
gtk_dependency = dependency('gtk4', version: '>= 4.12.0')
adw_dependency = dependency('libadwaita-1', version: '>= 1.7')
libm_dependency = cc.find_library('m', required: false) # some platforms do not have libm separated from libc
posix_dependency = valac.find_library('posix')
glycin_dependency = dependency('glycin-2', version: '>= 2.0')
glycin_gtk4_dependency = dependency('glycin-gtk4-2', version: '>= 2.0')

appstreamcli            = find_program('appstreamcli',          required: false)
desktop_file_validate   = find_program('desktop-file-validate', required: false)

# Set gettext package name
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

localedir   = join_paths(get_option('prefix'), get_option('localedir'))
datadir     = join_paths(get_option('prefix'), get_option('datadir'))
bindir      = join_paths(get_option('prefix'), get_option('bindir'))
icondir     = join_paths(datadir, 'icons', 'hicolor')
pkgdatadir  = join_paths(datadir, meson.project_name())
soundsdir   = join_paths(pkgdatadir, 'sounds')
schemadir   = join_paths(datadir, 'glib-2.0', 'schemas')
appsdir     = join_paths(datadir, 'applications')

conf = configuration_data ()
conf.set_quoted ('APP_ID', app_id)
conf.set_quoted ('VERSION', meson.project_version())
conf.set_quoted ('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted ('DATA_DIRECTORY', pkgdatadir)
conf.set_quoted ('SOUND_DIRECTORY', soundsdir)
conf.set_quoted ('LOCALEDIR', localedir)

configure_file(output: 'config.h', configuration: conf)

subdir('data')
subdir('po')
subdir('help')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
