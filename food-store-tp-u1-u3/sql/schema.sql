-- ============================================================
-- TP1 - Food Store: schema.sql
-- Base de Datos I - Tecnicatura en Programación (UTN)
-- Autores: Guzmán Agustina y Lemus Nahuel
-- ============================================================

-- Dominio cerrado: forma de pago
CREATE TYPE tipo_forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- CATEGORÍA (participación parcial respecto de producto: puede no tener productos)
CREATE TABLE categoria (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    activo BOOLEAN     NOT NULL DEFAULT TRUE      -- baja lógica (R7)
);

-- PRODUCTO (participación total en categoria: siempre tiene una categoría)
CREATE TABLE producto (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    descripcion  VARCHAR(255),                    -- atributo opcional
    precio       NUMERIC(12, 2) NOT NULL,
    stock        INTEGER        NOT NULL DEFAULT 0,
    activo       BOOLEAN        NOT NULL DEFAULT TRUE,
    categoria_id BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    CONSTRAINT chk_producto_precio CHECK (precio >= 0),   -- R5
    CONSTRAINT chk_producto_stock  CHECK (stock  >= 0)    -- R5
);

-- CLIENTE (email es clave candidata alternativa, R6)
CREATE TABLE cliente (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre   VARCHAR(60)  NOT NULL,
    apellido VARCHAR(60)  NOT NULL,
    email    VARCHAR(120) NOT NULL UNIQUE,
    telefono VARCHAR(30)                              -- opcional / multivaluado
);

-- PEDIDO (participación total en cliente: siempre pertenece a un cliente)
CREATE TABLE pedido (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    forma_pago tipo_forma_pago  NOT NULL,
    cliente_id BIGINT NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT
);

-- LÍNEA_PEDIDO (tabla intermedia de la relación N:M pedido-producto)
-- PK compuesta (pedido_id, producto_id): un producto no se repite dentro de un pedido
CREATE TABLE linea_pedido (
    pedido_id       BIGINT NOT NULL REFERENCES pedido(id)    ON DELETE RESTRICT,
    producto_id     BIGINT NOT NULL REFERENCES producto(id)  ON DELETE RESTRICT,
    cantidad        INTEGER NOT NULL,
    precio_unitario NUMERIC(12, 2) NOT NULL,                -- precio histórico (R4)
    PRIMARY KEY (pedido_id, producto_id),
    CONSTRAINT chk_linea_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_linea_precio   CHECK (precio_unitario >= 0)
);

-- ÍNDICES (justificación en comentario de cada uno)
-- Busca los pedidos de un cliente: consulta frecuente desde el panel del cliente.
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);
-- Lista los productos vigentes de una categoría.
CREATE INDEX idx_producto_categoria ON producto (categoria_id);
-- Responde "cuánto se vendió de cada producto" agregando por producto.
CREATE INDEX idx_linea_producto ON linea_pedido (producto_id);
