---
name: airgateway-integration
description: Guía para integrar servicios REST de AirGateway (agregador multi-GDS) en servicios .NET, incluyendo normalización de respuestas heterogéneas entre proveedores subyacentes. Úsala cuando el trabajo involucre AirGateway como capa de abstracción sobre Sabre/Amadeus/otros.
---

# AirGateway — Integración REST

## Naturaleza del proveedor

AirGateway actúa como agregador sobre múltiples GDS/NDC subyacentes — su respuesta normaliza estructura, pero **no homogeniza completamente semántica**. Un mismo campo puede tener significado ligeramente distinto según el proveedor de origen real detrás de la oferta.

## Puntos críticos de mapeo

- El campo `source` (o equivalente que identifique el GDS de origen) en cada oferta debe persistirse en nuestro `PricingResult` interno — es necesario para saber qué reglas de cambio/reembolso/reglas tarifarias aplican realmente, ya que difieren por proveedor subyacente aunque AirGateway las presente en formato uniforme.
- No asumir que todos los ancillaries están disponibles para todas las ofertas por igual — la disponibilidad de ancillaries depende del proveedor subyacente, y AirGateway a veces devuelve el ancillary como "disponible" a nivel de búsqueda pero falla al confirmarlo en booking si el proveedor origen no lo soporta para esa tarifa concreta.
- El TTL de las ofertas de AirGateway puede ser más corto que el TTL nativo del proveedor subyacente (AirGateway aplica su propio TTL de caché) — no confiar en los tiempos de expiración documentados de Sabre/Amadeus individualmente cuando se pasa por AirGateway.

## Errores comunes y su causa real

| Síntoma | Causa habitual | Acción |
|---|---|---|
| Booking falla en AirGateway aunque el pricing fue exitoso | El proveedor subyacente perdió inventario en el intervalo, AirGateway no siempre lo detecta hasta el intento de booking | Reintentar con nuevo pricing, nunca reintentar el booking directo con la misma oferta |
| Ancillary confirmado en pricing mostrar error en booking | Ancillary soportado por AirGateway a nivel de catálogo pero no por el GDS origen para esa tarifa específica | Tratar ancillaries como "solicitados", nunca como "garantizados" hasta confirmación de booking |
| Latencia inconsistente entre requests idénticos | AirGateway enruta a distintos proveedores según disponibilidad/comercial en cada shop | Timeout generoso (config específica, no reutilizar el de Sabre/Amadeus directo) y no asumir latencia constante |

## Resiliencia

- Circuit breaker independiente del que se usa para Sabre/Amadeus directos — un fallo en AirGateway no debe compartir el mismo breaker que las integraciones directas, porque son sistemas independientes con SLAs distintos.
- Loguear siempre el `source`/proveedor subyacente devuelto junto con cualquier error, para poder diferenciar si el fallo es de AirGateway o del GDS detrás.

## Testing

- Validar contra al menos dos proveedores subyacentes distintos en sandbox (si AirGateway lo permite seleccionar), no solo contra el proveedor por defecto del entorno de test — el comportamiento real en producción varía según qué GDS resuelve cada búsqueda.
