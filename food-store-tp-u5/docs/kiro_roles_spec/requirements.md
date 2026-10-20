# Requisitos de roles Food Store - revision 20/10/2026

Plan previo: redactado con Codex en formato requirements/design. No se afirma
que Kiro lo haya generado; esa herramienta no esta disponible en esta sesion.

| Rol | Permisos necesarios y justificacion |
|---|---|
| rol_app_lectura | SELECT de catalogo/ventas y columnas publicas de usuario para la aplicacion |
| rol_app_escritura | INSERT/UPDATE de producto, pedido y detalle; lectura de referencias; sin DELETE |
| rol_soporte | Diagnostico de stock/ventas y solo id/nombre/apellido de cliente; sin correo/celular |
| rol_reportes | Lectura de catalogo/ventas y id/rol/fecha_alta de usuario; sin PII ni hashes |
| app_web | Hereda lectura/escritura; LOGIN sin facultades administrativas |
| admin_datos | Soporte/reportes, actualizacion de estado/rol y reseteo controlado de passwords |
| foodstore_auth_owner | NOLOGIN propietario de funciones de autenticacion; solo acceso a usuario |

Criterios de aceptacion: ningun rol funcional lee password_hash; app_web no
concede roles ni borra ventas; no se otorga CREATEDB/CREATEROLE ni ADMIN OPTION.
PUBLIC sin accesos. Las tablas futuras quedan cerradas por defecto; funciones
futuras no heredan EXECUTE publico. Verificar con du, role_table_grants,
role_column_grants y pruebas efectivas positivas/negativas.
