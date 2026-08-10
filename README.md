# qa-nix

Единый QA для всех Nix-репозиториев: **nixfmt**, **statix**, **deadnix** и
**nix flake check**. Настройки живут только здесь — в проектах не должно быть ни
`statix.toml`, ни `treefmt`-форматтеров для nix.

| Способ | Чем ставится |
| --- | --- |
| GitHub-экшен | `uses: wprhvso/qa-nix@v1` |
| Флейк nix | `nix run github:wprhvso/qa-nix` |
| Скрипт | `bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-nix/v1/scripts/local.sh)` |

## Проверки

| Проверка | Команда | Входит в `all` |
| --- | --- | --- |
| `fmt` | `nixfmt --check` по всем найденным `*.nix` | да |
| `statix` | `statix check` | да |
| `deadnix` | `deadnix --fail` с флагами из [`config/deadnix.args`](config/deadnix.args) | да |
| `flake` | `nix flake check -L` | нет |

Инструменты берутся из nixpkgs: `nix shell <nixpkgs>#nixfmt`,
`#statix`, `#deadnix`.

Список файлов собирается через `git ls-files '*.nix'` (без git — через `find`),
из него вычитаются пути из входа `exclude`.

## Использование

```yaml
name: ci

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  qa:
    runs-on: nested
    steps:
      - uses: actions/checkout@v7
      - uses: wprhvso/qa-nix@v1
```

Каждая проверка отдельной галочкой в PR:

```yaml
jobs:
  qa:
    runs-on: nested
    strategy:
      fail-fast: false
      matrix:
        check: [fmt, statix, deadnix]
    steps:
      - uses: actions/checkout@v7
      - uses: wprhvso/qa-nix@v1
        with:
          checks: ${{ matrix.check }}
```

Файлы, которые генерирует не человек:

```yaml
      - uses: wprhvso/qa-nix@v1
        with:
          exclude: "hosts/*/hardware-configuration.nix"
```

## Входные параметры

| Параметр | По умолчанию | Назначение |
| --- | --- | --- |
| `checks` | `all` | `all` либо список через запятую: `fmt`, `statix`, `deadnix`, `flake`. |
| `working-directory` | `.` | Каталог проекта в рабочей копии. |
| `config-mode` | `enforce` | `enforce` — общие конфиги перекрывают локальные, о найденных пишем warning; `check` — то же плюс падение job'а; `off` — конфиги не устанавливаются. |
| `setup-nix` | `true` | Ставить ли nix (`cachix/install-nix-action`). |
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` | Откуда берутся nixfmt, statix и deadnix. |
| `nix-config` | пусто | Дополнительные строки `nix.conf`. |
| `exclude` | пусто | Пути и glob'ы через запятую, которые не проверяются. |
| `fmt-args` / `statix-args` / `deadnix-args` / `flake-args` | пусто | Дополнительные аргументы. |

## Конфиги

| Файл | Куда кладётся |
| --- | --- |
| [`config/statix.toml`](config/statix.toml) | `statix.toml` в рабочем каталоге |
| [`config/deadnix.args`](config/deadnix.args) | флаги дописываются к `deadnix` |

Локальные настройки, о которых экшен предупреждает: `statix.toml`,
`.statix.toml`, `.nixfmt.toml`, `treefmt.toml`, `treefmt.nix`.

## Локальный прогон

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-nix/v1/scripts/local.sh)
```

| Аргумент | Назначение |
| --- | --- |
| `--fix` | `nixfmt`, `statix fix` и `deadnix --edit` вместо проверок. |
| `--exclude ПУТИ` | Пути и glob'ы через запятую. |
| `fmt` / `statix` / `deadnix` / `flake` | Только выбранные проверки. |
| `-h`, `--help` | Справка. |

Конфиг прописывается в `.git/info/exclude`, так что в git не попадает и
`.gitignore` не трогает. Инструменты берутся из `PATH`, а если их там нет — из
`nix shell`.

```bash
nix run github:wprhvso/qa-nix
nix develop
```
