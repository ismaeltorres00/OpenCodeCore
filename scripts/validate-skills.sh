#!/usr/bin/env bash
# Valida que skills/index.json esté sincronizado con los ficheros reales
# y que cada skill cumpla el formato mínimo exigido por el equipo.
#
# Layout exigido por el mecanismo de fuente HTTP real de OpenCode
# (opencode.ai/v2/docs/skills): cada skill vive en su propia carpeta,
# fetch pattern <base-url>/<skill-name>/<fichero>. Por eso el fichero
# de cada skill es skills/<name>/<name>.md, NO skills/<name>.md.
set -euo pipefail

SKILLS_DIR="skills"
INDEX_FILE="${SKILLS_DIR}/index.json"
FAIL=0

echo "== Validando ${INDEX_FILE} =="

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq no está instalado en el runner"
  exit 1
fi

names_in_index=$(jq -r '.skills[].name' "$INDEX_FILE" | tr -d '\r')

for name in $names_in_index; do
  dir="${SKILLS_DIR}/${name}"
  file="${dir}/${name}.md"

  if [ ! -d "$dir" ]; then
    echo "ERROR: ${name} está en index.json pero no existe la carpeta ${dir}/"
    FAIL=1
    continue
  fi

  if [ ! -f "$file" ]; then
    echo "ERROR: ${name} está en index.json pero no existe ${file}"
    FAIL=1
    continue
  fi

  # nombre en frontmatter debe existir y coincidir
  fm_name=$(awk '/^---$/{c++; next} c==1 && /^name:/{print $2; exit}' "$file")
  if [ "$fm_name" != "$name" ]; then
    echo "ERROR: ${file} tiene 'name: ${fm_name}' en frontmatter, esperado '${name}'"
    FAIL=1
  fi

  # nombre debe ser lowercase-con-guiones
  if ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
    echo "ERROR: ${name} no cumple el patrón [a-z0-9-]+"
    FAIL=1
  fi

  # description mínima de 20 caracteres
  desc_len=$(awk '/^---$/{c++; next} c==1 && /^description:/{sub(/^description:[ ]*/,""); print length($0); exit}' "$file")
  if [ -z "$desc_len" ] || [ "$desc_len" -lt 20 ]; then
    echo "ERROR: ${file} tiene description ausente o demasiado corta (<20 caracteres)"
    FAIL=1
  fi

  # cada entrada de index.json declara "files": deben existir todos, dentro de la carpeta de la skill
  files=$(jq -r --arg n "$name" '.skills[] | select(.name==$n) | .files[]' "$INDEX_FILE" | tr -d '\r')
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ ! -f "${dir}/${f}" ]; then
      echo "ERROR: index.json declara '${f}' para ${name} pero no existe ${dir}/${f}"
      FAIL=1
    fi
  done <<< "$files"
done

# carpetas en skills/ que NO están en index.json (huérfanas)
for d in "${SKILLS_DIR}"/*/; do
  base=$(basename "$d")
  if ! echo "$names_in_index" | grep -qx "$base"; then
    echo "ERROR: ${d} existe pero '${base}' no está listado en index.json"
    FAIL=1
  fi
done

# ficheros .md sueltos directamente en skills/ (layout viejo, ya no soportado)
shopt -s nullglob
stray=("${SKILLS_DIR}"/*.md)
shopt -u nullglob
if [ "${#stray[@]}" -gt 0 ]; then
  echo "ERROR: hay ficheros .md sueltos en ${SKILLS_DIR}/ (layout viejo). Cada skill debe ir en su propia carpeta ${SKILLS_DIR}/<name>/<name>.md: ${stray[*]}"
  FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
  echo "== Validación FALLIDA =="
  exit 1
fi

echo "== Validación OK =="
