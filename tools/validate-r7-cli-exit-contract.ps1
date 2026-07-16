param(
  [string]$ReportRoot = 'state/checks/r7-cli-exit-contract'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

try {
  $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $reportRootPath = if ([IO.Path]::IsPathRooted($ReportRoot)) {
    [IO.Path]::GetFullPath($ReportRoot)
  } else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $ReportRoot))
  }
  $allowedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'state/checks'))
  $contained = Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath $reportRootPath -RejectReparsePoints
  if ($contained.status -ne 'pass') { throw 'report_root_outside_state_checks' }
  New-Item -ItemType Directory -Path $reportRootPath -Force | Out-Null

  $probeId = [guid]::NewGuid().ToString('N')
  $missingSession = Join-Path $reportRootPath "missing-$probeId"
  $stdoutPath = Join-Path $reportRootPath "stdout-$probeId.log"
  $stderrPath = Join-Path $reportRootPath "stderr-$probeId.log"
  $entry = Join-Path $projectRoot 'tools/invoke-r7-semantic-workflow.ps1'
  $process = Start-TaogeProcess -FilePath 'powershell.exe' -Arguments @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $entry,
    '-Session', $missingSession,
    '-Mode', 'initialize'
  ) -StandardOutputPath $stdoutPath -StandardErrorPath $stderrPath -WorkingDirectory $projectRoot -Wait -Hidden

  $exitCode = [int]$process.ExitCode
  $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -Raw -Encoding UTF8 $stdoutPath } else { '' }
  $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -Raw -Encoding UTF8 $stderrPath } else { '' }
  $resultLinePresent = $stdout -match '(?m)^R7_RUNTIME_RESULT=session_missing\s*$'
  $passed = $exitCode -eq 2 -and $resultLinePresent -and [string]::IsNullOrWhiteSpace($stderr)

  Write-Output "R7_CLI_EXIT_CONTRACT_RESULT=$(if ($passed) { 'pass' } else { 'fail' })"
  Write-Output "R7_CLI_EXIT_CODE=$exitCode"
  Write-Output "R7_CLI_RESULT_LINE_PRESENT=$resultLinePresent"
  if (-not $passed) {
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Output "R7_CLI_STDERR=$($stderr.Trim())" }
    exit 1
  }
  exit 0
} catch {
  Write-Error ("R7_CLI_EXIT_CONTRACT_ERROR={0}" -f $_.Exception.Message)
  exit 3
}
