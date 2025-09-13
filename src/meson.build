# Tests generation
run_target('update-perfs-tests', command: executable ('iagno-perfs-tests-generator',
        [
            'vapi/config.vapi',
            'perfs-tests-generator.vala',
            'computer-player.vala',
            'computer-reversi.vala',
            'game.vala',
            'player.vala'
        ],
        c_args: [
            '-include', 'config.h'
        ],
        vala_args: [
            '--enable-experimental-non-null'
        ],
        dependencies : [
            gio_dependency,
            posix_dependency
        ]
    )
)

# Generated tests
if get_option('perfs_tests')
    iagno_generated_tests = executable('iagno-generated-tests',
        [
            'perfs-tests-iagno.vala',
            'perfs-tests-reverse.vala',
            'perfs-tests-reversi.vala',
            'computer-player.vala',
            'computer-reversi.vala',
            'game.vala',
            'player.vala'
        ],
        vala_args: [
            '--enable-experimental-non-null'
        ],
        dependencies : [
            gio_dependency
        ]
    )

    test('iagno-perfs-tests-reversi', iagno_generated_tests, args : ['-m', 'perf', '-p', '/Reversi/reversi'], timeout :  5)
    test('iagno-perfs-tests-reverse', iagno_generated_tests, args : ['-m', 'perf', '-p', '/Reversi/reverse'], timeout : 20)
endif

# Static tests
iagno_tests = executable('iagno-tests',
    [
        'test-iagno.vala',
        'computer-player.vala',
        'computer-reversi.vala',
        'game.vala',
        'player.vala'
    ],
    vala_args: [
        '--enable-experimental-non-null'
    ],
    dependencies : [
        gio_dependency
    ]
)
test('iagno-short-tests', iagno_tests, timeout : 1)

# Game
executable(meson.project_name(),
    [
        'vapi/config.vapi',
        'adaptative-window.vala',
        'computer-player.vala',
        'computer-reversi.vala',
        'game-window.vala',
        'game.vala',
        'history-button.vala',
        'iagno.vala',
        'new-game-screen.vala',
        'game-select-button.vala',
        'player.vala',
        'reversi-view.vala',
        'theme-manager.vala'
    ] + resources,
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--target-glib', '2.78',
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi'),
        '--enable-experimental-non-null'
    ],
    dependencies: [
        gio_dependency,
        glib_dependency,
        gtk_dependency,
        adw_dependency,
        libm_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
