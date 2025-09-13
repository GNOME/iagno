themes = [
    'adwaita',
    'classic',
    'high_contrast',
    'sun_and_star'
]
foreach theme: themes
    i18n.merge_file(
        input: '@0@.theme.desktop.in'.format(theme),
        output: '@0@.theme'.format(theme),
        po_dir: join_paths(meson.project_source_root(), 'po'),
        type: 'desktop',
        install: true,
        install_dir: join_paths(get_option('datadir'), 'iagno', 'themes','key')
    )
endforeach
