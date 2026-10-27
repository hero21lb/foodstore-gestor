# U7 FoodStore: entregable y laboratorio

Consigna: `../../bases de datos/consignas/BDII_Unidad7_TP_FoodStore_NoSQL.pdf`.
La entrega final requiere un PDF de hasta cinco paginas y los archivos de consultas.
El PDF final es `TP_U7_NoSQL_FoodStore_Entregable.pdf`: cinco paginas con la
caratula y los autores de U5/U6, modelo, migracion, consultas, tabla comparativa,
contraste de IA y conclusion. Se revisaron visualmente las cinco paginas.
Paquete completo: `../../output/compartir/FoodStore_BD2_U7_Entregable.zip`.

## Infraestructura

- Proyecto Railway: postgrefacu (`b26b03ee-46b4-434a-bf14-4629c5a3806e`).
- Entorno: production (`790cff46-0c51-4815-addf-d76819554c83`).
- Postgres: `b4e08230-038a-495f-833a-accc606fc3ae`; base de trabajo **foodstore**.
- MongoDB: `fdf5f0f5-4d31-4363-9db7-fa887537086b`; base **foodstore_u7**, coleccion **pedidos**.
- MongoDB usa volumen persistente y tunel SSH efimero; no se agrega acceso TCP publico.
- Se configuro la clave local `~/.ssh/id_ed25519`, registrada en Railway como
  `FoodStore U7 - PC local`, para usar ese tunel. La clave privada no pertenece al repositorio.
- El gestor web existente no necesita cambios para esta consigna.

## Decision autorizada sobre estado

El 27/10/2026 se verifico que `public.pedido` no tenia `estado`.
El usuario solicito agregarlo en la misma base foodstore, sin crear otra copia.
Se agrega una columna nullable con CHECK; se asignan estos valores **de prueba**:

| Pedido | Estado sintetico U7 |
|---|---|
| 1 | PENDIENTE |
| 2 | CONFIRMADO |
| 3 | ENTREGADO |
| 4 | CANCELADO |
| 5 | CONFIRMADO |

Los otros pedidos conservan NULL (estado no registrado). No se interpreta NULL
como pendiente ni se atribuyen estos estados a operaciones historicas reales.
Los importes, cantidades, fechas, IDs y datos originales se conservan.
`preparacion_postgresql.json` registra hashes antes/despues y el respaldo validado.

## Ejecutar

Requiere Node.js con Railway CLI autenticado, Python y los requisitos del directorio.
Las credenciales se obtienen de Railway y no se escriben a disco.

```powershell
python -m pip install -r requirements.txt
python laboratorio_u7.py preparar
python laboratorio_u7.py migrar
```

`preparar` crea un dump custom en `backups/` antes de la transaccion SQL. Si un
pedido seleccionado tiene un estado distinto, se detiene sin reemplazarlo.
`migrar` verifica MongoDB, crea una coleccion validada y migra cinco pedidos.
Si existen documentos diferentes, se detiene: no hace DROP, delete ni reemplazo.

## Modelo

Un documento por pedido: `_id` conserva el BIGINT mediante BSON Long; `cliente`
contiene ID y alias sintetico; `lineas` embebe IDs de detalle y producto,
nombre de catalogo, cantidad, precio historico y subtotal. `total` suma esas lineas.
Se usa Decimal128 para conservar importes exactos. `fecha` es BSON Date UTC y
`fecha_origen_iso` conserva los microsegundos de PostgreSQL. No se exportan
nombres, apellidos, mails ni telefonos de clientes.

Integridad: cantidad mayor que cero, precio no negativo, pedido unico por `_id`,
igualdad exacta de documentos leidos y exportados, totales calculados desde
`detalle_pedido.precio_unitario`. La aplicacion no recalcula ventas con el precio
actual de producto. Se conserva el estado asignado antes de migrar.

## Evidencias y proximos pasos

Verificado el 27/10/2026: MongoDB 8.0.34, PostgreSQL 18.6; cinco documentos migrados.
Despliegues SUCCESS: MongoDB `c0ec482b-1a66-4347-a01b-17297c362b7d` y
Postgres `c80f3726-dcf6-4168-904e-515c8813c0e6`. Postgres estaba detenido y fue
iniciado usando su imagen y volumen existentes. El gestor web no fue redeplegado.

| Consulta sobre los mismos cinco pedidos | IDs PostgreSQL | IDs MongoDB |
|---|---|---|
| Todos | 1, 2, 3, 4, 5 | 1, 2, 3, 4, 5 |
| Estado CONFIRMADO | 2, 5 | 2, 5 |
| Producto 2 | 1 | 1 |
| Total mayor a 300 | 2, 3, 4 | 2, 3, 4 |

Las consultas fueron ejecutadas por `laboratorio_u7.py` usando psycopg2 y PyMongo.
Los archivos SQL/JS adjuntos expresan las mismas consultas para ejecutar en las consolas.

- `evidencias/preparacion_postgresql.json`: respaldo, distribucion y hashes.
- `evidencias/pedidos_migrados.ejson`: documentos con clientes seudonimizados.
- `evidencias/verificacion.json`: consultas ejecutadas e IDs por motor.
- `consultas_postgresql.sql` y `consultas_mongodb.js`: equivalencias reproducibles.
- `asistencia_ia.md`: consulta, sintesis de Codex y conclusion; dos afirmaciones
  contrastadas con documentacion oficial en el PDF. Equipo y repositorio identificados.
- El PDF y el ZIP estan preparados; no se subio nada al campus.

La comparacion usa **los mismos cinco IDs** en ambos motores; no compara cinco
documentos contra todos los pedidos del servidor relacional.

Fuentes oficiales para el informe:
- https://www.mongodb.com/docs/manual/data-modeling/embedding/
- https://www.mongodb.com/docs/manual/core/schema-validation/
- https://www.mongodb.com/docs/manual/reference/bson-types/
- https://www.postgresql.org/docs/current/datatype-numeric.html
