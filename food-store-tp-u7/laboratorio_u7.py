"""Preparacion y verificacion reproducible de U7; secretos solo en memoria."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time

import psycopg2
from psycopg2.extensions import parse_dsn
from bson import Decimal128, Int64, json_util
from pymongo import MongoClient, ASCENDING

ROOT = Path(__file__).resolve().parent
PROJECT = 'b26b03ee-46b4-434a-bf14-4629c5a3806e'
ENVIRONMENT = '790cff46-0c51-4815-addf-d76819554c83'
POSTGRES = 'b4e08230-038a-495f-833a-accc606fc3ae'
MONGO = 'fdf5f0f5-4d31-4363-9db7-fa887537086b'
CLI = Path(os.environ['APPDATA']) / 'npm/node_modules/@railway/cli/bin/railway.js'
ENV = dict(os.environ, RAILWAY_CALLER='skill:use-railway@1.7.0',
           RAILWAY_AGENT_SESSION='railway-foodstore-u7-20261027')
STATES = {1: 'PENDIENTE', 2: 'CONFIRMADO', 3: 'ENTREGADO',
          4: 'CANCELADO', 5: 'CONFIRMADO'}
IDS = list(STATES)
EVIDENCE = ROOT / 'evidencias'


def railway(*args):
    p = subprocess.run(['node', str(CLI), *args], env=ENV, capture_output=True,
                       text=True, timeout=60)
    if p.returncode:
        raise RuntimeError('Railway no completo la operacion; revisar sesion y servicio.')
    return json.loads(p.stdout)


def variables(service):
    return railway('variable', 'list', '--project', PROJECT,
                   '--environment', ENVIRONMENT, '--service', service, '--json')


def pg_connection():
    cfg = parse_dsn(variables(POSTGRES)['DATABASE_PUBLIC_URL'])
    conn = psycopg2.connect(**dict(cfg, dbname='foodstore', sslmode='require',
                                 connect_timeout=20, application_name='foodstore_u7'))
    return conn, cfg


def write_json(name, value):
    EVIDENCE.mkdir(exist_ok=True)
    (EVIDENCE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2,
                                          default=str) + '\n', encoding='utf-8')


def business_fingerprint(q):
    # Incluye todos los valores de negocio, pero no el nuevo campo estado.
    expressions = {
        'pedido': 'id, fecha, forma_pago, cliente_id',
        'detalle_pedido': 'id, cantidad, precio_unitario, pedido_id, producto_id',
        'cliente': 'id, nombre, apellido, mail, celular',
        'producto': 'id, nombre, descripcion, precio, stock, categoria_id, activo',
        'categoria': 'id, nombre, descripcion, activo',
    }
    result = {}
    for table, fields in expressions.items():
        q.execute(f'SELECT {fields} FROM public.{table} ORDER BY id')
        rows = q.fetchall()
        encoded = json.dumps(rows, default=str, ensure_ascii=False).encode()
        result[table] = {'filas': len(rows), 'sha256': hashlib.sha256(encoded).hexdigest()}
    return result


def backup(cfg):
    directory = ROOT / 'backups'
    directory.mkdir(exist_ok=True)
    dest = directory / ('foodstore_antes_u7_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '.dump')
    pg_bin = Path(os.environ['LOCALAPPDATA']) / 'Programs/FoodStore/PostgreSQL18/pgsql/bin'
    env = dict(os.environ, PGHOST=cfg['host'], PGPORT=cfg.get('port', '5432'),
               PGUSER=cfg['user'], PGPASSWORD=cfg['password'], PGDATABASE='foodstore',
               PGSSLMODE='require', PGCONNECT_TIMEOUT='20')
    for program, args in [('pg_dump', ['-Fc', '--no-owner', '--no-privileges', '-f', str(dest)]),
                          ('pg_restore', ['--list', str(dest)])]:
        p = subprocess.run([str(pg_bin / (program + '.exe')), *args], env=env,
                           capture_output=True, timeout=180)
        if p.returncode:
            raise RuntimeError(f'{program} no pudo validar el respaldo; no se modifica PostgreSQL.')
    return {'archivo': dest.name, 'bytes': dest.stat().st_size,
            'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}


def prepare_states():
    conn, cfg = pg_connection()
    try:
        # La preparacion no se ejecuta si no puede generarse un respaldo valido.
        saved = backup(cfg)
        with conn:
            with conn.cursor() as q:
                q.execute("SET LOCAL lock_timeout = '5s'")
                q.execute("SET LOCAL statement_timeout = '60s'")
                q.execute('LOCK TABLE public.pedido IN SHARE ROW EXCLUSIVE MODE')
                before = business_fingerprint(q)
                q.execute('SELECT id FROM public.pedido WHERE id=ANY(%s) ORDER BY id', (IDS,))
                if [r[0] for r in q.fetchall()] != IDS:
                    raise RuntimeError('No existen los cinco pedidos previstos; detenerse y revisar.')
                q.execute("SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='pedido' AND column_name='estado'")
                column = q.fetchone()
                if not column:
                    q.execute('ALTER TABLE public.pedido ADD COLUMN estado text')
                    q.execute("ALTER TABLE public.pedido ADD CONSTRAINT pedido_estado_u7_valido CHECK (estado IS NULL OR estado IN ('PENDIENTE','CONFIRMADO','ENTREGADO','CANCELADO'))")
                    q.execute("COMMENT ON COLUMN public.pedido.estado IS 'Agregado para laboratorio U7 el 2026-10-27. Estados de prueba en pedidos 1 a 5, no historicos; otros pedidos sin estado registrado.'")
                elif column[0] != 'text':
                    raise RuntimeError('estado tiene un tipo no previsto; no se modifica.')
                for order_id, state in STATES.items():
                    q.execute('SELECT estado FROM public.pedido WHERE id=%s', (order_id,))
                    current = q.fetchone()[0]
                    if current is not None and current != state:
                        raise RuntimeError(f'Pedido {order_id}: ya tiene otro estado; no se reemplaza.')
                    q.execute('UPDATE public.pedido SET estado=%s WHERE id=%s AND estado IS NULL', (state, order_id))
                after = business_fingerprint(q)
                if before != after:
                    raise RuntimeError('Cambio inesperado en datos previos: se revierte la transaccion.')
                q.execute('SELECT estado,count(*) FROM public.pedido GROUP BY estado ORDER BY estado NULLS LAST')
                distribution = q.fetchall()
        result = {'fecha_utc': datetime.now(timezone.utc).isoformat(),
                  'base': 'foodstore', 'respaldo': saved, 'datos_previos_sin_cambios': before == after,
                  'huellas_antes': before, 'huellas_despues': after,
                  'estados_sinteticos': STATES, 'distribucion_estados': distribution}
        write_json('preparacion_postgresql.json', result)
        return result
    finally:
        conn.close()


@contextmanager
def mongo_connection():
    v = variables(MONGO)
    # Tunel SSH privado: MongoDB no necesita un puerto publico adicional.
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        port = s.getsockname()[1]
    proc = subprocess.Popen(['node', str(CLI), 'connect', 'MongoDB', '--project', PROJECT,
                             '--environment', ENVIRONMENT, '--tunnel-only', '--port', str(port)],
                            env=ENV, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    client = None
    try:
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                raise RuntimeError('El tunel SSH de MongoDB no pudo iniciarse.')
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=1):
                    break
            except OSError:
                time.sleep(1)
        else:
            raise RuntimeError('Tiempo agotado abriendo el tunel privado MongoDB.')
        client = MongoClient('127.0.0.1', port, username=v['MONGOUSER'],
                             password=v['MONGOPASSWORD'], authSource='admin',
                             serverSelectionTimeoutMS=20000, tz_aware=True,
                             directConnection=True)
        client.admin.command('ping')
        yield client
    finally:
        if client:
            client.close()
        if os.name == 'nt' and proc.poll() is None:
            # El lanzador Node crea railway.exe y ssh.exe; cerrar todo el arbol.
            subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'],
                           capture_output=True, timeout=15)
        elif proc.poll() is None:
            proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


def source_documents():
    conn, _ = pg_connection()
    try:
        conn.set_session(readonly=True, isolation_level='REPEATABLE READ')
        with conn, conn.cursor() as q:
            q.execute('SELECT id,fecha,forma_pago,cliente_id,estado FROM public.pedido WHERE id=ANY(%s) ORDER BY id', (IDS,))
            orders = q.fetchall()
            if len(orders) != 5 or any(r[4] != STATES[r[0]] for r in orders):
                raise RuntimeError('Ejecutar preparar antes de migrar.')
            docs = []
            for order_id, date, payment, customer, state in orders:
                q.execute('SELECT d.id,d.producto_id,p.nombre,d.cantidad,d.precio_unitario FROM public.detalle_pedido d JOIN public.producto p ON p.id=d.producto_id WHERE d.pedido_id=%s ORDER BY d.id', (order_id,))
                lines = []
                total = Decimal('0.00')
                for detail, product, name, qty, price in q.fetchall():
                    if qty <= 0 or price < 0:
                        raise RuntimeError('Detalle invalido; no se migra.')
                    total += qty * price
                    lines.append({'detalle_id': Int64(detail), 'producto_id': Int64(product),
                                  'nombre': name, 'cantidad': qty,
                                  'precio_unitario': Decimal128(price),
                                  'subtotal': Decimal128(qty * price)})
                if not lines:
                    raise RuntimeError('Pedido sin detalles; revisar muestra.')
                docs.append({'_id': Int64(order_id), 'fecha': date,
                             'fecha_origen_iso': date.isoformat(), 'forma_pago': payment,
                             'estado': state,
                             'cliente': {'id': Int64(customer), 'alias': f'Cliente laboratorio {customer}'},
                             'lineas': lines, 'total': Decimal128(total),
                             'origen': {'base': 'foodstore', 'esquema': 'public',
                                        'estado_sintetico_u7': True,
                                        'cliente_seudonimizado': True}})
            return docs
    finally:
        conn.close()


def migrate():
    docs = source_documents()
    # BSON Date conserva milisegundos. fecha_origen_iso conserva tambien microsegundos.
    normalized = json_util.loads(json_util.dumps(docs, json_options=json_util.CANONICAL_JSON_OPTIONS))
    with mongo_connection() as client:
        db = client['foodstore_u7']
        validator = {'$jsonSchema': {'bsonType': 'object',
            'required': ['_id', 'fecha', 'fecha_origen_iso', 'estado', 'cliente', 'lineas', 'total', 'origen'],
            'properties': {'_id': {'bsonType': 'long'}, 'fecha': {'bsonType': 'date'},
                'estado': {'enum': ['PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'CANCELADO']},
                'total': {'bsonType': 'decimal', 'minimum': Decimal128('0')},
                'lineas': {'bsonType': 'array', 'minItems': 1, 'items': {
                    'bsonType': 'object', 'required': ['detalle_id', 'producto_id', 'cantidad', 'precio_unitario'],
                    'properties': {'cantidad': {'bsonType': 'int', 'minimum': 1},
                                   'precio_unitario': {'bsonType': 'decimal', 'minimum': Decimal128('0')}}}}}}}
        if 'pedidos' not in db.list_collection_names():
            db.create_collection('pedidos', validator=validator, validationLevel='strict', validationAction='error')
        col = db.pedidos
        existing = list(col.find().sort('_id', ASCENDING))
        if existing:
            if json_util.dumps(existing, sort_keys=True) != json_util.dumps(normalized, sort_keys=True):
                raise RuntimeError('La coleccion tiene documentos diferentes; no se reemplazan.')
        else:
            col.insert_many(normalized)
        col.create_index('estado', name='idx_estado_u7')
        col.create_index('lineas.producto_id', name='idx_producto_u7')
        col.create_index('total', name='idx_total_u7')
        actual = list(col.find().sort('_id', ASCENDING))
        if json_util.dumps(actual, sort_keys=True) != json_util.dumps(normalized, sort_keys=True):
            raise RuntimeError('Los documentos no coinciden con PostgreSQL.')
        product = docs[0]['lineas'][0]['producto_id']
        state = 'CONFIRMADO'
        threshold = Decimal('300.00')
        queries = {'todos': {}, 'estado': {'estado': state},
                   'producto': {'lineas.producto_id': product},
                   'total': {'total': {'$gt': Decimal128(threshold)}}}
        mongo_results = {name: [int(d['_id']) for d in col.find(query, {'_id': 1}).sort('_id', ASCENDING)]
                         for name, query in queries.items()}
        mongo_version = client.server_info()['version']
        indexes = sorted(col.index_information())
    conn, _ = pg_connection()
    try:
        conn.set_session(readonly=True)
        with conn, conn.cursor() as q:
            q.execute('SELECT id FROM public.pedido WHERE id=ANY(%s) AND estado=%s ORDER BY id', (IDS, state))
            by_state = [r[0] for r in q.fetchall()]
            q.execute('SELECT DISTINCT pedido_id FROM public.detalle_pedido WHERE pedido_id=ANY(%s) AND producto_id=%s ORDER BY pedido_id', (IDS, int(product)))
            by_product = [r[0] for r in q.fetchall()]
            q.execute('SELECT pedido_id FROM public.detalle_pedido WHERE pedido_id=ANY(%s) GROUP BY pedido_id HAVING SUM(cantidad*precio_unitario)>%s ORDER BY pedido_id', (IDS, threshold))
            by_total = [r[0] for r in q.fetchall()]
        expected = {'todos': IDS, 'estado': by_state, 'producto': by_product, 'total': by_total}
        if mongo_results != expected:
            raise RuntimeError('Las consultas no coinciden entre los motores.')
    finally:
        conn.close()
    EVIDENCE.mkdir(exist_ok=True)
    (EVIDENCE / 'pedidos_migrados.ejson').write_text(json_util.dumps(actual, indent=2, ensure_ascii=False,
        json_options=json_util.CANONICAL_JSON_OPTIONS), encoding='utf-8')
    result = {'fecha_utc': datetime.now(timezone.utc).isoformat(), 'mongodb_version': mongo_version,
              'base_destino': 'foodstore_u7', 'coleccion': 'pedidos', 'documentos': len(actual),
              'estados_de_prueba': STATES, 'indices': indexes,
              'parametros': {'ids': IDS, 'estado': state, 'producto_id': int(product), 'umbral': str(threshold)},
              'postgresql': expected, 'mongodb': mongo_results, 'coinciden': True,
              'documentos_identicos_al_origen_transformado': True,
              'alcance_comparacion': 'Solo los mismos cinco pedidos en ambos motores',
              'umbral_justificacion': '300 separa importes menores y mayores dentro de la muestra.',
              'conexion_mongodb': 'Tunel SSH efimero; sin proxy TCP publico'}
    write_json('verificacion.json', result)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('accion', choices=['preparar', 'migrar'])
    action = p.parse_args().accion
    result = prepare_states() if action == 'preparar' else migrate()
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        # No imprimir DSN ni detalles de errores de conexion con credenciales.
        print(f'ERROR U7 ({type(exc).__name__}): operacion detenida. Revisar el servicio y la etapa indicada.')
        raise SystemExit(1)
