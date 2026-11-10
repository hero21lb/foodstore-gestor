-- ============================================================
-- TP2 - Food Store: restricciones de integridad versionadas
-- Base de Datos II - Unidad 1 - Semana 2
-- Autores: Lemus Nahuel, Anglat Juan, Elias Juan Cruz
-- Generado con OpenCode (Muse Spark) en modo Plan -> Build
-- Aplicar SIEMPRE sobre foodstore_copia_trabajo y dentro de
-- BEGIN; ...; ROLLBACK; antes de COMMIT (ver protocolo_seguridad.md)
-- ============================================================

-- R1: La fecha de un pedido nunca puede ser futura
-- Tabla: pedido.columna fecha TIMESTAMPTZ
-- Spec: "fecha <= now()" (zona America/Argentina/Mendoza)
ALTER TABLE pedido
  ADD CONSTRAINT chk_pedido_fecha_no_futura
  CHECK (fecha <= now());

COMMENT ON CONSTRAINT chk_pedido_fecha_no_futura ON pedido
  IS 'R1: fecha no futura (TP2) - impide INSERT con 2030-01-01';

-- R2: La cantidad por línea de pedido en rango operativo 1..20
-- Tabla: detalle_pedido.columna cantidad INTEGER
-- Reemplaza el CHECK existente cantidad > 0 por rango 1..20
ALTER TABLE detalle_pedido DROP CONSTRAINT IF EXISTS chk_detalle_cantidad;
ALTER TABLE detalle_pedido DROP CONSTRAINT IF EXISTS chk_linea_cantidad;

ALTER TABLE detalle_pedido
  ADD CONSTRAINT chk_detalle_cantidad_rango
  CHECK (cantidad BETWEEN 1 AND 20);

COMMENT ON CONSTRAINT chk_detalle_cantidad_rango ON detalle_pedido
  IS 'R2: cantidad 1..20 (TP2) - evita typos y carga masiva erronea';

-- R3: El precio histórico no puede superar 1.5x el precio de lista
-- Tabla: detalle_pedido.precio_unitario vs producto.precio
-- Tipo: TRIGGER BEFORE INSERT OR UPDATE
CREATE OR REPLACE FUNCTION trg_check_precio_unitario() RETURNS trigger AS $$
BEGIN
  IF NEW.precio_unitario > 1.5 * (SELECT precio FROM producto WHERE id = NEW.producto_id) THEN
    RAISE EXCEPTION 'precio_unitario % supera 1.5x el precio de lista del producto %',
      NEW.precio_unitario, NEW.producto_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS chk_precio_unitario ON detalle_pedido;

CREATE TRIGGER chk_precio_unitario
  BEFORE INSERT OR UPDATE ON detalle_pedido
  FOR EACH ROW EXECUTE FUNCTION trg_check_precio_unitario();

-- Comentarios para defensa oral (qué hace cada línea)
-- chk_pedido_fecha_no_futura: CHECK compara fecha insertada contra now() del motor.
-- chk_detalle_cantidad_rango: BETWEEN 1 AND 20 es inclusivo; bloquea 0 y 50.
-- trg_check_precio_unitario: SELECT precio dentro del trigger lee producto.precio vigente;
--   1.5x da tolerancia (no <= precio estricto) para aumentos sin actualizar histórico.

-- ============================================================
-- Verificación en copia (ejecutar en psql foodstore_copia_trabajo)
-- ============================================================
-- BEGIN;
-- -- R1 válido
-- INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES (now(), 'EFECTIVO', 1); -- OK 1 row
-- -- R1 inválido (fecha futura)
-- INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES ('2030-01-01', 'EFECTIVO', 1);
-- -- ERROR: violates check constraint "chk_pedido_fecha_no_futura"
--
-- -- R2 válido
-- INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (5, 1000, 1, 1); -- OK
-- -- R2 inválido 0
-- INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (0, 1000, 1, 1);
-- -- ERROR: violates check constraint "chk_detalle_cantidad_rango"
-- -- R2 inválido 50
-- INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (50, 1000, 1, 2);
-- -- ERROR: violates check constraint "chk_detalle_cantidad_rango"
--
-- -- R3 válido (1000 con producto precio 1050 -> ratio 0.95)
-- INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (1, 1000, 2, 1); -- OK
-- -- R3 inválido (3000 > 1.5*1050=1575)
-- INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (1, 3000, 2, 1);
-- -- ERROR: precio_unitario 3000.00 supera 1.5x el precio de lista del producto 1
-- ROLLBACK;
-- -- Tras verificar, repetir con COMMIT y commitear el .sql
