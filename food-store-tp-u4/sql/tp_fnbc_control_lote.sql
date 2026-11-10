-- Unidad 4, Parte 1. Ejecutar sobre una COPIA de Food Store.
-- La extensión mayorista se aísla en tp_u4 para no alterar el TPI previo.
BEGIN;

CREATE SCHEMA IF NOT EXISTS tp_u4;

-- Maestros mínimos: el esquema actual de Food Store no tiene estas tablas.
CREATE TABLE IF NOT EXISTS tp_u4.lote (
    id BIGINT PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS tp_u4.deposito (
    id BIGINT PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS tp_u4.usuario (
    id BIGINT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

INSERT INTO tp_u4.lote (id) VALUES (501), (502), (503)
ON CONFLICT DO NOTHING;
INSERT INTO tp_u4.deposito (id) VALUES (30), (31)
ON CONFLICT DO NOTHING;
INSERT INTO tp_u4.usuario (id, nombre) VALUES
    (801, 'Responsable 801'), (802, 'Responsable 802')
ON CONFLICT DO NOTHING;

-- Relación original de la consigna; conserva la anomalía R -> D.
CREATE TABLE IF NOT EXISTS tp_u4.control_lote_almacen_original (
    lote_id BIGINT NOT NULL REFERENCES tp_u4.lote(id),
    deposito_id BIGINT NOT NULL REFERENCES tp_u4.deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES tp_u4.usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO tp_u4.control_lote_almacen_original
    (lote_id, deposito_id, responsable_control_id)
VALUES (501, 30, 801), (502, 30, 801), (503, 31, 802)
ON CONFLICT (lote_id, deposito_id) DO NOTHING;

-- Descomposición por ResponsableControlID -> DepositoID:
-- R1(ResponsableControlID, DepositoID), R2(LoteID, ResponsableControlID).
CREATE TABLE IF NOT EXISTS tp_u4.responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY
        REFERENCES tp_u4.usuario(id),
    deposito_id BIGINT NOT NULL REFERENCES tp_u4.deposito(id)
);

CREATE TABLE IF NOT EXISTS tp_u4.control_lote_almacen (
    lote_id BIGINT NOT NULL REFERENCES tp_u4.lote(id),
    responsable_control_id BIGINT NOT NULL
        REFERENCES tp_u4.responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Si un mismo responsable figura en dos depósitos, la PK de R1 hace
-- fallar la migración: la inconsistencia no queda escondida.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tp_u4.control_lote_almacen_original
        GROUP BY responsable_control_id
        HAVING COUNT(DISTINCT deposito_id) > 1
    ) OR EXISTS (
        SELECT 1
        FROM tp_u4.control_lote_almacen_original o
        JOIN tp_u4.responsable_deposito r USING (responsable_control_id)
        WHERE o.deposito_id <> r.deposito_id
    ) THEN
        RAISE EXCEPTION 'La instancia viola ResponsableControlID -> DepositoID';
    END IF;
END;
$$;

INSERT INTO tp_u4.responsable_deposito
    (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM tp_u4.control_lote_almacen_original
ON CONFLICT (responsable_control_id) DO UPDATE
SET deposito_id = EXCLUDED.deposito_id
WHERE tp_u4.responsable_deposito.deposito_id = EXCLUDED.deposito_id;

INSERT INTO tp_u4.control_lote_almacen
    (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM tp_u4.control_lote_almacen_original
ON CONFLICT DO NOTHING;

-- JOIN USING equivale a una reunión natural sobre el único atributo común.
CREATE OR REPLACE VIEW tp_u4.vw_control_lote_almacen AS
SELECT lote_id, deposito_id, responsable_control_id
FROM tp_u4.control_lote_almacen
JOIN tp_u4.responsable_deposito USING (responsable_control_id);

-- La descomposición sin pérdida no preserva por sí sola LD -> R.
-- Se serializan asignaciones del mismo lote y se rechaza un segundo
-- responsable para el mismo par (lote, depósito).
CREATE OR REPLACE FUNCTION tp_u4.fn_control_lote_sin_duplicado()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_deposito_id BIGINT;
BEGIN
    PERFORM pg_advisory_xact_lock(NEW.lote_id);
    SELECT deposito_id INTO STRICT v_deposito_id
    FROM tp_u4.responsable_deposito
    WHERE responsable_control_id = NEW.responsable_control_id;

    IF EXISTS (
        SELECT 1
        FROM tp_u4.control_lote_almacen a
        JOIN tp_u4.responsable_deposito r USING (responsable_control_id)
        WHERE a.lote_id = NEW.lote_id
          AND r.deposito_id = v_deposito_id
          AND a.responsable_control_id <> NEW.responsable_control_id
    ) THEN
        RAISE EXCEPTION 'El lote % ya tiene responsable para el depósito %',
            NEW.lote_id, v_deposito_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_control_lote_sin_duplicado
ON tp_u4.control_lote_almacen;
CREATE TRIGGER trg_control_lote_sin_duplicado
BEFORE INSERT OR UPDATE ON tp_u4.control_lote_almacen
FOR EACH ROW EXECUTE FUNCTION tp_u4.fn_control_lote_sin_duplicado();

-- Evita que un cambio de depósito del responsable reinterprete controles
-- existentes sin volver a validar la asignación.
CREATE OR REPLACE FUNCTION tp_u4.fn_responsable_deposito_inmutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.deposito_id IS DISTINCT FROM NEW.deposito_id
       AND EXISTS (
           SELECT 1 FROM tp_u4.control_lote_almacen
           WHERE responsable_control_id = OLD.responsable_control_id
       ) THEN
        RAISE EXCEPTION 'No se puede cambiar el depósito de un responsable con controles';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_responsable_deposito_inmutable
ON tp_u4.responsable_deposito;
CREATE TRIGGER trg_responsable_deposito_inmutable
BEFORE UPDATE OF deposito_id ON tp_u4.responsable_deposito
FOR EACH ROW EXECUTE FUNCTION tp_u4.fn_responsable_deposito_inmutable();

-- Debe devolver cero filas: ambas diferencias con multiplicidad.
SELECT 'original_menos_vista' AS diferencia, x.*
FROM (
    SELECT * FROM tp_u4.control_lote_almacen_original
    EXCEPT ALL
    SELECT * FROM tp_u4.vw_control_lote_almacen
) x
UNION ALL
SELECT 'vista_menos_original' AS diferencia, x.*
FROM (
    SELECT * FROM tp_u4.vw_control_lote_almacen
    EXCEPT ALL
    SELECT * FROM tp_u4.control_lote_almacen_original
) x;

COMMIT;

-- Resultado legible esperado: (501,30,801), (502,30,801), (503,31,802).
SELECT * FROM tp_u4.vw_control_lote_almacen ORDER BY lote_id;
