"""Cliente del laboratorio: credenciales efimeras desde Railway, nunca en disco."""
import argparse
from datetime import datetime, timezone
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import time

import psycopg2
from psycopg2 import sql
from psycopg2.extensions import parse_dsn

ROOT = Path(__file__).resolve().parent
CLIENT = Path(os.environ.get('PG_BIN', str(Path(os.environ.get('LOCALAPPDATA', '.')) / 'Programs/FoodStore/PostgreSQL18/pgsql/bin')))
SCOPE = ['--project', 'b26b03ee-46b4-434a-bf14-4629c5a3806e',
         '--environment', '790cff46-0c51-4815-addf-d76819554c83',
         '--service', 'b4e08230-038a-495f-833a-accc606fc3ae']
TABLES = ['categoria', 'producto', 'cliente', 'pedido', 'detalle_pedido']


def credentials():
    if os.environ.get('DATABASE_PUBLIC_URL'):
        return parse_dsn(os.environ['DATABASE_PUBLIC_URL'])
    cli = Path(os.environ['APPDATA']) / 'npm/node_modules/@railway/cli/bin/railway.js'
    env = dict(os.environ, RAILWAY_CALLER='skill:use-railway@1.7.0',
               RAILWAY_AGENT_SESSION='railway-foodstore-tps-20261020')
    p = subprocess.run(['node', str(cli), 'variable', 'list', *SCOPE, '--json'],
                       capture_output=True, text=True, env=env)
    if p.returncode:
        raise RuntimeError('No se pudieron obtener las credenciales de Railway. Revisar railway login.')
    return parse_dsn(json.loads(p.stdout)['DATABASE_PUBLIC_URL'])


def connect(params, database):
    return psycopg2.connect(**dict(params, dbname=database, sslmode='require',
                                  connect_timeout=20, application_name='foodstore_laboratorio'))


def run_client(program, params, database, *args, capture=True):
    env = dict(os.environ, PGHOST=params['host'], PGPORT=params.get('port', '5432'),
               PGUSER=params['user'], PGPASSWORD=params['password'], PGDATABASE=database,
               PGSSLMODE='require', PGCONNECT_TIMEOUT='20', PGCLIENTENCODING='UTF8',
               PGAPPNAME='foodstore_laboratorio')
    target = ['--dbname', database] if program == 'pg_restore' and '--list' not in args else []
    executable = CLIENT / (program + '.exe')
    binary = str(executable) if executable.is_file() else shutil.which(program)
    if not binary:
        raise RuntimeError(f'Falta {program}; definir PG_BIN o agregar clientes PostgreSQL 18+ al PATH.')
    result = subprocess.run([binary, *target, *map(str, args)],
                            env=env, capture_output=capture, text=capture,
                            encoding='utf-8' if capture else None, errors='replace' if capture else None)
    if result.returncode:
        # No volcar variables, URL o contrasenas al log.
        message = (result.stderr or '') if capture else 'Ver salida de la consola.'
        message = message.replace(params['password'], '[REDACTADO]')
        raise RuntimeError(f'{program} fallo ({result.returncode}): {message}')
    return result.stdout if capture else ''


def counts(params, database):
    with connect(params, database) as c, c.cursor() as q:
        return {table: _count(q, table) for table in TABLES}


def _count(q, table):
    q.execute(sql.SQL('SELECT count(*) FROM {}').format(sql.Identifier(table)))
    return q.fetchone()[0]


