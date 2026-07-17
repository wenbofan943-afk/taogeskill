[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('start', 'resume')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$SessionRoot,
    [Parameter(Mandatory = $true)][string]$SessionId,
    [Parameter(Mandatory = $true)][ValidateSet('direct', 'hotspot')][string]$RouteId,
    [Parameter(Mandatory = $true)][string]$RequestedAt,
    [string]$ProjectRoot = '',
    [switch]$FixtureMode,
    [string]$WorkflowIrPath = '',
    [string]$ArchitectureControlPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

$runtimePath = Join-Path $PSScriptRoot 'WorkflowKernelSessionEntry.ps1'
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    Write-Error 'workflow_session_entry_runtime_missing'
    exit 2
}
. $runtimePath

$result = Invoke-WorkflowSessionEntry `
    -ProjectRoot $ProjectRoot `
    -SessionRoot $SessionRoot `
    -Intent $Mode `
    -SessionId $SessionId `
    -RouteId $RouteId `
    -RequestedAt $RequestedAt `
    -FixtureMode ([bool]$FixtureMode) `
    -WorkflowIrPath $WorkflowIrPath `
    -ArchitectureControlPath $ArchitectureControlPath

$result | ConvertTo-Json -Depth 30
if (-not [bool]$result.success) {
    exit 1
}
exit 0
