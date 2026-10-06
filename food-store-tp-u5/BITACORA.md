# Bitácora de uso de IA - Unidad 5

> Esta bitácora registra el trabajo asistido realizado en el repositorio. Las evidencias de ejecución contra PostgreSQL deben completarse con los resultados de la instancia local.

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Revisar el esquema de Food Store y diseñar roles de mínimo privilegio. | Propuso separar roles de grupo de las identidades de login y negar privilegios a `PUBLIC`. | Se verificó que el esquema real usa `cliente` y no `usuario`; se ajustaron los permisos a las tablas existentes. |
| Auditar `roles.sql` y sugerir mejoras. | Sugirió simplificar con `GRANT ALL` para evitar errores de la aplicación. | Se rechazó la propuesta por ser más amplia de lo necesario; se mantuvieron privilegios puntuales y un permiso de columna. Este es el error inseguro más significativo detectado. |
| Diseñar una prueba de auditoría. | Recomendó `log_connections`, `log_disconnections`, `log_statement=mod` y un prefijo con usuario/base/cliente. | Se conservó la configuración y se aclaró que el log nativo no prueba detalle fila por fila. |
| Reconstruir el incidente desde un log anonimizado, sin contexto adicional. | La reconstrucción debe limitarse a eventos observables y proponer contención como hipótesis. | Se documentó que fechas, causa humana y compromiso de credenciales no pueden afirmarse sin evidencia. |
| Proponer una consulta agregada equivalente sobre datos anonimizados. | Comparar conteos agrupados por rol y mes de alta. | Como U1-U4 no conserva una tabla `usuario`, se usó `cliente` como fuente disponible y se dejó explícita la adaptación. |

## Validación final

La ejecución debe hacerse exclusivamente sobre la base de desarrollo. Antes de entregar se deben sustituir las evidencias de referencia por logs y resultados reales, anonimizados, y verificar que el intento de escalamiento falla.

## Historial Git

El trabajo se organizó por partes en archivos separados. Si la entrega requiere commits visibles por parte, se recomienda confirmar en GitHub Desktop los commits `Parte A`, `Parte B`, `Parte C`, `Parte D` y `Parte E` antes de publicar.
