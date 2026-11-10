# DUIA - Declaración y bitácora de uso de IA

## Alcance

La IA se utilizó como apoyo para leer el enunciado, proponer alternativas SQL,
revisar compatibilidad con el esquema previo y redactar pruebas reproducibles.
La decisión final sobre qué aceptar, descartar y cómo justificarlo corresponde
al estudiante.

## Interacciones registradas

1. **Lectura del enunciado:** se identificaron las consignas de índices, vistas,
   vista materializada, mediciones, especificaciones y bitácora.
2. **Revisión del proyecto anterior:** se detectaron dos variantes heredadas del
   esquema. Se aceptó `schema_completo.sql` como fuente de verdad porque coincide
   con `queries.sql`, `indices.sql` y los nombres `detalle_pedido`/`mail`.
3. **Propuesta de índices:** se aceptaron índices para fecha, producto y nombre
   activo. Se rechazó el índice adicional sobre `pedido(cliente_id)` por ser
   redundante con `idx_pedido_cliente`.
4. **Propuesta de vistas:** se aceptaron tres vistas de reportes y una vista
   materializada de facturación mensual por categoría. Se ocultaron credenciales;
   en este modelo la tabla cliente no contiene columna contraseña.
5. **Verificación:** se dejaron consultas equivalentes y comandos EXPLAIN en el
   informe para ejecutar sobre la base con volumen masivo.
