# Food Store · Gestor estático con API

Panel web para administrar categorías y productos (con baja lógica), consultar pedidos y mostrar métricas. La interfaz es HTML, CSS y JavaScript; el servidor Express se limita a servirla y a exponer una API interna que consulta PostgreSQL.

## Ejecución local

1. Definir `DATABASE_URL` con la URL de conexión PostgreSQL.
2. Ejecutar `npm install` y `npm start` dentro de esta carpeta.
3. Abrir `http://localhost:3000`.

## Despliegue en Railway

1. Crear un servicio desde este directorio (`foodstore-gestor`).
2. Definir la variable `DATABASE_URL` como referencia a la variable del servicio PostgreSQL `postgrefacu`.
3. Railway detecta `npm start` y publica el servicio.

Antes de usarlo, aplicar en la base `schema_completo.sql`, `views.sql`, `indices_u3.sql` y `objetos_programables_tpi.sql`. La aplicación no guarda credenciales en el navegador: `DATABASE_URL` vive sólo en Railway.

## TPI Food Store - capa de datos (Unidades 1 a 8)

Este repositorio también reúne la capa de datos del Trabajo Práctico Integrador
de Base de Datos II. Integrantes: **Lemus Nahuel, Anglat Juan, Elias Juan Cruz**.

| Carpeta | Contenido |
|---|---|
| `food-store-tp-u1-u3/` | Esquema PostgreSQL, datos, restricciones, índices, vistas, objetos programables y documentos de las unidades 1 a 3. |
| `food-store-tp-u4/` | FNBC, migración sin pérdida, desnormalización controlada y PDF de U4. |
| `food-store-tp-u5/` | Roles, autenticación bcrypt, auditoría, simulacro de incidente y PDF de U5. |
| `food-store-tp-u6/` | Respaldo, restauración probada, mantenimiento y PDF de U6. |
| `food-store-tp-u7/` | Modelo documental MongoDB, consultas y comparación con PostgreSQL; PDF de U7. |
| `food-store-tp-u8/` | Tablet SQLite, snapshot, semáforo, casos C1-C7, code review y PDF de U8. |
| `TPI/` | Informe técnico U4-U8, checklist de objetivos y DUIA consolidada. |

El informe de la segunda entrega es `TPI/INFORME_TECNICO_U4_U8.md`. La aplicación
web (`server.mjs`, `public/`) sigue siendo el gestor del proyecto.
