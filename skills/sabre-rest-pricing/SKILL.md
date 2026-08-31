---
name: sabre-rest-pricing
description: Guía para implementar y depurar integraciones con las APIs REST de pricing de Sabre (Bargain Finder Max, Price Quote, Air Availability). Úsala cuando el trabajo involucre llamadas a Sabre para tarifas, disponibilidad o revalidación de precio.
---

# Sabre REST — Pricing

## Flujo estándar

1. **Air Availability / Shop** (`/v*/shop/flights`) — búsqueda inicial de opciones.
2. **Bargain Finder Max (BFM)** (`/v*/offers/shop`) — shopping con tarifas negociadas/publicadas combinadas.
3. **Price Quote / Revalidation** (`/v*/price/quote` o vía `AirPriceRQ` en versiones SOAP-wrapped) — antes de confirmar cualquier booking, siempre revalidar el precio devuelto por el shop; el precio de shopping tiene TTL corto y puede haber cambiado.

## Modelo de datos — mapeo a nuestro dominio

- El `TotalFare` de Sabre no incluye siempre todos los ancillaries — separar explícitamente `BaseFare`, `Taxes`, `Q-surcharges` y `Ancillary` al mapear a nuestro `PricingResult` interno; no asumir que `TotalFare` es el monto final a cobrar sin sumar ancillaries seleccionados.
- Los `FareBasisCode` y `RuleNumber` deben persistirse aunque no se usen inmediatamente — son necesarios para reglas de cambio/reembolso posteriores y Sabre no los re-expone fácilmente después del booking.
- Mapear `PassengerTypeCode` (ADT/CNN/INF) de Sabre al enum interno de traveller type explícitamente; no asumir 1:1 con nomenclatura IATA estándar en todos los mercados.

## Errores comunes y su causa real

| Código/síntoma Sabre | Causa habitual | Acción |
|---|---|---|
| `Unable to price` en Price Quote tras un shop exitoso | El TTL del shop expiró (~15-20 min) o el inventario cambió | Re-ejecutar shop, no reintentar price quote con el mismo token |
| Precio distinto entre shop y price quote | Comportamiento esperado por fluctuación de tarifa, no un bug | Siempre mostrar el precio de la revalidación al usuario final, no el de shop |
| `Segment sell failure` en booking tras price quote OK | Overbooking en el intervalo entre price quote y booking | Implementar reintento con nuevo shop+price quote, no reintentar el booking directo |

## Resiliencia específica de Sabre

- Rate limiting de Sabre es agresivo en BFM — implementar cola/throttling del lado cliente antes de depender solo del retry de Polly; un 429 repetido puede escalar a bloqueo temporal de credenciales.
- El token de sesión (`Authorization: Bearer`) tiene expiración corta — renovar proactivamente antes de que expire dentro de una transacción multi-step (shop → price → book), no esperar al 401 a mitad de flujo.

## Testing

- Sabre expone un entorno de certificación (CERT) con PNRs de prueba fijos — usar esos, no generar bookings aleatorios contra CERT sin limpieza posterior (Sabre limita bookings activos en CERT).
