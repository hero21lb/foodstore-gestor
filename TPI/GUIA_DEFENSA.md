# Guía de defensa - TPI Food Store (U1 a U8)

**Formato:** charla cara a cara con la profesora, 8 a 10 minutos, con el gestor
abierto. No es una exposición con diapositivas: se muestra el Laboratorio TPI y
se ejecutan dos o tres pruebas por unidad. La profesora pregunta sobre lo que ve.

**Integrantes:** Lemus Nahuel, Anglat Juan, Elias Juan Cruz.

## Reparto sugerido

| Tramo | Quién | Tema | Qué muestra en el gestor |
|---|---|---|---|
| 0:00-1:00 | Nahuel | Mapa y regla de oro | Laboratorio TPI: PostgreSQL, MongoDB, SQLite; estados del laboratorio |
| 1:00-3:00 | Nahuel | U1-U3 | Restricciones, dos sesiones, EXPLAIN, vistas y refresh |
| 3:00-5:00 | Juan | U4-U6 | FNBC, top normal/desnormalizado, roles 42501, auditoría, RTO |
| 5:00-7:00 | Elias | U7-U8 | MongoDB vs. PostgreSQL, C2/C3/C4/C6 del semáforo |
| 7:00-8:30 | Los tres | IA y decisiones | Un hallazgo aceptado, uno corregido, uno descartado |
| 8:30-10:00 | Los tres | Preguntas | Responder mirando el gestor, no leyendo |

Si la profesora pide empezar por otro lado, se sigue el orden de las unidades;
la guía es un guion, no un libreto cerrado.

## 1. Apertura (Nahuel, 1 minuto)

Frase de entrada:

> "Food Store tiene tres motores. PostgreSQL es la fuente de verdad de precio,
> stock y venta. MongoDB guarda el pedido como documento para consulta NoSQL.
> SQLite es la tablet: guarda una foto del catálogo y borradores. La regla es
> **el móvil propone, el servidor dispone**."

Mostrar la tarjeta **Laboratorio TPI** y leer los pills: base `foodstore`,
1.000 productos, 5.000 clientes, 20.000 pedidos, U4 instalado, roles U5, SQLite
lista. Aclarar que U8 usa una base de laboratorio y que el gestor no escribe en
`railway`.

## 2. U1-U3 (Nahuel, 2 minutos)

1. **U1 - Probar restricciones.** Mostrar que el pedido válido pasa y que fecha
   futura, cantidad 0/50 y precio > 1,5x fallan con su código (`23514`,
   `P0001`). Cerrar: "las reglas están en la base, no solo en la aplicación".
2. **U1 - Simular dos sesiones.** Mostrar el `55P03` de la sesión B: "FOR UPDATE
   bloquea la fila; B espera y vence el lock_timeout. No es un error de lógica,
   es concurrencia".
3. **U2 - Ver EXPLAIN ANALYZE.** Mostrar el nodo y el tiempo. Aclarar que el plan
   puede cambiar con el volumen; la decisión se toma con datos, no por intuición.
4. **U3 - Leer vistas y refrescar materializada.** Mostrar los conteos de las
   tres vistas y las 260 filas de facturación; ejecutar refresh y mostrar el
   tiempo. "La materializada es un corte; no es dato transaccional en vivo".

## 3. U4-U6 (Juan, 2 minutos)

1. **U4 - Probar FNBC.** Mostrar las tres tuplas de la vista y `diferencias: 0`.
   Explicar: `R -> D` viola FNBC; se descompone en R1(R,D) y R2(L,R); la vista
   reconstruye sin pérdida.
2. **U4 - Top normal vs. desnorm.** Mostrar que ambos devuelven el mismo top y
   que el plan cambia a un acceso por `fecha_venta_u4` (Bitmap/Index) frente al
   JOIN de cuatro tablas. Aclarar que la mejora de 14,4 ms a 1,28 ms es de la
   copia PGlite de U4, no de Railway.
3. **U5 - Probar permisos.** Mostrar `app_web` leyendo productos y los tres
   `42501`: hash, DELETE de pedido y `GRANT admin_datos`. "El rol no puede
   escalar solo".
4. **U5 - Generar evento de stock.** Ejecutar y mostrar el JSONB de
   `auditoria_stock`; aclarar que el stock neto no cambia.
5. **U5 - Login demo.** `demo@foodstore.local` / `defensa2026`; mostrar el id y
   rol. Aclarar que es un usuario sintético de laboratorio.
