# Diseno de permisos y autenticacion

Plan previo del 20/10/2026: Codex, formato requirements/design. No atribuido a Kiro.
Se trabaja en foodstore, copia de railway. Los roles son globales al cluster;
una base separada protege datos, pero no vuelve locales los roles.

Grupos NOLOGIN separan lectura, escritura, soporte y reportes. app_web hereda
lectura/escritura; admin_datos hereda soporte/reportes y recibe privilegios
puntuales sobre atributos no secretos de usuario. Ambos LOGIN son NOSUPERUSER,
NOCREATEDB, NOCREATEROLE, NOREPLICATION y NOBYPASSRLS, sin ADMIN OPTION.

usuario contiene identidades sinteticas de aplicacion, independientes de cliente
y de roles del motor. Tiene rol y fecha_alta distribuidos en varios meses.
Passwords con bcrypt/pgcrypto. No se usa un mes inventado para todos los clientes.

fn_autenticar y fn_resetear_password son SECURITY DEFINER, propiedad de un rol
NOLOGIN con acceso solo a usuario. search_path fijo y nombres calificados evitan
sustitucion de objetos. Se revoca EXECUTE de PUBLIC; autenticar solo app_web,
reseteo solo admin_datos. Nunca se devuelve ni registra el hash.

ALTER DEFAULT PRIVILEGES deja tablas futuras cerradas y revoca EXECUTE publico
sobre funciones futuras. Evita abrir automaticamente nuevas tablas sensibles.
La verificacion incluye permisos efectivos y negaciones, no solo una matriz.

Auditoria global configurada manualmente por el usuario. Funciones emiten
U5_AUTH sin passwords. log_statement=mod no registra SELECT: el simulacro usa
log_statement=all en una sesion dedicada con parametros truncados a cero.
Anonimizar el log antes de enviarlo a IA. No se exponen claves ni hashes.
