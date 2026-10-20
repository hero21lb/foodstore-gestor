# Reglas del laboratorio U6

- Leer SPEC_U6.md antes de editar o ejecutar.
- foodstore es la fuente; no eliminarla ni restaurar sobre ella.
- Restaurar exclusivamente en una base nueva foodstore_restore_test.
- Si esa base existe, detenerse. No usar DROP, --clean ni terminar sesiones.
- Usar pg_dump -Fc y pg_restore --exit-on-error --no-owner --no-privileges.
- Credenciales por entorno efimero; no escribirlas ni registrarlas.
- Registrar resultados reales. No atribuir a una herramienta lo que no ejecuto.
- VACUUM FULL no es mantenimiento periodico. Justificar cualquier ANALYZE.
