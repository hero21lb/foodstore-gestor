"""Pruebas reales U5 en foodstore. Credenciales efimeras, filas sinteticas."""
import json
from datetime import datetime, timezone
from pathlib import Path
import secrets
import sys
import psycopg2
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'laboratorio'))
import railway_client as db
ROOT=Path(__file__).resolve().parent
DOC=ROOT/'docs'

def main():
 p=db.credentials(); DOC.mkdir(exist_ok=True)
 c=db.connect(p,'foodstore');c.autocommit=True
 with c.cursor() as q:
  q.execute("SELECT to_regclass('public.usuario')")
  installed=q.fetchone()[0] is not None
 if not installed:
  output=db.run_client('psql',p,'foodstore','-X','-v','ON_ERROR_STOP=1','-f',ROOT/'sql/roles.sql')
  (DOC/'verificacion_roles.txt').write_text(output,encoding='utf-8')
 # Esta prueba modifica tablas de laboratorio, no los clientes ni las ventas.
 events=[]
 def event(name,**details):events.append(dict(utc=datetime.now(timezone.utc).isoformat(),evento=name,**details))
 with c.cursor() as q:
  q.execute("SET application_name='foodstore_u5_simulacro'")
  q.execute("SET log_statement='none'")
  # RAISE LOG puede incluir STATEMENT aun con log_statement=none.
  q.execute("SET log_min_error_statement='panic'")
  q.execute('SET log_parameter_max_length=0');q.execute('SET log_parameter_max_length_on_error=0')
  password=secrets.token_urlsafe(24)
  q.execute('SET SESSION AUTHORIZATION admin_datos')
  q.execute('SELECT fn_resetear_password(%s,%s)',(1,password))
  q.execute('RESET SESSION AUTHORIZATION')
  q.execute('SET SESSION AUTHORIZATION app_web')
  for n in range(3):
   q.execute('SELECT fn_autenticar(%s,%s)',('persona1@example.invalid',secrets.token_urlsafe(24)))
   assert q.fetchone()[0] is None
   event('autenticacion_fallida',intento=n+1)
  q.execute('SELECT fn_autenticar(%s,%s)',('persona1@example.invalid',password))
  assert q.fetchone()[0]==1;event('autenticacion_exitosa')
  # Volver al administrador solo para cambiar configuracion de la sesion.
  q.execute('RESET SESSION AUTHORIZATION');q.execute("SET log_statement='all'")
  q.execute('SET SESSION AUTHORIZATION app_web')
  q.execute('SELECT id,nombre,mail,rol,fecha_alta,activo FROM usuario')
  rows=q.fetchall();assert len(rows)==18;event('lectura_masiva_usuario',filas=len(rows))
  c.autocommit=False
  try:
   q.execute('GRANT admin_datos TO app_web')
  except psycopg2.Error as exc:
   code=exc.pgcode;c.rollback();assert code=='42501';event('escalamiento_rechazado',sqlstate=code)
  else:
   c.rollback();raise RuntimeError('Fallo critico: escalamiento permitido')
  c.autocommit=True
  for label,query in [('hash_denegado','SELECT password_hash FROM usuario'),('delete_denegado','DELETE FROM pedido WHERE false'),('reset_denegado',"SELECT fn_resetear_password(1,'valor-sintetico-no-secreto')")]:
   try:q.execute(query)
   except psycopg2.Error as exc:
    assert exc.pgcode=='42501';event(label,sqlstate=exc.pgcode)
   else:raise RuntimeError(label+' no fallo')
  q.execute('SELECT count(*) FROM producto');assert q.fetchone()[0]==1000;event('lectura_producto_permitida')
  q.execute('RESET SESSION AUTHORIZATION')
  q.execute('SET SESSION AUTHORIZATION rol_soporte')
  q.execute('SELECT id,nombre,apellido FROM cliente LIMIT 1');q.fetchall();event('soporte_columnas_permitidas')
  try:q.execute('SELECT mail FROM cliente LIMIT 1')
  except psycopg2.Error as exc:assert exc.pgcode=='42501';event('soporte_mail_denegado',sqlstate=exc.pgcode)
  else:raise RuntimeError('Soporte lee mail')
  q.execute('RESET SESSION AUTHORIZATION')
  c.autocommit=False
  q.execute('CREATE TABLE public.u5_default_test(id integer)')
  q.execute("SELECT has_table_privilege('app_web','public.u5_default_test','SELECT')")
  assert not q.fetchone()[0];event('tabla_futura_cerrada')
  q.execute('CREATE FUNCTION public.u5_default_function() RETURNS int LANGUAGE sql AS $$SELECT 1$$')
  q.execute("SELECT has_function_privilege('app_web','public.u5_default_function()','EXECUTE')")
  assert not q.fetchone()[0];event('funcion_futura_cerrada')
  c.rollback();c.autocommit=True
 c.close()
 output=db.run_client('psql',p,'foodstore','-X','-v','ON_ERROR_STOP=1','-f',ROOT/'sql/auditoria_test.sql')
 (DOC/'salida_auditoria.txt').write_text(output,encoding='utf-8')
 try:
  bad=psycopg2.connect(**dict(p,dbname='foodstore',user='u5_login_inexistente',password=secrets.token_urlsafe(24),sslmode='require',connect_timeout=20,application_name='foodstore_u5_login_fallido'))
 except psycopg2.OperationalError:
  event('conexion_motor_rechazada')
 else:
  bad.close();raise RuntimeError('Login inexistente aceptado')
 output=db.run_client('psql',p,'foodstore','-X','-v','ON_ERROR_STOP=1','-f',ROOT/'sql/usuario_anon.sql')
 (DOC/'verificacion_equivalencia.txt').write_text(output,encoding='utf-8')
 with db.connect(p,'foodstore') as c,c.cursor() as q:
  q.execute("SELECT count(*) FROM ((SELECT rol,date_trunc('month',fecha_alta AT TIME ZONE 'UTC')::date,count(*) FROM usuario GROUP BY 1,2 EXCEPT SELECT rol,mes_alta,count(*) FROM usuario_anon GROUP BY 1,2) UNION ALL (SELECT rol,mes_alta,count(*) FROM usuario_anon GROUP BY 1,2 EXCEPT SELECT rol,date_trunc('month',fecha_alta AT TIME ZONE 'UTC')::date,count(*) FROM usuario GROUP BY 1,2)) x")
  assert q.fetchone()[0]==0
  q.execute("SELECT pg_has_role('app_web','admin_datos','MEMBER')")
  assert not q.fetchone()[0]
 event('equivalencia_verificada',diferencias=0)
 (DOC/'pruebas_reales.json').write_text(json.dumps(events,indent=2),encoding='utf-8')
 print(json.dumps(events,indent=2))

if __name__=='__main__':main()
