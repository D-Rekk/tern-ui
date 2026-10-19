#!/bin/sh
set -eu

tern --version
tern plugin types .

for manifest in extensions/*/plugin.toml; do
	[ -f "$manifest" ] || continue
	package=${manifest%/plugin.toml}
	tern plugin types "$package"
done
