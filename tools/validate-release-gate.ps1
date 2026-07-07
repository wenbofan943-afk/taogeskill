param(
  [string]$ProjectRoot = '',
  [string]$PublicReleasePath = 'releases\v0.1.0-alpha.1\public_release',
  [string]$ZipPath = 'releases\v0.1.0-alpha.1\taoge-creative-workflow-0.1.0-alpha.1-public-release.zip',
  [string]$Sha256Path = 'releases\v0.1.0-alpha.1\taoge-creative-workflow-0.1.0-alpha.1-public-release.zip.sha256',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'

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
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $root 'releases\v0.1.0-alpha.1\release-gate-report.md'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $root 'releases\v0.1.0-alpha.1\release-gate-report.json'
  }
  $reportDir = Split-Path -Parent $HumanReportPath
  if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $publicPath = Join-Path $root $PublicReleasePath
  $zipFullPath = Join-Path $root $ZipPath
  $shaFullPath = Join-Path $root $Sha256Path

  $releaseReportPath = Join-Path $publicPath 'release-check-report.json'
  if (Test-Path -LiteralPath $releaseReportPath) {
    $releaseReport = Get-Content -LiteralPath $releaseReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $result = $releaseReport.release_check_report.overall_result
    $status = if ($result -eq 'pass') { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-001' $status ('release_check_report=' + $result) 'Run tools/validate-public-release.ps1 until public release validator passes.'
  } else {
    Add-GateCheck $checks 'GATE-001' 'blocked' 'public_release/release-check-report.json missing' 'Run tools/validate-public-release.ps1.'
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
      (($record.release_state -eq 'remote_ready') -and ($record.publish_status -eq 'publish_ready_waiting_human'))) -and
      ($record.human_approval_required -eq $true)
    $status = if ($stateOk) { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-003' $status ('release_state=' + $record.release_state + '; publish_status=' + $record.publish_status) 'Keep candidate state honest until human approves commit/tag/remote/publish.'
  } else {
    Add-GateCheck $checks 'GATE-003' 'blocked' 'release-record.json missing' 'Build public release candidate.'
  }

  $gitPath = 'D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe'
  if (-not (Test-Path -LiteralPath $gitPath)) {
    $gitPath = 'git'
  }

  $gitStatus = & $gitPath -C $root status --short 2>$null
  if ($LASTEXITCODE -eq 0) {
    $dirtyCount = @($gitStatus).Count
    $status = if ($dirtyCount -eq 0) { 'pass' } else { 'blocked' }
    Add-GateCheck $checks 'GATE-004' $status ('dirty_worktree_items=' + $dirtyCount) 'Create a release commit only after reviewing and staging intended public-source changes.'
  } else {
    Add-GateCheck $checks 'GATE-004' 'blocked' 'git status failed' 'Fix Git availability before release gate.'
  }

  $remoteList = & $gitPath -C $root remote 2>$null
  if ($LASTEXITCODE -eq 0 -and @($remoteList).Count -gt 0) {
    Add-GateCheck $checks 'GATE-005' 'pass' ('remotes=' + ([string]::Join(', ', @($remoteList)))) 'Remote exists.'
  } else {
    Add-GateCheck $checks 'GATE-005' 'waiting_human' 'no_git_remote_configured' 'Ask human to confirm GitHub remote before push.'
  }

  $tagExists = & $gitPath -C $root tag --list 'v0.1.0-alpha.1' 2>$null
  if ($LASTEXITCODE -eq 0 -and @($tagExists).Count -gt 0) {
    Add-GateCheck $checks 'GATE-006' 'pass' 'tag v0.1.0-alpha.1 exists' 'Tag exists.'
  } else {
    Add-GateCheck $checks 'GATE-006' 'waiting_human' 'tag v0.1.0-alpha.1 not created' 'Create tag only after human approval.'
  }

  Add-GateCheck $checks 'GATE-007' 'waiting_human' 'release commit/tag/remote/push require explicit approval' 'Ask human before any release commit, tag, remote setup, push, or GitHub Release.'

  $blocked = @($checks | Where-Object { $_.status -eq 'blocked' })
  $waiting = @($checks | Where-Object { $_.status -eq 'waiting_human' })
  $overall = if ($blocked.Count -gt 0) { 'blocked' } elseif ($waiting.Count -gt 0) { 'ready_waiting_human' } else { 'ready' }
  $exitCode = if ($blocked.Count -gt 0) { 2 } else { 0 }
  $nextAction = if ($overall -eq 'blocked') { 'fix_release_gate_blockers' } elseif ($overall -eq 'ready_waiting_human') { 'ask_human_release_approval' } else { 'eligible_for_release_actions_after_human_confirmation' }

  $report = [ordered]@{
    release_gate_report = [ordered]@{
      release_gate_report_id = 'REL-GATE-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      gate_version = '0.1.0'
      release_candidate_path = $PublicReleasePath
      zip_path = $ZipPath
      sha256_path = $Sha256Path
      target_tag = 'v0.1.0-alpha.1'
      overall_result = $overall
      blocker_count = $blocked.Count
      waiting_human_count = $waiting.Count
      next_action = $nextAction
      checks = [object[]]$checks.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @('# Release Gate Report', '', '```yaml')
  $lines += 'gate_version: 0.1.0'
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
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  Write-Output ('RELEASE_GATE_RESULT=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
