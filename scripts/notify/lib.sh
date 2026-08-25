#!/usr/bin/env bash
# Funcoes compartilhadas pelos scripts em scripts/notify/.
# Uso: `source` este arquivo. Nao deve ser executado diretamente.

# Extrai a ultima linha FROM de um conteudo Dockerfile.
# Em builds multi-stage a ultima e a imagem final que o dev consome.
extract_last_from() {
  printf '%s\n' "$1" \
    | grep -E '^[[:space:]]*FROM[[:space:]]+' \
    | tail -n1 \
    | sed -E 's/^[[:space:]]*FROM[[:space:]]+//; s/[[:space:]]+AS[[:space:]]+.*$//I; s/[[:space:]]+$//'
}

# Quebra "image[:tag][@digest]" em tres campos separados por TAB.
# Cobre registry:porta/path:tag (o : da porta nao pode ser confundido com o : da tag).
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

# Descobre a tag imediatamente anterior a $1. Vazio se nao houver.
resolve_prev_tag() {
  local current="$1"
  if git rev-parse -q --verify "refs/tags/$current" >/dev/null 2>&1; then
    git tag --sort=-creatordate | awk -v cur="$current" '$0 != cur' | head -n1 || true
  else
    git tag --sort=-creatordate | head -n1 || true
  fi
}

# Lista todos os Dockerfiles do repo (excluindo .git), ordenados.
list_dockerfiles() {
  find . -type f -name 'Dockerfile*' -not -path './.git/*' | sort
}
