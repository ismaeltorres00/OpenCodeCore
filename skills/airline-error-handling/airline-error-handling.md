---
name: airline-error-handling
description: Patrón común del equipo para normalizar errores heterogéneos de Sabre, Amadeus y AirGateway en un único modelo de excepción de dominio. Úsala al diseñar o revisar el manejo de errores de cualquier cliente de integración GDS.
---

# Normalización de errores entre proveedores GDS

## Problema que resuelve

Cada proveedor (Sabre, Amadeus, AirGateway) devuelve errores con estructura, códigos y semántica distintos. Sin normalización, la capa de aplicación termina acoplada a los detalles de cada proveedor, y el frontend/consumidor final recibe mensajes inconsistentes según qué GDS resolvió la operación.

## Modelo de excepción común

Todo cliente de integración (`ISabreClient`, `IAmadeusClient`, `IAirGatewayClient`) debe traducir el error nativo del proveedor a una de estas categorías de dominio antes de propagarlo fuera de `Infrastructure`:

- `PricingExpiredException` — el offer/shop expiró (Sabre TTL, Amadeus offer expirado, AirGateway TTL de caché).
- `InventoryUnavailableException` — pérdida de disponibilidad entre shop y booking.
- `ProviderRateLimitException` — throttling/429 del proveedor, distinto de un fallo real de negocio.
- `ProviderTimeoutException` — timeout de red/latencia, candidato a retry.
- `ProviderValidationException` — el proveedor rechazó el request por datos inválidos (no reintentable sin corregir el payload).
- `ProviderUnknownException` — catch-all para errores no mapeados explícitamente; siempre loguear el payload crudo del proveedor en este caso (con los mismos cuidados de PII que en logging general).

## Regla de oro

Nunca dejar que un código de error nativo del proveedor (`"WPNI"`, `"NO FARE FOR CLASS USED"`, códigos HTTP crudos de AirGateway) llegue sin traducir a la capa `Application` o al consumidor de la API. La traducción vive exclusivamente en el cliente de `Infrastructure` correspondiente.

## Reintentabilidad

Solo `ProviderRateLimitException` y `ProviderTimeoutException` son candidatas a retry automático (vía Polly). `PricingExpiredException` e `InventoryUnavailableException` requieren rehacer el flujo desde shop, nunca un retry directo de la misma operación. `ProviderValidationException` nunca se reintenta sin intervención.

## Mensaje al usuario final vs. log interno

- El mensaje expuesto al consumidor de la API debe ser genérico y accionable ("La tarifa ha caducado, por favor busca de nuevo"), nunca el mensaje crudo del proveedor.
- El log interno sí debe incluir proveedor, código nativo y correlationId para poder diagnosticar sin exponer detalle de implementación externamente.
