# Instrucciones del equipo — Backend .NET / Integraciones aéreas

Estas instrucciones se cargan siempre, en todos los proyectos, vía la clave `instructions` del remote config. No las dupliques en el `AGENTS.md` de cada proyecto — ese fichero es solo para lo específico de ese repo.

## Contexto del equipo

Equipo de 10 desarrolladores .NET/C# construyendo servicios backend que integran con GDS/NDC (Sabre, Amadeus, AirGateway) vía REST. El código va a producción con tráfico real de reservas — la corrección y el manejo de errores importan más que la velocidad de entrega.

## Reglas no negociables

- Nunca generes código que haga booking/confirmación sin revalidación de precio previa (ver skill `sabre-rest-pricing` / `amadeus-offer-management`).
- Nunca captures excepciones de forma silenciosa (`catch { }` vacío).
- Nunca uses `.Result` o `.Wait()` sobre tareas async — usa `async`/`await` end-to-end.
- Nunca loguees payloads completos de pricing/booking (riesgo de PII de pasajeros); loguea proveedor, operación, latencia y `correlationId`.
- Nunca propongas un retry automático sobre errores de negocio (`PricingExpiredException`, `InventoryUnavailableException`) — solo sobre `ProviderRateLimitException`/`ProviderTimeoutException`.

## Cómo trabajar en este equipo

- Arquitectura por capas: `Api` → `Application` → `Domain` → `Infrastructure`. Los clientes GDS viven solo en `Infrastructure`.
- Antes de escribir un cliente/endpoint nuevo, consulta la skill del proveedor correspondiente (`sabre-rest-pricing`, `amadeus-offer-management`, `airgateway-integration`) y `dotnet-backend-standards`.
- Si el proyecto en el que trabajas no tiene activada la skill de un proveedor que sí necesitas, indícalo explícitamente en vez de improvisar sin esa guía — probablemente falta en la allow-list de `.opencode/opencode.json` de ese proyecto.

## Referencia rápida de errores normalizados

Usa siempre las categorías de `airline-error-handling` (`PricingExpiredException`, `InventoryUnavailableException`, `ProviderRateLimitException`, `ProviderTimeoutException`, `ProviderValidationException`, `ProviderUnknownException`) en vez de propagar códigos nativos del proveedor fuera de `Infrastructure`.
