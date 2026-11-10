# Informe de Concurrencia - Food Store (BD II - TP2)

> Base de Datos II - Unidad 1 - Semana 2
> Autores: Lemus Nahuel, Anglat Juan, Elias Juan Cruz
> Base de trabajo: `foodstore_copia_trabajo` - dos sesiones `psql` simultáneas

Flujo por escenario: **reproducir con dos sesiones -> pedir explicación a IA -> verificar con `SET TRANSACTION ISOLATION LEVEL` en el motor -> documentar acierto/discrepancia.** La que vale es la del motor, no la del modelo.

---

## Escenario 1 - Lectura no repetible (Read Committed vs Repeatable Read)

**Tabla:** `producto.stock` - Sesión A lee el mismo producto dos veces dentro de una transacción; entre medio Sesión B modifica el stock y hace COMMIT.

| Paso | Sesión A | Sesión B | Qué devuelve |
|------|----------|----------|--------------|
| 1 | `BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED;` | `BEGIN;` | BEGIN |
| 2 | `SELECT stock FROM producto WHERE id=1;` |  | `30` |
| 3 |  | `UPDATE producto SET stock=10 WHERE id=1; COMMIT;` | `UPDATE 1` |
| 4 | `SELECT stock FROM producto WHERE id=1;` |  | `10` (¡cambió!) |
| 5 | `COMMIT;` |  |  |

**Explicación de la IA (copiada tal cual, OpenCode - Muse Spark):**

> "En READ COMMITTED cada SELECT ve los datos commiteados al momento de ejecutarse, por eso la segunda lectura ve el stock=10 ya commiteado por B. En REPEATABLE READ la transacción ve un snapshot tomado al primer SELECT, por eso repetir no cambia."

**Verificación en el motor (mismo experimento con REPEATABLE READ):**

```sql
-- Sesión A
BEGIN; SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE id=1; -- 30
-- Sesión B (en paralelo)
UPDATE producto SET stock=10 WHERE id=1; COMMIT; -- UPDATE 1
-- Sesión A de nuevo
SELECT stock FROM producto WHERE id=1; -- 30 (no cambia, snapshot)
COMMIT;
```

**Conclusión:** IA acertó. Nivel que evita la anomalía: `REPEATABLE READ` (snapshot) o `SERIALIZABLE`.

---

## Escenario 2 - Lectura fantasma (phantom read)

**Tabla:** `pedido` - Sesión A hace `COUNT` de pedidos del último mes dos veces; entre medio Sesión B inserta un pedido nuevo que cumple el `WHERE`.

| Paso | Sesión A | Sesión B | Resultado |
|------|----------|----------|-----------|
| 1 | `BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED;` |  |  |
| 2 | `SELECT count(*) FROM pedido WHERE fecha >= now() - interval '30 days';` |  | `16278` |
| 3 |  | `INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES (now(), 'EFECTIVO', 1); COMMIT;` | `INSERT 1` |
| 4 | `SELECT count(*) FROM pedido WHERE fecha >= now() - interval '30 days';` |  | `16279` (fantasma) |
| 5 | `COMMIT;` |  |  |

**Explicación de la IA (copiada tal cual):**

> "El segundo COUNT ve una fila nueva (fantasma) porque READ COMMITTED no bloquea el rango. Con REPEATABLE READ el snapshot evita el fantasma y el COUNT repetiría 16278."

**Verificación en el motor (REPEATABLE READ):**

```sql
-- Sesión A
BEGIN; SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) FROM pedido WHERE fecha >= now() - interval '30 days'; -- 16278
-- Sesión B
INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES (now(), 'EFECTIVO', 1); COMMIT; -- OK, no bloquea
-- Sesión A
SELECT count(*) FROM pedido WHERE fecha >= now() - interval '30 days'; -- 16278 (snapshot, no fantasma)
COMMIT;
```

**Corrección documentada:** Postgres `REPEATABLE READ` usa snapshot y no ve el fantasma; `SERIALIZABLE` también lo evita pero con error de serialización si hay conflicto de escritura. La IA confundió "bloqueo de rango" (propio de `SERIALIZABLE`) con snapshot. No hay bloqueo, hay snapshot.

**Conclusión:** Fantasma evitado por `REPEATABLE READ` (snapshot) y por `SERIALIZABLE`; verificado en el motor.

---

## Escenario 3 - Espera por bloqueo (FOR UPDATE)

**Tabla:** `producto` - Dos sesiones piden la misma fila en modo exclusivo; la segunda queda esperando hasta COMMIT/ROLLBACK de la primera. Mecanismo base de bloqueos pesimistas.

| Paso | Sesión A | Sesión B (queda bloqueada) | Estado |
|------|----------|-----------------------------|--------|
| 1 | `BEGIN;` | `BEGIN;` |  |
| 2 | `SELECT * FROM producto WHERE id=1 FOR UPDATE;` |  | `1 row` (lock adquirido) |
| 3 |  | `SELECT * FROM producto WHERE id=1 FOR UPDATE;` | `Esperando...` |
| 4 | `UPDATE producto SET stock=stock-1 WHERE id=1; COMMIT;` |  | `COMMIT` |
| 5 |  | *(se desbloquea y devuelve fila)* | `1 row tras ~4.2s` |

**Explicación de la IA (copiada tal cual):**

> "FOR UPDATE toma un row-level lock exclusivo. La segunda sesión queda en espera (wait) hasta que la primera libere el lock con COMMIT/ROLLBACK. No es un error, es espera."

**Verificación en el motor:**

```sql
-- Sesión A
BEGIN;
SELECT * FROM producto WHERE id=1 FOR UPDATE; -- lock adquirido
-- Sesión B (en pg_stat_activity: wait_event_type=Lock, state=active)
SELECT * FROM producto WHERE id=1 FOR UPDATE; -- queda esperando
-- Sesión A
COMMIT; -- Sesión B se desbloquea inmediatamente y devuelve la fila actualizada
```

No requiere cambiar nivel de aislamiento; es bloqueo pesimista fila-a-fila + MVCC.

**Conclusión:** IA acertó. Mecanismo: bloqueo pesimista (`FOR UPDATE`).

### Extensión - Interbloqueo (opcional, nota adicional)

```sql
-- Sesión A
UPDATE producto SET stock=stock-1 WHERE id=1;
-- Sesión B
UPDATE producto SET stock=stock-1 WHERE id=2;
-- Sesión A (espera por B)
UPDATE producto SET stock=stock-1 WHERE id=2; -- espera
-- Sesión B (espera por A)
UPDATE producto SET stock=stock-1 WHERE id=1; -- ERROR 40P01 deadlock detected, se aborta B
-- Postgres aborta una transacción con "deadlock detected" y la otra continúa.
```

---

## DUIA - Parte 2

| Campo | Detalle |
|-------|---------|
| Herramienta | OpenCode (Muse Spark) para explicar cada anomalía; `psql` para verificar |
| Explicaciones IA | 3 explicaciones copiadas tal cual (lectura no repetible, fantasma, bloqueo) |
| Qué se aceptó | Las 3 explicaciones de fondo se aceptaron tras verificar |
| Correcciones | Fantasma: se corrigió "bloquea el rango" -> en Postgres es snapshot, no bloqueo. Nota `SERIALIZABLE` vs `REPEATABLE READ` agregada |
| Verificación | Los 3 escenarios se repitieron con `SET TRANSACTION ISOLATION LEVEL` y `FOR UPDATE`; resultados arriba |
