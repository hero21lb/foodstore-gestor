# Verificación de equivalencia - Parte D

`usuario_anon.sql` genera nombres y correos sintéticos deterministas a partir del identificador interno. La comparación usa la misma clave de agrupamiento (`rol`, `mes_alta`) y únicamente cuenta filas.

## Consulta anonimizada

```sql
SELECT rol, mes_alta, count(*) AS cantidad
FROM usuario_anon GROUP BY rol, mes_alta ORDER BY rol, mes_alta;
```

## Consulta sobre la fuente

```sql
SELECT 'cliente' AS rol, date_trunc('month', current_date)::date AS mes_alta,
       count(*) AS cantidad
FROM cliente GROUP BY 1, 2 ORDER BY 1, 2;
```

Los resultados deben compararse fila por fila: mismos grupos y mismos conteos. La tabla anonimizada no debe exportarse junto con `mail`, `celular`, nombres reales ni credenciales.

La información que nunca debe enviarse directamente a una IA incluye correos, celulares, nombres y apellidos reales, credenciales, tokens, direcciones IP identificables y logs sin anonimizar. Primero se reemplazan por valores sintéticos y se conserva solo la información necesaria para el análisis.
