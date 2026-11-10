# U8 - Tasks

## Preparación del laboratorio

- [x] Crear `foodstore_u8_lab` en el PostgreSQL de Railway a partir del esquema
      Food Store, sin tocar `railway` ni `foodstore`.
- [x] Cargar datos inventados y dos productos de feria.
- [x] Crear `v_snapshot_movil` con columnas mínimas y fecha de copia.
- [x] Exportar `servidor_snapshot.csv` y snapshots de C2, C3 y C4.

## Consigna 1 - Base de la tablet

- [x] Escribir `schema_sqlite.sql` con `PRAGMA foreign_keys = ON` y cuatro
      tablas `STRICT`.
- [x] Definir PK, FK, CHECK de estado, precio, stock y cantidad.
- [x] Probar borrador completo con COMMIT y otro con ROLLBACK.
- [x] Probar C1 (catálogo offline) y C7 (cantidad 0 / producto inexistente).

## Consigna 2 - Sincronización y semáforo

- [x] Importar el CSV en `snapshot_servidor`.
- [x] Cargar `producto_cache` con normalización de booleanos `t/f`.
- [x] Implementar el semáforo con prioridad rojo > amarillo > verde.
- [x] Ejecutar C2, C3, C4, C5 y C6.
- [x] Comprobar que pedidos, detalles y stock de PostgreSQL no cambian por la
      simulación.

## Consigna 3 - Integración y revisión

- [x] Armar el mapa PostgreSQL + MongoDB + SQLite.
- [x] Agregar el plan de mantenimiento y recuperación.
- [x] Ejecutar el code review de scripts de la cursada con OpenCode (Plan).
- [x] Registrar hallazgos aceptados, corregidos y descartados.

## Consigna 4 - Kiro, bitácora y defensa

- [x] Escribir `requirements.md` (EARS), `design.md` y este `tasks.md`.
- [x] Registrar tres entradas de IA y la DUIA.
- [x] Escribir el README de reproducción y el guion de defensa.
- [x] Generar el PDF de entrega y el ZIP del paquete.
- [x] Cerrar la base de laboratorio (`foodstore_u8_lab`) y documentar el estado
      del servicio PostgreSQL que aloja la fuente `railway`.
