# Informe de incidente - Parte C

## Secuencia

El script ejecuta tres autenticaciones fallidas, intenta una autenticación exitosa con identidad sintética, realiza una lectura agregada de `cliente` y finalmente intenta que `app_web` otorgue la membresía `admin_datos`.

## Resultado esperado

El escalamiento debe fallar porque `app_web` no posee `CREATEROLE` ni membresía administrativa. Si la instancia devuelve éxito, se debe tratar como hallazgo y detener la entrega hasta corregir `roles.sql`.

## Lectura crítica de IA

La IA solo puede inferir lo que aparece en el log: intentos, identidad técnica, horarios, consultas y errores. No puede afirmar la causa humana, el origen real del atacante ni que una contraseña fue comprometida si el log no lo demuestra. La respuesta del asistente debe adjuntarse después de pasarle únicamente `log_simulacro_anonimizado.txt`.

## Contención decidida por el equipo

En un caso real se revocaría temporalmente la membresía sospechosa, se rotarían credenciales de `app_web`, se restringiría el origen de conexión y se preservaría una copia inmutable de los logs. Esa decisión la toma el equipo después de validar la evidencia; no se ejecuta automáticamente por una recomendación de IA.
