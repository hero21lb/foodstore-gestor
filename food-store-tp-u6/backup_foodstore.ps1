$ErrorActionPreference = 'Stop'
python "$PSScriptRoot/laboratorio_u6.py" backup
if ($LASTEXITCODE -ne 0) { throw "El respaldo fallo (codigo $LASTEXITCODE). Ver logs." }
