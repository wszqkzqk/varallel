project('varallel', ['c', 'vala'],
          version: run_command('git', 'describe', '--tags').stdout().strip(),
    meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2', 'werror=false', 'b_lto=true'],
)

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = dependency('gio-2.0')

subdir('src')
