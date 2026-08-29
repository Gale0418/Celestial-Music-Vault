#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
workspace_root="${repo_root:h:h}"
target_root="${CMV_CARGO_TARGET_DIR:-/tmp/cmv-cargo-target}"
smoke_root="${CMV_SWIFT_SMOKE_DIR:-/tmp/cmv-swift-bridge-smoke}"
cargo_bin="${CARGO:-$(command -v cargo || true)}"

if [[ -z "$cargo_bin" ]]; then
  echo "error: cargo is not available; install Rust or set CARGO" >&2
  exit 1
fi

host_target="$("$cargo_bin" -vV | sed -n 's/^host: //p')"
if [[ -z "$host_target" ]]; then
  echo "error: unable to resolve the Rust host target" >&2
  exit 1
fi

mkdir -p "$smoke_root"
CARGO_TARGET_DIR="$target_root" "$cargo_bin" build \
  --manifest-path "$repo_root/Cargo.toml" \
  --package cmv-core-ffi \
  --release \
  --target "$host_target"

xcrun swiftc \
  -swift-version 6 \
  -I "$repo_root/ffi/include" \
  -L "$target_root/$host_target/release" \
  -lcmv_core_ffi \
  "$workspace_root/Native/CMV/CMV/CMVCoreRSClient.swift" \
  "$repo_root/tests/swift_bridge/main.swift" \
  -o "$smoke_root/cmvcore-swift-bridge-smoke"

"$smoke_root/cmvcore-swift-bridge-smoke"
