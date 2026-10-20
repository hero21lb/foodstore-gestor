$ErrorActionPreference = 'Stop'
python "$PSScriptRoot/laboratorio_u6.py" restore
if ($LASTEXITCODE -ne 0) { throw "El ensayo fallo (codigo $LASTEXITCODE). La fuente no fue reemplazada." }
