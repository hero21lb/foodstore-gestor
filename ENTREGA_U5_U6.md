# FoodStore - U5 y U6 sobre Railway

20/10/2026. Proyecto postgrefacu, servicio Postgres, PostgreSQL 18.6.
La base railway original se conserva. foodstore es la copia de trabajo.

## Resultado tecnico
- U5: roles de minimo privilegio, usuario y funciones reconstruidas, bcrypt,
  auditoria real y simulacro. Escalamiento denegado 42501; hashes inaccesibles,
  soporte sin correo, objetos futuros cerrados. Agregados equivalentes.
- U6: dump custom de 321577 bytes y restauracion en foodstore_restore_test;
  20 categorias, 1000 productos, 5000 clientes, 20000 pedidos y 20000 detalles.
  Coinciden conteos y contenido; cero invalidos; RTO 32,224 s; antiguedad 263,558 s.

## Archivos
U5: food-store-tp-u5/sql/, laboratorio_u5.py, docs/ y BITACORA.md.
U6: food-store-tp-u6/SPEC_U6.md, scripts y un informe_u6.pdf de una pagina.
Cliente comun: laboratorio/railway_client.py; requisitos: laboratorio/requirements.txt.
Credenciales solo por entorno o Railway CLI autenticado. No hay passwords de
LOGIN permanentes para app_web/admin_datos. No adjuntar dumps ni datos privados.
Los logs adjuntos contienen metadatos, conteos y datos sinteticos anonimizados.

## Ejecucion
Dentro de foodstore-gestor, con Python/psycopg2-binary y clientes PostgreSQL 18:

    python food-store-tp-u5/laboratorio_u5.py
    powershell -File food-store-tp-u6/backup_foodstore.ps1
    python food-store-tp-u6/laboratorio_u6.py health
    python food-store-tp-u6/laboratorio_u6.py maintenance
    powershell -File food-store-tp-u6/restore_test.ps1

roles.sql es instalacion inicial: no repetir CREATE ROLE sobre roles existentes.
El runner detecta usuario existente y ejecuta pruebas sin reinstalar.
restore_test se detiene si foodstore_restore_test ya existe: no la borra.
El dump utilizado por el informe U6 precede a la reconstruccion sintetica de U5;
el informe identifica su nombre y fecha exactos. No se afirma que ese ensayo
incluya las nuevas identidades de U5 ni la recuperacion de roles globales.

## Pendientes para entrega academica completa
La consigna requiere Kiro y OpenCode y validacion humana. El plan fue escrito
con Codex, no con Kiro. OpenCode se intento pero fallo por HTTP 400 de esquemas
MCP; su error completo queda registrado. Faltan sus intervenciones validas, la
reconstruccion del log por esa herramienta y la revision/decision del estudiante.
No se inventaron respuestas, errores de IA ni revisiones humanas. El trabajo
tecnico esta probado; estos requisitos de proceso siguen pendientes.
