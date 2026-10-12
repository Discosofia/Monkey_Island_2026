#!/usr/bin/env bash
# Instala en CI (Linux x86_64) las herramientas con las versiones fijadas en rokit.toml.
# Descarga directa desde GitHub Releases: no necesita token ni la API de GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="${TOOLS_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

# Lee la versión de una herramienta en rokit.toml. Ej.: rojo = "rojo-rbx/rojo@7.7.1" -> 7.7.1
version_of() {
	local version
	version="$(sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"[^@\"]+@([^\"]+)\".*/\1/p" "$ROOT/rokit.toml")"
	if [[ -z "$version" ]]; then
		echo "No se encontró la versión de '$1' en rokit.toml" >&2
		exit 1
	fi
	echo "$version"
}

install_zip() {
	local name="$1" url="$2" tmp
	tmp="$(mktemp -d)"
	echo "Instalando $name desde $url"
	curl -fsSL --retry 3 -o "$tmp/tool.zip" "$url"
	unzip -q -o "$tmp/tool.zip" -d "$tmp/out"
	install -m 755 "$tmp/out/$name" "$BIN_DIR/$name"
	rm -rf "$tmp"
}

ROJO="$(version_of rojo)"
STYLUA="$(version_of stylua)"
SELENE="$(version_of selene)"

install_zip rojo "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO}/rojo-${ROJO}-linux-x86_64.zip"
install_zip stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA}/stylua-linux-x86_64.zip"
install_zip selene "https://github.com/Kampfkarren/selene/releases/download/${SELENE}/selene-${SELENE}-linux.zip"

if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "$BIN_DIR" >>"$GITHUB_PATH"
fi

"$BIN_DIR/rojo" --version
"$BIN_DIR/stylua" --version
"$BIN_DIR/selene" --version
