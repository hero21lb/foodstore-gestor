// Ejecutar con mongosh desde esta carpeta, conectado por tunel al servicio MongoDB.
// Ejemplo: load('consultas_mongodb.js'). No incluye secretos ni altera documentos.
const parametrosU7 = JSON.parse(require('fs').readFileSync('evidencias/verificacion.json', 'utf8')).parametros;
const pedidosU7 = db.getSiblingDB('foodstore_u7').pedidos;
const muestraU7 = parametrosU7.ids.map(id => Long(String(id)));

// a) Todos los pedidos, identificador y estado.
print('a) Todos los pedidos');
printjson(pedidosU7.find({_id: {$in: muestraU7}}, {_id: 1, estado: 1}).sort({_id: 1}).toArray());

// b) Filtrar por estado sintetico registrado en PostgreSQL antes de migrar.
print('b) Estado CONFIRMADO');
printjson(pedidosU7.find({_id: {$in: muestraU7}, estado: parametrosU7.estado}, {_id: 1}).sort({_id: 1}).toArray());

// c) Producto dentro del arreglo de lineas.
print('c) Producto de la primera linea del pedido 1');
printjson(pedidosU7.find({_id: {$in: muestraU7},
  'lineas.producto_id': Long(String(parametrosU7.producto_id))}, {_id: 1}).sort({_id: 1}).toArray());

// d) Importe decimal exacto; no utilizar precios actuales del catalogo.
print('d) Total mayor que 300');
printjson(pedidosU7.find({_id: {$in: muestraU7},
  total: {$gt: Decimal128(parametrosU7.umbral)}}, {_id: 1, total: 1}).sort({_id: 1}).toArray());
