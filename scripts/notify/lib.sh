#!/usr/bin/env bash
# Shared helpers used by scripts under scripts/notify/.
# Usage: `source` this file. Do NOT execute directly.

# Extract the last FROM line from Dockerfile content.
# In multi-stage builds the last FROM is the final runtime image
# -- the one developers actually consume.
extract_last_from() {
  printf '%s\n' "$1" \
    | grep -E '^[[:space:]]*FROM[[:space:]]+' \
    | tail -n1 \
    | sed -E 's/^[[:space:]]*FROM[[:space:]]+//; s/[[:space:]]+AS[[:space:]]+.*$//I; s/[[:space:]]+$//'
}

# Split "image[:tag][@digest]" into three TAB-separated fields.
# Correctly handles registry:port/path:tag (the port `:` must not be
# confused with the tag `:`).
parse_ref() {
  local raw="$1" image tag digest="-"
  if [[ "$raw" == *"@"* ]]; then
    digest="${raw##*@}"
    raw="${raw%@*}"
  fi
  local last="${raw##*/}"
  if [[ "$last" == *":"* ]]; then
    tag="${raw##*:}"
    image="${raw%:*}"
  else
    tag="latest"
    image="$raw"
  fi
  printf '%s\t%s\t%s\n' "$image" "$tag" "$digest"
}

# Resolve the tag immediately preceding $1. Empty string if none.
resolve_prev_tag() {
  local current="$1"
  if git rev-parse -q --verify "refs/tags/$current" >/dev/null 2>&1; then
    git tag --sort=-creatordate | awk -v cur="$current" '$0 != cur' | head -n1 || true
  else
    git tag --sort=-creatordate | head -n1 || true
  fi
}

# List every Dockerfile in the repo (excluding .git), sorted.
list_dockerfiles() {
  find . -type f -name 'Dockerfile*' -not -path './.git/*' | sort
}
