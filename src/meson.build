version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala',
)

executable_sources = [
  'bindings.c',
  'unit.vala',
  'parallelmanager.vala',
  'main.vala',
  'reporter.vala',
  version_file,
]

basic_deps = [
  glib,
  gobject,
  gio,
  gmodule,
]

executable('varallel', executable_sources,
  dependencies: basic_deps,
  install: true,
)
