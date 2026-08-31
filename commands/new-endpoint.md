---
description: Crea un endpoint nuevo siguiendo la arquitectura por capas del equipo (Api/Application/Domain/Infrastructure)
agent: build
---

Crea un endpoint nuevo para: $ARGUMENTS

Sigue estrictamente `dotnet-backend-standards`:
- DTO de request/response específico del endpoint, no reutilices el modelo de dominio.
- Controller delgado — solo mapea request → caso de uso de `Application` → response.
- Si el endpoint llama a un proveedor GDS, la llamada va detrás de una interfaz (`ISabreClient`/`IAmadeusClient`/`IAirGatewayClient`), nunca instanciada directamente en el controller.
- Añade el middleware de excepciones si el proyecto no lo tiene ya, para traducir excepciones de dominio a `ProblemDetails`.
- Genera también el test unitario del caso de uso con el cliente GDS mockeado.

Antes de escribir código, confirma qué proveedor(es) están en la allow-list de `.opencode/opencode.json` de este proyecto y usa esa skill como referencia.
