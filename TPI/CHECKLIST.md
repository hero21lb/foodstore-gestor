# Checklist TPI - Segunda entrega (U4 a U8)

Cada objetivo de las condiciones del campus tiene que quedar demostrado con un
archivo o una salida concreta. Esta tabla es el mapa de verificación.

## U4 - Normalización avanzada y redundancia

| Objetivo | Evidencia | Estado |
|---|---|---|
| Refactorización a FNBC con dependencias reales | `food-store-tp-u4/sql/tp_fnbc_control_lote.sql`, `food-store-tp-u4/specs/requirements.md` | Cumplido |
| Migración sin pérdida en transacción reversible | Bloque `BEGIN/COMMIT`, `DO` de validación, vista `vw_control_lote_almacen`; `EXCEPT ALL` = 0 | Cumplido |
| Plan de reversión | `food-store-tp-u4/sql/tp_desnormalizacion_top_categorias.sql` (DROP INDEX/TRIGGER/COLUMN) y `specs/design.md` | Cumplido |
| Desnormalización controlada documentada | Columnas `*_u4`, triggers, índice, `food-store-tp-u4/docs/evidencia_u4.md` | Cumplido |

## U5 - Administración y seguridad

| Objetivo | Evidencia | Estado |
|---|---|---|
| Roles y permisos de mínimo privilegio | `food-store-tp-u5/sql/roles.sql`, `docs/verificacion_roles.txt` | Cumplido |
| Auditoría de accesos/operaciones y simulacro | `docs/informe_auditoria.md`, `docs/informe_incidente.md`, `docs/log_auditoria_prueba.txt` | Cumplido |
| Reconstrucción y contención | `docs/informe_incidente.md` (sección "Propuesta de contención"); `docs/log_simulacro_anonimizado.txt` | Cumplido |
| Auditoría de seguridad asistida por IA + decisión humana | `BITACORA.md`, `docs/opencode_auditoria.jsonl`, `TPI/DUIA.md` | Cumplido con salvedad: OpenCode falló HTTP 400 y no se inventó respuesta; la decisión humana está documentada |

## U6 - Mantenimiento

| Objetivo | Evidencia | Estado |
|---|---|---|
| Respaldo programado y restauración probada | `food-store-tp-u6/backup_foodstore.ps1`, `restore_test.ps1`, `logs/backup_*.json`, `logs/restore_resultado.json` | Cumplido |
| Tareas rutinarias (estadísticas, limpieza, integridad) | `food-store-tp-u6/maintenance.sql`, `health_check.sql`, `logs/health.txt`, `logs/maintenance.txt` | Cumplido |
| Automatización documentada | scripts PowerShell + `laboratorio_u6.py` + `SPEC_U6.md` | Cumplido |
| Simulacro de desastre contra reloj e informe post-incidente | RTO 32,224 s; `logs/restore_resultado.json`; PDF U6 | Cumplido |

## U7 - NoSQL

| Objetivo | Evidencia | Estado |
|---|---|---|
| Modelado documental de parte del dominio | `food-store-tp-u7/README.md`, `evidencias/pedidos_migrados.ejson` | Cumplido |
| Consultas documentales generadas y verificadas | `consultas_mongodb.js`, `evidencias/verificacion.json` | Cumplido |
| Comparación práctica con PostgreSQL | `consultas_postgresql.sql`, tabla de IDs en README y `verificacion.json` | Cumplido |
| Justificación de la tecnología | `README.md` (modelo, Decimal128, referencias), PDF U7 | Cumplido |

## U8 - Base móvil e integración

| Objetivo | Evidencia | Estado |
|---|---|---|
| Base SQLite con esquema especificado en Kiro | `food-store-tp-u8/docs/requirements.md`, `design.md`, `tasks.md`, `sql/u8/schema_sqlite.sql` | Cumplido |
| Sincronización simulada con conflictos | `sql/u8/semaforo.sql`, `u8/resultados/evidencia_u8.txt` (C1-C7) | Cumplido |
| Code review final con decisión humana | `food-store-tp-u8/docs/code_review_u8.md` (H-01 a H-06, H-02 corregido, H-05 descartado) | Cumplido |
| Capa de datos completa y versionada | repo Git con U1-U3, U4, U5, U6, U7 y U8; `TPI/INFORME_TECNICO_U4_U8.md` | Cumplido |

## Cierre

| Requisito de entrega | Evidencia |
|---|---|
| Link del repositorio | https://github.com/hero21lb/foodstore-gestor |
| Integrantes | Lemus Nahuel, Anglat Juan, Elias Juan Cruz |
| Informe técnico breve | `TPI/INFORME_TECNICO_U4_U8.md` y PDF |
| DUIA | `TPI/DUIA.md` + bitácoras por unidad |
| Sin datos personales ni credenciales | dumps y `.env` fuera del repo; evidencias con datos sintéticos |
