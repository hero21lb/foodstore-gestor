from pathlib import Path
import json
from datetime import datetime,timezone,timedelta
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
r=Path(__file__).resolve().parent
d=json.loads((r/'logs/restore_resultado.json').read_text());b=json.loads(next((r/'logs').glob('backup_*.json')).read_text())
s=getSampleStyleSheet();s['BodyText'].fontSize=10;s['BodyText'].leading=14
flow=[Paragraph('Food Store | Unidad 6',s['Title'])]
def p(t):flow.extend([Paragraph(t,s['BodyText']),Spacer(1,8)])
p('Mantenimiento, respaldo y recuperacion - 20/10/2026')
p('<b>Entorno.</b> Railway / postgrefacu, PostgreSQL 18.6. Fuente: foodstore. Destino: base nueva foodstore_restore_test. La fuente no se elimino ni reemplazo.')
p('<b>Respaldo.</b> '+d['backup']+'<br/>Inicio: '+datetime.fromisoformat(d['backup_started_utc']).astimezone(timezone(timedelta(hours=-3))).strftime('%d/%m/%Y %H:%M:%S %z')+'. Formato custom; '+str(b['bytes'])+' bytes; pg_dump/pg_restore con codigo 0. Snapshot compartido con la referencia.')
p('<b>RTO.</b> Objetivo: 120 segundos. Observado: '+str(d['rto_seconds'])+' segundos, desde antes de CREATE DATABASE hasta completar las validaciones; incluye comunicacion con Railway.')
p('<b>RPO.</b> Previsto: hasta 24 horas con respaldos diarios. Antiguedad al comenzar: '+str(d['backup_age_seconds'])+' segundos. Es una aproximacion a la ventana de exposicion, no una medicion de transacciones perdidas. La programacion diaria es propuesta, no esta activada.')
rows=[['Tabla','Antes','Restaurada']]+[[k,str(v['count']),str(d['restored'][k]['count'])] for k,v in d['expected'].items()]
t=Table(rows,colWidths=[230,105,105]);t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e5e7eb')),('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),('BOTTOMPADDING',(0,0),(-1,-1),6),('GRID',(0,0),(-1,-1),0.3,colors.grey)]));flow.extend([t,Spacer(1,10)])
p('<b>Validacion.</b> Conteos y resumen MD5 de contenido coinciden en cinco tablas. Productos invalidos: 0; detalles invalidos: 0; restricciones restauradas: 18. MD5 sirve para comparar contenido, no como prueba contra ataques.')
p('<b>Mantenimiento.</b> Autovacuum activo; estadisticas presentes y sin modificaciones pendientes al observar. ANALYZE condicional no selecciono tablas. No se ejecuto VACUUM FULL. Salud: 14 MB, cero deadlocks y sin otras consultas activas al muestrear.')
p('<b>Problema y mejora.</b> Se conserva un ensayo anterior con otro nombre. El script aborta si foodstore_restore_test existe, evitando sobrescribirlo. Mejora: rotacion supervisada, copias cifradas fuera del servidor y alertas ante fallos.')
p('<b>Asistencia y revision.</b> Scripts revisados y ejecutados con Codex; evidencia en logs/restore_resultado.json, health.txt, maintenance.txt y listado del dump. OpenCode se intento ejecutar, pero fallo por esquema incompatible de herramientas (HTTP 400). No se atribuye a OpenCode la autoria de esta ejecucion. Pendiente: intervencion de OpenCode y revision humana exigidas por la consigna.')
SimpleDocTemplate(str(r/'informe_u6.pdf'),pagesize=(595,842),rightMargin=48,leftMargin=48,topMargin=36,bottomMargin=30).build(flow)
import fitz
pdf=fitz.open(r/'informe_u6.pdf');print('Paginas:',len(pdf));assert len(pdf)==1
(r/'logs').mkdir(exist_ok=True)
pdf[0].get_pixmap(matrix=fitz.Matrix(1.5,1.5)).save(str(r/'logs/informe_u6_vista.png'))
