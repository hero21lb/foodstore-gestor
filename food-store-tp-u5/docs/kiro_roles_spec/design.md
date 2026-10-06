# Diseño - roles y permisos

`roles.sql` es idempotente para roles y explícito en revocaciones. Los roles de grupo (`NOLOGIN`) separan capacidades de las identidades de conexión. `app_web` hereda solo los grupos necesarios para funcionar; no puede crear roles ni bases.

La tabla `cliente` contiene datos personales. Por eso soporte recibe únicamente `id`, `nombre` y `apellido` mediante permiso de columna, mientras que `rol_reportes` queda pensado para consultas controladas. En un despliegue real se recomienda sumar vistas de reporte que minimicen aún más la exposición.

La administración de roles debe ejecutarse con una cuenta administrativa fuera de la aplicación. Las contraseñas y nombres de usuario reales no se incluyen en este repositorio.
