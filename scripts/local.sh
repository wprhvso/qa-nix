#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
qa-nix — локальный прогон тех же проверок, что делает экшен в CI.

  bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-nix/v1/scripts/local.sh)
  ... --fix                              nixfmt, statix fix и deadnix --edit
  ... fmt statix                         только выбранные проверки
  ... --exclude 'hosts/*/hardware-configuration.nix'

Проверки: fmt, statix, deadnix, flake. По умолчанию — fmt, statix, deadnix.

Переменные окружения: QA_REF (тег qa-nix, по умолчанию v1), QA_LOCAL (локальная
копия qa-nix), QA_NIXPKGS (флейк-референс nixpkgs), QA_EXCLUDE.
USAGE
}

ref=${QA_REF:-v1}
base=${QA_BASE:-"https://raw.githubusercontent.com/wprhvso/qa-nix/$ref"}
nixpkgs=${QA_NIXPKGS:-github:NixOS/nixpkgs/nixos-unstable}

fix=false
checks=()
exclude=${QA_EXCLUDE:-}

while (($# > 0)); do
    case "$1" in
        --fix)
            fix=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --exclude)
            if (($# < 2)); then
                echo "--exclude требует значение" >&2
                exit 2
            fi
            exclude=$2
            shift 2
            ;;
        --exclude=*)
            exclude=${1#--exclude=}
            shift
            ;;
        fmt | statix | deadnix | flake)
            checks+=("$1")
            shift
            ;;
        *)
            echo "неизвестный аргумент: $1" >&2
            exit 2
            ;;
    esac
done
((${#checks[@]} == 0)) && checks=(fmt statix deadnix)

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch() {
    local rel=$1 dst=$2
    rm -f "$dst"
    if [[ -n ${QA_LOCAL:-} && -f "$QA_LOCAL/$rel" ]]; then
        cp "$QA_LOCAL/$rel" "$dst"
        chmod u+w "$dst"
    else
        curl -fsSL --retry 3 --retry-all-errors "$base/$rel" -o "$dst"
    fi
}

installed=()
install_config() {
    fetch "config/$1" "$root/$1"
    installed+=("$1")
    if [[ -d $root/.git ]] && ! grep -qxF "/$1" "$root/.git/info/exclude" 2>/dev/null; then
        mkdir -p "$root/.git/info"
        echo "/$1" >>"$root/.git/info/exclude"
    fi
}

install_config statix.toml

fetch config/deadnix.args "$work/deadnix.args"
read -r -a flags <<<"$(grep -vE '^[[:space:]]*(#|$)' "$work/deadnix.args" | tr '\n' ' ')" || true

IFS=',' read -r -a patterns <<<"$(echo "$exclude" | tr -d '[:space:]')"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    found=$(git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.nix')
else
    found=$(find . \
        \( -name .git -o -name .direnv -o -name node_modules -o -name result -o -name 'result-*' \) -prune \
        -o -type f -name '*.nix' -print | sed 's|^\./||' | sort)
fi

files=()
while IFS= read -r file; do
    [[ -n $file ]] || continue
    skip=false
    for pattern in "${patterns[@]}"; do
        [[ -n $pattern ]] || continue
        # shellcheck disable=SC2053
        if [[ $file == $pattern || $file == $pattern/* ]]; then
            skip=true
            break
        fi
    done
    [[ $skip == true ]] && continue
    files+=("$file")
done <<<"$found"

ignore=()
for pattern in "${patterns[@]}"; do
    [[ -n $pattern ]] || continue
    ignore+=(--ignore "$pattern")
done

tool() {
    local bin=$1 pkg=$2
    shift 2
    if command -v "$bin" >/dev/null 2>&1; then
        "$bin" "$@"
    else
        nix --extra-experimental-features "nix-command flakes" shell "$nixpkgs#$pkg" -c "$bin" "$@"
    fi
}

echo "qa-nix@$ref — файлов .nix: ${#files[@]}"
printf 'конфиги: %s\n\n' "${installed[*]}"

failed=()
run() {
    local title=$1
    shift
    echo "== $title"
    printf '+ %s\n' "$*"
    if "$@"; then
        echo
    else
        failed+=("$title")
        echo
    fi
}

for check in "${checks[@]}"; do
    case "$check" in
        fmt)
            if ((${#files[@]} == 0)); then
                echo "== nixfmt: файлов .nix нет"
                continue
            fi
            if [[ $fix == true ]]; then
                run "nixfmt" tool nixfmt nixfmt "${files[@]}"
            else
                run "nixfmt --check" tool nixfmt nixfmt --check "${files[@]}"
            fi
            ;;
        statix)
            if [[ $fix == true ]]; then
                run "statix fix" tool statix statix fix "${ignore[@]}"
            else
                run "statix check" tool statix statix check "${ignore[@]}"
            fi
            ;;
        deadnix)
            if ((${#files[@]} == 0)); then
                echo "== deadnix: файлов .nix нет"
                continue
            fi
            if [[ $fix == true ]]; then
                run "deadnix --edit" tool deadnix deadnix --edit "${flags[@]}" "${files[@]}"
            else
                run "deadnix --fail" tool deadnix deadnix --fail "${flags[@]}" "${files[@]}"
            fi
            ;;
        flake)
            run "nix flake check" nix --extra-experimental-features "nix-command flakes" flake check -L
            ;;
    esac
done

if ((${#failed[@]} > 0)); then
    printf 'упало: %s\n' "${failed[*]}"
    exit 1
fi
echo "всё чисто"
