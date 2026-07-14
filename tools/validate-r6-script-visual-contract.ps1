param([string]$ReportPath)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R6ScriptVisualContract.ps1')

function Copy-R6SVFixture {
  param([object]$Value)
  return (($Value | ConvertTo-Json -Depth 80) | ConvertFrom-Json)
}

function Invoke-R6SVMutation {
  param([object]$Bundle,[string]$CaseId)
  switch ($CaseId) {
    'baseline_digest_mutated' { $Bundle.draft.original_normalized_body_digest = 'sha256:' + ('0' * 64) }
    'baseline_has_structure' { $Bundle.draft.structure_plan_ref = [pscustomobject]@{artifact_id='STRUCT-EARLY';revision=1;sha256=('sha256:' + ('1' * 64))} }
    'draft_bundle_stale' { $Bundle.draft.normalized_body_digest = 'sha256:' + ('2' * 64) }
    'direct_keep_missing' { $Bundle.structure_plan.alternatives_considered[0].transformation_level = 'local_repair' }
    'structure_order_gap' { $Bundle.structure_plan.stages[1].order = 3 }
    'waiting_false_blocked' { $Bundle.structure_plan.selection_status = 'waiting_human'; $Bundle.structure_plan.plan_status = 'blocked' }
    'semantic_only_visual_entry' { $Bundle.beat_map.mapping_phase = 'semantic_only' }
    'beat_digest_stale' { $Bundle.beat_map.normalized_body_digest = 'sha256:' + ('f' * 64) }
    'beat_anchor_overlap' { $Bundle.beat_map.beats[1].start_byte = 2 }
    'beat_uncovered' { $Bundle.beat_map.beats[1].start_byte = 5 }
    'beat_stage_missing' { $Bundle.beat_map.beats[1].stage_id = 'STAGE-MISSING' }
    'review_decision_stale' { $Bundle.revision_decision.script_design_review_ref.artifact_id = 'REVIEW-OLD' }
    'advisory_unaccepted' { $Bundle.revision_decision.accepted_advisory_issue_ids = @() }
    'visual_before_ready' { $Bundle.script_review.issues[0].issue_gate = 'authorization_required'; $Bundle.revision_decision.decision = 'waiting_authorization'; $Bundle.revision_decision.derived_script_readiness = 'waiting_authorization' }
    'visual_binding_stale' { $Bundle.visual_need_analysis.beat_map_ref.artifact_id = 'BEATMAP-OLD' }
    'coverage_missing' { $Bundle.coverage_ledger.coverage_records = @($Bundle.coverage_ledger.coverage_records[0]) }
    'coverage_duplicate' { $Bundle.coverage_ledger.coverage_records = @($Bundle.coverage_ledger.coverage_records) + @($Bundle.coverage_ledger.coverage_records[0]) }
    'value_proof_missing' { $Bundle.coverage_ledger.accepted_visual_tasks[0].value_proof.viewer_problem_without_visual = '' }
    'non_generate_provider' { $Bundle.coverage_ledger.accepted_visual_tasks[0].disposition = 'create_deterministic_visual' }
    'source_route_invalid' { $task=$Bundle.coverage_ledger.accepted_visual_tasks[0]; $task.disposition='use_source_evidence'; $task.production_path='source_capture'; $task.provider_task_ref=$null; $task.capture_mode='reuse_verified_capture'; $task.evidence_binding=$null }
    'existing_asset_missing' { $task=$Bundle.coverage_ledger.accepted_visual_tasks[0]; $task.disposition='use_existing_asset'; $task.production_path='existing_asset'; $task.provider_task_ref=$null; $task.existing_asset_ref=$null }
    'reuse_target_missing' { $record=$Bundle.coverage_ledger.coverage_records[1]; $record.primary_disposition='reuse_visual_task'; $record.primary_visual_task_id=$null; $record.reused_visual_task_id='VTASK-MISSING' }
    'talking_reason_missing' { $Bundle.coverage_ledger.coverage_records[0].talking_head_advantage = '' }
    'provider_count_wrong' { $Bundle.coverage_ledger.counts.provider_generation_task_count = 2 }
    'occurrence_dangling' { $Bundle.coverage_ledger.visual_insert_occurrences[0].visual_task_id = 'VTASK-MISSING' }
    'coverage_false_complete' { $Bundle.coverage_ledger.unresolved_beat_ids = @('BEAT-R6-002') }
    'zero_false_ready' { $Bundle.coverage_ledger.accepted_visual_tasks=@(); $Bundle.coverage_ledger.visual_insert_occurrences=@(); $Bundle.coverage_ledger.provider_attempt_refs=@(); $Bundle.coverage_ledger.counts.derived_visual_asset_count=0; $Bundle.coverage_ledger.counts.materialized_visual_asset_count=0; $Bundle.coverage_ledger.counts.provider_generation_task_count=0; $Bundle.coverage_ledger.counts.provider_generation_attempt_count=0; $Bundle.coverage_ledger.counts.visual_insert_occurrence_count=0 }
    'alignment_binding_stale' { $Bundle.alignment_review.coverage_ledger_ref.artifact_id = 'LEDGER-OLD' }
    'current_binding_digest_stale' { $Bundle.current_bindings[0].source_draft_digest = 'sha256:' + ('e' * 64) }
    'current_binding_target_wrong' { $Bundle.current_bindings[0].artifact_id = 'STRUCT-OLD' }
    default { throw "unknown_case:$CaseId" }
  }
}

$basePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'examples/r6-script-visual-fixtures/base-direct.json'
$base = Get-Content -LiteralPath $basePath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @(
  @('baseline_digest_mutated','direct_baseline_semantic_mutation'),
  @('baseline_has_structure','direct_baseline_lineage_invalid'),
  @('draft_bundle_stale','draft_bundle_binding_mismatch'),
  @('direct_keep_missing','direct_keep_current_missing'),
  @('structure_order_gap','structure_stage_order_gap'),
  @('waiting_false_blocked','structure_waiting_false_blocked'),
  @('semantic_only_visual_entry','semantic_only_visual_entry_forbidden'),
  @('beat_digest_stale','beat_map_draft_digest_mismatch'),
  @('beat_anchor_overlap','beat_anchor_overlap'),
  @('beat_uncovered','beat_nonwhitespace_uncovered'),
  @('beat_stage_missing','beat_stage_missing'),
  @('review_decision_stale','script_readiness_mismatch:stale'),
  @('advisory_unaccepted','script_readiness_mismatch:needs_revision'),
  @('visual_before_ready','visual_started_before_script_ready'),
  @('visual_binding_stale','visual_analysis_binding_mismatch'),
  @('coverage_missing','coverage_missing'),
  @('coverage_duplicate','coverage_duplicate'),
  @('value_proof_missing','visual_task_value_proof_missing'),
  @('non_generate_provider','non_generate_provider_task_forbidden'),
  @('source_route_invalid','source_evidence_route_invalid'),
  @('existing_asset_missing','existing_asset_ref_missing'),
  @('reuse_target_missing','coverage_reuse_task_missing'),
  @('talking_reason_missing','talking_head_reason_missing'),
  @('provider_count_wrong','visual_count_mismatch:provider_generation_task_count'),
  @('occurrence_dangling','occurrence_task_missing'),
  @('coverage_false_complete','coverage_false_complete'),
  @('zero_false_ready','zero_visual_result_invalid'),
  @('alignment_binding_stale','alignment_binding_mismatch'),
  @('current_binding_digest_stale','current_binding_invalid'),
  @('current_binding_target_wrong','current_binding_target_mismatch')
)

