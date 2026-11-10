# Evidencia de ejecución - TP Unidad 4

Entorno: copia local de Food Store en PGlite (PostgreSQL 18.3 embebido),
zona `America/Argentina/Buenos_Aires`. Carga: 20 categorías, 1.000 productos,
203 clientes, 20.005 pedidos y 20.007 detalles. Se usaron el esquema, seed,
restricciones e índices previos; la carga adicional del banco de pruebas se
generó con SQL sobre una base aislada.

## Parte 1

- `vw_control_lote_almacen` devolvió `(501,30,801)`, `(502,30,801)` y
  `(503,31,802)`.
- El `EXCEPT ALL` bidireccional entre original y vista devolvió 0 filas.
- Una segunda asignación del lote 501 al depósito 30 con responsable 803 fue
  rechazada por `trg_control_lote_sin_duplicado`.

## Parte 2

Consulta: top 5 por ventas del día de negocio. En el día probado se leyeron
666 líneas y el resultado normalizado coincidió exactamente con el
desnormalizado, incluso en el orden de desempate.

| Indicador | Antes: 4 tablas | Después: `detalle_pedido` |
|---|---:|---:|
| `Execution Time` de las capturas | 14,440 ms | 1,280 ms |
| Mediana de 5 repeticiones | 14,576 ms | 1,230 ms |
| Nodo de acceso dominante | `Hash Join` sobre `Seq Scan` de 20.007 detalles | `Bitmap Heap Scan` + `Bitmap Index Scan` sobre fecha |
| Filas del top | 5 | 5, idénticas |

La mediana disminuyó unas 11,9 veces en este banco local. El `EXPLAIN` inicial
se hizo con `ANALYZE` y `BUFFERS`; tras el backfill se ejecutó `ANALYZE
detalle_pedido` y se repitió la medición. Los planes mostraron 329 buffers
compartidos alcanzados antes y 271 después.

Extracto literal del plan anterior:

```text
-> HashAggregate (actual time=14.267..14.304 rows=20.00 loops=1)
   -> Hash Join (actual time=1.639..13.768 rows=666.00 loops=1)
      -> Hash Join (actual time=1.583..13.295 rows=666.00 loops=1)
         -> Hash Join (actual time=0.816..12.021 rows=666.00 loops=1)
            -> Seq Scan on detalle_pedido dp
               (actual time=0.006..5.141 rows=20007.00 loops=1)
Planning Time: 0.899 ms
Execution Time: 14.440 ms
```

Extracto literal del plan posterior:

```text
-> HashAggregate (actual time=1.168..1.184 rows=20.00 loops=1)
   -> Bitmap Heap Scan on detalle_pedido
      (actual time=0.135..0.639 rows=666.00 loops=1)
      Recheck Cond: (fecha_venta_u4 = CURRENT_DATE)
      -> Bitmap Index Scan on idx_detalle_top_categorias_u4
         (actual time=0.092..0.092 rows=666.00 loops=1)
Planning Time: 0.226 ms
Execution Time: 1.280 ms
```

La auditoría de todas las filas devolvió 0 diferencias inmediatamente después
del backfill. También devolvió 0 tras cambiar, dentro de una transacción de
prueba, la cantidad de un detalle, la fecha de un pedido, la categoría de un
producto y el nombre de una categoría. Una línea nueva insertada en la misma
prueba obtuvo sus cuatro valores precalculados correctos. Las pruebas se
revirtieron con `ROLLBACK`.

Estos tiempos son del motor local embebido y no son una medición de Railway.