6. **U6 - Ver respaldo/restore.** Mostrar RTO 32,224 s, conteos y md5
   coincidentes, cero inválidos; aclarar que el simulacro se hizo sobre
   `foodstore_restore_test` y que no se borró la fuente.

## 4. U7-U8 (Elias, 2 minutos)

1. **U7 - Consultar MongoDB.** Si `MONGO_URL` está configurada, mostrar los 5
   documentos y las consultas por estado/producto/total; si no, mostrar la
   evidencia y aclarar que el modo evidencia es el mismo resultado guardado.
   Frase: "los mismos 5 IDs en PostgreSQL y MongoDB; no comparamos 5 documentos
   contra 20.000 pedidos".
2. **U8 - Ver tablet.** Mostrar la cola final: 1 CONFLICTO, 2 RECHAZADO, 2
   SIMULADO_APROBADO.
3. **U8 - C2 precio.** Ejecutar: `CONFLICTO` "visto 105000, ahora 110000"; luego
   la segunda solicitud `SIMULADO_APROBADO`.
4. **U8 - C3 stock.** `RECHAZADO` "pedido 5, disponible 2".
5. **U8 - C4 baja.** `RECHAZADO` "dado de baja"; la fila queda con
   `eliminado=1` y el catálogo no la muestra.
6. **U8 - C6 UUID.** Mostrar el error de PK y que no se duplica.
7. Cierre: "`SIMULADO_APROBADO` no es una venta. La tablet nunca descuenta stock
   ni confirma; el servidor decide."

## 5. IA y decisiones (los tres, 1,5 minutos)

Elegir tres hallazgos del code review:

- **Aceptado (H-03):** la vista materializada de facturación filtraba `activo`;
  al dar de baja un producto, sus ventas históricas desaparecían. Prueba:
  14.700 -> 8.500 -> 4.000, mientras la facturación real seguía en 14.700.
- **Corregido (H-02):** `indices.sql` e `indices_u3.sql` duplicaban índices
  sobre `pedido(fecha)` y `detalle_pedido(producto_id)`. Se comprobó con
  `pg_indexes` y se eliminaron los duplicados exactos en el laboratorio.
- **Descartado (H-05):** agregar `pedido(cliente_id)` era redundante con
  `idx_pedido_cliente`; solo sumaba costo de escritura.

Aclarar la limitación de U5: OpenCode devolvió HTTP 400 al intentar auditar el
SQL; se registró el error y **no se inventó** una auditoría. La decisión humana
está documentada en `DECISION_HUMANA.md`. No ocultar esto: la profesora ya lo vio
en la devolución de U5.

## 6. Preguntas probables y respuestas cortas

| Pregunta | Respuesta |
|---|---|
| ¿Por qué PostgreSQL manda? | ACID, FK, CHECK, triggers y transacciones; el precio y el stock no se negocian desde la tablet. |
| ¿Por qué MongoDB? | El pedido es un documento con líneas embebidas y se consulta por estado/producto/importe; no reemplaza la venta relacional. |
| ¿Por qué SQLite? | La tablet necesita funcionar sin señal; guarda una foto y borradores, no la verdad del servidor. |
| ¿Qué es `SIMULADO_APROBADO`? | Una simulación: los datos coinciden, pero no se confirma la venta. |
| ¿Qué pasa si restauran un respaldo viejo? | La tablet no manda: se recarga la instantánea y el semáforo reevalúa; precios viejos dan CONFLICTO. |
| ¿Por qué desnormalizar si ya están en 3FN? | Porque el top de categorías es una lectura frecuente; se paga con triggers y auditoría, no con datos sin control. |
| ¿Qué significa 42501? | Permiso insuficiente; el rol no puede leer el hash ni autoasignarse admin_datos. |
| ¿Cómo evitan duplicados? | UUID como PK en SQLite y, en un servidor real, idempotencia por `solicitud_uuid`. |
| ¿Qué hizo la IA? | Revisó scripts y generó borradores; nosotros probamos, aceptamos, corregimos o descartamos. |
| ¿Qué mejorarían? | Una auditoría válida de OpenCode en U5, un endpoint real de sincronización y acceso del docente al repo. |

## 7. Reglas de la charla

- No leer el PDF: el gestor es la evidencia.
- Cada afirmación se acompaña de una prueba o de un archivo.
- Si una prueba falla, decir qué se esperaba y qué se vio; no improvisar.
- Si la profesora pregunta por un tema de otro integrante, responder entre los
  tres, sin pisarse.
- Cerrar siempre con la regla de oro y con el control final: 5 pedidos, 7
  detalles, stock 220, mismos md5.
