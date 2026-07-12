param(
  [string]$ProjectRoot = '',
  [string]$MatrixPath = 'examples\windows-clean-room-matrix\matrix.json',
  [ValidateSet('full','definition')][string]$Mode = 'full',
  [string]$WindowsPowerShellPath = 'powershell.exe',
  [string]$PowerShell7Path = 'pwsh.exe',
  [string]$WorkRoot = '',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Resolve-H5ProjectPath {
  param([string]$Root,[string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Resolve-H5HostPath {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
  $command = Get-Command ($Path -replace '\.exe$','') -ErrorAction SilentlyContinue
  if ($null -eq $command) { return '' }
  return $command.Source
}

function Test-H5MatrixDefinition {
  param([object]$Definition)
  $errors = [System.Collections.Generic.List[string]]::new()
  $requiredHosts = @('windows_powershell_5_1','powershell_7')
  $requiredPaths = @('short_ascii','space_unicode','over_budget')
  $requiredSources = @('source','zip')
  $cases = @($Definition.clean_room_matrix.cases)
  if ($Definition.clean_room_matrix.schema_version -ne 'taoge.windows-clean-room-matrix.v0.1') { $errors.Add('matrix_schema_invalid') }
  if ($cases.Count -ne 12) { $errors.Add("matrix_case_count_invalid:$($cases.Count)") }
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($case in $cases) {
    $key = "$($case.host_id)|$($case.path_shape)|$($case.source_kind)"
    if (-not $seen.Add($key)) { $errors.Add("matrix_duplicate_case:$key") }
    if ($case.host_id -notin $requiredHosts) { $errors.Add("matrix_host_invalid:$($case.case_id)") }
    if ($case.path_shape -notin $requiredPaths) { $errors.Add("matrix_path_invalid:$($case.case_id)") }
    if ($case.source_kind -notin $requiredSources) { $errors.Add("matrix_source_invalid:$($case.case_id)") }
    $expected = if ($case.path_shape -eq 'over_budget') { 'blocked_preflight' } else { 'pass' }
    if ($case.expected_outcome -ne $expected) { $errors.Add("matrix_expected_outcome_invalid:$($case.case_id)") }
  }
  foreach ($hostId in $requiredHosts) { foreach ($pathShape in $requiredPaths) { foreach ($sourceKind in $requiredSources) { $key="$hostId|$pathShape|$sourceKind";if(-not $seen.Contains($key)){$errors.Add("matrix_case_missing:$key")} } } }
  return $errors.ToArray()
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $MatrixPath = Resolve-H5ProjectPath $ProjectRoot $MatrixPath
  if ([string]::IsNullOrWhiteSpace($WorkRoot)) { $WorkRoot = Join-Path $ProjectRoot 'state\checks\h5m' }
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) { $HumanReportPath = Join-Path $ProjectRoot 'state\checks\windows-clean-room-matrix-report.md' }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) { $MachineReportPath = Join-Path $ProjectRoot 'state\checks\windows-clean-room-matrix-report.json' }
  $WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot)
  $HumanReportPath = Resolve-H5ProjectPath $ProjectRoot $HumanReportPath
  $MachineReportPath = Resolve-H5ProjectPath $ProjectRoot $MachineReportPath
  $definition = Get-Content -LiteralPath $MatrixPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $definitionErrors = @(Test-H5MatrixDefinition -Definition $definition)
  $caseResults = [System.Collections.Generic.List[object]]::new()
  $archivePath = ''
  $archiveSha256 = ''
  $buildExitCode = $null

  if ($Mode -eq 'full' -and $definitionErrors.Count -eq 0) {
    if (Test-Path -LiteralPath $WorkRoot) {
      $existingItems = @(Get-ChildItem -LiteralPath $WorkRoot -Force -ErrorAction Stop)
      if ($existingItems.Count -gt 0) { throw 'clean_room_work_root_not_empty_use_unique_short_root' }
    } else {
      New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
    }
    $resolvedWindowsPowerShell = Resolve-H5HostPath $WindowsPowerShellPath
    $resolvedPowerShell7 = Resolve-H5HostPath $PowerShell7Path
    $hostMap = @{
      windows_powershell_5_1 = $resolvedWindowsPowerShell
      powershell_7 = $resolvedPowerShell7
    }
    $buildHost = if (-not [string]::IsNullOrWhiteSpace($resolvedPowerShell7)) { $resolvedPowerShell7 } else { $resolvedWindowsPowerShell }
    if ([string]::IsNullOrWhiteSpace($buildHost)) { throw 'clean_room_build_host_missing' }
    $releaseBase = Join-Path $ProjectRoot ('releases\h5-matrix-' + (Get-Date -Format 'HHmmss'))
    $publicRoot = Join-Path $releaseBase 'p'
    $archivePath = Join-Path $releaseBase 'h5.zip'
    $shaPath = "$archivePath.sha256"
    $buildStdout = Join-Path $WorkRoot 'build.stdout.txt'
    $buildStderr = Join-Path $WorkRoot 'build.stderr.txt'
    $buildProcess = Start-TaogeProcess -FilePath $buildHost -Arguments @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'build-public-release.ps1'),'-ProjectRoot',$ProjectRoot,'-PublicReleasePath',$publicRoot,'-ZipPath',$archivePath,'-Sha256Path',$shaPath) -StandardOutputPath $buildStdout -StandardErrorPath $buildStderr -Wait -Hidden
    $buildExitCode = [int]$buildProcess.ExitCode
    if ($buildExitCode -ne 0 -or -not (Test-Path -LiteralPath $archivePath -PathType Leaf)) { throw "clean_room_public_build_failed:$buildExitCode" }
    $archiveSha256 = Get-TaogeFileSha256 -Path $archivePath

    $ordinal = 0
    foreach ($case in @($definition.clean_room_matrix.cases)) {
      $ordinal++
      $caseRoot = Join-Path $WorkRoot ('c' + $ordinal.ToString('00'))
      New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
      $resultPath = Join-Path $caseRoot 'result.json'
      $stdout = Join-Path $caseRoot 'case.stdout.txt'
      $stderr = Join-Path $caseRoot 'case.stderr.txt'
      $hostPath = [string]$hostMap[[string]$case.host_id]
      if ([string]::IsNullOrWhiteSpace($hostPath)) {
        $caseResults.Add([pscustomobject][ordered]@{case_id=$case.case_id;host_id=$case.host_id;source_kind=$case.source_kind;path_shape=$case.path_shape;expected_outcome=$case.expected_outcome;actual_outcome='not_tested';expectation_met=$false;failure_category='powershell_host_missing'})
        continue
      }
      $arguments = @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'invoke-windows-clean-room-case.ps1'),'-CaseId',[string]$case.case_id,'-HostId',[string]$case.host_id,'-SourceKind',[string]$case.source_kind,'-PathShape',[string]$case.path_shape,'-ExpectedOutcome',[string]$case.expected_outcome,'-ProjectRoot',$ProjectRoot,'-WorkRoot',$caseRoot,'-ArchivePath',$archivePath,'-ResultPath',$resultPath)
      $process = Start-TaogeProcess -FilePath $hostPath -Arguments $arguments -StandardOutputPath $stdout -StandardErrorPath $stderr -Wait -Hidden
      if (Test-Path -LiteralPath $resultPath) {
        $caseResult = (Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json).case_result
        $caseResult | Add-Member -NotePropertyName process_exit_code -NotePropertyValue ([int]$process.ExitCode) -Force
        $caseResults.Add($caseResult)
      } else {
        $caseResults.Add([pscustomobject][ordered]@{case_id=$case.case_id;host_id=$case.host_id;source_kind=$case.source_kind;path_shape=$case.path_shape;expected_outcome=$case.expected_outcome;actual_outcome='tool_error';expectation_met=$false;failure_category='case_report_missing';process_exit_code=[int]$process.ExitCode})
      }
    }
  }

  $failedCases = @($caseResults | Where-Object { -not $_.expectation_met -or $_.process_exit_code -ne 0 })
  $notTestedCases = @($caseResults | Where-Object { $_.actual_outcome -eq 'not_tested' })
  $overall = if ($definitionErrors.Count -gt 0 -or $failedCases.Count -gt 0) { 'fail' } else { 'pass' }
  if ($Mode -eq 'definition' -and $definitionErrors.Count -eq 0) { $overall = 'pass' }
  $report = [ordered]@{
    clean_room_matrix_report = [ordered]@{
      report_id = 'WIN-H5-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      schema_version = 'taoge.windows-clean-room-matrix-report.v0.1'
      mode = $Mode
      overall_result = $overall
      definition_status = if ($definitionErrors.Count -eq 0) { 'pass' } else { 'fail' }
      definition_errors = $definitionErrors
      canonical_case_count = @($definition.clean_room_matrix.cases).Count
      executed_case_count = $caseResults.Count
      pass_case_count = @($caseResults | Where-Object { $_.expectation_met }).Count
      fail_case_count = $failedCases.Count
      not_tested_case_count = $notTestedCases.Count
      build_exit_code = $buildExitCode
      archive_path = $archivePath
      archive_sha256 = $archiveSha256
      cases = $caseResults.ToArray()
      not_certified_axes = @($definition.clean_room_matrix.not_certified_axes)
      system_configuration_mutated = $false
      network_called = $false
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 20
  $lines = @('# Windows Clean-room Matrix Report','',"mode: $Mode","overall_result: $overall","canonical_case_count: $(@($definition.clean_room_matrix.cases).Count)","executed_case_count: $($caseResults.Count)","fail_case_count: $($failedCases.Count)",'','| Case | Host | Path | Source | Expected | Actual | Result |','|---|---|---|---|---|---|---|')
  foreach ($case in $caseResults) { $lines += "| $($case.case_id) | $($case.host_id) | $($case.path_shape) | $($case.source_kind) | $($case.expected_outcome) | $($case.actual_outcome) | $(if($case.expectation_met){'pass'}else{'fail'}) |" }
  $lines += '','## Not Certified',''
  foreach ($axis in @($definition.clean_room_matrix.not_certified_axes)) { $lines += "- $axis" }
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines
  Write-Output "WINDOWS_CLEAN_ROOM_MATRIX=$overall"
  Write-Output "WINDOWS_CLEAN_ROOM_MODE=$Mode"
  Write-Output "WINDOWS_CLEAN_ROOM_CASES=$($caseResults.Count)"
  Write-Output "WINDOWS_CLEAN_ROOM_REPORT=$MachineReportPath"
  if ($overall -ne 'pass') { exit 1 }
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line)
  exit 3
}
