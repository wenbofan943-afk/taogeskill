Set-StrictMode -Version 2.0

if (-not (Get-Command Resolve-WorkflowCompatibilityAsset -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'WorkflowCompatibilityLoader.ps1')
}

$legacyRuntimeRef = 'compatibility/legacy-r7/tools/R7SemanticRuntime.impl.ps1'
$legacyRuntimePath = Resolve-WorkflowCompatibilityAsset `
  -ProjectRoot (Split-Path -Parent $PSScriptRoot) `
  -AssetReference $legacyRuntimeRef `
  -CallerRuntimeGeneration 'legacy_r7'

. $legacyRuntimePath
