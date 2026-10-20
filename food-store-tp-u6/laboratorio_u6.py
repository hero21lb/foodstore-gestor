"""Respaldo/restore controlado. Usar el cliente compartido sin guardar secretos."""
from datetime import datetime, timezone
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'laboratorio'))
import railway_client as db

ROOT=Path(__file__).resolve().parent

def save(name, data):
    (ROOT/'logs').mkdir(exist_ok=True)
    (ROOT/'logs'/name).write_text(json.dumps(data,indent=2,ensure_ascii=False,default=str),encoding='utf-8')

def fingerprint(params, database):
    result={}
    with db.connect(params,database) as c,c.cursor() as q:
        for table in db.TABLES:
            # Solo se guarda un resumen criptografico: no se exportan filas al log.
            q.execute(db.sql.SQL("SELECT count(*), md5(string_agg(md5(row_to_json(t)::text),'' ORDER BY id)) FROM {} t").format(db.sql.Identifier(table)))
            count,digest=q.fetchone(); result[table]={'count':count,'md5':digest}
    return result

def backup(params):
    out=ROOT/'backups';out.mkdir(exist_ok=True)
    started=datetime.now(timezone.utc)
    stamp=started.strftime('%Y%m%dT%H%M%S_%fZ')
    dest=out/f'foodstore_{stamp}.dump'
    # Compartir snapshot entre pg_dump y la evidencia evita comparar cortes distintos.
    c=db.connect(params,'foodstore')
    c.set_session(isolation_level='REPEATABLE READ',readonly=True)
    with c.cursor() as q:
        q.execute('SELECT pg_export_snapshot()');snapshot=q.fetchone()[0]
        rows={}
        for table in db.TABLES:
            q.execute(db.sql.SQL("SELECT count(*),md5(string_agg(md5(row_to_json(t)::text),'' ORDER BY id)) FROM {} t").format(db.sql.Identifier(table)))
            n,h=q.fetchone();rows[table]={'count':n,'md5':h}
        output=db.run_client('pg_dump',params,'foodstore','-Fc','--snapshot',snapshot,'-f',dest)
    c.rollback();c.close()
    listing=db.run_client('pg_restore',params,'foodstore','--list',dest)
    (ROOT/'logs'/f'{stamp}_contenido_dump.txt').write_text(listing,encoding='utf-8')
    result={'backup':dest.name,'started_utc':started.isoformat(),
            'completed_utc':datetime.now(timezone.utc).isoformat(),'bytes':dest.stat().st_size,
            'format':'custom','exit_code':0,'snapshot_compartido':True,'tables':rows}
    dest.with_suffix('.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    save(f'backup_{stamp}.json',result)
    print(json.dumps(result,ensure_ascii=False))

def restore(params):
    files=sorted((ROOT/'backups').glob('foodstore_*.dump'))
    if not files:raise RuntimeError('Falta respaldo: ejecutar backup primero.')
    dump=files[-1];meta=json.loads(dump.with_suffix('.json').read_text(encoding='utf-8'))
    c=db.connect(params,'postgres');c.autocommit=True
    with c.cursor() as q:
        q.execute("SELECT 1 FROM pg_database WHERE datname='foodstore_restore_test'")
        if q.fetchone():raise RuntimeError('foodstore_restore_test existe: no se sobrescribe. Conservar o renombrar manualmente el ensayo anterior.')
        started=datetime.now(timezone.utc);tick=time.perf_counter()
        q.execute('CREATE DATABASE foodstore_restore_test TEMPLATE template0')
    c.close()
    db.run_client('pg_restore',params,'foodstore_restore_test','--exit-on-error','--no-owner','--no-privileges',dump)
    actual=fingerprint(params,'foodstore_restore_test')
    with db.connect(params,'foodstore_restore_test') as c,c.cursor() as q:
        q.execute('SELECT count(*) FROM producto WHERE precio<0 OR stock<0');bad_product=q.fetchone()[0]
        q.execute('SELECT count(*) FROM detalle_pedido WHERE cantidad<=0 OR precio_unitario<0');bad_detail=q.fetchone()[0]
        q.execute("SELECT count(*) FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype IN ('p','f','u','c')");constraints=q.fetchone()[0]
    elapsed=time.perf_counter()-tick
    ok=actual==meta['tables'] and bad_product==0 and bad_detail==0
    result={'backup':dump.name,'backup_started_utc':meta['started_utc'],'started_utc':started.isoformat(),
            'completed_utc':datetime.now(timezone.utc).isoformat(),'rto_seconds':round(elapsed,3),
            'backup_age_seconds':round((started-datetime.fromisoformat(meta['started_utc'])).total_seconds(),3),
            'expected':meta['tables'],'restored':actual,'invalid_products':bad_product,
            'invalid_details':bad_detail,'restored_constraints':constraints,'ok':ok}
    save('restore_resultado.json',result);print(json.dumps(result))
    if not ok:raise RuntimeError('Restore o validaciones no coinciden. Conservar diagnostico.')

def main():
    (ROOT/'logs').mkdir(exist_ok=True)
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['backup','restore','health','maintenance'])
    a=parser.parse_args();params=db.credentials()
    try:
        if a.action=='backup':backup(params)
        elif a.action=='restore':restore(params)
        else:
            path=ROOT/('health_check.sql' if a.action=='health' else 'maintenance.sql')
            output=db.run_client('psql',params,'foodstore','-X','-v','ON_ERROR_STOP=1','-f',path)
            (ROOT/'logs'/f'{a.action}.txt').write_text(output,encoding='utf-8');print(output)
    except Exception as exc:
        message=str(exc).replace(params.get('password','<sinclave>'),'[REDACTADO]')
        save(f'error_{a.action}.json',{'utc':datetime.now(timezone.utc).isoformat(),'error':message})
        raise RuntimeError(message) from None

if __name__=='__main__':main()
