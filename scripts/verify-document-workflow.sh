#!/bin/zsh
set -eu
project_root="$(cd "$(dirname "$0")/.." && pwd)"
products="${1:?Pass the existing Debug Build/Products/Debug directory}"
verification_output="${2:?Pass an isolated output directory}"
mkdir -p "$verification_output"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos15.6" \
  -I "$products" "$project_root/Tests/DocumentWorkflowVerification.swift" \
  "$products/SenseFlow.app/Contents/MacOS/SenseFlow.debug.dylib" \
  -Xlinker -rpath -Xlinker "$products/SenseFlow.app/Contents/MacOS" \
  -o "$verification_output/verify-document-workflow"
"$verification_output/verify-document-workflow" "$verification_output" "${@:3}"
