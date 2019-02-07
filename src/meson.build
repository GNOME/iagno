# Tests
iagno_tests = executable('iagno_tests',
    [
        'test-iagno.vala',
        'computer-player.vala',
        'game.vala',
        'player.vala'
    ],
    dependencies : [
        gio_dependency
    ]
)
test('iagno-tests', iagno_tests)

executable(meson.project_name(),
    [
        'vapi/config.vapi',
        'computer-player.vala',
        'game-view.vala',
        'game-window.vala',
        'game.vala',
        'iagno.vala',
        'player.vala',
        'themes-dialog.vala'
    ] + resources,
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--target-glib', '2.44',
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi'),
        '--enable-experimental-non-null'
    ],
    dependencies: [
        canberra_dependency,
        canberra_gtk3_dependency,
        gio_dependency,
        glib_dependency,
        gtk_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
