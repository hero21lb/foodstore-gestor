const $ = (selector) => document.querySelector(selector);
const state = { categories: [], products: [], orders: [] };
const money = (value) => new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS" }).format(Number(value || 0));
const date = (value) => new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
const toast = (message) => { const el=$("#toast"); el.textContent=message; el.classList.add("show"); setTimeout(()=>el.classList.remove("show"),2800); };
async function api(url, options={}) { const r=await fetch(url,{headers:{"Content-Type":"application/json"},...options}); const data=await r.json(); if(!r.ok) throw new Error(data.error||"No se pudo completar la operación"); return data; }
function setConnection(ok, text) { const el=$(".status"); el.classList.toggle("connected",ok); $("#connection").textContent=text; }
function renderMetrics(data) { const defs=[["Productos activos",data.productos_activos],["Categorías activas",data.categorias_activas],["Clientes",data.clientes],["Pedidos",data.pedidos],["Facturación",money(data.facturacion)]]; $("#metrics").innerHTML=defs.map(([label,value])=>`<div class="metric"><p>${label.toUpperCase()}</p><span>${value}</span></div>`).join(""); }
function recentOrders() { const rows=state.orders.slice(0,5); $("#recent-orders").innerHTML=rows.length?`<table><tbody>${rows.map(o=>`<tr><td><strong>#${o.pedido_id}</strong></td><td>${o.cliente}</td><td><span class="tag pay">${o.forma_pago}</span></td><td>${money(o.total)}</td></tr>`).join("")}</tbody></table>`:`<div class="empty">Todavía no hay pedidos registrados.</div>`; }
function renderProducts() { const rows=state.products; $("#products-body").innerHTML=rows.length?rows.map(p=>`<tr><td><strong>${p.nombre}</strong><br><small>${p.descripcion||"Sin descripción"}</small></td><td>${p.categoria}</td><td>${money(p.precio)}</td><td>${p.stock}</td><td><span class="tag ${p.activo?"ok":"off"}">${p.activo?"Activo":"Inactivo"}</span></td><td><button class="row-action" data-product="${p.id}">Editar</button></td></tr>`).join(""):`<tr><td colspan="6" class="empty">No hay productos que coincidan.</td></tr>`; }
function renderCategories() { $("#category-grid").innerHTML=state.categories.map(c=>`<article class="category-card"><p>${c.activo?"ACTIVA":"INACTIVA"}</p><h3>${c.nombre}</h3><span class="muted">${c.descripcion||"Sin descripción"}</span><div class="foot"><span>${c.productos} productos</span><button class="row-action" data-category="${c.id}">${c.activo?"Desactivar":"Activar"}</button></div></article>`).join(""); }
function renderOrders() { $("#orders-body").innerHTML=state.orders.length?state.orders.map(o=>`<tr><td><strong>#${o.pedido_id}</strong></td><td>${date(o.fecha)}</td><td>${o.cliente}</td><td><span class="tag pay">${o.forma_pago}</span></td><td>${o.unidades}</td><td><strong>${money(o.total)}</strong></td></tr>`).join(""):`<tr><td colspan="6" class="empty">No hay pedidos registrados.</td></tr>`; }
function categoriesOptions(selected="") { return state.categories.filter(c=>c.activo).map(c=>`<option value="${c.id}" ${String(c.id)===String(selected)?"selected":""}>${c.nombre}</option>`).join(""); }
function openProduct(product=null) { $("#modal-kicker").textContent=product?"EDICIÓN":"CATÁLOGO"; $("#modal-title").textContent=product?"Editar producto":"Nuevo producto"; $("#modal-fields").innerHTML=`<div class="field"><label>Nombre</label><input name="nombre" required value="${product?.nombre||""}"></div><div class="field"><label>Descripción</label><textarea name="descripcion">${product?.descripcion||""}</textarea></div><div class="field"><label>Precio</label><input name="precio" type="number" min="0" step="0.01" required value="${product?.precio||""}"></div><div class="field"><label>Stock</label><input name="stock" type="number" min="0" required value="${product?.stock??0}"></div><div class="field"><label>Categoría</label><select name="categoria_id" required>${categoriesOptions(product?.categoria_id)}</select></div>${product?`<label class="switch"><input name="activo" type="checkbox" ${product.activo?"checked":""}> Producto activo</label>`:""}`; $("#modal-form").onsubmit=async(e)=>{e.preventDefault();const f=new FormData(e.target);const body={nombre:f.get("nombre"),descripcion:f.get("descripcion"),precio:f.get("precio"),stock:f.get("stock"),categoria_id:f.get("categoria_id")};if(product)body.activo=f.get("activo")==="on";await api(product?`/api/products/${product.id}`:"/api/products",{method:product?"PATCH":"POST",body:JSON.stringify(body)});$("#modal").close();toast("Producto guardado");await loadProducts();await loadDashboard();};$("#modal").showModal(); }
function openCategory() { $("#modal-kicker").textContent="CATÁLOGO";$("#modal-title").textContent="Nueva categoría";$("#modal-fields").innerHTML=`<div class="field"><label>Nombre</label><input name="nombre" required></div><div class="field"><label>Descripción</label><textarea name="descripcion"></textarea></div>`;$("#modal-form").onsubmit=async(e)=>{e.preventDefault();const f=new FormData(e.target);await api("/api/categories",{method:"POST",body:JSON.stringify({nombre:f.get("nombre"),descripcion:f.get("descripcion")})});$("#modal").close();toast("Categoría creada");await loadCategories();await loadDashboard();};$("#modal").showModal(); }
async function loadCategories(){state.categories=await api("/api/categories");$("#product-category").innerHTML=`<option value="">Todas las categorías</option>${categoriesOptions()}`;renderCategories();}
async function loadProducts(){const q=new URLSearchParams();if($("#product-search").value)q.set("search",$("#product-search").value);if($("#product-category").value)q.set("category",$("#product-category").value);if($("#show-inactive").checked)q.set("all","true");state.products=await api(`/api/products?${q}`);renderProducts();}
async function loadOrders(){state.orders=await api("/api/orders");renderOrders();recentOrders();}
async function loadDashboard(){renderMetrics(await api("/api/dashboard"));}
async function boot(){try{const h=await api("/api/health");setConnection(true,`Railway · ${h.database}`);await Promise.all([loadCategories(),loadProducts(),loadOrders(),loadDashboard()]);}catch(e){setConnection(false,"Sin conexión");toast(e.message);}}
document.querySelectorAll(".nav").forEach(btn=>btn.onclick=()=>{document.querySelectorAll(".nav,.view").forEach(el=>el.classList.remove("active"));btn.classList.add("active");$(`#${btn.dataset.view}`).classList.add("active");$("#title").textContent=btn.textContent;$("#eyebrow").textContent=btn.textContent.toUpperCase();});
$("#refresh").onclick=boot;$("#new-product").onclick=()=>openProduct();$("#new-category").onclick=openCategory;$("#product-search").oninput=()=>loadProducts();$("#product-category").onchange=loadProducts;$("#show-inactive").onchange=loadProducts;$("#products-body").onclick=e=>{const id=e.target.dataset.product;if(id)openProduct(state.products.find(p=>p.id===Number(id)));};$("#category-grid").onclick=async (e)=>{const id=e.target.dataset.category;if(!id)return;const cat=state.categories.find(c=>c.id===Number(id));await api(`/api/categories/${id}`,{method:"PATCH",body:JSON.stringify({activo:!cat.activo})});toast(cat.activo?"Categoría desactivada":"Categoría activada");await loadCategories();await loadDashboard();};document.querySelectorAll("[data-go]").forEach(el=>el.onclick=()=>document.querySelector(`.nav[data-view="${el.dataset.go}"]`).click());
// ---------------------------------------------------------------- laboratorio TPI
const labUnits = [
  {
    id: "u1", num: "U1", title: "Integridad y concurrencia", tag: "POSTGRESQL · TP2",
    desc: "Restricciones reales: fecha no futura, cantidad 1..20, precio histórico y baja lógica. Además, dos sesiones compiten por la misma fila con FOR UPDATE.",
    actions: [
      { id: "u1-restricciones", label: "Probar restricciones", url: "/api/lab/u1/restricciones" },
      { id: "u1-concurrencia", label: "Simular dos sesiones", url: "/api/lab/u1/concurrencia" },
    ],
  },
  {
    id: "u2", num: "U2", title: "Consultas y planes", tag: "POSTGRESQL · OPTIMIZACIÓN",
    desc: "JOIN + agregación, top de productos y DENSE_RANK por categoría. El plan muestra el nodo que elige PostgreSQL y el tiempo real.",
    actions: [
      { id: "u2-consultas", label: "Ejecutar consultas", url: "/api/lab/u2/consultas" },
      { id: "u2-explain", label: "Ver EXPLAIN ANALYZE", url: "/api/lab/u2/explain" },
    ],
  },
  {
    id: "u3", num: "U3", title: "Vistas y materializada", tag: "POSTGRESQL · U3",
    desc: "Tres vistas de reporte y una vista materializada de facturación por mes/categoría. El refresh concurrente se mide en vivo.",
    actions: [
      { id: "u3-vistas", label: "Leer vistas", url: "/api/lab/u3/vistas" },
      { id: "u3-refresh", label: "Refrescar materializada", url: "/api/lab/u3/refresh", method: "POST" },
    ],
  },
  {
    id: "u4", num: "U4", title: "FNBC y desnormalización", tag: "POSTGRESQL · U4",
    desc: "Descomposición R1/R2 sin pérdida, vista de compatibilidad y columnas precalculadas con triggers. Compará el top normal contra el desnormalizado.",
    actions: [
      { id: "u4-estado", label: "Estado U4", url: "/api/lab/u4/estado" },
      { id: "u4-fnbc", label: "Probar FNBC", url: "/api/lab/u4/fnbc" },
      { id: "u4-top", label: "Top normal vs. desnorm.", url: "/api/lab/u4/top" },
      { id: "u4-instalar", label: "Instalar U4 si falta", url: "/api/lab/u4/instalar", method: "POST", body: { confirm: true }, confirm: "Esto agrega columnas y triggers a detalle_pedido. ¿Continuar?" },
    ],
  },
  {
    id: "u5", num: "U5", title: "Roles, auditoría y login", tag: "POSTGRESQL · U5",
    desc: "Mínimo privilegio: app_web lee productos, pero no hashes, borrados ni autoasignación de admin_datos. El login usa fn_autenticar con bcrypt.",
    actions: [
      { id: "u5-roles", label: "Probar permisos", url: "/api/lab/u5/roles" },
      { id: "u5-auditoria", label: "Ver auditoría", url: "/api/lab/u5/auditoria" },
      { id: "u5-auditar", label: "Generar evento de stock", url: "/api/lab/u5/auditar", method: "POST" },
    ],
    extra: '<div class="lab-login"><input id="u5-mail" value="demo@foodstore.local" aria-label="Mail demo"><input id="u5-pass" type="password" value="defensa2026" aria-label="Contraseña demo"><button class="lab-btn" data-login="u5">Probar login</button></div>',
  },
  {
    id: "u6", num: "U6", title: "Mantenimiento y restore", tag: "POSTGRESQL · U6",
    desc: "Salud de la base, tamaño, conexiones y evidencia del simulacro: RTO 32,224 s, conteos y md5 coincidentes, cero inválidos.",
    actions: [
      { id: "u6-estado", label: "Ver respaldo/restore", url: "/api/lab/u6/estado" },
      { id: "u6-salud", label: "Chequeo de salud", url: "/api/lab/u6/salud" },
    ],
  },
  {
    id: "u7", num: "U7", title: "MongoDB documental", tag: "MONGODB · U7",
    desc: "Pedido como documento con líneas embebidas y cliente seudonimizado. Si MONGO_URL está configurada consulta en vivo; si no, muestra la evidencia.",
    actions: [{ id: "u7-estado", label: "Consultar MongoDB", url: "/api/lab/u7/estado" }],
  },
  {
    id: "u8", num: "U8", title: "Tablet SQLite y semáforo", tag: "SQLITE · U8",
    desc: "Catálogo offline, borradores y cola. El semáforo decide RECHAZADO / CONFLICTO / SIMULADO_APROBADO sin tocar PostgreSQL.",
    actions: [
      { id: "u8-estado", label: "Ver tablet", url: "/api/lab/u8/estado" },
      { id: "u8-c1", label: "C1 offline", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C1" } },
      { id: "u8-c2", label: "C2 precio", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C2" } },
      { id: "u8-c3", label: "C3 stock", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C3" } },
      { id: "u8-c4", label: "C4 baja", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C4" } },
      { id: "u8-c5", label: "C5 verde", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C5" } },
      { id: "u8-c6", label: "C6 UUID", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C6" } },
      { id: "u8-c7", label: "C7 errores", url: "/api/lab/u8/caso", method: "POST", body: { caso: "C7" } },
    ],
  },
];
const labActions = Object.fromEntries(labUnits.flatMap((unit) => unit.actions.map((action) => [action.id, action])));

function renderLab() {
  $("#lab-grid").innerHTML = labUnits.map((unit) => `
    <article class="lab-card">
      <div class="lab-head"><span class="lab-num">${unit.num}</span><div><p>${unit.tag}</p><h3>${unit.title}</h3></div></div>
      <p class="lab-desc">${unit.desc}</p>
      <div class="lab-actions">${unit.actions.map((action) => `<button class="lab-btn" data-lab="${action.id}">${action.label}</button>`).join("")}</div>
      ${unit.extra || ""}
      <pre class="lab-result" data-result="${unit.id}">Listo para probar.</pre>
    </article>`).join("");
}

async function loadLabOverview() {
  try {
    const o = await api("/api/lab/overview");
    $("#lab-overview").innerHTML = [
      ["Base", o.database],
      ["Productos", o.productos],
      ["Clientes", o.clientes],
      ["Pedidos", o.pedidos],
      ["U4", o.u4 ? "instalado" : "falta instalar"],
      ["Roles U5", o.roles],
      ["Mongo", o.mongo ? "configurado" : "modo evidencia"],
      ["SQLite", o.u8 ? "tablet lista" : "sin archivo"],
    ].map(([k, v]) => `<span class="lab-pill"><b>${k}:</b> ${v}</span>`).join("");
  } catch (error) {
    $("#lab-overview").textContent = "No se pudo leer el laboratorio: " + error.message;
  }
}

$("#lab-grid").addEventListener("click", async (event) => {
  const login = event.target.closest("[data-login]");
  if (login) {
    const card = login.closest(".lab-card");
    const result = card.querySelector("[data-result]");
    login.disabled = true;
    result.textContent = "Autenticando…";
    try {
      const data = await api("/api/lab/u5/login", {
        method: "POST",
        body: JSON.stringify({ mail: $("#u5-mail").value, password: $("#u5-pass").value }),
      });
      result.textContent = JSON.stringify(data, null, 2);
    } catch (error) {
      result.textContent = "ERROR: " + error.message;
    } finally {
      login.disabled = false;
    }
    return;
  }

  const button = event.target.closest("[data-lab]");
  if (!button) return;
  const action = labActions[button.dataset.lab];
  const result = button.closest(".lab-card").querySelector("[data-result]");
  if (action.confirm && !window.confirm(action.confirm)) return;
  button.disabled = true;
  result.textContent = "Ejecutando…";
  try {
    const options = { method: action.method || "GET" };
    if (action.body) options.body = JSON.stringify(action.body);
    const data = await api(action.url, options);
    result.textContent = JSON.stringify(data, null, 2);
  } catch (error) {
    result.textContent = "ERROR: " + error.message;
  } finally {
    button.disabled = false;
  }
});

renderLab();
loadLabOverview();

boot();
