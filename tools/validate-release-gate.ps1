param(
  [string]$ProjectRoot = '',
  [string]$Version = '',
  [string]$GitPath = 'git',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'ArchiveIntegrity.ps1')

function Add-GateCheck {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$Id,
    [string]$Status,
    [string]$Evidence,
    [string]$Remediation
  )
  $Checks.Add([pscustomobject]@{
    check_item_id = $Id
    status = $Status
    evidence = $Evidence
    remediation = $Remediation
  })
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  if ([string]::IsNullOrWhiteSpace($Version)) { $Version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw -Encoding UTF8).Trim() }

  $tagName = "v$Version"
  $PublicReleasePath = "releases\$tagName\public_release"
  $ZipPath = "releases\$tagName\taoge-creative-workflow-$Version-public-release.zip"
  $Sha256Path = "releases\$tagName\taoge-creative-workflow-$Version-public-release.zip.sha256"

  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $root "releases\$tagName\release-gate-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $root "releases\$tagName\release-gate-report.json"
  }
  $reportDir = Split-Path -Parent $HumanReportPath
  if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $publicPath = Join-Path $root $PublicReleasePath
  $zipFullPath = Join-Path $root $ZipPath
  $shaFullPath = Join-Path $root $Sha256Path

  $releaseReportPath = Join-Path (Split-Path -Parent $publicPath) 'release-check-report.json'
  $legacyReleaseReportPath = Join-Path $publicPath 'release-check-report.json'
  if (-not (Test-Path -LiteralPath $releaseReportPath) -and (Test-Path -LiteralPath $legacyReleaseReportPath)) {
    $releaseReportPath = $legacyReleaseReportPath
  }
  if (Test-Path -LiteralPath $releaseReportPath) {
    $releaseReport = Get-Content -LiteralPath $releaseReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $result = $releaseReport.release_check_report.overall_result
    $status = if ($result -eq 'pass') { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-001' $status ('release_check_report=' + $result) 'Run tools/validate-public-release.ps1 until public release validator passes.'
  } else {
    Add-GateCheck $checks 'GATE-001' 'blocked' 'version release-check-report.json missing' 'Run tools/validate-public-release.ps1.'
  }

  if (Test-Path -LiteralPath (Join-Path $publicPath 'archive-manifest.json')) {
    $payloadIntegrity = Test-TaogeArchivePayload -PayloadRoot $publicPath
    $payloadStatus = if ($payloadIntegrity.status -eq 'pass') { 'pass' } else { 'blocked' }
    $payloadEvidence = if ($payloadIntegrity.status -eq 'pass') { "payload_files=$($payloadIntegrity.actual_file_count)" } else { [string]::Join(';', @($payloadIntegrity.errors)) }
    Add-GateCheck $checks 'GATE-009' $payloadStatus $payloadEvidence 'Rebuild the candidate and keep all checker reports outside public_release/.'
  } else {
    Add-GateCheck $checks 'GATE-009' 'blocked' 'archive-manifest.json missing' 'Rebuild the public candidate with archive integrity enabled.'
  }

  if ((Test-Path -LiteralPath $zipFullPath) -and (Test-Path -LiteralPath $shaFullPath)) {
    $actual = (Get-FileHash -LiteralPath $zipFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $record = (Get-Content -LiteralPath $shaFullPath -Raw -Encoding ASCII).ToLowerInvariant()
    $status = if ($record.Contains($actual)) { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-002' $status ('sha256=' + $actual) 'Rebuild public release zip and sha256 together.'
  } else {
    Add-GateCheck $checks 'GATE-002' 'blocked' 'zip or sha256 missing' 'Run tools/build-public-release.ps1.'
  }

  $releaseRecordPath = Join-Path $publicPath 'release-record.json'
  if (Test-Path -LiteralPath $releaseRecordPath) {
    $releaseRecord = Get-Content -LiteralPath $releaseRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $record = $releaseRecord.release_record
    $stateOk =
      ((($record.release_state -eq 'release_candidate_built') -and ($record.publish_status -eq 'not_published')) -or
      (($record.release_state -eq 'tag_ready') -and ($record.publish_status -eq 'publish_ready_waiting_human')) -or
      (($record.release_state -eq 'remote_ready') -and ($record.publish_status -eq 'publish_ready_waiting_human')) -or
      (($record.release_state -eq 'github_release_published') -and ($record.publish_status -eq 'published_to_github'))) -and
      (($record.human_approval_required -eq $true) -or ($record.human_approval_required -eq $false))
    $status = if ($stateOk) { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-003' $status ('release_state=' + $record.release_state + '; publish_status=' + $record.publish_status) 'Keep candidate state honest until human approves commit/tag/remote/publish.'
  } else {
    Add-GateCheck $checks 'GATE-003' 'blocked' 'release-record.json missing' 'Build public release candidate.'
  }

  if (-not (Test-Path -LiteralPath $GitPath)) {
    $GitPath = 'git'
  }

  # Match the Git-index builder's definition of dirty. `git status` can report
  # a Windows working-tree EOL conversion as modified even when `git diff`
  # has no content change, which would otherwise create a false release block.
  & $GitPath -C $root diff --quiet --
  $gitDiffExit = $LASTEXITCODE
  if ($gitDiffExit -eq 0) {
    Add-GateCheck $checks 'GATE-004' 'pass' 'tracked_content_dirty_items=0' 'Create a release commit only after reviewing tracked public-source changes; separately audit untracked files against the Git index package.'
  } elseif ($gitDiffExit -eq 1) {
    Add-GateCheck $checks 'GATE-004' 'blocked' 'tracked_content_dirty_items=one_or_more' 'Create a release commit only after reviewing tracked public-source changes; separately audit untracked files against the Git index package.'
  } else {
    Add-GateCheck $checks 'GATE-004' 'blocked' 'git diff failed' 'Fix Git availability before release gate.'
  }

  $remoteList = & $GitPath -C $root remote 2>$null
  if ($LASTEXITCODE -eq 0 -and @($remoteList).Count -gt 0) {
    Add-GateCheck $checks 'GATE-005' 'pass' ('remotes=' + ([string]::Join(', ', @($remoteList)))) 'Remote exists.'
  } else {
    Add-GateCheck $checks 'GATE-005' 'waiting_human' 'no_git_remote_configured' 'Ask human to confirm GitHub remote before push.'
  }

  $tagExists = & $GitPath -C $root tag --list $tagName 2>$null
  if ($LASTEXITCODE -eq 0 -and @($tagExists).Count -gt 0) {
    Add-GateCheck $checks 'GATE-006' 'pass' ("tag $tagName exists") 'Tag exists.'
  } else {
    Add-GateCheck $checks 'GATE-006' 'waiting_human' ("tag $tagName not created") 'Create tag only after human approval.'
  }

  try {
    $trackedPaths = @(Get-TaogeGitTrackedPathsUtf8 -ProjectRoot $root)
    $restrictedRootPrefixes = @('accounts/', 'indexes/', 'support-logs/', 'offline_tester_packages/', 'releases/', 'state/checks/', '外部资料/')
    $trackedPrivate = @($trackedPaths | Where-Object {
      $candidate = ([string]$_ -replace '\\', '/')
      @($restrictedRootPrefixes | Where-Object { $candidate.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    })
    $status = if ($trackedPrivate.Count -eq 0) { 'pass' } else { 'blocked' }
    $evidence = if ($trackedPrivate.Count -eq 0) { 'no tracked public-source boundary roots' } else { 'tracked_private_paths=' + ([string]::Join(', ', @($trackedPrivate | Select-Object -First 20))) }
    Add-GateCheck $checks 'GATE-007' $status $evidence 'Remove private production roots and local external research from Git tracking; use examples/ or docs/tutorials/ for public samples.'

    $ignorePath = Join-Path $root '.gitignore'
    $ignoreText = if (Test-Path -LiteralPath $ignorePath -PathType Leaf) { Get-Content -LiteralPath $ignorePath -Raw -Encoding UTF8 } else { '' }
    $externalIgnoreAnchored = $ignoreText -match '(?m)^/外部资料/\s*$'
    $externalTracked = @($trackedPaths | Where-Object { ([string]$_ -replace '\\', '/').StartsWith('外部资料/', [System.StringComparison]::OrdinalIgnoreCase) })
    $externalBoundaryStatus = if ($externalIgnoreAnchored -and $externalTracked.Count -eq 0) { 'pass' } else { 'blocked' }
    $externalEvidence = 'ignore_anchor=' + $externalIgnoreAnchored + '; tracked_external_count=' + $externalTracked.Count
    Add-GateCheck $checks 'GATE-010' $externalBoundaryStatus $externalEvidence 'Keep /外部资料/ fully ignored and untracked; external references belong in local research storage, not GitHub Source archives.'
  } catch {
    Add-GateCheck $checks 'GATE-007' 'blocked' 'git tracked-path boundary check failed' 'Fix Git availability before release.'
    Add-GateCheck $checks 'GATE-010' 'blocked' 'external research boundary check unavailable' 'Restore the NUL-separated tracked-path source-boundary gate before release.'
  }

  Add-GateCheck $checks 'GATE-008' 'waiting_human' 'release commit/tag/remote/push require explicit approval' 'Ask human before any release commit, tag, remote setup, push, or GitHub Release.'

  $blocked = @($checks | Where-Object { $_.status -eq 'blocked' })
  $waiting = @($checks | Where-Object { $_.status -eq 'waiting_human' })
  $overall = if ($blocked.Count -gt 0) { 'blocked' } elseif ($waiting.Count -gt 0) { 'ready_waiting_human' } else { 'ready' }
  $exitCode = if ($blocked.Count -gt 0) { 2 } else { 0 }
  $nextAction = if ($overall -eq 'blocked') { 'fix_release_gate_blockers' } elseif ($overall -eq 'ready_waiting_human') { 'ask_human_release_approval' } else { 'eligible_for_release_actions_after_human_confirmation' }

  $report = [ordered]@{
    release_gate_report = [ordered]@{
      release_gate_report_id = 'REL-GATE-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      gate_version = '0.1.0'
      target_version = $Version
      target_tag = $tagName
      release_candidate_path = $PublicReleasePath
      zip_path = $ZipPath
      sha256_path = $Sha256Path
      overall_result = $overall
      blocker_count = $blocked.Count
      waiting_human_count = $waiting.Count
      next_action = $nextAction
      checks = [object[]]$checks.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @('# Release Gate Report', '', '```yaml')
  $lines += 'gate_version: 0.1.0'
  $lines += 'target_version: ' + $Version
  $lines += 'target_tag: ' + $tagName
  $lines += 'overall_result: ' + $overall
  $lines += 'exit_code: ' + $exitCode
  $lines += 'blocker_count: ' + $blocked.Count
  $lines += 'waiting_human_count: ' + $waiting.Count
  $lines += 'next_action: ' + $nextAction
  $lines += '```'
  $lines += ''
  $lines += '| Check ID | Status | Evidence | Remediation |'
  $lines += '|---|---|---|---|'
  foreach ($check in $checks) {
    $lines += ('| {0} | {1} | {2} | {3} |' -f $check.check_item_id, $check.status, $check.evidence, $check.remediation)
  }
  $lines += ''
  $lines += '## Boundary'
  $lines += ''
  $lines += 'This gate does not commit, tag, configure a remote, push, or create a GitHub Release. It only reports whether those actions are safe to ask a human about.'
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output ('RELEASE_GATE_RESULT=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
