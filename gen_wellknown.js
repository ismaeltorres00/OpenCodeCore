const fs = require("fs");
const path = require("path");

const BASE_URL = "https://gitlab.grupocdv.com/grupo-cdv/opencode-org-config/-/raw/main";

const sabrePrompt = `Eres un agente especializado en integraciones REST con Sabre para el equipo de backend .NET.
Dominas los flujos de Air Availability, Bargain Finder Max, Price Quote/Revalidation y Booking.
Sigue siempre las convenciones descritas en las skills sabre-rest-pricing, dotnet-backend-standards y airline-error-handling.
Nunca propongas un booking directo sin pasar por revalidación de precio previa.
Al generar o revisar código, respeta la arquitectura por capas del equipo: los clientes Sabre viven solo en Infrastructure, nunca se referencian desde Api o Domain.`;

const amadeusPrompt = `Eres un agente especializado en integraciones REST con Amadeus Self-Service/NDC para el equipo de backend .NET.
Dominas los flujos de Flight Offers Search, Flight Offers Price y Flight Create Orders.
Sigue siempre las convenciones descritas en las skills amadeus-offer-management, dotnet-backend-standards y airline-error-handling.
Nunca propongas crear un order con el offer original del search; siempre debe pasar por Offers Price primero.
Al generar o revisar código, respeta la arquitectura por capas del equipo: los clientes Amadeus viven solo en Infrastructure, nunca se referencian desde Api o Domain.`;

const airgatewayPrompt = `Eres un agente especializado en integraciones REST con AirGateway (agregador multi-GDS) para el equipo de backend .NET.
Entiendes que AirGateway normaliza estructura pero no semántica completa entre proveedores subyacentes.
Sigue siempre las convenciones descritas en las skills airgateway-integration, dotnet-backend-standards y airline-error-handling.
Nunca trates un ancillary como garantizado hasta que el booking lo confirme explícitamente.
Al generar o revisar código, respeta la arquitectura por capas del equipo: el cliente AirGateway vive solo en Infrastructure, con su propio circuit breaker independiente de los clientes directos.`;

// NOTA IMPORTANTE (ver README secciones 0 y 3):
// El endpoint .well-known/opencode es un mecanismo real de OpenCode, pero su
// auto-descubrimiento está atado a autenticarse con un proveedor que lo
// soporte (en la práctica, OpenCode Enterprise + SSO). No hay forma pública
// documentada de registrar esta URL vía `opencode auth login <url>` para un
// repo propio. Por eso este mismo objeto se escribe en DOS sitios:
//   - .well-known/opencode → por si en el futuro se activa Enterprise/SSO.
//   - opencode.json (raíz)  → fichero que cada dev consume YA, hoy, vía la
//     variable de entorno OPENCODE_CONFIG (ver scripts/bootstrap.sh).
// El contenido debe ser idéntico en ambos.
const config = {
  "$schema": "https://opencode.ai/config.json",

  // ---- Modelos por defecto para todo el equipo (override-able en proyecto/global) ----
  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",

  // ---- Solo proveedores autorizados por la organización ----
  "enabled_providers": ["anthropic"],

  // ---- Agente por defecto al abrir OpenCode sin especificar uno ----
  "default_agent": "build",

  // ---- Profundidad de subagentes: evita cadenas descontroladas de coste/tiempo ----
  "subagent_depth": 1,

  // ---- Catálogo de skills, deny-by-default a nivel organización ----
  // Fuente HTTP real de OpenCode: <url>/index.json + <url>/<skill>/<fichero>.
  // Confirmado contra la doc oficial (opencode.ai/v2/docs/skills).
  "skills": [`${BASE_URL}/skills/`],

  // ---- Instrucciones organizacionales, siempre cargadas ----
  "instructions": [`${BASE_URL}/AGENTS.md`],

  // ---- Permisos por defecto a nivel organización ----
  "permission": {
    "edit": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "git push --force*": "ask"
    },
    "webfetch": "ask",
    "external_directory": "ask",
    "skill": {
      "*": "deny"
    }
  },

  // ---- Herramientas disponibles por defecto ----
  "tools": {
    "write": true,
    "edit": true,
    "bash": true
  },

  // ---- MCP servers conocidos por la organización, deshabilitados hasta que
  //      cada proyecto los active explícitamente si los necesita ----
  "mcp": {
    "gitlab": {
      "type": "remote",
      "url": "https://gitlab.grupocdv.com/api/v4/mcp",
      "enabled": false
    }
  },

  // ---- Formatters: activados con los defaults de OpenCode ----
  "formatter": true,

  // ---- LSP: activado con los defaults de OpenCode (incluye omnisharp/csharp si está disponible) ----
  "lsp": true,

  // ---- Compartir sesiones: manual, nunca automático (código propietario) ----
  "share": "manual",

  // ---- Autoupdate silencioso ----
  "autoupdate": true,

  // ---- Compactación de contexto ----
  "compaction": {
    "auto": true,
    "prune": false
  },

  // ---- Directorios ignorados por el watcher en todos los proyectos ----
  "watcher": {
    "ignore": ["node_modules/**", "bin/**", "obj/**", ".git/**", "**/*.Designer.cs"]
  },

  "agent": {
    "sabre-integrator": {
      "description": "Especialista en integraciones REST con Sabre: pricing, disponibilidad, revalidación y booking",
      "prompt": sabrePrompt,
      "mode": "subagent"
    },
    "amadeus-integrator": {
      "description": "Especialista en integraciones REST con Amadeus Self-Service/NDC: offers, pricing y orders",
      "prompt": amadeusPrompt,
      "mode": "subagent"
    },
    "airgateway-integrator": {
      "description": "Especialista en integraciones REST con AirGateway como agregador multi-GDS",
      "prompt": airgatewayPrompt,
      "mode": "subagent"
    }
  }
};

const serialized = JSON.stringify(config, null, 2) + "\n";

const targets = [
  path.join(__dirname, ".well-known", "opencode"),
  path.join(__dirname, "opencode.json")
];

for (const target of targets) {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, serialized);
  console.log("written:", target);
}
