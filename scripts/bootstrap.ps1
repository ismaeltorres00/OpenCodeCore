<#
.SYNOPSIS
  Onboarding de un dev al config centralizado de OpenCode (equivalente PowerShell de bootstrap.sh).

.DESCRIPTION
  bootstrap.sh solo sirve OPENCODE_CONFIG vía ~/.bashrc, que PowerShell no lee — por eso
  este script existe por separado. Hace lo mismo que bootstrap.sh pero fija OPENCODE_CONFIG
  como variable de entorno de usuario de Windows ([Environment]::SetEnvironmentVariable),
  que sí recogen tanto PowerShell como cmd.exe y cualquier proceso lanzado después (nuevas
  ventanas, VS Code, etc. — no la sesión ya abierta en la que corres este script; para esa,
  el script también exporta $env:OPENCODE_CONFIG en la sesión actual).

  Re-ejecutable en cualquier momento (idempotente) para sincronizar cambios.
#>
param(
  [string]$OrgConfigRepo = "https://github.com/ismaeltorres00/OpenCodeCore.git",
  [string]$CloneDir = (Join-Path $HOME ".opencode-org-config")
)

$ErrorActionPreference = "Stop"
$GlobalDir = Join-Path $env:USERPROFILE ".config\opencode"

Write-Host "== opencode-org-config: bootstrap (PowerShell) =="

# 1. Clonar o actualizar el repo de config
if (Test-Path (Join-Path $CloneDir ".git")) {
  Write-Host "-> Repo ya clonado en $CloneDir, actualizando (git pull --ff-only)"
  git -C $CloneDir pull --ff-only
} else {
  Write-Host "-> Clonando $OrgConfigRepo en $CloneDir"
  git clone $OrgConfigRepo $CloneDir
}

$orgConfigFile = Join-Path $CloneDir "opencode.json"
if (-not (Test-Path $orgConfigFile)) {
  throw "No existe $orgConfigFile (¿regeneraste con 'node gen_wellknown.js' y lo mergeaste a main?)"
}

# 2. commands/ -> ~/.config/opencode/commands/
$commandsDir = Join-Path $GlobalDir "commands"
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
Write-Host "-> Sincronizando commands/ -> $commandsDir"
Copy-Item -Path (Join-Path $CloneDir "commands\*.md") -Destination $commandsDir -Force

# 3. skills/<name>/<name>.md -> ~/.config/opencode/skills/<name>/
$skillsDir = Join-Path $GlobalDir "skills"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
Write-Host "-> Sincronizando skills/ -> $skillsDir (carpeta por skill)"
Get-ChildItem -Path (Join-Path $CloneDir "skills") -Directory | ForEach-Object {
  $dest = Join-Path $skillsDir $_.Name
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Path (Join-Path $_.FullName "*.md") -Destination $dest -Force
}

# 4. OPENCODE_CONFIG -> opencode.json del repo, persistente a nivel de usuario de Windows
$existing = [Environment]::GetEnvironmentVariable("OPENCODE_CONFIG", "User")
if ($existing -and ($existing -ne $orgConfigFile)) {
  Write-Host "-> OPENCODE_CONFIG ya esta fijado a un valor distinto ($existing), no se toca. Cambialo a mano si quieres apuntar aqui."
} else {
  [Environment]::SetEnvironmentVariable("OPENCODE_CONFIG", $orgConfigFile, "User")
  Write-Host "-> OPENCODE_CONFIG fijado a nivel de usuario: $orgConfigFile"
}
$env:OPENCODE_CONFIG = $orgConfigFile

Write-Host ""
Write-Host "== Listo =="
Write-Host "Esta sesion ya tiene OPENCODE_CONFIG activo. Para nuevas ventanas de PowerShell/cmd/VS Code no hace falta nada mas."
Write-Host "Para actualizar en el futuro, vuelve a ejecutar este script."
