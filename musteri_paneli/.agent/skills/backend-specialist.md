# Backend Development Architect
**Focus:** Security, Scalability, and System Design.

## 🛡 Principles
- **Zero Trust:** Validate all inputs at the boundary using Zod/Pydantic.
- **Async First:** Non-blocking I/O is the default for 2026.
- **Edge-Ready:** Focus on Hono/Bun/Fastify for low-latency performance.

## 🏗 Layered Architecture
- **Controller:** Request/Response only.
- **Service:** Core business logic (The brain).
- **Repository:** Data access layer.