def backup(params, database):
    out = ROOT / 'backups'
    out.mkdir(exist_ok=True)
    started = datetime.now(timezone.utc)
    stamp = started.strftime('%Y%m%dT%H%M%SZ')
    dest = out / f'{database}_{stamp}.dump'
    baseline = counts(params, database)
    run_client('pg_dump', params, database, '-Fc', '--no-owner', '--no-privileges', '-f', dest)
    run_client('pg_restore', params, database, '--list', dest)
    metadata = dict(database=database, backup_utc=started.isoformat(),
                    completed_utc=datetime.now(timezone.utc).isoformat(),
                    path=dest.name, bytes=dest.stat().st_size, counts=baseline)
    dest.with_suffix('.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    log = ROOT / 'logs'
    log.mkdir(exist_ok=True)
    (log / f'backup_{stamp}.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print(json.dumps(metadata, ensure_ascii=False))
    return dest, metadata


def clone(params):
    c = connect(params, 'railway')
    c.autocommit = True
    with c.cursor() as q:
        q.execute("SELECT 1 FROM pg_database WHERE datname='foodstore'")
        if q.fetchone():
            raise RuntimeError('foodstore ya existe; no se reemplaza. Usar estado o consola.')
    dest, metadata = backup(params, 'railway')
    with c.cursor() as q:
        q.execute('CREATE DATABASE foodstore TEMPLATE template0')
    c.close()
    run_client('pg_restore', params, 'foodstore', '--exit-on-error', '--no-owner', '--no-privileges', dest)
    actual = counts(params, 'foodstore')
    if actual != metadata['counts']:
        raise RuntimeError('Los conteos de la copia no coinciden. Conservar la copia para diagnostico.')
    print('Copia foodstore creada y verificada:', actual)


def status(params, database):
    with connect(params, database) as c, c.cursor() as q:
        q.execute('SELECT version(), current_database(), current_user')
        print(q.fetchone())
        q.execute("SELECT schemaname,tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY 1,2")
        print('Tablas:', q.fetchall())
    print('Filas:', counts(params, database))


def restore_test(params):
    backups = sorted((ROOT / 'backups').glob('foodstore_*.dump'))
    if not backups:
        raise RuntimeError('Primero ejecutar respaldo sobre foodstore.')
    dump = backups[-1]
    meta = json.loads(dump.with_suffix('.json').read_text(encoding='utf-8'))
    c = connect(params, 'postgres')
    c.autocommit = True
    with c.cursor() as q:
        q.execute("SELECT 1 FROM pg_database WHERE datname='foodstore_restore_test'")
        if q.fetchone():
            raise RuntimeError('foodstore_restore_test ya existe. No se elimina automaticamente.')
        started = datetime.now(timezone.utc)
        tick = time.perf_counter()
        q.execute('CREATE DATABASE foodstore_restore_test TEMPLATE template0')
    c.close()
    run_client('pg_restore', params, 'foodstore_restore_test', '--exit-on-error',
               '--no-owner', '--no-privileges', dump)
    actual = counts(params, 'foodstore_restore_test')
    with connect(params, 'foodstore_restore_test') as c, c.cursor() as q:
        q.execute('SELECT count(*) FROM producto WHERE precio<0 OR stock<0')
        bad_products = q.fetchone()[0]
        q.execute('SELECT count(*) FROM detalle_pedido WHERE cantidad<=0 OR precio_unitario<0')
        bad_details = q.fetchone()[0]
    if actual != meta['counts'] or bad_products or bad_details:
        raise RuntimeError('La restauracion no paso las validaciones. Conservar para diagnostico.')
    result = dict(backup=dump.name, started_utc=started.isoformat(),
                  rto_seconds=round(time.perf_counter()-tick, 3),
                  backup_age_seconds=round((started-datetime.fromisoformat(meta['backup_utc'])).total_seconds(),3),
                  counts=actual, invalid_products=bad_products, invalid_details=bad_details)
    (ROOT/'logs/restore_test.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['estado', 'consola', 'respaldo', 'crear-copia', 'restaurar-prueba', 'sql'])
    p.add_argument('--database', default='foodstore', choices=['railway', 'foodstore', 'foodstore_restore_test', 'foodstore_u5_lab'])
    p.add_argument('--file', type=Path)
    a = p.parse_args()
    params = credentials()
    if a.action == 'estado': status(params, a.database)
    elif a.action == 'consola': run_client('psql', params, a.database, '-X', capture=False)
    elif a.action == 'respaldo': backup(params, a.database)
    elif a.action == 'crear-copia': clone(params)
    elif a.action == 'restaurar-prueba': restore_test(params)
    elif a.action == 'sql':
        if a.database == 'railway':
            raise RuntimeError('Usar foodstore para scripts del laboratorio; railway se conserva como fuente.')
        if not a.file or not a.file.is_file(): raise RuntimeError('Indicar --file con un SQL existente.')
        print(run_client('psql', params, a.database, '-X', '-v', 'ON_ERROR_STOP=1', '-f', a.file))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
