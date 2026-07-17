[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$WorkRoot = '',
    [string]$MachineReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Read-M3Json {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Copy-M3Object {
    param([Parameter(Mandatory = $true)][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

function Get-M3Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-TaogeFileSha256 -Path $Path).ToLowerInvariant()
}

function Invoke-M3Kernel {
    param(
        [Parameter(Mandatory = $true)][string]$PowerShellPath,
        [Parameter(Mandatory = $true)][string]$KernelCliPath,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ShadowRoot,
        [string]$CommandPath = ''
    )
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $KernelCliPath,
        '-Mode', $Mode,
        '-ProjectRoot', $Root,
        '-ShadowRoot', $ShadowRoot
    )
    if (-not [string]::IsNullOrWhiteSpace($CommandPath)) {
        $arguments += @('-RequestPath', $CommandPath)
    }
    return Invoke-TaogeProcessCapture -FilePath $PowerShellPath -Arguments $arguments -WorkingDirectory $Root -AllowNonZeroExit
}

function Get-M3KernelCode {
    param([Parameter(Mandatory = $true)][object]$ProcessResult)
    try {
        $payload = [string]$ProcessResult.stdout | ConvertFrom-Json
        return [string]$payload.code
    }
    catch {
        return 'tool_output_invalid'
    }
}

function New-M3Activity {
    param(
        [Parameter(Mandatory = $true)][string]$ComponentId,
        [Parameter(Mandatory = $true)][string]$Status
    )
    $isResearch = $ComponentId -eq 'hotspot_research'
    $prefix = if ($isResearch) { 'RESEARCH' } else { 'FRESHNESS' }
    $hashChar = if ($isResearch) { 'a' } else { 'b' }
    $outcomeChar = if ($isResearch) { 'c' } else { 'd' }
    if ($Status -eq 'attempt_started') {
        return [pscustomobject][ordered]@{
            activity_id = "M3-ACT-$prefix-001"
            component_id = $ComponentId
            activity_status = 'attempt_started'
            request_id = "M3-REQ-$prefix-001"
            request_sha256 = ($hashChar * 64)
            attempt_id = "M3-ATTEMPT-$prefix-001"
            attempt_no = 1
            attempt_status = 'started'
            started_at = if ($isResearch) { '2026-07-18T10:01:30+08:00' } else { '2026-07-18T10:21:30+08:00' }
            completed_at = $null
            outcome_id = $null
            outcome_status = 'not_available'
            outcome_sha256 = $null
            output_artifact_id = $null
            consumer_status = 'pending'
            accepted_at = $null
            retry_performed = $false
        }
    }
    return [pscustomobject][ordered]@{
        activity_id = "M3-ACT-$prefix-001"
        component_id = $ComponentId
        activity_status = 'outcome_reconciled'
        request_id = "M3-REQ-$prefix-001"
        request_sha256 = ($hashChar * 64)
        attempt_id = "M3-ATTEMPT-$prefix-001"
        attempt_no = 1
        attempt_status = 'succeeded'
        started_at = if ($isResearch) { '2026-07-18T10:01:30+08:00' } else { '2026-07-18T10:21:30+08:00' }
        completed_at = if ($isResearch) { '2026-07-18T10:02:30+08:00' } else { '2026-07-18T10:22:30+08:00' }
        outcome_id = "M3-OUTCOME-$prefix-001"
        outcome_status = 'succeeded'
        outcome_sha256 = ($outcomeChar * 64)
        output_artifact_id = "M3-OUTPUT-$prefix-001"
        consumer_status = 'accepted'
        accepted_at = if ($isResearch) { '2026-07-18T10:02:40+08:00' } else { '2026-07-18T10:22:40+08:00' }
        retry_performed = $false
    }
}

function New-M3Result {
    param(
        [Parameter(Mandatory = $true)][object]$Expected,
        [Parameter(Mandatory = $true)][object]$Component,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][int]$Ordinal
    )
    $componentId = [string]$Expected.component_id
    $result = [pscustomobject][ordered]@{
        stage_id = [string]$Expected.stage_id
        component_id = $componentId
        artifact_id = ('M3-{0:d2}-{1}' -f ($Ordinal + 1), $componentId)
        artifact_revision = 1
        result_status = $Status
        output_contract_ref = [string]$Component.output_contract_ref
        occurred_at = ('2026-07-18T10:{0:d2}:00+08:00' -f (($Ordinal + 1) % 60))
        validation_receipt = [pscustomobject][ordered]@{
            validation_status = 'pass'
            contract_ref = [string]$Component.output_contract_ref
            validator_id = ('m3-fixture-{0}' -f $componentId)
        }
        payload_kind = 'json_inline'
        payload = [pscustomobject][ordered]@{
            fixture_id = 'workflow-kernel-m3-hotspot-shadow-v0.1'
            component_id = $componentId
            external_side_effects = $false
        }
    }
    if ($componentId -eq 'final_delivery_render_h7') {
        $result.payload_kind = 'file_ref'
        $result.PSObject.Properties.Remove('payload')
        $result | Add-Member -NotePropertyName payload_relative_path -NotePropertyValue 'expected-final-delivery.html'
    }
    return $result
}

function New-M3Command {
    param(
        [Parameter(Mandatory = $true)][string]$CommandId,
        [Parameter(Mandatory = $true)][string]$Mode,
        [AllowNull()][object]$PriorSha256,
        [Parameter(Mandatory = $true)][object[]]$ExpectedResults,
        [Parameter(Mandatory = $true)][hashtable]$ComponentMap,
        [Parameter(Mandatory = $true)][object]$ProgressMap,
        [Parameter(Mandatory = $true)][int]$StartIndex,
        [Parameter(Mandatory = $true)][int]$EndIndex,
        [Parameter(Mandatory = $true)][string]$StopReason,
        [Parameter(Mandatory = $true)][string]$StopStage,
        [Parameter(Mandatory = $true)][string]$StopComponent,
        [Parameter(Mandatory = $true)][string]$ResumeComponent,
        [Parameter(Mandatory = $true)][string]$InputSha256,
        [Parameter(Mandatory = $true)][string]$ComparisonMode,
        [AllowNull()][object]$LegacyObservation,
        [string]$BranchStatus = ''
    )
    $results = [System.Collections.Generic.List[object]]::new()
    for ($index = $StartIndex; $index -lt $EndIndex; $index++) {
        $expected = $ExpectedResults[$index]
        $componentId = [string]$expected.component_id
        $status = [string]$ProgressMap.PSObject.Properties[$componentId].Value[0]
        if ($componentId -eq 'delivery_topic_freshness_apply' -and -not [string]::IsNullOrWhiteSpace($BranchStatus)) {
            $status = $BranchStatus
        }
        $results.Add((New-M3Result -Expected $expected -Component $ComponentMap[$componentId] -Status $status -Ordinal $index))
    }
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($componentId in @('hotspot_research', 'delivery_topic_freshness_review')) {
        if (@($results | Where-Object { [string]$_.component_id -eq $componentId }).Count -eq 1) {
            $records.Add((New-M3Activity -ComponentId $componentId -Status 'outcome_reconciled'))
        }
    }
    if ($StopReason -eq 'waiting_external') {
        $records.Add((New-M3Activity -ComponentId $StopComponent -Status 'attempt_started'))
    }
    return [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/hotspot-shadow-command/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        command_id = $CommandId
        command_mode = $Mode
        prior_command_sha256 = $PriorSha256
        shadow_run_id = 'M3-HOTSPOT-SHADOW-001'
        shadow_session_id = 'M3-HOTSPOT-S001'
        source_session_id = 'LEGACY-FIXTURE-HOTSPOT-S001'
        runtime_generation = 'kernel_v1_shadow'
        source_runtime_generation = 'legacy_r7'
        route_id = 'hotspot'
        route_version = '0.1'
        issued_at = if ($Mode -eq 'start') { '2026-07-18T10:00:00+08:00' } else { '2026-07-18T10:40:00+08:00' }
        comparison_mode = $ComparisonMode
        input = [pscustomobject][ordered]@{
            input_id = 'M3-HOTSPOT-INPUT-001'
            relative_path = 'source-content.md'
            sha256 = $InputSha256
        }
        component_results = $results.ToArray()
        external_activity_records = $records.ToArray()
        stop = [pscustomobject][ordered]@{
            stage_id = $StopStage
            component_id = $StopComponent
            stop_reason = $StopReason
            resume_from_component_id = $ResumeComponent
            occurred_at = if ($Mode -eq 'start') { '2026-07-18T10:35:00+08:00' } else { '2026-07-18T10:55:00+08:00' }
        }
        legacy_observation = $LegacyObservation
    }
}

function Write-M3Command {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Command
    )
    Write-TaogeUtf8NoBomJson -Path $Path -Value $Command -Depth 100
    return Get-M3Sha256 -Path $Path
}

