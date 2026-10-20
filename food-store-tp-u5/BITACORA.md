# Bitacora real de asistencia - U5

Revision del 20/10/2026. Asistente efectivo: Codex. Las afirmaciones anteriores
sobre revision humana y respuestas de IA no capturadas fueron sustituidas por
hechos verificables. No se atribuye a Kiro/OpenCode lo hecho con Codex.

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validacion o correccion humana aplicada |
|---|---|---|
| Usuario: revisar consignas U5/U6 y resolver con Railway. Parte A: reconstruir identidades y privilegios. | Codex preparo roles y funciones SECURITY DEFINER con propietario NOLOGIN y path fijo. | Pruebas automaticas efectivas en Railway; revision humana pendiente. El usuario instalo pgcrypto en foodstore. |
| Parte B: activar/verificar auditoria y capturar eventos. | Codex verifico la configuracion ya aplicada por el usuario y ejecuto lectura/INSERT/UPDATE con ROLLBACK y login motor fallido. | Logs reales del servidor. Se detecto exposicion de parametros sinteticos por RAISE LOG y se corrigio la configuracion de la sesion sensible. Revision humana pendiente. |
| Parte C: ejecutar fallos, exito, lectura masiva e intento de escalamiento. | Codex orquesto 3 fallos, 1 exito, 18 filas leidas y GRANT rechazado. | SQLSTATE 42501 y ausencia de membresia verificados automaticamente. Contraste escrito en informe_incidente.md; decision humana pendiente. |
| Parte D: comparar usuarios por rol/mes con tabla sintetizada. | Codex preparo ambas consultas con el mismo mes UTC y EXCEPT bidireccional. | Cero diferencias observado. No se confundieron meses historicos de cliente con fecha actual. Revision humana pendiente. |
| OpenCode: auditar SOLO el SQL adjunto, sin herramientas ni cambios; evaluar minimo privilegio/SECURITY DEFINER/defaults/GRANT ALL. | Error HTTP 400: esquema invalido de herramientas MCP. | Respuesta completa en docs/opencode_auditoria.jsonl. No se acepto como auditoria ni se invento una recomendacion insegura. |

## Error significativo real
El borrador daba CREATEDB/CREATEROLE a admin_datos y lectura automatica de tablas
futuras a reportes/aplicacion. Se corrigio a privilegios puntuales y objetos futuros
cerrados, para evitar exponer futuras credenciales. Ademas se verifico que un
REVOKE de EXECUTE por esquema no elimina el default global publico: se uso REVOKE
global y se probo creando una funcion temporal dentro de una transaccion revertida.
El defecto de parametros en RAISE LOG se corrigio tras observar logs reales, no
suponiendo que log_statement=none bastaba. Son correcciones de Codex pendientes de
validacion humana; no satisfacen por si solas el caso obligatorio de una propuesta
insegura efectivamente emitida por OpenCode.

## Pendientes de la consigna
Kiro no esta disponible: requirements/design son un plan redactado con Codex.
Faltan auditoria/reconstruccion efectivas de OpenCode, el contraste del estudiante,
y su revision humana. No se inventan esas evidencias. Git conserva avance por partes;
la reconstruccion del borrador inicial se mantiene en su historial.
