#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
task_build_dir="$(mktemp -d)"
trap 'rm -rf "$task_build_dir"' EXIT
for task_suite in ProtocolTests TargetTests ConfigurationTests OnboardKeysTests FnShortcutTests SecurityTests; do
  swiftc -swift-version 5 Sources/Security.swift Sources/Hardware.swift Sources/OnboardKeys.swift Sources/Keys.swift Sources/Shortcuts.swift Sources/Configuration.swift Tests/TestFixtures.swift "Tests/$task_suite.swift" -o "$task_build_dir/$task_suite"
  "$task_build_dir/$task_suite"
done