function Add-M3Result {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][object]$Case,
        [Parameter(Mandatory = $true)][string]$Actual,
        [Parameter(Mandatory = $true)][string]$Fingerprint,
        [Parameter(Mandatory = $true)][string]$Detail
    )
    $Results.Add([pscustomobject][ordered]@{
        fixture_id = [string]$Case.fixture_id
        scenario = [string]$Case.scenario
        expected_result = [string]$Case.expected_result
        actual_result = $Actual
        expected_fingerprint = [string]$Case.expected_fingerprint
        actual_fingerprint = $Fingerprint
        fixture_result = if ([string]$Case.expected_result -eq $Actual -and [string]$Case.expected_fingerprint -eq $Fingerprint) { 'pass' } else { 'fail' }
        detail = $Detail
    })
}

try {
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
        $WorkRoot = Join-Path $root 'state\checks\workflow-kernel-m3\fixtures'
    }
    if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
        $MachineReportPath = Join-Path $root 'state\checks\workflow-kernel-m3-fixture-report.json'
    }
    $work = [System.IO.Path]::GetFullPath($WorkRoot)
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'state\checks')).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $work.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'work_root_outside_state_checks'
    }
    if (Test-Path -LiteralPath $work) {
        $verifiedWork = [System.IO.Path]::GetFullPath($work)
        if (-not $verifiedWork.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'work_root_delete_preflight_failed'
        }
        Remove-Item -LiteralPath $verifiedWork -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    $fixtureRoot = Join-Path $root 'examples\workflow-kernel-m3-hotspot-shadow-fixtures'
    $fixtureCatalog = Read-M3Json (Join-Path $fixtureRoot 'fixtures.json')
    $legacyObservation = Read-M3Json (Join-Path $fixtureRoot 'frozen-observation.json')
    $workflowIr = Read-M3Json (Join-Path $root 'routes\current-workflow-ir.json')
    $componentCatalog = Read-M3Json (Join-Path $root 'routes\component-catalog.json')
    $route = @($workflowIr.routes | Where-Object { [string]$_.route_id -eq 'hotspot' })[0]
    $expectedResults = [System.Collections.Generic.List[object]]::new()
    foreach ($binding in @($route.stage_bindings)) {
        if ([string]$binding.stage_id -eq 'final_decision') {
            continue
        }
        foreach ($componentId in @($binding.component_refs)) {
            $expectedResults.Add([pscustomobject][ordered]@{
                stage_id = [string]$binding.stage_id
                component_id = [string]$componentId
            })
        }
    }
    $componentMap = @{}
    foreach ($component in @($componentCatalog.components)) {
        $componentMap[[string]$component.component_id] = $component
    }
    $progressMap = $componentCatalog.m3_hotspot_progress_profile.progress_statuses_by_component
    $kernelCliPath = Join-Path $root 'tools\invoke-workflow-kernel-shadow.ps1'
    $powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    $results = [System.Collections.Generic.List[object]]::new()
    $positiveEvidence = $null
    $sourceHash = Get-M3Sha256 -Path (Join-Path $fixtureRoot 'source-content.md')
    $fullEnd = $expectedResults.Count
    $researchIndex = 1
    $topicGateIndex = 3
    $freshnessIndex = 21
    $freshnessApplyEnd = 23

    foreach ($case in @($fixtureCatalog.cases)) {
        $caseName = [string]$case.fixture_id
        if ($case.PSObject.Properties['path_variant'] -and [string]$case.path_variant -eq 'space_unicode') {
            $caseName += ' space ' + [char]0x4E2D + [char]0x6587
        }
        $caseRoot = Join-Path $work $caseName
        $sourceRoot = Join-Path $caseRoot 'source'
        $shadowRoot = Join-Path $caseRoot 'shadow'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $fixtureRoot 'source-content.md') -Destination (Join-Path $sourceRoot 'source-content.md') -Force
        Copy-Item -LiteralPath (Join-Path $fixtureRoot 'expected-final-delivery.html') -Destination (Join-Path $sourceRoot 'expected-final-delivery.html') -Force
        $scenario = [string]$case.scenario
        $targetProcess = $null
        $detail = ''

        if ($scenario -eq 'shadow_output_escape') {
            $command = New-M3Command -CommandId 'M3-CMD-START' -Mode 'start' -PriorSha256 $null -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex 0 -EndIndex $fullEnd -StopReason 'waiting_human' -StopStage 'final_decision' -StopComponent 'final_human_decision_gate' -ResumeComponent 'final_human_decision_gate' -InputSha256 $sourceHash -ComparisonMode 'contract_only' -LegacyObservation $null
            $commandPath = Join-Path $sourceRoot 'command.json'
            [void](Write-M3Command -Path $commandPath -Command $command)
            $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot (Join-Path $root 'm3-output-escape') -CommandPath $commandPath
        }
        elseif ($scenario -eq 'wrong_prior_command_digest') {
            $start = New-M3Command -CommandId 'M3-CMD-START' -Mode 'start' -PriorSha256 $null -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex 0 -EndIndex $researchIndex -StopReason 'waiting_external' -StopStage 'research_topic' -StopComponent 'hotspot_research' -ResumeComponent 'hotspot_research' -InputSha256 $sourceHash -ComparisonMode 'contract_only' -LegacyObservation $null
            $startPath = Join-Path $sourceRoot 'start.json'
            [void](Write-M3Command -Path $startPath -Command $start)
            $pre = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $startPath
            $resume = New-M3Command -CommandId 'M3-CMD-RESUME' -Mode 'resume' -PriorSha256 ('f' * 64) -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex $researchIndex -EndIndex $topicGateIndex -StopReason 'topic_gate' -StopStage 'research_topic' -StopComponent 'topic_human_gate' -ResumeComponent 'topic_human_gate' -InputSha256 $sourceHash -ComparisonMode 'contract_only' -LegacyObservation $null
            $resumePath = Join-Path $sourceRoot 'resume.json'
            [void](Write-M3Command -Path $resumePath -Command $resume)
            $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $resumePath
            $detail = 'prerequisite=' + (Get-M3KernelCode -ProcessResult $pre)
        }
        elseif ($scenario -in @('research_resume_to_topic_gate', 'topic_gate_resume_to_final', 'freshness_resume_to_final')) {
            if ($scenario -eq 'research_resume_to_topic_gate') {
                $startEnd = $researchIndex
                $startReason = 'waiting_external'
                $startStage = 'research_topic'
                $startComponent = 'hotspot_research'
                $resumeStart = $researchIndex
                $resumeEnd = $topicGateIndex
                $resumeReason = 'topic_gate'
                $resumeStage = 'research_topic'
                $resumeComponent = 'topic_human_gate'
            }
            elseif ($scenario -eq 'topic_gate_resume_to_final') {
                $startEnd = $topicGateIndex
                $startReason = 'topic_gate'
                $startStage = 'research_topic'
                $startComponent = 'topic_human_gate'
                $resumeStart = $topicGateIndex
                $resumeEnd = $fullEnd
                $resumeReason = 'waiting_human'
                $resumeStage = 'final_decision'
                $resumeComponent = 'final_human_decision_gate'
            }
            else {
                $startEnd = $freshnessIndex
                $startReason = 'waiting_external'
                $startStage = 'delivery_compile'
                $startComponent = 'delivery_topic_freshness_review'
                $resumeStart = $freshnessIndex
                $resumeEnd = $fullEnd
                $resumeReason = 'waiting_human'
                $resumeStage = 'final_decision'
                $resumeComponent = 'final_human_decision_gate'
            }
            $start = New-M3Command -CommandId 'M3-CMD-START' -Mode 'start' -PriorSha256 $null -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex 0 -EndIndex $startEnd -StopReason $startReason -StopStage $startStage -StopComponent $startComponent -ResumeComponent $startComponent -InputSha256 $sourceHash -ComparisonMode 'contract_only' -LegacyObservation $null
            $startPath = Join-Path $sourceRoot 'start.json'
            $priorSha = Write-M3Command -Path $startPath -Command $start
            $pre = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $startPath
            $resume = New-M3Command -CommandId 'M3-CMD-RESUME' -Mode 'resume' -PriorSha256 $priorSha -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex $resumeStart -EndIndex $resumeEnd -StopReason $resumeReason -StopStage $resumeStage -StopComponent $resumeComponent -ResumeComponent $resumeComponent -InputSha256 $sourceHash -ComparisonMode 'contract_only' -LegacyObservation $null
            $resumePath = Join-Path $sourceRoot 'resume.json'
            [void](Write-M3Command -Path $resumePath -Command $resume)
            $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $resumePath
            $detail = 'prerequisite=' + (Get-M3KernelCode -ProcessResult $pre)
        }
        else {
            $endIndex = $fullEnd
            $stopReason = 'waiting_human'
            $stopStage = 'final_decision'
            $stopComponent = 'final_human_decision_gate'
            $resumeComponent = 'final_human_decision_gate'
            $comparisonMode = 'contract_only'
            $legacy = $null
            $branchStatus = ''
            if ($scenario -eq 'full_frozen_parity' -or $scenario -eq 'failed_parity_replay_stays_failed') {
                $comparisonMode = 'frozen_legacy_contract_fixture'
                $legacy = Copy-M3Object -Value $legacyObservation
                if ($scenario -eq 'failed_parity_replay_stays_failed') {
                    $legacy.input_sha256 = 'f' * 64
                }
            }
            elseif ($scenario -eq 'research_wait' -or $scenario -eq 'wait_with_reconciled_outcome') {
                $endIndex = $researchIndex
                $stopReason = 'waiting_external'
                $stopStage = 'research_topic'
                $stopComponent = 'hotspot_research'
                $resumeComponent = 'hotspot_research'
            }
            elseif ($scenario -eq 'freshness_wait') {
                $endIndex = $freshnessIndex
                $stopReason = 'waiting_external'
                $stopStage = 'delivery_compile'
                $stopComponent = 'delivery_topic_freshness_review'
                $resumeComponent = 'delivery_topic_freshness_review'
            }
            elseif ($scenario -eq 'semantic_update_replan' -or $scenario -eq 'wrong_replan_target') {
                $endIndex = $freshnessApplyEnd
                $stopReason = 'semantic_update_replan'
                $stopStage = 'delivery_compile'
                $stopComponent = 'delivery_topic_freshness_apply'
                $resumeComponent = 'hotspot_content_brief'
                $branchStatus = 'semantic_update_replan'
            }
            elseif ($scenario -eq 'topic_revalidation_replan') {
                $endIndex = $freshnessApplyEnd
                $stopReason = 'topic_revalidation_replan'
                $stopStage = 'delivery_compile'
                $stopComponent = 'delivery_topic_freshness_apply'
                $resumeComponent = 'hotspot_research'
                $branchStatus = 'topic_revalidation_replan'
            }
            $command = New-M3Command -CommandId 'M3-CMD-START' -Mode 'start' -PriorSha256 $null -ExpectedResults $expectedResults.ToArray() -ComponentMap $componentMap -ProgressMap $progressMap -StartIndex 0 -EndIndex $endIndex -StopReason $stopReason -StopStage $stopStage -StopComponent $stopComponent -ResumeComponent $resumeComponent -InputSha256 $sourceHash -ComparisonMode $comparisonMode -LegacyObservation $legacy -BranchStatus $branchStatus
            if ($scenario -eq 'missing_external_outcome') {
                $command.external_activity_records = @($command.external_activity_records | Where-Object { [string]$_.component_id -ne 'hotspot_research' })
            }
            elseif ($scenario -eq 'wait_with_reconciled_outcome') {
                $command.external_activity_records = @((New-M3Activity -ComponentId 'hotspot_research' -Status 'outcome_reconciled'))
            }
            elseif ($scenario -eq 'external_retry_true') {
                $command.external_activity_records[0].retry_performed = $true
            }
            elseif ($scenario -eq 'wrong_replan_target') {
                $command.stop.resume_from_component_id = 'hotspot_research'
            }
            elseif ($scenario -eq 'component_sequence_invalid') {
                $temporary = $command.component_results[0]
                $command.component_results[0] = $command.component_results[1]
                $command.component_results[1] = $temporary
            }
            elseif ($scenario -eq 'component_contract_invalid') {
                $command.component_results[0].output_contract_ref = 'taoge://invalid/contract'
            }
            elseif ($scenario -eq 'unknown_command_property') {
                $command | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
            }
            elseif ($scenario -eq 'direct_route_rejected') {
                $command.route_id = 'direct'
            }
            $commandPath = Join-Path $sourceRoot 'command.json'
            [void](Write-M3Command -Path $commandPath -Command $command)
            $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $commandPath

            if ($scenario -eq 'artifact_tamper_before_rebuild' -and $targetProcess.exit_code -eq 0) {
                $artifact = Get-ChildItem -LiteralPath (Join-Path $shadowRoot 'artifacts') -File -Recurse | Select-Object -First 1
                [System.IO.File]::AppendAllText($artifact.FullName, 'tamper', (New-Object System.Text.UTF8Encoding($false)))
                $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'rebuild_hotspot_projection' -ShadowRoot $shadowRoot
            }
            elseif ($scenario -eq 'command_replay_idempotent' -and $targetProcess.exit_code -eq 0) {
                $eventHashBefore = Get-M3Sha256 -Path (Join-Path $shadowRoot 'events.jsonl')
                $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $commandPath
                $eventHashAfter = Get-M3Sha256 -Path (Join-Path $shadowRoot 'events.jsonl')
                if ($eventHashBefore -ne $eventHashAfter) {
                    $detail = 'event_log_changed_on_replay'
                    $targetProcess.exit_code = 1
                }
            }
            elseif ($scenario -eq 'failed_parity_replay_stays_failed') {
                $targetProcess = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_hotspot' -ShadowRoot $shadowRoot -CommandPath $commandPath
            }
            elseif ($scenario -eq 'full_frozen_parity' -and $targetProcess.exit_code -eq 0) {
                $before = @(
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'artifact-projection.json')
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'event-projection.json')
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'shadow-observation.json')
                ) -join '|'
                $rebuild = Invoke-M3Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'rebuild_hotspot_projection' -ShadowRoot $shadowRoot
                $after = @(
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'artifact-projection.json')
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'event-projection.json')
                    Get-M3Sha256 -Path (Join-Path $shadowRoot 'shadow-observation.json')
                ) -join '|'
                if ($rebuild.exit_code -ne 0 -or $before -ne $after) {
                    $detail = 'projection_rebuild_not_byte_stable'
                    $targetProcess.exit_code = 1
                }
                else {
                    $positiveEvidence = Read-M3Json (Join-Path $shadowRoot 'shadow-observation.json')
                }
            }
        }

        $fingerprint = Get-M3KernelCode -ProcessResult $targetProcess
        $actual = if ($targetProcess.exit_code -eq 0) { 'pass' } else { 'fail' }
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = ([string]$targetProcess.stdout + ' ' + [string]$targetProcess.stderr).Trim()
        }
        Add-M3Result -Results $results -Case $case -Actual $actual -Fingerprint $fingerprint -Detail $detail
    }

    $failed = @($results | Where-Object { [string]$_.fixture_result -ne 'pass' })
    $report = [pscustomobject][ordered]@{
        schema_id = 'taoge://checks/workflow-kernel-m3/v0.1'
        architecture_change_id = 'ARCH-20260718-002'
        status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        total = $results.Count
        passed = $results.Count - $failed.Count
        failed = $failed.Count
        route_id = 'hotspot'
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'kernel_v1_current'
        runtime_switch_enabled = $false
        current_write_performed = $false
        runtime_certification = $false
        network_access_performed = $false
        provider_calls_performed = 0
        external_retry_count = 0
        windows_powershell_5_1_executed = $true
        space_unicode_path_executed = $true
        fixture_cardinality_mode = [string]$fixtureCatalog.cardinality_mode
        positive_evidence = $positiveEvidence
        results = $results.ToArray()
    }
    Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 100
    if ($failed.Count -gt 0) {
        foreach ($failedCase in $failed) {
            Write-Output ("$($failedCase.fixture_id) fail actual=$($failedCase.actual_fingerprint)")
        }
        Write-Output ("WORKFLOW_KERNEL_M3_RESULT=fail failed=$($failed.Count) total=$($results.Count)")
        exit 1
    }
    Write-Output ("WORKFLOW_KERNEL_M3_RESULT=pass total=$($results.Count)")
    exit 0
}
catch {
    $failure = [pscustomobject][ordered]@{
        schema_id = 'taoge://checks/workflow-kernel-m3/v0.1'
        status = 'fail'
        code = 'workflow_kernel_m3_checker_error'
        diagnostic = [string]$_.Exception.Message
        script_stack = [string]$_.ScriptStackTrace
        runtime_certification = $false
        network_access_performed = $false
        provider_calls_performed = 0
    }
    try {
        if (-not [string]::IsNullOrWhiteSpace($MachineReportPath)) {
            Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $failure -Depth 30
        }
    }
    catch {
    }
    Write-Error ('WORKFLOW_KERNEL_M3_TOOL_ERROR=' + $failure.diagnostic + ' stack=' + $failure.script_stack)
    exit 1
}
