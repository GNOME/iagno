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
        'about-list.vala',
        'adaptative-window.vala',
        'base-headerbar.vala',
        'base-view.vala',
        'base-window.vala',
        'computer-player.vala',
        'computer-reversi.vala',
        'game-actionbar.vala',
        'game-headerbar.vala',
        'game-view.vala',
        'game-window.vala',
        'game.vala',
        'history-button.vala',
        'iagno.vala',
        'new-game-screen.vala',
        'night-light-monitor.vala',
        'notifications-revealer.vala',
        'overlayed-list.vala',
        'player.vala',
        'registry-placeholder.vala',
        'reversi-view.vala',
        'theme-manager.vala'
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
        gio_dependency,
        glib_dependency,
        gsound_dependency,
        gtk_dependency,
        libm_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
