param(
  [string]$FixturePath = 'examples/windows-environment-preflight-fixture/fixtures.json',
  [string]$ReportPath = 'state/checks/environment-preflight-fixture-report.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')

function Resolve-H3Path {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Add-H3Check {
  param([System.Collections.Generic.List[object]]$Checks,[string]$Id,[bool]$Passed,[string]$Evidence)
  $Checks.Add([ordered]@{check_id=$Id;status=$(if($Passed){'pass'}else{'fail'});evidence=$Evidence})
}

try {
  $fixtureFull = Resolve-H3Path $FixturePath
  $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $workParent = Join-Path $projectRoot 'state/checks/environment-preflight-work'
  $workRoot = Join-Path $workParent '空格 中文'
  if (Test-Path -LiteralPath $workParent) { Remove-Item -LiteralPath $workParent -Recurse -Force }
  New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
  $checks = [System.Collections.Generic.List[object]]::new()

  $validFailures = @($fixture.valid_segments | ForEach-Object { Test-TaogeWindowsPathSegment ([string]$_) } | Where-Object { $_.status -ne 'pass' })
  Add-H3Check $checks 'WIN-H3-001-valid-windows-segments' ($validFailures.Count -eq 0) ([string]::Join(';',@($validFailures|ForEach-Object{"$($_.segment):$($_.errors -join ',')"})))

  $invalidMisses = [System.Collections.Generic.List[string]]::new()
  foreach($case in @($fixture.invalid_segments)){
    $result = Test-TaogeWindowsPathSegment ([string]$case.value)
    if($result.status-ne'fail' -or @($result.errors)-notcontains[string]$case.error){$invalidMisses.Add("$($case.value):$($case.error):$($result.errors -join ',')")}
  }
  Add-H3Check $checks 'WIN-H3-002-invalid-windows-segments' ($invalidMisses.Count -eq 0) ([string]::Join(';',$invalidMisses))

  $allowedRoot = Join-Path $workRoot 'allowed-root'
  $outsideRoot = Join-Path $workRoot 'outside-root'
  New-Item -ItemType Directory -Path $allowedRoot,$outsideRoot -Force | Out-Null
  $containedFailures = @($fixture.valid_relative_paths | ForEach-Object { Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath ([string]$_) -RejectReparsePoints } | Where-Object { $_.status -ne 'pass' })
  Add-H3Check $checks 'WIN-H3-003-contained-relative-paths' ($containedFailures.Count -eq 0) ([string]::Join(';',@($containedFailures|ForEach-Object{$_.errors -join ','})))

  $escapeResult = Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath ([string]$fixture.escape_relative_path) -RejectReparsePoints
  Add-H3Check $checks 'WIN-H3-004-lexical-root-escape-blocked' ($escapeResult.status-eq'fail' -and @($escapeResult.errors)-contains'root_escape') ($escapeResult.errors -join ',')

  $junctionPath = Join-Path $allowedRoot 'junction-out'
  $junction = New-Item -ItemType Junction -Path $junctionPath -Target $outsideRoot -Force
  $reparseResult = Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath (Join-Path $junctionPath 'escaped.txt') -RejectReparsePoints
  Add-H3Check $checks 'WIN-H3-005-reparse-point-blocked' ($null-ne$junction -and $reparseResult.status-eq'fail' -and @($reparseResult.errors|Where-Object{$_-like'reparse_point_not_allowed:*'}).Count-eq1) ($reparseResult.errors -join ',')

  $budgetPass = Test-TaogePathBudget -InstallationRoot $projectRoot -TargetRoot $allowedRoot -RelativePaths @($fixture.valid_relative_paths) -RecommendedInstallationRootMaxChars 90 -ClassicPathMaxChars 259
  Add-H3Check $checks 'WIN-H3-006-short-path-budget-pass' ($budgetPass.status-eq'pass' -and $budgetPass.over_limit_count-eq0) "root=$($budgetPass.installation_root_length);longest=$($budgetPass.longest_target_path_length)"

  $budgetFail = Test-TaogePathBudget -InstallationRoot $projectRoot -TargetRoot $allowedRoot -RelativePaths @([string]$fixture.long_relative_path) -RecommendedInstallationRootMaxChars 90 -ClassicPathMaxChars 180
  Add-H3Check $checks 'WIN-H3-007-over-budget-blocked-before-write' ($budgetFail.status-eq'fail' -and $budgetFail.over_limit_count-eq1) "longest=$($budgetFail.longest_target_path_length);limit=$($budgetFail.classic_path_max_chars)"

  $storagePass = Test-TaogeWritableTempSpace -TargetRoot $allowedRoot -RequiredFreeBytes ([long]$fixture.minimum_free_bytes) -ProbeWrite
  $probeResidue = @(Get-ChildItem -LiteralPath $allowedRoot -Filter '.taoge-preflight-*' -Force -ErrorAction SilentlyContinue)
  Add-H3Check $checks 'WIN-H3-008-temp-write-rename-cleanup' ($storagePass.status-eq'pass' -and $storagePass.probe_created -and $storagePass.atomic_rename_succeeded -and $storagePass.cleanup_succeeded -and $probeResidue.Count-eq0) "volume=$($storagePass.volume_root);filesystem=$($storagePass.drive_format);residue=$($probeResidue.Count)"

  $storageFail = Test-TaogeWritableTempSpace -TargetRoot $allowedRoot -RequiredFreeBytes ([long]$storagePass.available_free_bytes + 1)
  Add-H3Check $checks 'WIN-H3-009-insufficient-disk-blocked' ($storageFail.status-eq'fail' -and @($storageFail.errors)-contains'insufficient_free_space') "available=$($storageFail.available_free_bytes);required=$($storageFail.required_free_bytes)"

  $preflight = Invoke-TaogeEnvironmentPreflight -ProjectRoot $projectRoot -AllowedRoot $workRoot -TargetRoot $allowedRoot -RelativePaths @($fixture.valid_relative_paths) -RequiredFreeBytes ([long]$fixture.minimum_free_bytes) -ProbeWrite
  Add-H3Check $checks 'WIN-H3-010-environment-facts-readonly' ($preflight.status-eq'pass' -and -not$preflight.system_configuration_mutated -and -not$preflight.network_called -and -not[string]::IsNullOrWhiteSpace([string]$preflight.facts.powershell_version) -and -not[string]::IsNullOrWhiteSpace([string]$preflight.facts.filesystem)) "ps=$($preflight.facts.powershell_version);fs=$($preflight.facts.filesystem);longpaths=$($preflight.facts.long_paths_enabled)"

  $foreignCwd = Join-Path $workRoot 'foreign cwd'
  New-Item -ItemType Directory -Path $foreignCwd -Force | Out-Null
  $doctorOutput = Join-Path $projectRoot 'state/checks/environment-doctor-cwd-fixture.json'
  $doctorStdout = Join-Path $workRoot 'doctor.stdout.txt'
  $doctorStderr = Join-Path $workRoot 'doctor.stderr.txt'
  $runtimeHost = Get-P0PowerShellHost
  $doctorProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'invoke-environment-doctor.ps1'),'-ProjectRoot',$projectRoot,'-AllowedRoot',$projectRoot,'-TargetRoot',$projectRoot,'-RelativePaths','README.md','-RequiredFreeBytes','0','-ReportPath','state/checks/environment-doctor-cwd-fixture.json') -WorkingDirectory $foreignCwd -StandardOutputPath $doctorStdout -StandardErrorPath $doctorStderr -Wait -Hidden
  $doctorReport = if(Test-Path -LiteralPath $doctorOutput){Get-Content -LiteralPath $doctorOutput -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
  Add-H3Check $checks 'WIN-H3-011-cwd-independent-doctor' ([int]$doctorProcess.ExitCode-eq0 -and $null-ne$doctorReport -and [string]$doctorReport.facts.project_root-ceq[System.IO.Path]::GetFullPath($projectRoot)) "exit=$($doctorProcess.ExitCode);cwd=$foreignCwd;root=$($doctorReport.facts.project_root)"

  $preflightSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1') -Raw -Encoding UTF8
  $doctorSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'invoke-environment-doctor.ps1') -Raw -Encoding UTF8
  Add-H3Check $checks 'WIN-H3-012-no-cwd-resolution-dependency' (-not$preflightSource.Contains('Get-Location') -and -not$doctorSource.Contains('Get-Location')) 'Environment paths must derive from PSScriptRoot or explicit roots'

  $buildSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build-public-release.ps1') -Raw -Encoding UTF8
  Add-H3Check $checks 'WIN-H3-013-public-build-preflight-wired' ($buildSource.Contains('Invoke-TaogeEnvironmentPreflight') -and $buildSource.Contains('environment_preflight_failed')) 'Public build must stop before clearing or copying when preflight fails'

  $negativeReleaseRoot = Join-Path $projectRoot 'releases'
  $negativePrefix = '路径预算负例-'
  $negativeFixedLength = $negativeReleaseRoot.Length + 1 + $negativePrefix.Length + 1 + 'public_release'.Length + 1 + 'sentinel.keep'.Length
  $negativeRepeatCount = [Math]::Max(16, 245 - $negativeFixedLength)
  $negativeToken = $negativePrefix + ('深' * $negativeRepeatCount)
  $negativeBase = Join-Path $negativeReleaseRoot $negativeToken
  $negativePublic = Join-Path $negativeBase 'public_release'
  New-Item -ItemType Directory -Path $negativePublic -Force | Out-Null
  $sentinelPath = Join-Path $negativePublic 'sentinel.keep'
  Write-TaogeUtf8NoBomText -Path $sentinelPath -Text 'must-survive-preflight-failure'
  $negativeStdout = Join-Path $workRoot 'negative-build.stdout.txt'
  $negativeStderr = Join-Path $workRoot 'negative-build.stderr.txt'
  $negativeProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'build-public-release.ps1'),'-ProjectRoot',$projectRoot,'-PublicReleasePath',$negativePublic,'-ZipPath',(Join-Path $negativeBase 'candidate.zip'),'-Sha256Path',(Join-Path $negativeBase 'candidate.zip.sha256')) -StandardOutputPath $negativeStdout -StandardErrorPath $negativeStderr -Wait -Hidden
  $negativeText = ((Get-Content -LiteralPath $negativeStdout -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $negativeStderr -Raw -Encoding UTF8 -ErrorAction SilentlyContinue))
  $sentinelSurvived = Test-Path -LiteralPath $sentinelPath
  Add-H3Check $checks 'WIN-H3-014-public-build-fails-before-clear' ([int]$negativeProcess.ExitCode-ne0 -and $negativeText.Contains('environment_preflight_failed') -and $sentinelSurvived) "exit=$($negativeProcess.ExitCode);sentinel=$sentinelSurvived"
  $negativeContainment = Resolve-TaogeContainedPath -AllowedRoot (Join-Path $projectRoot 'releases') -CandidatePath $negativeBase -RejectReparsePoints
  if($negativeContainment.status-eq'pass' -and (Test-Path -LiteralPath $negativeBase)){Remove-Item -LiteralPath $negativeBase -Recurse -Force}

  $runtimeSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1') -Raw -Encoding UTF8
  Add-H3Check $checks 'WIN-H3-015-git-root-identity-required' ($buildSource.Contains('Get-TaogeGitTopLevelUtf8') -and $buildSource.Contains('gitRootMatchesProjectRoot') -and $runtimeSource.Contains("'rev-parse','--show-toplevel'")) 'Nested copies must not borrow the parent repository index; non-Git roots must not terminate under ErrorActionPreference Stop'

  $failed = @($checks|Where-Object{$_.status-eq'fail'})
  $report=[ordered]@{schema_id='taoge://reports/environment-preflight-fixtures/v0.1';fixture_set_id=[string]$fixture.fixture_set_id;generated_at=[DateTimeOffset]::UtcNow.ToString('o');powershell_edition=[string]$PSVersionTable.PSEdition;powershell_version=[string]$PSVersionTable.PSVersion;result=$(if($failed.Count){'fail'}else{'pass'});check_count=$checks.Count;pass_count=@($checks|Where-Object{$_.status-eq'pass'}).Count;fail_count=$failed.Count;checks=[object[]]$checks.ToArray();system_configuration_mutated=$false;network_called=$false}
  $reportFull=Resolve-H3Path $ReportPath
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 30
  foreach($check in $checks){Write-Output "$($check.check_id) $($check.status) $($check.evidence)"}
  Write-Output "ENVIRONMENT_PREFLIGHT_FIXTURE_CHECK=$($report.result)"
  Write-Output "ENVIRONMENT_PREFLIGHT_CHECK_COUNT=$($report.check_count)"
  Write-Output "ENVIRONMENT_PREFLIGHT_REPORT=$ReportPath"
  if($failed.Count){exit 1}
  exit 0
} catch {
  Write-Error ("ENVIRONMENT_PREFLIGHT_FIXTURE_ERROR="+$_.Exception.Message)
  exit 3
}
