#!/usr/bin/env bash
#
# Assembles a minimal, standalone Godot project from this repo's self-contained
# scripts and runs the GUT unit tests against them.
#
# Why assemble instead of committing a project.godot + addons/gut?
#   This repo is consumed as a git submodule of the main game project. The UI
#   scripts (mod_manager.gd, popups/*) depend on the parent project's autoloads
#   and base classes, so they can't compile standalone — only the data layer
#   (helpers.gd, pack_data.gd, pack_data_loader.gd) is self-contained. And
#   committing addons/gut here would collide with the parent project's own copy
#   (duplicate class_name GutTest) once embedded. So CI builds a throwaway
#   project containing just the testable units plus a freshly fetched GUT.
#
# Env overrides: GODOT_BIN, GUT_VERSION, BUILD_DIR
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${BUILD_DIR:-${RUNNER_TEMP:-/tmp}/mod-manager-test-project}"
GUT_VERSION="${GUT_VERSION:-v9.6.0}"
GODOT="${GODOT_BIN:-godot}"

echo "Assembling test project in $BUILD"
rm -rf "$BUILD"
mkdir -p "$BUILD/test"

# Self-contained units only (see header note).
cp "$ROOT/helpers.gd" "$BUILD/"
cp "$ROOT/pack_data.gd" "$BUILD/"
cp "$ROOT/pack_data_loader.gd" "$BUILD/"
cp -r "$ROOT/test/." "$BUILD/test/"

cat >"$BUILD/project.godot" <<'PROJECT'
config_version=5

[application]
config/name="Mod Manager Tests"
config/features=PackedStringArray("4.6")
PROJECT

echo "Fetching GUT $GUT_VERSION"
git clone --depth 1 --branch "$GUT_VERSION" https://github.com/bitwes/Gut.git "$BUILD/.gut_src"
mkdir -p "$BUILD/addons"
cp -r "$BUILD/.gut_src/addons/gut" "$BUILD/addons/gut"
rm -rf "$BUILD/.gut_src"

echo "Importing project"
"$GODOT" --headless --path "$BUILD" --import

echo "Running GUT"
"$GODOT" --headless --path "$BUILD" \
	-s addons/gut/gut_cmdln.gd \
	-gdir=res://test -ginclude_subdirs -gexit
