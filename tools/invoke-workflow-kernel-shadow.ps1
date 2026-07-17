[CmdletBinding()]
param(
    [ValidateSet('run_direct', 'rebuild_projection')]
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

if ($Mode -eq 'run_direct') {
    if ([string]::IsNullOrWhiteSpace($RequestPath)) {
        $result = New-WorkflowKernelResult -Success $false -Code 'request_path_required' -Message 'RequestPath is required for run_direct.'
    }
    else {
        $result = Invoke-WorkflowKernelDirectShadow -ProjectRoot $ProjectRoot -RequestPath $RequestPath -ShadowRoot $ShadowRoot
    }
}
else {
    $result = Invoke-WorkflowKernelProjectionRebuild -ProjectRoot $ProjectRoot -ShadowRoot $ShadowRoot
}

$result | ConvertTo-Json -Depth 30
if (-not [bool]$result.success) {
    exit 1
}
exit 0
