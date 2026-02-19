conf = configuration_data()
conf.set('app_id', app_id)
conf.set('bindir', bindir)

# Install icon
install_data(
    'icons' / 'hicolor' / 'scalable' / '@0@.svg'.format(app_id),
    install_dir: join_paths(icondir, 'scalable', 'apps')
)

# Install symbolic icon
install_data(
    'icons' / 'hicolor' / 'symbolic' / 'org.gnome.Reversi-symbolic.svg',
    install_dir: join_paths(icondir, 'symbolic', 'apps')
)

# Install gschema
install_data(
    'org.gnome.Reversi.gschema.xml',
    install_dir: schemadir
)

# Compiling gresource
resources = gnome.compile_resources(
    'resources',
    'iagno.gresource.xml',
    source_dir: '.'
)

# Make D-Bus activatable
configure_file(
    input: 'org.gnome.Reversi.service.in',
    output: app_id + '.service',
    install: true,
    install_dir: datadir / 'dbus-1' / 'services',
    configuration: conf
)

# Desktop file
desktop_file = i18n.merge_file(
    input: configure_file(
        input: 'org.gnome.Reversi.desktop.in',
        output: 'iagno.desktop', # intermediate file
        configuration: conf,
    ),
    output: '@0@.desktop'.format(app_id),
    po_dir: join_paths(meson.project_source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: appsdir
)

# Validate desktop file
if desktop_file_validate.found()
    test(
        'validate-desktop',
        desktop_file_validate,
        args: [
            desktop_file.full_path()
        ]
    )
endif

# Metainfo file
metainfo_file = i18n.merge_file(
    input: configure_file(
        input: 'org.gnome.Reversi.metainfo.xml.in',
        output: 'iagno.metainfo.xml', # intermediate file
        configuration: conf,
    ),
    output: '@0@.metainfo.xml'.format(app_id),
    po_dir: join_paths(meson.project_source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate AppData file
if appstreamcli.found()
    test(
        'validate-metainfo',
        appstreamcli,
        args: [
            'validate', '--no-net', '--explain', metainfo_file.full_path()
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
