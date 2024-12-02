#!/usr/bin/env -S v

fn sh(cmd string) {
  println('INFO: Running \'${cmd}\'')
  print(execute_or_exit(cmd).output)
}

name := 'rr-dl'
linux_name := name + '_linux_amd64'
windows_name := name + '.exe'

// Delete old files
rm(linux_name) or {}
rm(windows_name) or {}

// Build for linux
sh('v -os linux -prod .')
mv(name, linux_name) or { println('ERROR: Failed to rename linux build') }

// Build for windows
sh('v -os windows -prod .')

// Print version
$if windows {
  sh('.\\', windows_name + ' --version')
} $else {
  sh('./' + linux_name + ' --version')
}
