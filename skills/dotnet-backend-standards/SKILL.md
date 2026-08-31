---
name: dotnet-backend-standards
description: Convenciones de arquitectura y estilo del equipo para servicios backend en .NET/C#. Úsala siempre que se cree o modifique un endpoint, servicio, repositorio o clase en cualquier proyecto .NET del equipo, para mantener consistencia entre proyectos e integrantes.
---

# Estándares Backend .NET del equipo

## Arquitectura

- Estructura por capas: `Api` (controllers/endpoints) → `Application` (casos de uso, DTOs, validación) → `Domain` (entidades, reglas de negocio puras, sin dependencias externas) → `Infrastructure` (clientes HTTP a GDS, persistencia, mensajería).
- Los clientes de integraciones externas (Sabre, Amadeus, AirGateway) viven exclusivamente en `Infrastructure`, nunca se referencian directamente desde `Api` o `Domain`.
- Un servicio de aplicación no debe conocer el proveedor GDS concreto: se comunica contra una interfaz (`ISabreClient`, `IAmadeusClient`) inyectada por DI, nunca instanciada directamente.

## Convenciones de código

- `async`/`await` en toda operación de I/O (HTTP, DB, colas). Nunca `.Result` o `.Wait()` — bloquean el thread pool y en integraciones GDS con latencias de 1-3s esto degrada el throughput rápidamente.
- `CancellationToken` propagado en toda la cadena de llamadas async que involucre HTTP externo.
- DTOs de request/response específicos por endpoint — no reutilizar el modelo de dominio como contrato de API.
- Records (`record`) para DTOs inmutables; clases normales solo para entidades con estado mutable real.
- Nulabilidad de referencia (`<Nullable>enable</Nullable>`) activada en todos los proyectos nuevos.

## Manejo de errores

- Excepciones custom por capa (`SabreIntegrationException`, `PricingValidationException`), nunca `Exception` genérica.
- Ningún catch silencioso (`catch { }` vacío) — si se captura, se loguea con contexto (correlationId, proveedor, endpoint llamado) o se re-lanza.
- Middleware global de excepciones en `Api` que traduce excepciones de dominio/infraestructura a respuestas HTTP consistentes (ProblemDetails, RFC 7807).

## Resiliencia en llamadas a GDS

- `Polly` para retry con backoff exponencial + circuit breaker en todo cliente HTTP hacia Sabre/Amadeus/AirGateway. Nunca retry sin backoff en pricing (puede duplicar holds).
- Timeout explícito por llamada, nunca el default del `HttpClient`. Referencia: pricing 10-15s, disponibilidad 5-8s, booking 20-30s.
- `IHttpClientFactory` con `HttpClient` tipado por proveedor (`AddHttpClient<ISabreClient, SabreClient>()`), nunca `new HttpClient()` directo.

## Testing

- Unit tests sobre `Application`/`Domain` con mocks de las interfaces de cliente GDS — nunca contra el proveedor real.
- Tests de integración contra los sandbox/test environments oficiales de cada proveedor, separados en un proyecto de test distinto y no ejecutados en cada build de CI (solo en pipeline nightly o manual).

## Logging y observabilidad

- Structured logging (Serilog) con `correlationId` propagado desde el request de entrada hasta cada llamada saliente a GDS.
- Loguear siempre: proveedor, operación, latencia, código de resultado. Nunca loguear payloads completos de pricing/booking (pueden contener PII de pasajeros).
