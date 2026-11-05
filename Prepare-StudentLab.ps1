#Requires -Version 5.1
<#
.SYNOPSIS
Prepare a Windows 11 VM for the NanoCore student exercise.
.EXAMPLE
.\Prepare-StudentLab.ps1 -SamplePath 'D:\lab\sample.exe' `
  -ILSpyZip 'D:\tools\ILSpy.zip' -De4dotZip 'D:\tools\de4dot.zip' `
  -Wheelhouse 'D:\tools\wheels'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SamplePath,
    [Parameter(Mandatory = $true)][string]$ILSpyZip,
    [Parameter(Mandatory = $true)][string]$De4dotZip,
    [string]$Wheelhouse,
    [string]$Destination = (Join-Path $env:USERPROFILE 'Documents\NanoCoreStudentLab')
)

$ErrorActionPreference = 'Stop'
$expectedSampleHash = '09f7d2a30633ca2ea229ae07d447819d96c19f1466021fb9c46a1fd241cf4ecf'

foreach ($path in @($SamplePath, $ILSpyZip, $De4dotZip)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Файл не найден: $path" }
}
$actualHash = (Get-FileHash -LiteralPath $SamplePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedSampleHash) {
    throw "SHA-256 образца не совпал: $actualHash"
}
if (Test-Path -LiteralPath $Destination) {
    if (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1) {
        throw "Каталог назначения не пуст: $Destination"
    }
}
if ($Wheelhouse -and -not (Test-Path -LiteralPath $Wheelhouse -PathType Container)) {
    throw "Каталог wheelhouse не найден: $Wheelhouse"
}

$null = New-Item -ItemType Directory -Path $Destination -Force
foreach ($part in @('input', 'output', 'tools\ILSpy', 'tools\de4dot')) {
    $null = New-Item -ItemType Directory -Path (Join-Path $Destination $part) -Force
}
Copy-Item -LiteralPath $SamplePath -Destination (Join-Path $Destination 'input\sample.exe')
Expand-Archive -LiteralPath $ILSpyZip -DestinationPath (Join-Path $Destination 'tools\ILSpy')
Expand-Archive -LiteralPath $De4dotZip -DestinationPath (Join-Path $Destination 'tools\de4dot')

$ilspy = Get-ChildItem -LiteralPath (Join-Path $Destination 'tools\ILSpy') -Recurse -File |
    Where-Object { $_.Name -eq 'ILSpy.exe' } | Select-Object -First 1
$de4dot = Get-ChildItem -LiteralPath (Join-Path $Destination 'tools\de4dot') -Recurse -File |
    Where-Object { $_.Name -in @('de4dot.exe', 'de4dot-x64.exe') } | Select-Object -First 1
if (-not $ilspy -or -not $de4dot) {
    throw 'После распаковки ILSpy.exe или de4dot.exe не найден. Проверьте архивы.'
}

$pythonReady = $false
if ($Wheelhouse) {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    $launcher = $null -ne $py
    if (-not $py) { $py = Get-Command python.exe -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'Python 3 не найден. Установите его до отключения сети ВМ.' }
    $venv = Join-Path $Destination '.venv'
    if ($launcher) { & $py.Source -3 -m venv $venv }
    else { & $py.Source -m venv $venv }
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать окружение Python.' }
    $venvPython = Join-Path $venv 'Scripts\python.exe'
    & $venvPython -m pip install --no-index --find-links $Wheelhouse pefile
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось установить pefile из wheelhouse.' }
    $pythonReady = $true
}

[ordered]@{
    SampleSha256 = $actualHash
    ILSpy = $ilspy.FullName
    De4dot = $de4dot.FullName
    PythonReady = $pythonReady
    NetworkIsolation = 'Проверить вручную в гипервизоре'
    SampleExecuted = $false
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination 'setup-manifest.json') -Encoding UTF8

Write-Host "Окружение подготовлено: $Destination"
Write-Host "ILSpy: $($ilspy.FullName)"
Write-Host "de4dot: $($de4dot.FullName)"
if (-not $pythonReady) { Write-Warning 'Для экспорта RCDATA потребуется Python 3 и pefile.' }
Write-Warning 'Проверьте снимок ВМ и сетевую изоляцию. Скрипт не запускает образец или de4dot.'
