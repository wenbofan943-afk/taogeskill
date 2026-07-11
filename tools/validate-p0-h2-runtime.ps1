param(
  [string]$FixturePath = "examples/p0-runtime-v0.2-fixture",
  [string]$LegacyFixturePath = "examples/p0-runtime-fixture",
  [string]$ReportPath = "state/checks/p0-h2-runtime-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

function Add-Result {
  param([string]$Id, [bool]$Passed, [string]$Evidence)
  $script:results.Add([ordered]@{ check_id=$Id; status=$(if($Passed){'pass'}else{'fail'}); evidence=$Evidence })
  if (-not $Passed) { $script:failures.Add("$Id $Evidence") }
}

function Invoke-Runtime {
  param([string]$Session, [string]$Mode)
  $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:runtimePath -SessionPath $Session -Mode $Mode 2>&1 | ForEach-Object { [string]$_ })
  $exitCode = $LASTEXITCODE
  return [pscustomobject]@{ ExitCode=$exitCode; Output=$output; Text=[string]::Join("`n", $output) }
}

function Copy-TestFixture {
  param([string]$Source, [string]$Name)
  $target = [System.IO.Path]::GetFullPath((Join-Path $script:checksRoot $Name))
  if (-not $target.StartsWith($script:checksRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "unsafe_test_target:$target" }
  if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  Copy-Item -LiteralPath $Source -Destination $target -Recurse
  return $target
}

try {
  $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $script:runtimePath = Join-Path $PSScriptRoot 'invoke-workflow-runtime.ps1'
  $contractHelper = Join-Path $PSScriptRoot 'P0ContractHelper.ps1'
  . $contractHelper
  . (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
  $fixture = (Resolve-Path (Join-Path $projectRoot $FixturePath)).Path
  $legacyFixture = (Resolve-Path (Join-Path $projectRoot $LegacyFixturePath)).Path
  $checksCandidate = Join-Path $projectRoot 'state/checks'
  if (-not (Test-Path -LiteralPath $checksCandidate)) { New-Item -ItemType Directory -Path $checksCandidate -Force | Out-Null }
  $script:checksRoot = (Resolve-Path $checksCandidate).Path
  $script:results = [System.Collections.Generic.List[object]]::new()
  $script:failures = [System.Collections.Generic.List[string]]::new()

  $workA = Copy-TestFixture $fixture 'p0-h2-runtime-a'
  $workB = Copy-TestFixture $fixture 'p0-h2-runtime-b'

  $validate = Invoke-Runtime $workA 'validate'
  Add-Result 'H2-RUN-001-plan-valid' ($validate.ExitCode -eq 0 -and $validate.Text.Contains('plan_valid_waiting_steps')) $validate.Text
  $resumeBefore = Invoke-Runtime $workA 'resume_report'
  Add-Result 'H2-RUN-002-resume-before' ($resumeBefore.ExitCode -eq 0 -and $resumeBefore.Text.Contains('RESUME_NEXT_STEP=STEP-compile-render-input')) $resumeBefore.Text

  $compileA = Invoke-Runtime $workA 'compile_render_input'
  Add-Result 'H2-RUN-003-compile' ($compileA.ExitCode -eq 0 -and $compileA.Text.Contains('DELIVERY_READINESS=ready_with_warnings')) $compileA.Text
  $renderA = Invoke-Runtime $workA 'render_final_delivery'
  Add-Result 'H2-RUN-004-render' ($renderA.ExitCode -eq 0 -and $renderA.Text.Contains('WORKFLOW_RUNTIME_RESULT=rendered')) $renderA.Text

  $inputPathA = Join-Path $workA 'deliverables/p0/final-delivery-render-input.json'
  $outputPathA = Join-Path $workA 'deliverables/final-delivery.html'
  $receiptPathA = Join-Path $workA 'deliverables/p0/render-receipt.json'
  $eventPathA = Join-Path $workA 'intermediate/p0/execution-events.jsonl'
  $lineagePathA = Join-Path $workA 'deliverables/p0/artifact-lineage-manifest.json'
  $checkPathA = Join-Path $workA 'deliverables/p0/artifact-checks.json'
  $renderInput = Read-P0JsonFile $inputPathA
  $renderInputErrors = @(Test-P0RenderInputContract $renderInput)
  Add-Result 'H2-RUN-005-typed-input' ($renderInputErrors.Count -eq 0 -and $renderInput.production_status.delivery_readiness -eq 'ready_with_warnings') ([string]::Join(';', $renderInputErrors))
  $inputText = Get-Content -LiteralPath $inputPathA -Raw -Encoding UTF8
  Add-Result 'H2-RUN-006-no-html-fragments' (-not ($inputText -match '"[^"]*_html"\s*:')) 'typed input contains no *_html fields'

  $events = @(Get-Content -LiteralPath $eventPathA -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
  $eventErrors = @(Test-P0EventLogContract $events)
  Add-Result 'H2-RUN-007-events' ($eventErrors.Count -eq 0 -and $events.Count -eq 3) ("count=$($events.Count);" + [string]::Join(';', $eventErrors))
  $lineageErrors = @(Test-P0LineageContract (Read-P0JsonFile $lineagePathA))
  Add-Result 'H2-RUN-008-lineage' ($lineageErrors.Count -eq 0) ([string]::Join(';', $lineageErrors))
  $checkErrors = @(Test-P0ArtifactCheckSetContract (Read-P0JsonFile $checkPathA))
  Add-Result 'H2-RUN-009-check-set' ($checkErrors.Count -eq 0) ([string]::Join(';', $checkErrors))

  $html = Get-Content -LiteralPath $outputPathA -Raw -Encoding UTF8
  $normalSecurityPass = -not ($html -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:|\{\{[^}]+\}\}')
  $encodingWork = Copy-TestFixture $fixture 'p0-h2-security-encoding'
  $encodingCandidatePath = Join-Path $encodingWork 'deliverables/p0/final-delivery-render-candidate.json'
  $encodingCandidate = Read-P0JsonFile $encodingCandidatePath
  $encodingCandidate.script_card.final_text = '</textarea><script>alert(1)</script>'
  $encodingCandidate.action_cards[0].card_id = 'CARD-ACTION-" data-evil="x'
  [System.IO.File]::WriteAllText($encodingCandidatePath, (($encodingCandidate | ConvertTo-Json -Depth 50) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $encodingCompile = Invoke-Runtime $encodingWork 'compile_render_input'
  $encodingRender = Invoke-Runtime $encodingWork 'render_final_delivery'
  $encodingHtml = if ($encodingRender.ExitCode -eq 0) { Get-Content -LiteralPath (Join-Path $encodingWork 'deliverables/final-delivery.html') -Raw -Encoding UTF8 } else { '' }
  $encodingPass = $encodingCompile.ExitCode -eq 0 -and $encodingRender.ExitCode -eq 0 -and $encodingHtml.Contains('&lt;script&gt;alert(1)&lt;/script&gt;') -and $encodingHtml.Contains('&quot; data-evil=&quot;x') -and -not ($encodingHtml -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:')
  $urlWork = Copy-TestFixture $fixture 'p0-h2-security-url'
  $urlCandidatePath = Join-Path $urlWork 'deliverables/p0/final-delivery-render-candidate.json'
  $urlCandidate = Read-P0JsonFile $urlCandidatePath
  $urlCandidate.trace_cards[0].relative_path = 'javascript:alert(1)'
  [System.IO.File]::WriteAllText($urlCandidatePath, (($urlCandidate | ConvertTo-Json -Depth 50) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $urlCompile = Invoke-Runtime $urlWork 'compile_render_input'
  $urlPass = $urlCompile.ExitCode -ne 0 -and ($urlCompile.Text.Contains('trace_artifact_path_invalid') -or $urlCompile.Text.Contains('trace_path_unsafe'))
  $securityPass = $normalSecurityPass -and $encodingPass -and $urlPass
  Add-Result 'H2-RUN-010-html-security' $securityPass ("normal=$normalSecurityPass;text_attribute_encoding=$encodingPass;unsafe_url_rejected=$urlPass")
  $semanticPass = [regex]::Matches($html, '<h1\b', 'IgnoreCase').Count -eq 1 -and [regex]::Matches($html, '<main\b', 'IgnoreCase').Count -eq 1 -and [regex]::Matches($html, '<details\b', 'IgnoreCase').Count -ge 2
  Add-Result 'H2-RUN-011-html-semantics' $semanticPass 'exactly one h1/main and folded audit evidence'
  $deliveryFirst = $html.IndexOf('id="final-script"', [System.StringComparison]::Ordinal) -ge 0 -and $html.IndexOf('id="final-script"', [System.StringComparison]::Ordinal) -lt $html.IndexOf('id="trace-links"', [System.StringComparison]::Ordinal)
  Add-Result 'H2-RUN-012-delivery-first' $deliveryFirst 'script precedes trace evidence'

  $receipt = Read-P0JsonFile $receiptPathA
  $receiptContractErrors = @(Test-P0V2RenderReceipt $receipt)
  $requiredReceipt = @('schema_id','schema_version','receipt_id','render_input_sha256','renderer_version','template_sha256','included_card_ids','included_asset_ids','warning_codes','output_html_sha256')
  $receiptMissing = @($requiredReceipt | Where-Object { -not (Test-P0HasProperty $receipt $_) })
  $expectedInputHash = Get-P0V2Hash $inputPathA
  $expectedOutputHash = Get-P0V2Hash $outputPathA
  $expectedTemplateHash = Get-P0V2Hash (Join-Path $projectRoot 'templates/final-delivery/final-delivery.template.html')
  $receiptPass = $receiptMissing.Count -eq 0 -and $receiptContractErrors.Count -eq 0 -and $receipt.renderer_version -eq 'final-delivery-renderer-v0.2' -and $receipt.render_input_sha256 -eq $expectedInputHash -and $receipt.output_html_sha256 -eq $expectedOutputHash -and $receipt.template_sha256 -eq $expectedTemplateHash -and @($receipt.included_card_ids).Count -eq 10
  Add-Result 'H2-RUN-013-receipt' $receiptPass ("missing=$([string]::Join(',', $receiptMissing));contract=$([string]::Join(';', $receiptContractErrors));output=$($receipt.output_html_sha256)")

  $eventCountBeforeReuse = $events.Count
  $reuse = Invoke-Runtime $workA 'render_final_delivery'
  $eventCountAfterReuse = @(Get-Content -LiteralPath $eventPathA -Encoding UTF8 | Where-Object { $_.Trim() }).Count
  $reusePass = $reuse.ExitCode -eq 0 -and $reuse.Text.Contains('skipped_reused') -and $eventCountAfterReuse -eq $eventCountBeforeReuse -and (Get-P0V2Hash $outputPathA) -eq $expectedOutputHash
  Add-Result 'H2-RUN-014-idempotent-reuse' $reusePass ("before=$eventCountBeforeReuse;after=$eventCountAfterReuse;$($reuse.Text)")

  $compileB = Invoke-Runtime $workB 'compile_render_input'
  $renderB = Invoke-Runtime $workB 'render_final_delivery'
  $outputPathB = Join-Path $workB 'deliverables/final-delivery.html'
  $receiptPathB = Join-Path $workB 'deliverables/p0/render-receipt.json'
  $deterministicPass = $compileB.ExitCode -eq 0 -and $renderB.ExitCode -eq 0 -and (Get-P0V2Hash $outputPathB) -eq $expectedOutputHash -and (Get-Content $receiptPathB -Raw -Encoding UTF8) -eq (Get-Content $receiptPathA -Raw -Encoding UTF8)
  Add-Result 'H2-RUN-015-cross-run-determinism' $deterministicPass 'fresh copied sessions produce identical HTML and receipt'

  $legacyWork = Copy-TestFixture $legacyFixture 'p0-h2-legacy-v0.1'
  $legacyEventPath = Join-Path $legacyWork 'intermediate/p0/execution-events.jsonl'
  $legacyLines = @(Get-Content -LiteralPath $legacyEventPath -Encoding UTF8 | Where-Object { (($_ | ConvertFrom-Json).step_id) -ne 'STEP-render-html' })
  [System.IO.File]::WriteAllText($legacyEventPath, ([string]::Join("`n", $legacyLines) + "`n"), [System.Text.UTF8Encoding]::new($false))
  foreach ($legacyArtifact in @('deliverables/final-delivery.html','deliverables/p0/artifact-lineage-manifest.json')) {
    $legacyArtifactPath = Join-Path $legacyWork $legacyArtifact
    if (Test-Path -LiteralPath $legacyArtifactPath) { Remove-Item -LiteralPath $legacyArtifactPath -Force }
  }
  $legacyValidate = Invoke-Runtime $legacyWork 'validate'
  $legacyResume = Invoke-Runtime $legacyWork 'resume_report'
  $legacyRender = Invoke-Runtime $legacyWork 'render_final_delivery'
  $legacyHtml = Get-Content -LiteralPath (Join-Path $legacyWork 'deliverables/final-delivery.html') -Raw -Encoding UTF8
  $legacyPass = $legacyValidate.ExitCode -eq 0 -and $legacyResume.ExitCode -eq 0 -and $legacyRender.ExitCode -eq 0 -and $legacyRender.Text.Contains('WORKFLOW_RUNTIME_RESULT=rendered') -and -not ($legacyHtml -match '\{\{[^}]+\}\}') -and $legacyHtml.Contains('legacy_v0.1_not_derived')
  Add-Result 'H2-RUN-016-legacy-compatibility' $legacyPass ($legacyValidate.Text + ';' + $legacyResume.Text + ';' + $legacyRender.Text)

  $revisionWork = Copy-TestFixture $fixture 'p0-h2-latest-pending-revision'
  $revisionCompile1 = Invoke-Runtime $revisionWork 'compile_render_input'
  $revisionRender1 = Invoke-Runtime $revisionWork 'render_final_delivery'
  $revisionPlanPath = Join-Path $revisionWork 'intermediate/p0/session-execution-plan.json'
  $revisionCandidatePath = Join-Path $revisionWork 'deliverables/p0/final-delivery-render-candidate.json'
  $revisionPlan = Read-P0JsonFile $revisionPlanPath
  $revisionPlan.steps = @($revisionPlan.steps) + @(
    [pscustomobject][ordered]@{step_id='STEP-compile-render-input-revision-2';step_kind='deterministic_tool';requires_step_ids=@('STEP-render-final-delivery');produces_artifact_type='deterministic_final_delivery_render_input';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=[pscustomobject][ordered]@{mode='bounded';automatic_retries=1;max_attempts=2;idempotency_scope='session_step_input_digest'};operation='compile_render_input';requires_artifact_ids=@('RCAND-P0H2-001')},
    [pscustomobject][ordered]@{step_id='STEP-render-final-delivery-revision-2';step_kind='deterministic_tool';requires_step_ids=@('STEP-compile-render-input-revision-2');produces_artifact_type='final_delivery';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=[pscustomobject][ordered]@{mode='bounded';automatic_retries=1;max_attempts=2;idempotency_scope='session_step_input_digest'};operation='render_final_delivery';requires_artifact_ids=@('RIN-P0H2-REV-2')}
  )
  [System.IO.File]::WriteAllText($revisionPlanPath, (($revisionPlan | ConvertTo-Json -Depth 50) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $revisionCandidate = Read-P0JsonFile $revisionCandidatePath
  $revisionCandidate.render_input_id = 'RIN-P0H2-REV-2'
  $revisionCandidate.final_delivery_id = 'FD-P0H2-REV-2'
  $revisionCandidate.script_card.hook_text = '第二次修订应选择最新待执行步骤。'
  [System.IO.File]::WriteAllText($revisionCandidatePath, (($revisionCandidate | ConvertTo-Json -Depth 50) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $revisionCompile2 = Invoke-Runtime $revisionWork 'compile_render_input'
  $revisionRender2 = Invoke-Runtime $revisionWork 'render_final_delivery'
  $revisionEvents = @(Get-Content -LiteralPath (Join-Path $revisionWork 'intermediate/p0/execution-events.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
  $revisionTail = @($revisionEvents | Select-Object -Last 2 | ForEach-Object { [string]$_.step_id })
  $revisionPass = $revisionCompile1.ExitCode -eq 0 -and $revisionRender1.ExitCode -eq 0 -and $revisionCompile2.ExitCode -eq 0 -and $revisionRender2.ExitCode -eq 0 -and ($revisionTail -join '|') -eq 'STEP-compile-render-input-revision-2|STEP-render-final-delivery-revision-2'
  Add-Result 'H2-RUN-017-latest-pending-revision' $revisionPass ("tail=" + ($revisionTail -join '|') + ";compile=$($revisionCompile2.Text);render=$($revisionRender2.Text)")

  $report = [ordered]@{
    report_id = 'P0-H2-RUNTIME-CHECK'
    generated_at = [DateTimeOffset]::UtcNow.ToString('o')
    fixture = $FixturePath
    real_account_data_executed = $false
    real_image_generation_executed = $false
    external_api_executed = $false
    publishing_executed = $false
    result = $(if($script:failures.Count -eq 0){'pass'}else{'fail'})
    checks = [object[]]$script:results.ToArray()
  }
  $reportTarget = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ReportPath))
  $reportParent = Split-Path -Parent $reportTarget
  if (-not (Test-Path -LiteralPath $reportParent)) { New-Item -ItemType Directory -Path $reportParent -Force | Out-Null }
  [System.IO.File]::WriteAllText($reportTarget, (($report | ConvertTo-Json -Depth 12) + "`n"), [System.Text.UTF8Encoding]::new($false))

  foreach ($result in $script:results) { Write-Output ("{0} {1} {2}" -f $result.check_id, $result.status, $result.evidence) }
  if ($script:failures.Count) {
    Write-Output ('P0_H2_RUNTIME_CHECK=fail ' + [string]::Join('; ', $script:failures))
    exit 1
  }
  Write-Output 'P0_H2_RUNTIME_CHECK=pass'
  Write-Output ("P0_H2_RUNTIME_REPORT=$ReportPath")
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
