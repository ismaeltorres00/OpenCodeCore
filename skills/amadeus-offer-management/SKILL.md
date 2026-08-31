---
name: amadeus-offer-management
description: Guía para integrar el flujo de ofertas de Amadeus Self-Service/NDC (Flight Offers Search, Flight Offers Price, Booking) en servicios .NET. Úsala cuando el trabajo involucre pricing, ancillaries o creación de orders en Amadeus.
---

# Amadeus — Offer Management (NDC / Self-Service)

## Flujo estándar

1. **Flight Offers Search** (`/v2/shopping/flight-offers`) — genera `FlightOffer` con TTL corto (definido en el propio offer, campo implícito de expiración de sesión, normalmente minutos).
2. **Flight Offers Price** (`/v1/shopping/flight-offers/pricing`) — SIEMPRE revalidar el offer completo (no solo el precio) antes de crear el order; Amadeus puede devolver un offer distinto (ej. cambio de cabina disponible) que hay que propagar al usuario, no descartar.
3. **Flight Create Orders** (`/v2/booking/flight-orders`) — requiere el offer ya repriced, no el offer original del search.

## Modelo de datos — puntos de fricción reales

- Un `FlightOffer` de Amadeus puede contener múltiples `pricingOptions.fareType` — no asumir que el primero es el aplicable; filtrar explícitamente por el `fareType` contratado en el acuerdo comercial antes de mostrarlo.
- Los `travelerPricings` vienen indexados por `travelerId`, que debe mapearse 1:1 y de forma estable con vuestros `travellers` internos durante todo el flujo search → price → order; un desalineamiento aquí es la causa más común de bookings con el pasajero equivocado en el asiento equivocado.
- Los ancillaries (`services` en Offers Price response) no siempre vienen en el search inicial — hay que hacer un segundo request de Offers Price con `include=bags,other-services` para obtenerlos; no está en el offer base.

## Errores comunes y su causa real

| Código/síntoma Amadeus | Causa habitual | Acción |
|---|---|---|
| `NO FARE FOR CLASS USED` en Offers Price | El offer expiró o la clase de reserva ya no tiene inventario | Nuevo search, no reintentar pricing sobre el mismo offer |
| `INVALID DATA RECEIVED` en Create Orders | El offer enviado no es el que devolvió Offers Price (se envió el original del search) | Verificar que el pipeline propaga el offer repriced completo, no el offer inicial |
| Diferencia de precio entre Price y Create Orders | Amadeus permite una segunda validación en creación de order | Mostrar warning solo si la diferencia supera el umbral de tolerancia configurado, no bloquear silenciosamente |

## Resiliencia específica de Amadeus

- El token OAuth2 de Amadeus (`/v1/security/oauth2/token`) dura ~30 min — cachear y renovar antes de expiración, no por cada request; Amadeus penaliza el volumen de solicitudes de token.
- Amadeus Self-Service tiene cuotas mensuales por endpoint en producción — monitorizar consumo por proveedor separadamente de AirGateway/Sabre para no agotar cuota de un producto por errores en otro.

## Testing

- El entorno de test de Amadeus devuelve datos ficticios pero con la misma estructura que producción — no hardcodear asunciones de campos "siempre presentes" basadas solo en el test data, algunos campos opcionales sí aparecen en producción y no en test.
