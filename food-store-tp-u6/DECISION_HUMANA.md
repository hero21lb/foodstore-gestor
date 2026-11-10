# U6 - Revisión humana del mantenimiento

**Responsable:** Lemus Nahuel
**Fecha de revisión:** 10/11/2026
**Alcance:** `SPEC_U6.md`, `backup_foodstore.ps1`, `restore_test.ps1`,
`laboratorio_u6.py`, `maintenance.sql`, `health_check.sql`,
`logs/backup_*.json`, `logs/restore_resultado.json`, `logs/health.txt`,
`logs/maintenance.txt`.

## Qué se revisó

1. El respaldo es `pg_dump -Fc` y se genera antes de cualquier DDL.
2. `restore_test` crea una base nueva `foodstore_restore_test`; no borra ni
   sobrescribe la fuente.
3. La restauración compara conteos y `md5` de las cinco tablas.
4. El simulacro reporta RTO 32,224 s y antigüedad 263,558 s.
5. `maintenance.sql` y `health_check.sql` revisan tamaño, conexiones, tuplas
   muertas, autovacuum y estadísticas.
6. No se ejecuta `VACUUM FULL` periódico; se usa `ANALYZE` cuando corresponde.

## Decisión

| Propuesta | Decisión | Motivo |
|---|---|---|
| Respaldo custom diario + restore semanal | **Aceptada** | Permite recuperar y probar sin depender del archivo original. |
| Restaurar sobre `foodstore` | **Rechazada** | Riesgo de pérdida; se restaura en una base nueva. |
| `VACUUM FULL` programado | **Rechazada** | Bloquea y reescribe la tabla; no es mantenimiento rutinario. |
| Retención de respaldos sin prueba | **Rechazada** | Un respaldo no probado no es evidencia de recuperación. |

## OpenCode

Los scripts y el informe se prepararon con apoyo de IA. La revisión humana
verificó los logs y los conteos. No se atribuye a OpenCode una ejecución que no
esté registrada en los logs del repositorio.

Firma: ______________________________