$results = [System.Collections.Generic.List[object]]::new()
$baseErrors = @(Test-R6ScriptVisualBundle (Copy-R6SVFixture $base))
$results.Add([ordered]@{case_id='valid_direct';status=$(if($baseErrors.Count){'fail'}else{'pass'});expected='pass';errors=[object[]]$baseErrors})
$generated = Copy-R6SVFixture $base
$generated.draft.draft_mode = 'generate_from_structure'
$generated.draft.content_origin = 'hotspot_topic'
$generated.draft.draft_status = 'ready'
$generated.draft.original_draft_ref = $null
$generated.draft.original_normalized_body_digest = $null
$generated.draft.structure_plan_ref = [pscustomobject]@{artifact_id='STRUCT-R6-FIX-001';revision=1;sha256=('sha256:' + ('5' * 64))}
$generated.structure_plan.plan_mode = 'design_before_draft'
$generated.structure_plan.content_origin = 'hotspot_topic'
$generated.structure_plan.source_draft_ref = $null
$generatedErrors = @(Test-R6ScriptVisualBundle $generated)
$results.Add([ordered]@{case_id='valid_generated';status=$(if($generatedErrors.Count){'fail'}else{'pass'});expected='pass';errors=[object[]]$generatedErrors})
$revised = Copy-R6SVFixture $base
$revised.draft.draft_mode = 'revise_from_decision'
$revised.draft.draft_revision = 2
$revised.draft.draft_status = 'ready'
$revised.draft.review_ref = [pscustomobject]@{artifact_id='REVIEW-R6-FIX-001';revision=1;sha256=('sha256:' + ('7' * 64))}
$revised.draft.revision_decision_ref = [pscustomobject]@{artifact_id='CRD-R6-FIX-001';revision=1;sha256=('sha256:' + ('a' * 64))}
$revisedErrors = @(Test-R6ScriptVisualBundle $revised)
$results.Add([ordered]@{case_id='valid_revision';status=$(if($revisedErrors.Count){'fail'}else{'pass'});expected='pass';errors=[object[]]$revisedErrors})
foreach ($case in $cases) {
  $copy = Copy-R6SVFixture $base
  Invoke-R6SVMutation $copy $case[0]
  $errors = @(Test-R6ScriptVisualBundle $copy)
  $match = @($errors | Where-Object { [string]$_ -like ('*' + $case[1] + '*') }).Count -gt 0
  $results.Add([ordered]@{case_id=$case[0];status=$(if($match){'pass'}else{'fail'});expected_error=$case[1];errors=[object[]]$errors})
}

$root = Join-Path (Split-Path $PSScriptRoot -Parent) ('state/checks/r6-pointer-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$revisionDir = Join-Path $root 'intermediate/contracts/revisions/content_beat_map'
[System.IO.Directory]::CreateDirectory($revisionDir) | Out-Null
$revisionPath = Join-Path $revisionDir 'BEATMAP-POINTER-FIXTURE.json'
Write-TaogeUtf8NoBomJson -Path $revisionPath -Value ([ordered]@{artifact_id='BEATMAP-POINTER-FIXTURE';revision=1})
$pointerPath = Join-Path $root 'intermediate/contracts/content-beat-map.current.json'
$entry = Join-Path $PSScriptRoot 'invoke-r6-script-visual-contract.ps1'
$pointerOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -Mode commit_pointer -SessionRoot $root -RevisionPath $revisionPath -PointerPath $pointerPath -ObjectType content_beat_map -ArtifactId BEATMAP-POINTER-FIXTURE -Revision 1 -Status ready -SourceDraftDigest ('sha256:' + ('d' * 64)))
$pointerExit = $LASTEXITCODE
$pointerPass = $pointerExit -eq 0 -and (Test-Path -LiteralPath $pointerPath)
if ($pointerPass) { $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json; $pointerPass = [string]$pointer.sha256 -eq ('sha256:' + (Get-TaogeFileSha256 -Path $revisionPath)) }
$results.Add([ordered]@{case_id='pointer_commit_last';status=$(if($pointerPass){'pass'}else{'fail'});expected='pass';output=[object[]]$pointerOutput})

$failed = @($results | Where-Object { $_.status -ne 'pass' })
$report = [ordered]@{schema_version='0.1';checker='validate-r6-script-visual-contract';generated_at=[DateTimeOffset]::UtcNow.ToString('o');case_count=$results.Count;pass_count=$results.Count-$failed.Count;fail_count=$failed.Count;result=$(if($failed.Count){'fail'}else{'pass'});cases=[object[]]$results.ToArray()}
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 40 }
Write-Output ('R6_SCRIPT_VISUAL_FIXTURE_RESULT=' + $report.result)
Write-Output ('R6_SCRIPT_VISUAL_FIXTURE_CASES=' + $results.Count)
if ($failed.Count) { $failed | ForEach-Object { Write-Output ('R6_SCRIPT_VISUAL_FIXTURE_FAIL=' + $_.case_id) }; exit 1 }
