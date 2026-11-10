-- ============================================================
-- schema_completo.sql — Food Store · esquema completo
-- Base de Datos II · Unidad 2 · Semana 3
-- Ejecutar de principio a fin sobre una base PostgreSQL vacía
-- ============================================================

-- Dominio cerrado: forma de pago
CREATE TYPE forma_pago AS ENUM ('TARJETA', 'TRANSFERENCIA', 'EFECTIVO');

-- ---------------------------------------------------------------
-- categoria
-- ---------------------------------------------------------------
CREATE TABLE categoria (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL,
    descripcion VARCHAR(255),
    activo      BOOLEAN      NOT NULL DEFAULT TRUE
    -- activo: regla de negocio 7 — baja lógica, nunca borrado físico
);

-- ---------------------------------------------------------------
-- producto
-- ---------------------------------------------------------------
CREATE TABLE producto (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120) NOT NULL,
    descripcion  VARCHAR(255),
    precio       NUMERIC(10,2) NOT NULL CHECK (precio >= 0),      -- regla 5
    stock        INTEGER      NOT NULL DEFAULT 0 CHECK (stock >= 0), -- regla 5
    categoria_id BIGINT       NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    activo       BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Listado de productos de una categoría
CREATE INDEX idx_producto_categoria ON producto(categoria_id);

-- ---------------------------------------------------------------
-- cliente
-- ---------------------------------------------------------------
CREATE TABLE cliente (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre   VARCHAR(80)  NOT NULL,
    apellido VARCHAR(80)  NOT NULL,
    mail     VARCHAR(120) NOT NULL UNIQUE,   -- clave candidata (regla 6)
    celular  VARCHAR(30)
);

-- ---------------------------------------------------------------
-- pedido
-- ---------------------------------------------------------------
CREATE TABLE pedido (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago  NOT NULL,
    cliente_id BIGINT      NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT
);

-- Historial de pedidos de un cliente
CREATE INDEX idx_pedido_cliente ON pedido(cliente_id);

-- ---------------------------------------------------------------
-- detalle_pedido (entidad asociativa: resuelve pedido N:M producto)
-- ---------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),      -- regla 4
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    pedido_id       BIGINT        NOT NULL REFERENCES pedido(id) ON DELETE RESTRICT,
    producto_id     BIGINT        NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    UNIQUE (pedido_id, producto_id)   -- un producto no se repite dentro de un pedido
    -- subtotal NO se almacena: se calcula al vuelo (cantidad * precio_unitario)
);
