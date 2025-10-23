test_deps = [
  dependency('glib-2.0'),
  dependency('gee-0.8')
]

test_exe = executable(
  'layout_tests',
  files('test_layout.vala'),
  dependencies: test_deps,
  vala_args: ['--fatal-warnings']
)

test('layout_logic', test_exe)
