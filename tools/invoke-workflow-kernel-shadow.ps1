[CmdletBinding()]
param(
    [ValidateSet('run_direct', 'run_hotspot', 'rebuild_projection', 'rebuild_hotspot_projection')]
    [string]$Mode = 'run_direct',
    [string]$ProjectRoot = '',
    [string]$RequestPath = '',
    [Parameter(Mandatory = $true)][string]$ShadowRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

$runtimePath = Join-Path $PSScriptRoot 'WorkflowKernelRuntime.ps1'
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    Write-Error 'workflow_kernel_runtime_missing'
    exit 2
}
. $runtimePath

$hotspotRuntimePath = Join-Path $PSScriptRoot 'WorkflowKernelHotspotRuntime.ps1'
if (-not (Test-Path -LiteralPath $hotspotRuntimePath -PathType Leaf)) {
    Write-Error 'workflow_kernel_hotspot_runtime_missing'
    exit 2
}
. $hotspotRuntimePath

if ($Mode -eq 'run_direct') {
    if ([string]::IsNullOrWhiteSpace($RequestPath)) {
        $result = New-WorkflowKernelResult -Success $false -Code 'request_path_required' -Message 'RequestPath is required for run_direct.'
    }
    else {
        $result = Invoke-WorkflowKernelDirectShadow -ProjectRoot $ProjectRoot -RequestPath $RequestPath -ShadowRoot $ShadowRoot
    }
}
elseif ($Mode -eq 'run_hotspot') {
    if ([string]::IsNullOrWhiteSpace($RequestPath)) {
        $result = New-WorkflowKernelResult -Success $false -Code 'command_path_required' -Message 'RequestPath is required for run_hotspot.'
    }
    else {
        $result = Invoke-WorkflowKernelHotspotShadow -ProjectRoot $ProjectRoot -CommandPath $RequestPath -ShadowRoot $ShadowRoot
    }
}
elseif ($Mode -eq 'rebuild_projection') {
    $result = Invoke-WorkflowKernelProjectionRebuild -ProjectRoot $ProjectRoot -ShadowRoot $ShadowRoot
}
else {
    $result = Invoke-WorkflowKernelHotspotProjectionRebuild -ProjectRoot $ProjectRoot -ShadowRoot $ShadowRoot
}

$result | ConvertTo-Json -Depth 30
if (-not [bool]$result.success) {
    exit 1
}
exit 0
