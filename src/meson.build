version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala'
)

lib_sources = [
  'unit.vala',
  'parallelmanager.vala',
]

executable_sources = [
  'main.vala',
  version_file
]

basic_deps = [
  glib,
  gobject,
  gio
]

lib = library('varallel', lib_sources,
  dependencies: basic_deps,
  install: true,
)

executable('varallel', executable_sources,
  dependencies: basic_deps,
  install: true,
  link_with: lib,
)
