#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: sh tern-ui/vendor.sh PLUGIN_DIR\n' >&2
    exit 2
fi

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
plugin_dir=$(CDPATH= cd -- "$1" && pwd)

if [ ! -f "$plugin_dir/plugin.toml" ]; then
    printf 'Not a Tern plugin directory: %s (missing plugin.toml)\n' "$plugin_dir" >&2
    exit 1
fi

# Only this generated library file is replaced; other vendor files are untouched.
destination="$plugin_dir/vendor/tern-ui"
mkdir -p "$destination"
cp "$source_dir/init.luau" "$destination/init.luau"
printf 'Vendored tern-ui into %s\n' "$destination"
