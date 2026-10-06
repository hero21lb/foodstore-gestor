# Especificación de requisitos - roles Food Store

## Alcance

La política aplica a la base de desarrollo de Food Store en PostgreSQL 16 o superior. Se adopta mínimo privilegio y se evita almacenar contraseñas en Git.

## Roles

| Rol | Necesidad | Permiso justificado |
|---|---|---|
| `rol_app_lectura` | Consultar el catálogo y el estado de pedidos | `SELECT` sobre las tablas operativas; no modifica datos ni administra roles. |
| `rol_app_escritura` | Registrar pedidos y actualizar productos | `SELECT` para validar referencias y `INSERT/UPDATE` solo sobre las operaciones de negocio necesarias. |
| `rol_soporte` | Diagnosticar la aplicación | Consulta auditoría y datos mínimos de cliente; no accede a correo/celular ni modifica tablas. |
| `rol_reportes` | Ejecutar reportes | `SELECT` sobre tablas operativas; no escribe ni otorga privilegios. |
| `app_web` | Identidad de conexión de la aplicación | Hereda lectura/escritura, sin `CREATEROLE`, `CREATEDB` ni superusuario. |
| `admin_datos` | Administrar datos y delegaciones controladas | Identidad administrativa separada de la aplicación; las credenciales se gestionan fuera del repositorio. |

## Criterios de aceptación

1. `PUBLIC` no conserva privilegios sobre el esquema ni las tablas.
2. Existe al menos un `GRANT` a nivel de columna.
3. Los privilegios por defecto protegen tablas futuras.
4. La salida de `\du` y de `information_schema.role_table_grants` permite verificar la política.
