#!/usr/bin/env bash
# Onboarding de un dev al config centralizado de OpenCode.
#
# Por qué existe este script (ver README sección 0/3):
# OpenCode NO ofrece un comando tipo `opencode auth login <url-de-config>`
# para registrar un remote config propio — `auth login` sólo gestiona
# credenciales de proveedor. El auto-descubrimiento real de
# .well-known/opencode está atado a autenticarte con un proveedor que lo
# soporte (en la práctica, OpenCode Enterprise + SSO), algo que este equipo
# no tiene. La vía soportada y documentada para todos es:
#   - opencode.json vía la variable de entorno OPENCODE_CONFIG (capa real
#     del resolver de config, entre global y proyecto). Ese mismo fichero
#     ya declara "skills": ["<url-pages>/skills/"], así que las skills
#     llegan solas por esa vía HTTP — no las copiamos a mano aquí (ver
#     nota más abajo, antes sí lo hacíamos y pisaba la caché de OpenCode).
#   - commands/ copiado a la ruta local que OpenCode descubre
#     (~/.config/opencode/commands) — no hay fuente HTTP para comandos.
#
# Este script clona/actualiza el repo y deja todo eso enlazado. Se puede
# re-ejecutar en cualquier momento (idempotente) para sincronizar cambios.
set -euo pipefail

ORG_CONFIG_REPO="${OPENCODE_ORG_CONFIG_REPO:-https://github.com/ismaeltorres00/OpenCodeCore.git}"
CLONE_DIR="${OPENCODE_ORG_CONFIG_DIR:-$HOME/.opencode-org-config}"
GLOBAL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

echo "== opencode-org-config: bootstrap =="

# 1. Clonar o actualizar el repo de config
if [ -d "$CLONE_DIR/.git" ]; then
  echo "-> Repo ya clonado en $CLONE_DIR, actualizando (git pull --ff-only)"
  git -C "$CLONE_DIR" pull --ff-only
else
  echo "-> Clonando $ORG_CONFIG_REPO en $CLONE_DIR"
  git clone "$ORG_CONFIG_REPO" "$CLONE_DIR"
fi

if [ ! -f "$CLONE_DIR/opencode.json" ]; then
  echo "ERROR: no existe $CLONE_DIR/opencode.json (¿regeneraste con 'node gen_wellknown.js' y lo mergeaste a main?)"
  exit 1
fi

# 2. commands/ -> ~/.config/opencode/commands/
#    (ruta real que OpenCode descubre: .opencode/commands ó ~/.config/opencode/commands)
mkdir -p "$GLOBAL_DIR/commands"
echo "-> Sincronizando commands/ -> $GLOBAL_DIR/commands/"
cp -f "$CLONE_DIR"/commands/*.md "$GLOBAL_DIR/commands/"

# 3. Las skills NO se copian a mano: opencode.json ya declara la fuente HTTP
#    ("skills": ["<url>/skills/"]), y OpenCode gestiona su propia caché en
#    ~/.config/opencode/skills/. Copiar ahí a mano además de eso hacía que
#    ambos mecanismos escribieran en el mismo sitio y se pisaran entre sí.

# 4. OPENCODE_CONFIG -> opencode.json del repo (modelo, permisos, agentes,
#    mcp, instructions, etc. — todo lo que no sean ficheros sueltos).
#    Esta capa se MERGEA con el global y el de proyecto, no los sustituye:
#    las preferencias personales del dev en ~/.config/opencode/opencode.json
#    siguen funcionando igual.
SHELL_RC="${OPENCODE_BOOTSTRAP_RC:-$HOME/.bashrc}"
EXPORT_LINE="export OPENCODE_CONFIG=\"$CLONE_DIR/opencode.json\""

if [ -f "$SHELL_RC" ] && grep -qF "OPENCODE_CONFIG=" "$SHELL_RC" 2>/dev/null; then
  echo "-> $SHELL_RC ya define OPENCODE_CONFIG, no se toca (revisa que apunte a $CLONE_DIR/opencode.json)"
else
  {
    echo ""
    echo "# opencode-org-config: config base del equipo (no editar a mano, se actualiza con git pull)"
    echo "$EXPORT_LINE"
  } >> "$SHELL_RC"
  echo "-> Añadido OPENCODE_CONFIG a $SHELL_RC"
fi

echo ""
echo "== Listo =="
echo "Abre una terminal nueva (o 'source $SHELL_RC') y ejecuta 'opencode' en cualquier proyecto."
echo "Para actualizar en el futuro, vuelve a ejecutar este script."
