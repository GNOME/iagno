# Install icons
icon_sizes = ['16', '22', '24', '32', '48', '256']
foreach size : icon_sizes
    install_data(
        join_paths('icons', 'hicolor', '@0@x@0@'.format(size), '@0@.png'.format(project_id)),
        install_dir: join_paths(icondir, '@0@x@0@'.format(size), 'apps')
    )
endforeach
# Install symbolic icon
install_data(
        join_paths('icons', 'hicolor', 'symbolic', '@0@-symbolic.svg'.format(project_id)),
    install_dir: join_paths(icondir, 'symbolic', 'apps')
)

# Install gschema
install_data(
  '@0@.gschema.xml'.format(project_id),
  install_dir : schemadir
)

# Compiling gresoruce
resources = gnome.compile_resources(
    'resources', '@0@.gresource.xml'.format(meson.project_name()),
    source_dir: '.'
)

# Desktop file
desktop_file = i18n.merge_file(
    input: '@0@.desktop.in'.format(project_id),
    output: '@0@.desktop'.format(project_id),
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: appsdir
)

# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif

# AppData file
appdata_file = i18n.merge_file(
    input: '@0@.appdata.xml.in'.format(project_id),
    output: '@0@.appdata.xml'.format(project_id),
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate AppData file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

# Install man page
install_man('@0@.6'.format(meson.project_name()))

# Install sounds
install_data(
    [
        'sounds/flip-piece.ogg',
        'sounds/gameover.ogg'
    ],
    install_dir: join_paths(get_option('datadir'), meson.project_name(), 'sounds')
)

# Install themes
install_data(
    [
        'black_and_white.svg',
        'high_contrast.svg',
        'sun_and_star.svg'
    ],
    install_dir: join_paths(get_option('datadir'), meson.project_name(), 'themes', 'svg')
)
subdir('themes')
