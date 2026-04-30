#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/decompile-lua-bytes.sh [options] <directory>

Recursively decompile every *.lua.bytes file under <directory> to a sibling
*.lua file using _build/native/release/build/cmd/luadec/luadec.exe.

Options:
  --luadec <path>  Path to luadec executable.
  --failures <path>
                  Path to write failed cases. Defaults to
                  <directory>/decompile-failures.txt.
  --force          Overwrite existing .lua files.
  -h, --help       Show this help.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
luadec="$repo_root/_build/native/release/build/cmd/luadec/luadec.exe"
failures_file=""
force=0

while (($# > 0)); do
  case "$1" in
    --luadec)
      if (($# < 2)); then
        echo "error: --luadec requires a path" >&2
        exit 2
      fi
      luadec="$2"
      shift 2
      ;;
    --failures)
      if (($# < 2)); then
        echo "error: --failures requires a path" >&2
        exit 2
      fi
      failures_file="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if (($# != 1)); then
  usage >&2
  exit 2
fi

input_dir="$1"

if [[ ! -x "$luadec" ]]; then
  echo "error: luadec executable not found or not executable: $luadec" >&2
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "error: directory not found: $input_dir" >&2
  exit 1
fi

if [[ -z "$failures_file" ]]; then
  failures_file="$input_dir/decompile-failures.txt"
fi

failures_dir="$(dirname "$failures_file")"
if [[ ! -d "$failures_dir" ]]; then
  echo "error: failures file directory not found: $failures_dir" >&2
  exit 1
fi

: > "$failures_file"

count=0
skipped=0
failed=0

while IFS= read -r -d '' input; do
  output="${input%.lua.bytes}.lua"
  output_dir="$(dirname "$output")"

  if [[ -e "$output" && "$force" -ne 1 ]]; then
    echo "skip: $output already exists (use --force to overwrite)"
    skipped=$((skipped + 1))
    continue
  fi

  tmp_output="$(mktemp "$output_dir/.decompile.XXXXXX.lua")"
  rm -f "$tmp_output"
  tmp_log="$(mktemp)"

  echo "decompile: $input -> $output"
  status=0
  "$luadec" decompile "$input" -o "$tmp_output" > "$tmp_log" 2>&1 || status=$?

  if [[ "$status" -eq 0 && -e "$tmp_output" ]]; then
    mv "$tmp_output" "$output"
    count=$((count + 1))
  else
    reason="exit-$status"
    if [[ "$status" -eq 0 && ! -e "$tmp_output" ]]; then
      reason="missing-output"
    fi
    message="$(tr '\n' ' ' < "$tmp_log")"
    printf 'input=%s\toutput=%s\treason=%s\tmessage=%s\n' \
      "$input" "$output" "$reason" "$message" >> "$failures_file"
    failed=$((failed + 1))
  fi

  rm -f "$tmp_output" "$tmp_log"
done < <(find "$input_dir" -type f -name '*.lua.bytes' -print0 | sort -z)

echo "done: $count decompiled, $skipped skipped, $failed failed"
if ((failed > 0)); then
  echo "failed cases: $failures_file"
else
  echo "failed cases: none"
fi

if ((failed > 0)); then
  exit 1
fi
