param(
  [string]$FixturePath = 'examples/r6-content-evidence-fixtures/fixtures.json',
  [string]$ReportPath = 'state/checks/r6-content-evidence-report.json',
  [switch]$SkipBrowserCapture
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R6ContentEvidenceRuntime.ps1')
. (Join-Path $PSScriptRoot 'R3VisualNeed.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
. (Join-Path $PSScriptRoot 'P0FinalDeliveryV03.ps1')

function Resolve-R6CheckerPath {
  param([Parameter(Mandatory=$true)][string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Copy-R6JsonObject {
  param([Parameter(Mandatory=$true)][object]$Value)
  return ($Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
}

function Set-R6FixtureValue {
  param(
    [Parameter(Mandatory=$true)][object]$Target,
    [Parameter(Mandatory=$true)][string]$Path,
    [AllowNull()][object]$Value
  )
  $parts = @($Path -split '\.')
  $current = $Target
  for ($index = 0; $index -lt $parts.Count; $index++) {
    $part = $parts[$index]
    $last = $index -eq $parts.Count - 1
    if ($part -match '^\d+$') {
      $arrayIndex = [int]$part
      if ($last) { $current[$arrayIndex] = $Value } else { $current = $current[$arrayIndex] }
      continue
    }
    if ($last) {
      if (@($current.PSObject.Properties.Name) -contains $part) { $current.$part = $Value }
      else { $current | Add-Member -NotePropertyName $part -NotePropertyValue $Value }
    } else {
      $current = $current.$part
    }
  }
}

function Invoke-R6PowerShellTool {
  param(
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [AllowEmptyCollection()][object[]]$Arguments,
    [Parameter(Mandatory=$true)][string]$LogRoot,
    [Parameter(Mandatory=$true)][string]$LogName
  )
  $hostPath = Join-Path $PSHOME 'pwsh.exe'
  if (-not (Test-Path -LiteralPath $hostPath -PathType Leaf)) { $hostPath = Join-Path $PSHOME 'powershell.exe' }
  if (-not (Test-Path -LiteralPath $hostPath -PathType Leaf)) { throw 'current_powershell_host_not_resolvable' }
  $stdout = Join-Path $LogRoot ($LogName + '.stdout.log')
  $stderr = Join-Path $LogRoot ($LogName + '.stderr.log')
  $processArgs = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$ScriptPath) + @($Arguments)
  $process = Start-TaogeProcess -FilePath $hostPath -Arguments $processArgs -StandardOutputPath $stdout -StandardErrorPath $stderr -WorkingDirectory $projectRoot -Wait -Hidden
  $stdoutText = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw -Encoding UTF8 } else { '' }
  $stderrText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw -Encoding UTF8 } else { '' }
  return [pscustomobject]@{exit_code=[int]$process.ExitCode;stdout=$stdoutText;stderr=$stderrText;stdout_path=$stdout;stderr_path=$stderr}
}

function Add-R6CaseResult {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Rows,
    [string]$FixtureId,
    [string]$Expected,
    [string]$Actual,
    [AllowEmptyCollection()][object[]]$Errors
  )
  $Rows.Add([ordered]@{
    fixture_id=$FixtureId
    expected_result=$Expected
    actual_result=$Actual
    expectation_met=($Expected -eq $Actual)
    errors=@($Errors)
  })
}

try {
  $fixtureFull = Resolve-R6CheckerPath $FixturePath
  $reportFull = Resolve-R6CheckerPath $ReportPath
  $fixtures = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $rows = [System.Collections.Generic.List[object]]::new()

  foreach ($case in @($fixtures.direct_cases)) {
    $value = Copy-R6JsonObject $fixtures.direct_base
    foreach ($override in @($case.overrides)) { Set-R6FixtureValue -Target $value -Path $override.path -Value $override.value }
    $result = Test-R6DirectContentIntake -Data $value
    Add-R6CaseResult -Rows $rows -FixtureId $case.fixture_id -Expected $case.expected_result -Actual $result.status -Errors @($result.errors)
  }

  foreach ($case in @($fixtures.evidence_cases)) {
    $value = Copy-R6JsonObject $fixtures.evidence_base
    foreach ($override in @($case.overrides)) { Set-R6FixtureValue -Target $value -Path $override.path -Value $override.value }
    $result = Test-R6EvidenceBundle -Data $value
    Add-R6CaseResult -Rows $rows -FixtureId $case.fixture_id -Expected $case.expected_result -Actual $result.status -Errors @($result.errors)
  }

  foreach ($case in @($fixtures.visual_need_cases)) {
    $value = Copy-R6JsonObject $fixtures.visual_need_base
    foreach ($override in @($case.overrides)) { Set-R6FixtureValue -Target $value -Path $override.path -Value $override.value }
    $errors = @(Test-R3VisualNeedAnalysis -Document $value)
    $actual = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    Add-R6CaseResult -Rows $rows -FixtureId $case.fixture_id -Expected $case.expected_result -Actual $actual -Errors $errors
  }

  $runtimeSmoke = [ordered]@{
    capture_status=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    capture_reconcile_status=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    capture_failure_recorded=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    capture_failure_recovery=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    render_status=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    render_reconcile_status=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    render_business_input_invalidation=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    source_commentary_separation=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    image2_impersonation_absent=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    final_html_evidence_card=$(if($SkipBrowserCapture){'not_tested'}else{'pending'})
    error=''
  }

  if (-not $SkipBrowserCapture) {
    $workRoot = Join-Path $projectRoot ('state\checks\r6-fixture-work-' + [guid]::NewGuid().ToString('N'))
    $sessionRoot = Join-Path $workRoot 'session'
    New-Item -ItemType Directory -Force -Path $sessionRoot | Out-Null
    $sourcePage = Join-Path $projectRoot 'examples\r6-content-evidence-fixtures\source-page.html'
    $captureScript = Join-Path $PSScriptRoot 'invoke-r6-source-capture.ps1'
    $runtimeScript = Join-Path $PSScriptRoot 'invoke-r6-content-evidence.ps1'
    $captureArgs = @(
      '-CaptureId','capture-fixture-001',
      '-SourceUrl',$sourcePage,
      '-SessionRoot',$sessionRoot,
      '-ScreenshotRelativePath','captures/fixture.png',
      '-AttemptRelativePath','capture/capture-fixture-001.json',
      '-ViewportWidth','1280',
      '-ViewportHeight','960',
      '-AllowLocalFixture'
    )
    try {
      $firstCapture = Invoke-R6PowerShellTool -ScriptPath $captureScript -Arguments $captureArgs -LogRoot $workRoot -LogName 'capture-first'
      if ($firstCapture.exit_code -ne 0 -or $firstCapture.stdout -notmatch 'CAPTURE_ACTION=captured|CAPTURE_ACTION=reconciled_existing_output') {
        throw "capture_first_failed:exit=$($firstCapture.exit_code):$($firstCapture.stderr.Trim())"
      }
      $runtimeSmoke.capture_status = 'pass'
      $captureRecordPath = Join-Path $sessionRoot 'capture\capture-fixture-001.json'
      $captureRecord = Get-Content -LiteralPath $captureRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $captureHashBefore = Get-TaogeFileSha256 -Path (Join-Path $sessionRoot 'captures\fixture.png')

      $bundle = Copy-R6JsonObject $fixtures.evidence_base
      Set-R6FixtureValue -Target $bundle -Path 'capture.captured_url' -Value $captureRecord.source_url
      Set-R6FixtureValue -Target $bundle -Path 'capture.fixture_mode' -Value $true
      Set-R6FixtureValue -Target $bundle -Path 'capture.capture_at' -Value $captureRecord.completed_at
      Set-R6FixtureValue -Target $bundle -Path 'capture.sha256' -Value $captureRecord.sha256
      Set-R6FixtureValue -Target $bundle -Path 'capture.attempt_number' -Value $captureRecord.attempt_number
      Set-R6FixtureValue -Target $bundle -Path 'capture.attempt_history' -Value @($captureRecord.attempt_history)
      Set-R6FixtureValue -Target $bundle -Path 'capture.capture_status' -Value 'captured'
      $bundlePath = Join-Path $workRoot 'evidence-bundle.json'
      Write-TaogeUtf8NoBomJson -Path $bundlePath -Value $bundle -Depth 30

      $assetPath = Join-Path $sessionRoot 'assets\images\evidence-pip\pip-fixture-001.svg'
      $sidecarPath = Join-Path $sessionRoot 'assets\images\metadata\pip-fixture-001.json'
      $renderArgs = @(
        '-Mode','render_evidence_pip',
        '-InputPath',$bundlePath,
        '-SessionRoot',$sessionRoot,
        '-OutputPath','assets/images/evidence-pip/pip-fixture-001.svg',
        '-SidecarPath','assets/images/metadata/pip-fixture-001.json'
      )
      $firstRender = Invoke-R6PowerShellTool -ScriptPath $runtimeScript -Arguments $renderArgs -LogRoot $workRoot -LogName 'render-first'
      if ($firstRender.exit_code -ne 0 -or $firstRender.stdout -notmatch 'RENDER_ACTION=rendered|RENDER_ACTION=reused_verified') {
        throw "render_first_failed:exit=$($firstRender.exit_code):$($firstRender.stderr.Trim())"
      }
      if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf) -or -not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) { throw 'render_outputs_missing' }
      $assetText = Get-Content -LiteralPath $assetPath -Raw -Encoding UTF8
      $runtimeSmoke.render_status = 'pass'
      $runtimeSmoke.source_commentary_separation = $(if($assetText -match '来源事实' -and $assetText -match '示例解读'){'pass'}else{'fail'})
      $runtimeSmoke.image2_impersonation_absent = $(if($assetText -match 'data:image/png;base64' -and $assetText -notmatch 'Image 2|codex_image2'){'pass'}else{'fail'})
      $pipDocument = [pscustomobject]@{pip_cards=@([pscustomobject]@{card_id='pip-card-fixture-001';display_order=1;relative_path='assets/images/evidence-pip/pip-fixture-001.svg';preview_alt='来源证据画中画';insert_after_text='示例公开资料显示';insert_before_text='该指标为 42';narrative_function='用来源页面帮助理解数据口径';visual_text_summary='来源事实与示例解读分层';trigger_text='指标为 42';prompt_path='evidence-bundle.json';generation_record_path='capture/capture-fixture-001.json';sidecar_path='assets/images/metadata/pip-fixture-001.json'})}
      $pipHtml = ConvertTo-P0V3PipCardsHtml -Document $pipDocument -Session $sessionRoot -HtmlBase (Join-Path $sessionRoot 'deliverables')
      $runtimeSmoke.final_html_evidence_card = $(if($pipHtml -match '示例研究机构' -and $pipHtml -match '打开公开来源' -and $pipHtml -match 'supported' -and $pipHtml -match '示例解读' -and $pipHtml -notmatch 'Image 2'){'pass'}else{'fail'})
      $assetHashBefore = Get-TaogeFileSha256 -Path $assetPath

      $secondCapture = Invoke-R6PowerShellTool -ScriptPath $captureScript -Arguments $captureArgs -LogRoot $workRoot -LogName 'capture-second'
      $captureHashAfter = Get-TaogeFileSha256 -Path (Join-Path $sessionRoot 'captures\fixture.png')
      $runtimeSmoke.capture_reconcile_status = $(if($secondCapture.exit_code -eq 0 -and $secondCapture.stdout -match 'CAPTURE_ACTION=reused_verified' -and $captureHashBefore -eq $captureHashAfter){'pass'}else{'fail'})

      $secondRender = Invoke-R6PowerShellTool -ScriptPath $runtimeScript -Arguments $renderArgs -LogRoot $workRoot -LogName 'render-second'
      $assetHashAfter = Get-TaogeFileSha256 -Path $assetPath
      $runtimeSmoke.render_reconcile_status = $(if($secondRender.exit_code -eq 0 -and $secondRender.stdout -match 'RENDER_ACTION=reused_verified' -and $assetHashBefore -eq $assetHashAfter){'pass'}else{'fail'})

      Set-R6FixtureValue -Target $bundle -Path 'pip.creator_commentary' -Value '业务输入变化后必须重新渲染。'
      Write-TaogeUtf8NoBomJson -Path $bundlePath -Value $bundle -Depth 30
      $thirdRender = Invoke-R6PowerShellTool -ScriptPath $runtimeScript -Arguments $renderArgs -LogRoot $workRoot -LogName 'render-business-input-change'
      $changedHash = Get-TaogeFileSha256 -Path $assetPath
      $changedSidecar = Get-Content -LiteralPath $sidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $runtimeSmoke.render_business_input_invalidation = $(if($thirdRender.exit_code -eq 0 -and $thirdRender.stdout -match 'RENDER_ACTION=rendered' -and $changedHash -ne $assetHashBefore -and $changedSidecar.creator_commentary -eq '业务输入变化后必须重新渲染。'){'pass'}else{'fail'})

      $recoverySessionRoot = Join-Path $workRoot 'recovery-session'
      New-Item -ItemType Directory -Force -Path $recoverySessionRoot | Out-Null
      $failureArgs = @(
        '-CaptureId','capture-recovery-fixture-001',
        '-SourceUrl',$sourcePage,
        '-SessionRoot',$recoverySessionRoot,
        '-ScreenshotRelativePath','captures/recovery.png',
        '-AttemptRelativePath','capture/capture-recovery-fixture-001.json',
        '-ViewportWidth','1280',
        '-ViewportHeight','960',
        '-BrowserPath',(Join-Path $env:SystemRoot 'System32\where.exe'),
        '-AllowLocalFixture'
      )
      $failedCapture = Invoke-R6PowerShellTool -ScriptPath $captureScript -Arguments $failureArgs -LogRoot $workRoot -LogName 'capture-intentional-failure'
      $recoveryRecordPath = Join-Path $recoverySessionRoot 'capture\capture-recovery-fixture-001.json'
      $failedRecord = Get-Content -LiteralPath $recoveryRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $runtimeSmoke.capture_failure_recorded = $(if($failedCapture.exit_code -ne 0 -and $failedRecord.capture_status -eq 'capture_failed' -and [int]$failedRecord.attempt_number -eq 1){'pass'}else{'fail'})
      $recoveryArgs = @($failureArgs | Where-Object { $_ -ne '-BrowserPath' -and $_ -ne (Join-Path $env:SystemRoot 'System32\where.exe') })
      $recoveredCapture = Invoke-R6PowerShellTool -ScriptPath $captureScript -Arguments $recoveryArgs -LogRoot $workRoot -LogName 'capture-recovery'
      $recoveredRecord = Get-Content -LiteralPath $recoveryRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $runtimeSmoke.capture_failure_recovery = $(if($recoveredCapture.exit_code -eq 0 -and $recoveredRecord.capture_status -eq 'captured' -and [int]$recoveredRecord.attempt_number -eq 2 -and @($recoveredRecord.attempt_history).Count -eq 1){'pass'}else{'fail'})
    } catch {
      $runtimeSmoke.error = $_.Exception.Message
      foreach ($key in @('capture_status','capture_reconcile_status','capture_failure_recorded','capture_failure_recovery','render_status','render_reconcile_status','render_business_input_invalidation','source_commentary_separation','image2_impersonation_absent','final_html_evidence_card')) {
        if ($runtimeSmoke[$key] -eq 'pending') { $runtimeSmoke[$key] = 'fail' }
      }
    }
  }

  $expectationFailures = @($rows | Where-Object { -not $_.expectation_met })
  $runtimeFailures = @($runtimeSmoke.GetEnumerator() | Where-Object { $_.Key -ne 'error' -and $_.Value -eq 'fail' })
  $overall = if ($expectationFailures.Count -eq 0 -and $runtimeFailures.Count -eq 0) { 'pass' } else { 'fail' }
  if ($SkipBrowserCapture -and $overall -eq 'pass') { $overall = 'pass_with_warnings' }
  $report = [ordered]@{
    schema_id='taoge://reports/r6/content-evidence/v0.1'
    schema_version='0.1.0'
    overall_result=$overall
    attribution=$(if($runtimeFailures.Count -gt 0){'checker_or_environment'}elseif($expectationFailures.Count -gt 0){'workflow_contract'}else{'none'})
    case_count=$rows.Count
    expectation_failure_count=$expectationFailures.Count
    runtime_smoke=$runtimeSmoke
    results=@($rows)
  }
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 30
  Write-Output "R6_CONTENT_EVIDENCE_CHECK=$overall"
  Write-Output "CASE_COUNT=$($rows.Count)"
  Write-Output "CAPTURE_SMOKE=$($runtimeSmoke.capture_status)"
  Write-Output "RENDER_SMOKE=$($runtimeSmoke.render_status)"
  if ($overall -eq 'fail') { exit 1 }
  exit 0
} catch {
  Write-Error $_
  exit 3
}
