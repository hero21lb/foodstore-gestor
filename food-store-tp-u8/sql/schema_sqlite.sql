-- ============================================================
-- U8 - Base de la tablet (SQLite 3.37+)
-- Ejecutar sobre una base nueva: sqlite3 tablet_u8.db < schema_sqlite.sql
-- La tablet solo guarda catálogo de lectura, borradores y la cola
-- de solicitudes. No guarda clientes, mails, celulares ni ventas.
-- ============================================================

PRAGMA foreign_keys = ON;

-- Catálogo recibido del servidor. Es una foto: la tablet no lo edita.
CREATE TABLE producto_cache (
    id               INTEGER PRIMARY KEY,
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible       INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado        INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia      TEXT    NOT NULL CHECK (length(fecha_copia) = 10)
) STRICT;

-- Borrador local: todavía no es un pedido del servidor.
CREATE TABLE pedido_borrador (
    id_local    TEXT PRIMARY KEY CHECK (length(id_local) = 36),
    usuario     TEXT NOT NULL,
    forma_pago  TEXT NOT NULL
                CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha       TEXT NOT NULL
) STRICT;

-- Renglones del borrador. El precio es el que la tablet vio, no el actual.
CREATE TABLE item_borrador (
    id_local                TEXT    NOT NULL
                            REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id             INTEGER NOT NULL
                            REFERENCES producto_cache(id) ON DELETE RESTRICT,
    cantidad                INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto   INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- Cola de sincronización. Una solicitud puede reevaluarse solo si sigue PENDIENTE.
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY CHECK (length(solicitud_uuid) = 36),
    id_local        TEXT NOT NULL
                    REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO',
                                      'SIMULADO_APROBADO')),
    motivo          TEXT
) STRICT;

-- Foto cruda importada del CSV de PostgreSQL. Los booleanos llegan como
-- 't'/'f'; se normalizan al cargar producto_cache.
CREATE TABLE snapshot_servidor (
    producto_id      INTEGER PRIMARY KEY,
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL,
    stock            INTEGER NOT NULL,
    disponible       TEXT    NOT NULL,
    eliminado        TEXT    NOT NULL,
    fecha_copia      TEXT    NOT NULL
) STRICT;

CREATE INDEX idx_item_borrador_pedido ON item_borrador(id_local);
CREATE INDEX idx_cola_sync_estado     ON cola_sync(estado);

-- Catálogo que puede ver el vendedor sin señal. C1 se apoya en esta vista.
CREATE VIEW vw_catalogo_disponible AS
SELECT id, nombre, precio_centavos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY nombre;
