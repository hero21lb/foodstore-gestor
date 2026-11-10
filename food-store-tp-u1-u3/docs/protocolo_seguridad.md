# Protocolo de seguridad - Food Store (BD II - TP2)

> Universidad Tecnológica Nacional - Tecnicatura Universitaria en Programación a Distancia
> Base de Datos II - Unidad 1 - Trabajo Práctico N.º 2
> Autores: Lemus Nahuel, Anglat Juan, Elias Juan Cruz

Condición no negociable de la cátedra: **todo script generado por IA se lee, se prueba sobre una copia y dentro de una transacción, y se defiende oralmente antes de darlo por bueno.** El protocolo de tres pasos no se salta nunca.

## Entorno real adaptado

- **Motor:** PostgreSQL 16 local (`localhost:5432`)
- **Base real:** `foodstore` (esquema `schema_completo.sql` + seed `data.sql`)
- **Copia de trabajo:** `foodstore_copia_trabajo` (clon de `foodstore`)
- **Respaldos:** `bases de datos/respaldos/` (dump custom format `.dump`)

## Paso 1 — Copia (nunca sobre datos reales)

Trabajar siempre sobre una copia de desarrollo, nunca sobre `foodstore`.

```bash
# Crear copia al iniciar cada sesión de trabajo (método rápido con TEMPLATE)
createdb -T foodstore foodstore_copia_trabajo

# Si ya existe de una sesión anterior:
dropdb foodstore_copia_trabajo
createdb -T foodstore foodstore_copia_trabajo

# Alternativa equivalente:
# psql -c "DROP DATABASE IF EXISTS foodstore_copia_trabajo;"
# psql -c "CREATE DATABASE foodstore_copia_trabajo TEMPLATE foodstore;"
```

Regla: ningún `psql`, DBeaver ni script de OpenCode apunta a `foodstore` durante el TP. Solo a `foodstore_copia_trabajo`.

## Paso 2 — Transacción (BEGIN ... ROLLBACK antes de COMMIT)

Todo script que escribe (INSERT/UPDATE/DELETE/DDL) corre primero dentro de una transacción para inspeccionar el efecto real antes de confirmar.

```sql
-- Conexión: psql foodstore_copia_trabajo  (o dos pestañas para concurrencia)

BEGIN;

-- 1. Aplicar script generado por IA (ALTER, CREATE TRIGGER, etc.)
-- 2. Probar con casos válidos e inválidos
INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES (now(), 'EFECTIVO', 1); -- debe pasar
INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES ('2030-01-01', 'EFECTIVO', 1); -- debe fallar

-- 3. Verificar filas afectadas, mensajes de error, SELECT de control
SELECT count(*) FROM pedido WHERE fecha > now();

ROLLBACK;  -- inspeccionar sin confirmar

-- Solo después de verificar, repetir con COMMIT si el resultado es el esperado:
-- BEGIN; ... ; COMMIT;
```

Si el script es DDL (`ALTER TABLE`, `DROP TRIGGER`), el `ROLLBACK` también revierte el DDL en PostgreSQL, por eso es seguro probar primero.

## Paso 3 — Respaldo (pg_dump antes de DDL)

Antes de aplicar cualquier cambio estructural (ALTER, DROP, migración) sobre la copia, se genera un respaldo independiente para poder volver atrás sin depender del ROLLBACK.

```bash
# Crear directorio si no existe
mkdir -p "bases de datos/respaldos"

# Dump custom format (restaura con pg_restore)
pg_dump -Fc foodstore_copia_trabajo > "bases de datos/respaldos/foodstore_2026-08-28.dump"

# Dump plano (alternativa legible)
pg_dump foodstore_copia_trabajo > "bases de datos/respaldos/foodstore_2026-08-28.sql"

# Restaurar si hace falta volver atrás:
pg_restore -d foodstore_copia_trabajo "bases de datos/respaldos/foodstore_2026-08-28.dump"
# o: psql foodstore_copia_trabajo < "bases de datos/respaldos/foodstore_2026-08-28.sql"
```

## Checklist de cada operación con IA

- [ ] ¿Estoy conectado a `foodstore_copia_trabajo` y no a `foodstore`?
- [ ] ¿Leí el `git diff` línea por línea antes de ejecutar?
- [ ] ¿Ejecuté dentro de `BEGIN; ... ROLLBACK;` primero?
- [ ] ¿Probé al menos un caso válido y uno inválido con su mensaje de error esperado?
- [ ] ¿Generé `pg_dump` si es DDL?
- [ ] ¿Commiteé en Git con mensaje que nombra la regla de negocio, no "agrego constraint"?

> **Nunca se salta ningún paso.** El protocolo se aplicó en Parte 1 (restricciones), Parte 2 (anomalías con dos sesiones) y Parte 3 (scripts peligrosos en copia con ROLLBACK).
