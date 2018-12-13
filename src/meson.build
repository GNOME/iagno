# TODO: run tests
#         'test-iagno.vala',
# test_iagno_SOURCES = \
# 	test-iagno.vala \
# 	computer-player.vala \
# 	game.vala \
# 	player.vala

# test_iagno_VALAFLAGS = \
# 	--pkg gio-2.0 \
# 	--target-glib $(GLIB_REQUIRED)

executable(meson.project_name(),
    [
        'vapi/config.vapi',        
        'game-view.vala',
        'game-window.vala',
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
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi')
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