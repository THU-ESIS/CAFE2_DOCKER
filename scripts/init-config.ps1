param([string]$Directory = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# First-install only: never rotate an existing database's credentials.
$secretDir = Join-Path $Directory 'secrets'
$names = @('mysql-root-password','mysql-app-password','portal-app-secret',
    'cafe2-central-jdbc.properties','cafe2-worker-jdbc.properties','cafe2-local-jdbc.properties')
foreach ($name in $names) {
    if (Test-Path -LiteralPath (Join-Path $secretDir $name)) {
        throw "Existing secret file $name; refusing to overwrite. Reuse this installation's credentials."
    }
}
[System.IO.Directory]::CreateDirectory($secretDir) | Out-Null
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
function New-Secret {
    $bytes = New-Object byte[] 32
    $rng.GetBytes($bytes)
    return ([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
}
function Write-NewFile([string]$Path, [string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $file.Write($bytes, 0, $bytes.Length) } finally { $file.Dispose() }
}
try {
    $appPassword = New-Secret
    Write-NewFile (Join-Path $secretDir 'mysql-root-password') (New-Secret)
    Write-NewFile (Join-Path $secretDir 'mysql-app-password') $appPassword
    Write-NewFile (Join-Path $secretDir 'portal-app-secret') (New-Secret)
    foreach ($mode in @('central','worker','local')) {
        $database = if ($mode -eq 'central') { 'CAFECENTRAL' } else { 'CAFEWORKER' }
        $props = "jdbc.url=jdbc:mysql://mysql:3306/${database}?characterEncoding=UTF-8&serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=false`njdbc.username=cafe2`njdbc.password=$appPassword`njdbc.driver=com.mysql.cj.jdbc.Driver`n"
        Write-NewFile (Join-Path $secretDir "cafe2-$mode-jdbc.properties") $props
    }
    Write-Host 'Created six local secret files (UTF-8 without BOM). No values printed.'
    Write-Host 'Restrict secrets directory access to your deployment account. Configure .env before starting.'
} finally { $rng.Dispose() }
