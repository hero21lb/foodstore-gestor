# Parte D - Equivalencia comprobada

La tabla usuario no existia en FoodStore U1-U4. Se reconstruyo con 18 identidades
enteramente sinteticas, tres roles y seis meses de alta. No son cuentas historicas
recuperadas ni se inventaron atributos sobre los 5.000 clientes.

usuario_anon conserva id/rol/mes UTC y sustituye nombre/mail por valores sinteticos.
verificacion_equivalencia.txt muestra ambas consultas lado a lado y cero diferencias;
laboratorio_u5.py verifica EXCEPT en ambas direcciones mediante una asercion.

El id estable y los grupos pequenos conservan posibilidad de vincular filas:
esta tecnica es seudonimizacion determinista y no garantiza anonimato irreversible.
Para compartir con IA se usa solo el resultado agregado de este laboratorio sintetico.
No deben salir nombres, mails, telefonos, direcciones, credenciales, hashes ni
historiales de compra vinculables sin tratamiento previo y autorizacion. Cambiar
el nombre no basta si permanecen identificadores o combinaciones reconocibles.
