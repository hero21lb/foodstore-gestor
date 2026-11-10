# U5 - Revisión humana de la auditoría de permisos

**Responsable:** Lemus Nahuel
**Fecha de revisión:** 10/11/2026
**Alcance:** `sql/roles.sql`, `docs/verificacion_roles.txt`,
`docs/informe_auditoria.md`, `docs/informe_incidente.md`,
`docs/opencode_auditoria.jsonl`.

## Qué se revisó

1. `persona`/`usuario` sintéticos: no se leen hashes ni datos personales.
2. `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`:
   permisos por tabla y por columna.
3. `app_web` y `admin_datos`: `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`,
   `NOREPLICATION`, `NOBYPASSRLS`, sin `ADMIN OPTION`.
4. `fn_autenticar` y `fn_resetear_password`: `SECURITY DEFINER`, `search_path`
   fijo, propietario `NOLOGIN`, `EXECUTE` revocado de `PUBLIC`.
5. Simulacro: 3 fallos, 1 éxito, 18 filas leídas sin hash, `GRANT` rechazado
   con SQLSTATE 42501.
6. `RAISE LOG`: se corrigió la exposición de parámetros sintéticos.

## Decisión

| Propuesta | Decisión | Motivo |
|---|---|---|
| `CREATEDB`/`CREATEROLE` para `admin_datos` | **Rechazada** | Viola mínimo privilegio; no los necesita para operar. |
| Lectura automática de tablas futuras para `reportes`/`app` | **Rechazada** | Una tabla futura sensible quedaría expuesta sin revisión. |
| `GRANT ALL` sobre el esquema | **Rechazada** | Incluye DDL y privilegios no requeridos. |
| Esquema de roles por grupo + propietario de funciones | **Aceptada** | Permite mínimo privilegio y separa autenticación. |
| `SECURITY DEFINER` con `search_path` fijo | **Aceptada** | Evita sustitución de objetos y mantiene el hash fuera del cliente. |
| Auditoría global + simulacro | **Aceptada** | Hay logs y pruebas efectivas, no solo una matriz teórica. |

## OpenCode

Se intentó una auditoría del SQL con OpenCode. La herramienta devolvió HTTP 400
por un esquema MCP incompatible. El error completo está en
`docs/opencode_auditoria.jsonl`. **No se aceptó como auditoría ni se inventó una
respuesta.** La revisión humana anterior es la decisión válida para esta
entrega; la intervención de OpenCode queda registrada como intento fallido.

## Qué falta para una entrega ideal

- Reemplazar el intento fallido de OpenCode por una sesión válida sobre el log
  anonimizado, si la cátedra exige esa herramienta en particular.
- Firmar esta revisión en la defensa oral.

Firma: ______________________________
