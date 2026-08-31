---
description: Revisa el código de integración GDS del diff actual contra los estándares del equipo
agent: build
model: anthropic/claude-sonnet-4-5
---

Revisa los cambios actuales (`git diff`) centrándote específicamente en:

1. **Resiliencia**: ¿hay retry/circuit breaker (Polly) en toda llamada HTTP a Sabre/Amadeus/AirGateway? ¿el timeout es explícito y no el default del `HttpClient`?
2. **Manejo de errores**: ¿se traduce el error nativo del proveedor a las excepciones de dominio de `airline-error-handling` antes de salir de `Infrastructure`? ¿algún `catch` silencioso?
3. **Revalidación de precio**: si hay un flujo de booking, ¿pasa por price quote/offers price revalidado antes de confirmar, o usa directamente el resultado del shop/search inicial?
4. **PII/logging**: ¿se loguean payloads completos de pricing/booking en vez de solo proveedor+operación+latencia+correlationId?
5. **Async**: ¿algún `.Result`/`.Wait()` sobre código async?

Da el feedback como lista priorizada (bloqueante / recomendado / nit), no como prosa larga.
