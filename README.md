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
