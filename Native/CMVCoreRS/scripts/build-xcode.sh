#!/bin/zsh
set -euo pipefail

requested_arches="${CURRENT_ARCH:-}"
if [[ -z "$requested_arches" || "$requested_arches" == "undefined_arch" ]]; then
  requested_arches="${ARCHS:-${NATIVE_ARCH_ACTUAL:-}}"
fi
if [[ -z "$requested_arches" || "$requested_arches" == "undefined_arch" ]]; then
  echo "error: Xcode did not provide an architecture (CURRENT_ARCH/ARCHS)" >&2
  exit 1
fi

# Xcode may invoke this phase once for a multi-architecture target. Build one
# Rust archive per requested architecture, then merge them so the Swift target
# never links an arm64 archive into an x86_64 slice (or vice versa).
typeset -a arch_list
arch_list=("${(@s: :)requested_arches}")

if [[ -n "${CARGO:-}" ]]; then
  cargo_bin="$CARGO"
else
  user_home="${HOME:-}"
  typeset -a cargo_candidates
  cargo_candidates=(
    "$(command -v cargo 2>/dev/null || true)"
    "${user_home:+$user_home/.cargo/bin/cargo}"
    "/opt/homebrew/bin/cargo"
    "/usr/local/bin/cargo"
  )
  cargo_bin=""
  for candidate in "${cargo_candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      cargo_bin="$candidate"
      break
    fi
  done
fi
if [[ -z "$cargo_bin" || ! -x "$cargo_bin" ]]; then
  echo "error: cargo is not available; set CARGO or install Rust (checked PATH, ~/.cargo/bin, Homebrew)" >&2
  exit 1
fi

repo_root="${SRCROOT}/../CMVCoreRS"
target_root="${CMV_CARGO_TARGET_DIR:-${PROJECT_TEMP_DIR:-$DERIVED_FILE_DIR}/cmv-cargo-target}"
output_root="${DERIVED_FILE_DIR}/CMVCoreRS"

mkdir -p "$output_root"
typeset -a rust_libs
rust_libs=()

for selected_arch in "${arch_list[@]}"; do
  case "${PLATFORM_NAME:-}" in
    macosx)
      case "$selected_arch" in
        arm64) rust_target="aarch64-apple-darwin" ;;
        x86_64) rust_target="x86_64-apple-darwin" ;;
        *) echo "error: unsupported macOS architecture: $selected_arch" >&2; exit 1 ;;
      esac
      ;;
    iphoneos)
      case "$selected_arch" in
        arm64) rust_target="aarch64-apple-ios" ;;
        *) echo "error: unsupported iPad device architecture: $selected_arch" >&2; exit 1 ;;
      esac
      ;;
    iphonesimulator)
      case "$selected_arch" in
        arm64) rust_target="aarch64-apple-ios-sim" ;;
        x86_64) rust_target="x86_64-apple-ios" ;;
        *) echo "error: unsupported iPad Simulator architecture: $selected_arch" >&2; exit 1 ;;
      esac
      ;;
    *)
      echo "error: unsupported Apple platform: ${PLATFORM_NAME:-unknown}" >&2
      exit 1
      ;;
  esac

  CARGO_TARGET_DIR="$target_root" "$cargo_bin" build \
    --manifest-path "$repo_root/Cargo.toml" \
    --package cmv-core-ffi \
    --release \
    --target "$rust_target"

  rust_lib="$target_root/$rust_target/release/libcmv_core_ffi.a"
  if [[ ! -f "$rust_lib" ]]; then
    echo "error: Rust archive was not produced for $selected_arch ($rust_target)" >&2
    exit 1
  fi
  rust_libs+=("$rust_lib")
done

if (( ${#rust_libs[@]} == 1 )); then
  cp "${rust_libs[1]}" "$output_root/libcmv_core_ffi.a"
else
  xcrun lipo -create "${rust_libs[@]}" -output "$output_root/libcmv_core_ffi.a"
fi
