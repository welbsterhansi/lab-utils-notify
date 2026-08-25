#!/usr/bin/env bash
# Build the markdown body containing the current base-image catalog and
# the diff against the previous release. Writes to stdout.
#
# Usage:
#   TAG=v1.2.3 ./scripts/notify/build-catalog.sh > release-catalog.md
set -euo pipefail

: "${TAG:?TAG env var required}"

# shellcheck disable=SC1091
. "$(dirname "$0")/lib.sh"

PREV_TAG="$(resolve_prev_tag "$TAG")"
echo "PREV_TAG=${PREV_TAG:-<none>}" >&2

emit_row() {
  local stack="$1" raw="$2"
  local image tag digest
  IFS=$'\t' read -r image tag digest < <(parse_ref "$raw")
  printf '| `%s` | `%s` | `%s` | `%s` |\n' "$stack" "$image" "$tag" "$digest"
}

build_catalog() {
  echo "## Catalog of base images (release \`${TAG}\`)"
  echo
  echo "| Stack | Image | Tag | Digest |"
  echo "|---|---|---|---|"
  list_dockerfiles | while read -r file; do
    local stack raw
    stack="$(dirname "$file" | sed 's#^\./##')"
    raw="$(extract_last_from "$(cat "$file")")"
    if [ -z "$raw" ]; then continue; fi
    emit_row "$stack" "$raw"
  done
}

build_diff() {
  if [ -z "$PREV_TAG" ]; then
    echo "_First release of the repository: no previous tag to compare against._"
    return
  fi
  echo "## Changes since \`${PREV_TAG}\` (for release \`${TAG}\`)"
  echo
  echo "| Stack | Previous tag | Current tag | Changed? |"
  echo "|---|---|---|---|"
  list_dockerfiles | while read -r file; do
    local stack relpath curr_raw prev_content prev_raw
    local curr_tag prev_tag verdict
    stack="$(dirname "$file" | sed 's#^\./##')"
    relpath="${file#./}"
    curr_raw="$(extract_last_from "$(cat "$file")")"
    prev_content="$(git show "$PREV_TAG:$relpath" 2>/dev/null || true)"
    if [ -z "$prev_content" ]; then
      echo "| \`$stack\` | _(new)_ | \`$curr_raw\` | NEW |"
      continue
    fi
    prev_raw="$(extract_last_from "$prev_content")"
    IFS=$'\t' read -r _ curr_tag _ < <(parse_ref "$curr_raw")
    IFS=$'\t' read -r _ prev_tag _ < <(parse_ref "$prev_raw")
    if [ "$prev_raw" = "$curr_raw" ]; then
      verdict="unchanged"
    else
      verdict="**YES**"
    fi
    printf '| `%s` | `%s` | `%s` | %s |\n' "$stack" "$prev_tag" "$curr_tag" "$verdict"
  done
}

build_catalog
echo
build_diff
