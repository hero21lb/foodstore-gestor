-- Food Store - Unidad 5 / Parte C
-- Simulacro controlado en la propia base de desarrollo.
-- No intenta conectarse a un servidor externo ni contiene contraseñas reales.

\set ON_ERROR_STOP off
SELECT clock_timestamp() AS evento, 'SIMULACRO_INICIO' AS tipo;

DO $$
BEGIN
  IF to_regprocedure('fn_autenticar(text,text)') IS NOT NULL THEN
    FOR i IN 1..3 LOOP
      BEGIN
        PERFORM fn_autenticar('intruso' || i || '@sintetico.invalid', 'clave-fallida');
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'LOGIN_FALLIDO intento=% SQLSTATE=%', i, SQLSTATE;
      END;
    END LOOP;
    BEGIN
      PERFORM fn_autenticar('usuario-demo@sintetico.invalid', 'clave-demo');
      RAISE NOTICE 'LOGIN_EXITOSO usuario=usuario-demo@sintetico.invalid';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'LOGIN_EXITOSO_NO_VERIFICADO SQLSTATE=%', SQLSTATE;
    END;
  ELSE
    RAISE NOTICE 'fn_autenticar no existe: se documenta la ausencia sin inventar evidencia';
  END IF;
END $$;

-- Lectura masiva controlada: no imprime datos personales, solo cantidad y
-- columnas sintéticas para que el log no exponga información real.
SELECT count(*) AS usuarios_leidos, min(id) AS primer_id, max(id) AS ultimo_id
FROM cliente;

-- El rol de bajo privilegio no debe poder otorgar membresías.
SET ROLE app_web;
GRANT admin_datos TO app_web;
RESET ROLE;

SELECT clock_timestamp() AS evento, 'SIMULACRO_FIN' AS tipo;
