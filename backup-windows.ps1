$ErrorActionPreference = 'Stop'

function Read-EnvValue([string]$Name) {
  $envPath = Join-Path $PSScriptRoot '.env'
  if (-not (Test-Path -LiteralPath $envPath)) { throw 'Create and configure the project .env file first.' }
  foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match ('^\s*' + [regex]::Escape($Name) + '\s*=(.*)$')) {
      $value = $Matches[1].Trim()
      if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) { $value = $value.Substring(1, $value.Length - 2) }
      return $value
    }
  }
  return ''
}

function Set-PrivateDirectoryAcl([string]$Path) {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $acl = Get-Acl -LiteralPath $Path
  $acl.SetAccessRuleProtection($true, $false)
  $acl.SetOwner([System.Security.Principal.WindowsIdentity]::GetCurrent().User)
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
  $acl.SetAccessRule($rule)
  Set-Acl -LiteralPath $Path -AclObject $acl
}

function Invoke-Native([string]$Command, [string[]]$Arguments, [string]$FailureMessage) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

$databaseUrl = Read-EnvValue 'DATABASE_URL'
$mediaSetting = Read-EnvValue 'MEDIA_ROOT'
$recipient = $env:BACKUP_GPG_RECIPIENT
if (-not $databaseUrl) { throw 'DATABASE_URL is missing in .env.' }
if (-not $recipient) { throw 'Set BACKUP_GPG_RECIPIENT to a verified full GPG public-key fingerprint for this PowerShell session.' }
foreach ($tool in @('pg_dump', 'tar', 'gpg')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Required tool was not found: $tool" }
}

$mediaRoot = if ($mediaSetting) { $mediaSetting } else { 'video_engine_backend/media' }
if (-not [System.IO.Path]::IsPathRooted($mediaRoot)) { $mediaRoot = Join-Path $PSScriptRoot $mediaRoot }
$mediaRoot = [System.IO.Path]::GetFullPath($mediaRoot)
if (-not (Test-Path -LiteralPath $mediaRoot -PathType Container)) { throw "MEDIA_ROOT does not exist: $mediaRoot" }

$backupRoot = Join-Path $PSScriptRoot 'backups'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$dbOutput = Join-Path $backupRoot "mk-school-db-$stamp.dump.gpg"
$mediaOutput = Join-Path $backupRoot "mk-school-media-$stamp.tar.gz.gpg"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mk-school-backup-$stamp"
New-Item -ItemType Directory -Path $tempRoot | Out-Null
Set-PrivateDirectoryAcl $tempRoot
$dbTemp = Join-Path $tempRoot 'school.dump'
$mediaTemp = Join-Path $tempRoot 'media.tar.gz'

try {
  Invoke-Native 'pg_dump' @('--format=custom', "--file=$dbTemp", "--dbname=$databaseUrl") 'PostgreSQL backup failed.'
  Invoke-Native 'tar' @('-czf', $mediaTemp, '-C', $mediaRoot, '.') 'Media backup failed.'
  Invoke-Native 'gpg' @('--batch', '--yes', '--trust-model', 'always', '--recipient', $recipient, '--output', $dbOutput, '--encrypt', $dbTemp) 'Database backup encryption failed.'
  Invoke-Native 'gpg' @('--batch', '--yes', '--trust-model', 'always', '--recipient', $recipient, '--output', $mediaOutput, '--encrypt', $mediaTemp) 'Media backup encryption failed.'
  if ((Get-Item -LiteralPath $dbOutput).Length -eq 0 -or (Get-Item -LiteralPath $mediaOutput).Length -eq 0) { throw 'An encrypted backup file is empty.' }
  Write-Output "Encrypted backup completed: $dbOutput and $mediaOutput"
  Write-Output 'Keep the matching GPG private key separate; restore-test both files on isolated staging infrastructure.'
} catch {
  Remove-Item -LiteralPath $dbOutput, $mediaOutput -Force -ErrorAction SilentlyContinue
  throw
} finally {
  Remove-Item -LiteralPath $dbTemp, $mediaTemp -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue
}
