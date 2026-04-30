#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/decompile-lua-bytes.sh [options] <directory>

Recursively decompile every *.lua.bytes file under <directory> into an output
directory, preserving paths relative to <directory>. For example:

  input/foo/bar.lua.bytes -> output/foo/bar.lua

Options:
  --luadec <path>  Path to luadec executable.
  -o, --output-dir <path>
                  Directory to write decompiled .lua files. Defaults to
                  <directory>, which preserves the historical sibling output.
  --failures <path>
                  Path to write failed cases. Defaults to
                  <output-dir>/decompile-failures.txt.
  -j, --jobs <n>  Number of files to decompile in parallel. Defaults to 1.
  --force          Overwrite existing .lua files.
  -h, --help       Show this help.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
luadec="$repo_root/_build/native/release/build/cmd/luadec/luadec.exe"
output_dir=""
failures_file=""
jobs=1
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
    -o|--output-dir)
      if (($# < 2)); then
        echo "error: $1 requires a path" >&2
        exit 2
      fi
      output_dir="$2"
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
    -j|--jobs)
      if (($# < 2)); then
        echo "error: $1 requires a number" >&2
        exit 2
      fi
      if [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: $1 must be a positive integer: $2" >&2
        exit 2
      fi
      jobs="$2"
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
input_dir="${input_dir%/}"

if [[ ! -x "$luadec" ]]; then
  echo "error: luadec executable not found or not executable: $luadec" >&2
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "error: directory not found: $input_dir" >&2
  exit 1
fi

if [[ -z "$output_dir" ]]; then
  output_dir="$input_dir"
fi
output_dir="${output_dir%/}"
mkdir -p "$output_dir"

if [[ -z "$failures_file" ]]; then
  failures_file="$output_dir/decompile-failures.txt"
fi

failures_dir="$(dirname "$failures_file")"
mkdir -p "$failures_dir"

: > "$failures_file"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/decompile-lua-bytes.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

record_status() {
  local status="$1"
  local status_file
  status_file="$(mktemp "$tmp_root/status.XXXXXX")"
  printf '%s\n' "$status" > "$status_file"
}

record_failure() {
  local input="$1"
  local output="$2"
  local reason="$3"
  local log_file="$4"
  local failure_file
  local message
  failure_file="$(mktemp "$tmp_root/failure.XXXXXX")"
  message="$(tr '\n' ' ' < "$log_file")"
  printf 'input=%s\toutput=%s\treason=%s\tmessage=%s\n' \
    "$input" "$output" "$reason" "$message" > "$failure_file"
}

decompile_one() {
  local input="$1"
  local rel="${input#"$input_dir"/}"
  local output="$output_dir/${rel%.lua.bytes}.lua"
  local output_parent
  local tmp_output
  local tmp_log
  local status
  local reason

  output_parent="$(dirname "$output")"
  mkdir -p "$output_parent"

  if [[ -e "$output" && "$force" -ne 1 ]]; then
    echo "skip: $output already exists (use --force to overwrite)"
    record_status skipped
    return 0
  fi

  tmp_output="$(mktemp "$output_parent/.decompile.XXXXXX")"
  rm -f "$tmp_output"
  tmp_log="$(mktemp)"

  echo "decompile: $input -> $output"
  status=0
  "$luadec" decompile "$input" -o "$tmp_output" > "$tmp_log" 2>&1 || status=$?

  if [[ "$status" -eq 0 && -e "$tmp_output" ]]; then
    mv "$tmp_output" "$output"
    record_status decompiled
  else
    reason="exit-$status"
    if [[ "$status" -eq 0 && ! -e "$tmp_output" ]]; then
      reason="missing-output"
    fi
    record_failure "$input" "$output" "$reason" "$tmp_log"
    record_status failed
  fi

  rm -f "$tmp_output" "$tmp_log"
}

export input_dir output_dir luadec force tmp_root
export -f record_status record_failure decompile_one

inputs_file="$tmp_root/inputs"
find "$input_dir" -type f -name '*.lua.bytes' -print0 | sort -z > "$inputs_file"

if [[ -s "$inputs_file" ]]; then
  xargs -0 -n 1 -P "$jobs" bash -c 'decompile_one "$1"' _ < "$inputs_file"
fi

count=0
skipped=0
failed=0
if compgen -G "$tmp_root/status.*" > /dev/null; then
  for status_file in "$tmp_root"/status.*; do
    status="$(cat "$status_file")"
    case "$status" in
      decompiled)
        count=$((count + 1))
        ;;
      skipped)
        skipped=$((skipped + 1))
        ;;
      failed)
        failed=$((failed + 1))
        ;;
    esac
  done
fi

if compgen -G "$tmp_root/failure.*" > /dev/null; then
  cat "$tmp_root"/failure.* > "$failures_file"
fi

echo "done: $count decompiled, $skipped skipped, $failed failed"
if ((failed > 0)); then
  echo "failed cases: $failures_file"
else
  echo "failed cases: none"
fi

if ((failed > 0)); then
  exit 1
fi
