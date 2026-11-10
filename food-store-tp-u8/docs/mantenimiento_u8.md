# U8 - Plan de mantenimiento (agregado al de U6)

## Qué se respalda y cómo se prueba

| Activo | Respaldo | Prueba de restauración | Frecuencia |
|---|---|---|---|
| PostgreSQL (`foodstore_u8_lab` en producción: `foodstore`) | `pg_dump -Fc` con fecha y hash; se conserva fuera del servidor. | Restaurar en una base nueva, comparar conteos y `md5` de pedido/detalle, y validar que no haya precios o stock inválidos. | Diaria. |
| SQLite de la tablet | Copia del archivo `tablet_u8.db` (o export de las cuatro tablas) al cerrar el turno. | Abrir la copia en una base temporal, contar borradores, ítems y cola, y verificar `PRAGMA integrity_check`. | Diaria o por turno. |
| Instantáneas CSV | Archivar `servidor_snapshot.csv` con la fecha en el nombre. | Importar en una SQLite vacía y comparar la cantidad de filas contra `v_snapshot_movil`. | Cada vez que se exporta. |
| Configuración de roles y vistas | Versionada en Git; el respaldo de PostgreSQL incluye los objetos. | Restaurar en una base nueva y ejecutar `\dn`, `\dv`, `\df`. | En cada cambio. |

El respaldo no se considera válido por existir: se prueba restaurando. La base
de prueba se crea con otro nombre y se valida antes de borrarla.

## Si se restaura un respaldo viejo de PostgreSQL

1. **La tablet no se cree dueña de la verdad.** Su `producto_cache` puede tener
   precios o stock más nuevos que el respaldo restaurado.
2. **No se reenvían automáticamente las solicitudes.** Todas las pendientes se
   vuelven a marcar `PENDIENTE` solo si se decide reabrir el turno; primero se
   exporta una instantánea nueva y se recarga `producto_cache`.
3. **El semáforo vuelve a evaluar.** Un precio viejo puede dar `CONFLICTO`; un
   producto que ya no existe o está dado de baja da `RECHAZADO`.
4. **Las ventas confirmadas no están en la tablet.** Si el respaldo es anterior
   a una venta confirmada, esa venta se pierde en el servidor: es un problema de
   RPO del servidor, no de la tablet. La tablet solo tiene borradores.
5. **Queda registro.** Se anota la fecha del respaldo restaurado y la fecha de
   la última instantánea de cada tablet; si la tablet es más nueva, se conserva
   su cola como evidencia y no se pisa.

## Quién revisa CONFLICTO y RECHAZADO

| Estado | Quién | Cuándo | Qué hace |
|---|---|---|---|
| `CONFLICTO` | Vendedor/encargado del turno | Al cerrar el turno o antes del siguiente | Acepta el precio nuevo o descarta el borrador; deja motivo. |
| `RECHAZADO` | Encargado + administrador de datos | Diario, al cierre | Verifica stock, baja lógica o producto inexistente; corrige el borrador o lo anula. |
| Cola sin resolver | Administrador de datos | Semanal | Revisa antigüedad, reincidencia y ajusta el catálogo o la frecuencia de snapshot. |

**Regla:** ningún `CONFLICTO` se resuelve solo por tiempo. Si nadie lo revisa, el
borrador queda pendiente y no se convierte en venta.

## Frecuencia de snapshot

- Al inicio de cada turno y después de un cambio de precio o stock relevante.
- Como máximo cada 4 horas si el catálogo cambia seguido.
- Si la tablet estuvo offline más de un turno, se marca la copia como vieja y se
  fuerza una recarga antes de aceptar nuevos borradores.
