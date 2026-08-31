# opencode-org-config

Repositorio central de configuración de OpenCode para el equipo de backend .NET (integraciones Sabre / Amadeus / AirGateway). No es solo un catálogo de skills — centraliza modelo por defecto, permisos, agentes, MCP servers, instrucciones, comandos, formatters, LSP y más.

Fuente única de verdad. Los proyectos individuales solo sobreescriben lo puntual (allow-lists, MCP que necesiten, instrucciones propias) — no redefinen nada desde cero.

> **Estado actual: desplegado en GitHub Pages para probar.**
> Repo: [`ismaeltorres00/OpenCodeCore`](https://github.com/ismaeltorres00/OpenCodeCore) · Pages: `https://ismaeltorres00.github.io/OpenCodeCore/`
> Cuando esto pase a ser el config real del equipo (GitLab u otro sitio), solo hace falta cambiar `BASE_URL` en `gen_wellknown.js` y `ORG_CONFIG_REPO` en `scripts/bootstrap.sh`, regenerar (`node gen_wellknown.js`) y hacer push — nada más en el repo depende de dónde esté alojado. Ver sección 1.5 para lo específico de GitHub Pages (obligatorio: `.nojekyll`).

## 0. Cómo funciona la jerarquía (importante entenderlo antes de tocar nada)

OpenCode carga config en este orden, cada capa puede sobreescribir claves de la anterior (se **mergea**, no se reemplaza el fichero entero):

1. **Remote config** (`.well-known/opencode`) → defaults de organización, pero con una condición importante (ver aviso abajo)
2. **Global** (`~/.config/opencode/opencode.json`) → preferencias personales del dev
3. **Custom** (`OPENCODE_CONFIG` env var) → **esta es la capa que usamos nosotros** para distribuir este repo, ver sección 3
4. **Project** (`opencode.json` en la raíz del proyecto) → lo que definimos por repo
5. **`.opencode/` del proyecto** (agents, commands, plugins locales)
6. **Managed settings** (admin-only, no aplica a nuestro caso por ahora)

⚠️ **Aviso importante sobre la capa 1 (remote config):** el endpoint `.well-known/opencode` es un mecanismo real de OpenCode, pero su auto-descubrimiento está documentado como "fetched automatically when you authenticate with a provider that supports it" — en la práctica, esto es una feature de **OpenCode Enterprise + SSO**, no algo que un repo Git propio pueda activar. **No existe** un comando tipo `opencode auth login <url-de-config>` para registrar una URL de config arbitraria: `opencode auth login` gestiona únicamente credenciales de proveedor (`--provider`/`--method`). Por eso este repo sigue publicando `.well-known/opencode` (por si en el futuro contratamos Enterprise y se puede asociar por SSO), pero **la distribución real hoy usa la capa 3 (`OPENCODE_CONFIG`)**, vía `scripts/bootstrap.sh` — ver sección 3.

Esto significa: si el config de org (capa 3) deniega una skill y el proyecto la permite explícitamente, gana el proyecto (capa 4, por encima). Ese es el mecanismo que usamos para el control de acceso por proyecto.

## 1. Antes de nada: sustituir la URL base

Todos los ficheros de este repo referencian una sola constante (hoy, la URL de GitHub Pages de este test):

```
https://ismaeltorres00.github.io/OpenCodeCore
```

Si el sitio de alojamiento cambia (por ejemplo al pasar esto al GitLab del equipo), actualizar esa constante en `gen_wellknown.js` (`BASE_URL`, regenera `.well-known/opencode` y `opencode.json`) y en `scripts/bootstrap.sh` (`ORG_CONFIG_REPO`, que es la URL de **clone** del repo, no la de Pages — son cosas distintas, ver 1.5).

## 1.5. Específico de GitHub Pages (leer si estás probando esto en Pages)

GitHub Pages sirve el contenido del repo tal cual **excepto** que por defecto lo pasa por Jekyll antes, y Jekyll:

- **ignora cualquier fichero/carpeta que empiece por `.`** — así que `.well-known/opencode` no se publicaría nunca.
- **procesa los `.md` con frontmatter YAML** (justo el formato de las skills) como si fueran páginas del site, intentando convertirlos a HTML en vez de servir el markdown tal cual — rompería lo que OpenCode espera descargar.

Por eso el repo incluye un fichero **`.nojekyll`** vacío en la raíz — le dice a GitHub Pages que sirva todo como ficheros estáticos, sin pasar por Jekyll. Sin él, nada de esto funciona en Pages. `.github/workflows/validate.yml` falla el build si `.nojekyll` desaparece.

Pasos para activar Pages en el repo (una sola vez, vía web, no automatizable sin `gh` autenticado):

1. `github.com/ismaeltorres00/OpenCodeCore` → **Settings** → **Pages**.
2. **Build and deployment → Source**: `Deploy from a branch`.
3. **Branch**: `main`, carpeta `/ (root)` → **Save**.
4. Espera 1-2 min al primer deploy (pestaña **Actions** del repo muestra el job `pages build and deployment`).

Nota: `opencode auth login` **no interviene aquí para nada** — esto es solo alojamiento HTTP estático, no un mecanismo de config de OpenCode. Cómo llega la config a cada dev está explicado en la sección 3.

## 2. Verificar que el endpoint sirve correctamente

Esto solo es necesario si quieres aprovechar el catálogo de skills vía HTTP (sección 6) además del bootstrap local. `opencode.json` y `.well-known/opencode` no necesitan servirse por HTTP para que el bootstrap funcione — se leen del clon local.

```bash
curl -I https://ismaeltorres00.github.io/OpenCodeCore/skills/index.json
curl -s  https://ismaeltorres00.github.io/OpenCodeCore/skills/index.json | jq .
curl -s  https://ismaeltorres00.github.io/OpenCodeCore/.well-known/opencode | jq .
```

Debe devolver `200` y JSON parseable. Si tarda en devolver `200` justo después de activar Pages, espera al primer deploy (sección 1.5). Si el repo es privado, ver sección 9.

## 3. Onboarding de un dev (una sola vez)

```bash
curl -s https://ismaeltorres00.github.io/OpenCodeCore/scripts/bootstrap.sh | bash
```

(O clona el repo y ejecuta `scripts/bootstrap.sh` directamente si prefieres revisar el script antes de correrlo — recomendado la primera vez.)

Esto hace, de forma idempotente:

1. Clona (o actualiza con `git pull`) este repo en `~/.opencode-org-config`.
2. Copia `commands/*.md` a `~/.config/opencode/commands/` — ruta real que OpenCode descubre automáticamente.
3. Copia cada `skills/<name>/` a `~/.config/opencode/skills/<name>/` — mismo layout que exige el mecanismo de fuente HTTP de OpenCode, así que sirve tanto si luego activas el catálogo remoto (sección 6) como si no.
4. Añade `export OPENCODE_CONFIG="$HOME/.opencode-org-config/opencode.json"` al `.bashrc` del dev.

A partir de aquí, cada arranque de OpenCode resuelve automáticamente modelo, permisos, agentes, MCP, instrucciones, etc. definidos en `opencode.json`. **`OPENCODE_CONFIG` se mergea con el global, no lo sustituye** — las preferencias personales de cada dev en `~/.config/opencode/opencode.json` siguen intactas.

**Actualizar = volver a ejecutar `scripts/bootstrap.sh`** (o simplemente `git -C ~/.opencode-org-config pull`, que ya cubre el `opencode.json`; para refrescar `commands/`/`skills/` copiados hace falta re-ejecutar el script completo). No hay push automático a los devs — cada uno sincroniza cuando quiere, o el equipo puede cronearlo.

## 4. Qué centraliza exactamente `opencode.json`

| Sección | Qué hace | Dónde se puede overridear |
|---|---|---|
| `model` / `small_model` | Modelo por defecto del equipo (`claude-sonnet-4-5` / `claude-haiku-4-5`) | Proyecto, si un caso concreto lo necesita |
| `enabled_providers` | Solo Anthropic autorizado — evita que alguien cargue credenciales de otro proveedor por error | No pensado para overridear sin aprobación |
| `default_agent` / `subagent_depth` | Agente por defecto (`build`) y profundidad máx. de subagentes (evita cadenas descontroladas de coste) | Proyecto |
| `skills` | Catálogo HTTP (ver sección 6) — opcional, complementa las skills ya copiadas localmente por el bootstrap | — |
| `instructions` | `AGENTS.md` de este repo, cargado siempre | Proyecto puede añadir instrucciones propias (se suman, no sustituyen) |
| `permission` | Ver sección 5 | Proyecto |
| `tools` | `write`/`edit`/`bash` activados por defecto | Proyecto (ej. deshabilitar `write` en repos de solo análisis) |
| `mcp` | Servidores MCP conocidos por la org (ej. GitLab), **deshabilitados por defecto** | Proyecto activa los que necesite |
| `formatter` / `lsp` | Activados con los defaults de OpenCode | Proyecto puede afinar por lenguaje |
| `share` | `manual` — nunca compartir sesiones automáticamente (código propietario) | No se recomienda overridear a `auto` |
| `autoupdate` | Activado | — |
| `compaction` / `watcher` | Compactación automática de contexto; watcher ignora `bin/`, `obj/`, `node_modules/` | Proyecto puede añadir patrones propios |

Este fichero se genera con `node gen_wellknown.js` (editar ahí, no `opencode.json`/`.well-known/opencode` a mano) y escribe **el mismo contenido en los dos sitios**: `opencode.json` (lo que consume `OPENCODE_CONFIG`, capa activa hoy) y `.well-known/opencode` (para el día que se active Enterprise/SSO). El CI falla si ambos ficheros divergen.

## 5. Modelo de permisos completo

No es solo skills. `permission` en `opencode.json` cubre:

```jsonc
{
  "permission": {
    "edit": "allow",                    // el agente puede modificar ficheros sin preguntar
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",               // bloqueado a nivel organización, no overrideable en la práctica
      "git push --force*": "ask"        // pide confirmación explícita
    },
    "webfetch": "ask",                  // el agente pregunta antes de hacer fetch a URLs externas
    "external_directory": "ask",        // pregunta antes de leer/editar fuera del proyecto actual
    "skill": { "*": "deny" }            // deny-by-default, cada proyecto habilita lo suyo
  }
}
```

Las reglas de `bash` se evalúan en orden y **gana la última que matchea** — por eso el catch-all `*` va primero y las excepciones específicas (`rm -rf *`, `git push --force*`) después.

Cada proyecto puede añadir reglas más finas en su `opencode.json` (ver plantilla), pero las reglas explícitas de `bash` a nivel org (`rm -rf *`, force push) están pensadas como guardarraíl duro del equipo — no las relajéis por proyecto sin hablarlo antes.

## 6. Catálogo de skills (formato HTTP source real de OpenCode)

```
skills/
├── index.json                              ← lista name + version + files de cada skill
├── dotnet-backend-standards/
│   └── dotnet-backend-standards.md
├── sabre-rest-pricing/
│   └── sabre-rest-pricing.md
├── amadeus-offer-management/
│   └── amadeus-offer-management.md
├── airgateway-integration/
│   └── airgateway-integration.md
└── airline-error-handling/
    └── airline-error-handling.md
```

**Cada skill vive en su propia carpeta** — no es un capricho de estilo: el fetch HTTP real de OpenCode pide los ficheros en `<base-url>/<skill-name>/<fichero>`, así que un `.md` suelto directamente bajo `skills/` no se resolvería. `scripts/validate-skills.sh` falla en CI si aparece un `.md` suelto (layout viejo).

`index.json` sigue el formato exacto que exige OpenCode para fuentes HTTP:

```json
{ "skills": [ { "name": "sabre-rest-pricing", "version": "1", "files": ["sabre-rest-pricing.md"] } ] }
```

Al modificar un skill, **incrementa su `version`** — es la señal que le dice a OpenCode que refresque la copia cacheada en cada dev que use la fuente HTTP (`"skills": ["<url>/skills/"]` en `opencode.json`, ya incluido).

Nota: `scripts/bootstrap.sh` **ya copia** `skills/<name>/` a `~/.config/opencode/skills/<name>/` como parte del onboarding, así que las skills funcionan aunque nunca se resuelva el problema de exponer el repo por HTTP sin auth (sección 9). El catálogo HTTP (`"skills"` en `opencode.json`) es un plus — evita tener que re-ejecutar el bootstrap para ver una skill actualizada — pero no es la única vía.

## 7. Agentes especializados

Tres agentes tipo `subagent` (invocables desde el agente principal, no como modo por defecto): `sabre-integrator`, `amadeus-integrator`, `airgateway-integrator`. Cada uno trae su propio system prompt orientado a su proveedor y referencia las skills correspondientes. Definidos en la clave `agent` de `opencode.json` — llegan a cada dev vía `OPENCODE_CONFIG`, no hace falta ningún paso adicional.

Se activan/desactivan por proyecto en la allow-list (`"agent": { "sabre-integrator": "enabled" }`).

## 8. Comandos custom compartidos

```
commands/
├── new-endpoint.md        → /new-endpoint <descripción>: crea un endpoint siguiendo la arquitectura por capas
└── review-integration.md  → /review-integration: revisa el diff actual contra los estándares de resiliencia/errores del equipo
```

(Nombre real que OpenCode descubre: **`commands/`**, en plural — tanto en `.opencode/commands/` de un proyecto como en `~/.config/opencode/commands/` global. No confundir con la carpeta de este repo antes de la corrección, que se llamaba `command/` en singular y no era resuelta por OpenCode.)

No hay mecanismo de fuente HTTP para comandos (solo las skills lo soportan). `scripts/bootstrap.sh` copia `commands/*.md` a `~/.config/opencode/commands/` como parte del onboarding — cada dev los recibe automáticamente al ejecutar el script, sin pasos manuales.

## 9. Si el repo debe ser privado

GitHub Pages solo sirve repos **privados** con plan GitHub Pro, Team o Enterprise Cloud — en plan gratuito, Pages exige que el repo sea público. Esto solo afecta al catálogo de skills por HTTP y a `curl`/CI accediendo a los ficheros sin auth (sección 2/6). **No bloquea el onboarding** (sección 3), que puede seguir usando `git clone`/`git pull` autenticado normal contra un repo privado aunque Pages no esté activo.

Opciones si el contenido no puede ser público:
1. Repo privado + plan que soporte Pages privado.
2. Repo de config separado, público-interno, distinto de cualquier repo de código real (los `.md` de este repo son estándares/prompts, no secretos — normalmente asumible).
3. Sin Pages en absoluto: el bootstrap sigue funcionando igual (usa `git clone` autenticado), simplemente sin el catálogo HTTP de skills — pierdes el refresco sin re-ejecutar el script, no la funcionalidad.

(Si esto vuelve a vivir en GitLab del equipo en vez de GitHub Pages, la vía allí es un deploy token de solo lectura a nivel de proyecto — ver historial del repo antes de este cambio.)

## 10. Contribuir un skill, agente o comando nuevo

1. Skill nuevo: `skills/<nombre>/<nombre>.md` (frontmatter `name`+`description`, mínimo 20 caracteres, `name` en minúsculas/guiones, coincide con el fichero y con el nombre de la carpeta) + entrada en `skills/index.json`.
2. Agente nuevo: añadir bloque en `agent` dentro de `gen_wellknown.js` y regenerar (`node gen_wellknown.js`, escribe `.well-known/opencode` y `opencode.json`).
3. Comando nuevo: `commands/<nombre>.md` con frontmatter `description`/`agent`/`model`.
4. Abrir MR — CODEOWNERS exige revisión del owner del dominio correspondiente.
5. Al mergear a `main`, el pipeline valida JSON, que `opencode.json` y `.well-known/opencode` coincidan, consistencia índice↔ficheros y que no reaparezca el layout viejo (`.gitlab-ci.yml`).
6. Los devs reciben el cambio la próxima vez que ejecuten `scripts/bootstrap.sh` (o `git pull` en `~/.opencode-org-config` para lo que va vía `OPENCODE_CONFIG`).

## 11. Estructura completa del repo

```
.nojekyll                     → obligatorio para GitHub Pages: sirve todo como estático, sin pasar por Jekyll (ver 1.5)
.well-known/opencode          → mismo contenido que opencode.json, para un futuro Enterprise/SSO (ver aviso sección 0)
opencode.json                 → config real que cada dev carga hoy vía OPENCODE_CONFIG: modelo, permisos, agentes, MCP, instructions, tools, etc.
AGENTS.md                     → instrucciones organizacionales, cargadas siempre vía "instructions"
skills/                       → catálogo de skills, una carpeta por skill (index.json + <name>/<name>.md)
commands/                     → comandos custom compartidos (nombre real que descubre OpenCode, plural)
templates/                    → plantilla completa de opencode.json por proyecto, con todos los overrides posibles
gen_wellknown.js              → genera opencode.json y .well-known/opencode (editar aquí, no los JSON a mano)
scripts/bootstrap.sh          → onboarding/actualización de un dev (clona, sincroniza commands/skills, configura OPENCODE_CONFIG)
scripts/validate-skills.sh    → validación ejecutada en CI
CODEOWNERS                    → revisión obligatoria por dominio
.gitlab-ci.yml                → valida lo mismo que .github/workflows/validate.yml, para cuando esto viva en GitLab
.github/workflows/validate.yml → CI en GitHub Actions: JSON válido, índice↔ficheros, estructura y presencia de .nojekyll
```
