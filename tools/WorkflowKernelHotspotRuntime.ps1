Set-StrictMode -Version 2.0

function New-WorkflowKernelHotspotEvent {
    param(
        [Parameter(Mandatory = $true)][string]$ShadowSessionId,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$OccurredAt,
        [AllowNull()][string]$StageId = $null,
        [AllowNull()][string]$ComponentId = $null,
        [AllowNull()][string]$ResultStatus = $null,
        [AllowNull()][object]$Artifact = $null,
        [AllowNull()][string]$StopReason = $null,
        [AllowNull()][object]$Activity = $null,
        [AllowNull()][string]$CommandId = $null
    )

    $previousEventId = $null
    if ($Sequence -gt 1) {
        $previousEventId = ('WKE-{0}-{1:d4}' -f $ShadowSessionId, ($Sequence - 1))
    }
    return [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/event/v0.1'
        event_id = ('WKE-{0}-{1:d4}' -f $ShadowSessionId, $Sequence)
        sequence = $Sequence
        previous_event_id = $previousEventId
        event_type = $EventType
        occurred_at = $OccurredAt
        shadow_session_id = $ShadowSessionId
        stage_id = $StageId
        component_id = $ComponentId
        result_status = $ResultStatus
        artifact = $Artifact
        stop_reason = $StopReason
        activity = $Activity
        command_id = $CommandId
    }
}

function Get-WorkflowKernelHotspotStageMap {
    param([Parameter(Mandatory = $true)][object]$Route)

    $map = @{}
    foreach ($binding in @($Route.stage_bindings)) {
        $ids = @($binding.component_refs | ForEach-Object { [string]$_ })
        $map[[string]$binding.stage_id] = $ids
    }
    return $map
}

function Get-WorkflowKernelHotspotAcceptedEvents {
    param([AllowNull()][object[]]$Events)

    if ($null -eq $Events) {
        return @()
    }
    return @($Events | Where-Object { [string]$_.event_type -eq 'component.result.accepted' })
}

function Get-WorkflowKernelHotspotActivityState {
    param([AllowNull()][object[]]$Events)

    $state = @{}
    if ($null -eq $Events) {
        return $state
    }
    foreach ($event in @($Events)) {
        if ($null -eq $event.PSObject.Properties['activity'] -or $null -eq $event.activity) {
            continue
        }
        $activityId = [string]$event.activity.activity_id
        if ([string]::IsNullOrWhiteSpace($activityId)) {
            continue
        }
        if (-not $state.ContainsKey($activityId)) {
            $state[$activityId] = [pscustomobject][ordered]@{
                activity_id = $activityId
                component_id = [string]$event.component_id
                request_id = [string]$event.activity.request_id
                request_sha256 = [string]$event.activity.request_sha256
                attempt_id = [string]$event.activity.attempt_id
                attempt_no = [int]$event.activity.attempt_no
                attempt_started = $false
                outcome_reconciled = $false
            }
        }
        if ([string]$event.event_type -eq 'external.attempt.started') {
            $state[$activityId].attempt_started = $true
        }
        elseif ([string]$event.event_type -eq 'external.outcome.reconciled') {
            $state[$activityId].outcome_reconciled = $true
        }
    }
    return $state
}

function Assert-WorkflowKernelHotspotResult {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][object]$Expected,
        [Parameter(Mandatory = $true)][hashtable]$ComponentMap,
        [Parameter(Mandatory = $true)][object]$ProgressStatusMap,
        [Parameter(Mandatory = $true)][object]$TerminalBranchMap,
        [Parameter(Mandatory = $true)][string]$RequestDirectory
    )

    Assert-WorkflowKernelAllowedProperties -Object $Result -AllowedProperties @(
        'stage_id',
        'component_id',
        'artifact_id',
        'artifact_revision',
        'result_status',
        'output_contract_ref',
        'occurred_at',
        'validation_receipt',
        'payload_kind',
        'payload',
        'payload_relative_path'
    ) -FailureCode 'component_result_shape_invalid'

    $componentId = [string](Get-WorkflowKernelProperty -Object $Result -Name 'component_id')
    $stageId = [string](Get-WorkflowKernelProperty -Object $Result -Name 'stage_id')
    if ($componentId -ne [string]$Expected.component_id -or $stageId -ne [string]$Expected.stage_id) {
        throw 'component_result_sequence_invalid'
    }
    if (-not $ComponentMap.ContainsKey($componentId)) {
        throw 'component_catalog_reference_missing'
    }
    $component = $ComponentMap[$componentId]
    if (-not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $Result -Name 'artifact_id'))) {
        throw 'artifact_id_invalid'
    }
    $revision = Get-WorkflowKernelProperty -Object $Result -Name 'artifact_revision'
    if ((-not ($revision -is [int])) -and (-not ($revision -is [long]))) {
        throw 'artifact_revision_invalid'
    }
    if ([int64]$revision -lt 1) {
        throw 'artifact_revision_invalid'
    }

    $resultStatus = [string](Get-WorkflowKernelProperty -Object $Result -Name 'result_status')
    if (@($component.allowed_result_statuses) -notcontains $resultStatus) {
        throw 'component_result_status_invalid'
    }
    $progressProperty = $ProgressStatusMap.PSObject.Properties[$componentId]
    $branchProperty = $TerminalBranchMap.PSObject.Properties[$componentId]
    $isProgress = $null -ne $progressProperty -and @($progressProperty.Value) -contains $resultStatus
    $isTerminalBranch = $null -ne $branchProperty -and $null -ne $branchProperty.Value.PSObject.Properties[$resultStatus]
    if (-not $isProgress -and -not $isTerminalBranch) {
        throw 'hotspot_result_status_not_compiled'
    }

    $contractRef = [string](Get-WorkflowKernelProperty -Object $Result -Name 'output_contract_ref')
    if ($contractRef -ne [string]$component.output_contract_ref) {
        throw 'component_result_contract_invalid'
    }
    if (-not (Test-WorkflowKernelTimestamp -Value (Get-WorkflowKernelProperty -Object $Result -Name 'occurred_at'))) {
        throw 'timestamp_invalid'
    }
    $receipt = Get-WorkflowKernelProperty -Object $Result -Name 'validation_receipt'
    Assert-WorkflowKernelAllowedProperties -Object $receipt -AllowedProperties @(
        'validation_status',
        'contract_ref',
        'validator_id'
    ) -FailureCode 'validation_receipt_invalid'
    if (
        [string](Get-WorkflowKernelProperty -Object $receipt -Name 'validation_status') -ne 'pass' -or
        [string](Get-WorkflowKernelProperty -Object $receipt -Name 'contract_ref') -ne $contractRef -or
        -not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $receipt -Name 'validator_id'))
    ) {
        throw 'validation_receipt_invalid'
    }

    $payloadKind = [string](Get-WorkflowKernelProperty -Object $Result -Name 'payload_kind')
    if ($payloadKind -eq 'json_inline') {
        [void](Get-WorkflowKernelProperty -Object $Result -Name 'payload')
        if ($null -ne $Result.PSObject.Properties['payload_relative_path']) {
            throw 'component_result_shape_invalid'
        }
    }
    elseif ($payloadKind -eq 'file_ref') {
        if ($null -ne $Result.PSObject.Properties['payload']) {
            throw 'component_result_shape_invalid'
        }
        $payloadRelativePath = [string](Get-WorkflowKernelProperty -Object $Result -Name 'payload_relative_path')
        $payloadPath = Resolve-WorkflowKernelRelativePath -Root $RequestDirectory -RelativePath $payloadRelativePath -FailureCode 'payload_path_invalid'
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw 'payload_file_missing'
        }
    }
    else {
        throw 'payload_kind_invalid'
    }
}

function Assert-WorkflowKernelHotspotActivity {
    param(
        [Parameter(Mandatory = $true)][object]$Record,
        [Parameter(Mandatory = $true)][hashtable]$ExistingState,
        [Parameter(Mandatory = $true)][string]$CommandMode
    )

    Assert-WorkflowKernelAllowedProperties -Object $Record -AllowedProperties @(
        'activity_id',
        'component_id',
        'activity_status',
        'request_id',
        'request_sha256',
        'attempt_id',
        'attempt_no',
        'attempt_status',
        'started_at',
        'completed_at',
        'outcome_id',
        'outcome_status',
        'outcome_sha256',
        'output_artifact_id',
        'consumer_status',
        'accepted_at',
        'retry_performed'
    ) -FailureCode 'external_activity_contract_invalid'

    foreach ($idName in @('activity_id', 'component_id', 'request_id', 'attempt_id')) {
        if (-not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $Record -Name $idName))) {
            throw 'external_activity_contract_invalid'
        }
    }
    if (@('hotspot_research', 'delivery_topic_freshness_review') -notcontains [string]$Record.component_id) {
        throw 'external_activity_component_invalid'
    }
    if (-not (Test-WorkflowKernelHash -Value $Record.request_sha256)) {
        throw 'external_activity_contract_invalid'
    }
    if ([int]$Record.attempt_no -ne 1 -or [bool]$Record.retry_performed) {
        throw 'external_retry_not_authorized'
    }
    if (-not (Test-WorkflowKernelTimestamp -Value $Record.started_at)) {
        throw 'timestamp_invalid'
    }

    $activityStatus = [string]$Record.activity_status
    $activityId = [string]$Record.activity_id
    $hasExisting = $ExistingState.ContainsKey($activityId)
    if ($hasExisting) {
        $existing = $ExistingState[$activityId]
        if (
            [string]$existing.component_id -ne [string]$Record.component_id -or
            [string]$existing.request_id -ne [string]$Record.request_id -or
            [string]$existing.request_sha256 -ne [string]$Record.request_sha256 -or
            [string]$existing.attempt_id -ne [string]$Record.attempt_id -or
            [int]$existing.attempt_no -ne [int]$Record.attempt_no
        ) {
            throw 'external_activity_identity_mismatch'
        }
    }

    if ($activityStatus -eq 'attempt_started') {
        if ($hasExisting) {
            throw 'external_attempt_already_persisted'
        }
        if (
            [string]$Record.attempt_status -ne 'started' -or
            $null -ne $Record.completed_at -or
            $null -ne $Record.outcome_id -or
            [string]$Record.outcome_status -ne 'not_available' -or
            $null -ne $Record.outcome_sha256 -or
            $null -ne $Record.output_artifact_id -or
            [string]$Record.consumer_status -ne 'pending' -or
            $null -ne $Record.accepted_at
        ) {
            throw 'external_attempt_contract_invalid'
        }
    }
    elseif ($activityStatus -eq 'outcome_reconciled') {
        if ($hasExisting -and [bool]$ExistingState[$activityId].outcome_reconciled) {
            throw 'external_outcome_already_reconciled'
        }
        if ($hasExisting -and -not [bool]$ExistingState[$activityId].attempt_started) {
            throw 'external_reconcile_requires_persisted_attempt'
        }
        if (
            [string]$Record.attempt_status -ne 'succeeded' -or
            -not (Test-WorkflowKernelTimestamp -Value $Record.completed_at) -or
            -not (Test-WorkflowKernelId -Value $Record.outcome_id) -or
            [string]$Record.outcome_status -ne 'succeeded' -or
            -not (Test-WorkflowKernelHash -Value $Record.outcome_sha256) -or
            -not (Test-WorkflowKernelId -Value $Record.output_artifact_id) -or
            [string]$Record.consumer_status -ne 'accepted' -or
            -not (Test-WorkflowKernelTimestamp -Value $Record.accepted_at)
        ) {
            throw 'external_outcome_contract_invalid'
        }
    }
    else {
        throw 'external_activity_status_invalid'
    }
}

function Test-WorkflowKernelHotspotCommand {
    param(
        [Parameter(Mandatory = $true)][object]$Command,
        [Parameter(Mandatory = $true)][string]$CommandDirectory,
        [Parameter(Mandatory = $true)][object]$WorkflowIr,
        [Parameter(Mandatory = $true)][object]$ComponentCatalog,
        [AllowNull()][object[]]$ExistingEvents,
        [AllowNull()][object]$ExistingSession
    )

    Assert-WorkflowKernelAllowedProperties -Object $Command -AllowedProperties @(
        'schema_id',
        'schema_version',
        'architecture_change_id',
        'command_id',
        'command_mode',
        'prior_command_sha256',
        'shadow_run_id',
        'shadow_session_id',
        'source_session_id',
        'runtime_generation',
        'source_runtime_generation',
        'route_id',
        'route_version',
        'issued_at',
        'comparison_mode',
        'input',
        'component_results',
        'external_activity_records',
        'stop',
        'legacy_observation'
    )
    if (
        [string]$Command.schema_id -ne 'taoge://workflow-kernel/hotspot-shadow-command/v0.1' -or
        [string]$Command.schema_version -ne '0.1'
    ) {
        throw 'command_schema_invalid'
    }
    if ([string]$Command.architecture_change_id -ne 'ARCH-20260718-002') {
        throw 'architecture_change_id_mismatch'
    }
    foreach ($idName in @('command_id', 'shadow_run_id', 'shadow_session_id', 'source_session_id')) {
        if (-not (Test-WorkflowKernelId -Value $Command.PSObject.Properties[$idName].Value)) {
            throw 'command_id_invalid'
        }
    }
    if (
        [string]$Command.runtime_generation -ne 'kernel_v1_shadow' -or
        [string]$Command.source_runtime_generation -ne 'legacy_r7' -or
        [string]$Command.route_id -ne 'hotspot' -or
        [string]$Command.route_version -ne '0.1'
    ) {
        throw 'hotspot_route_contract_invalid'
    }
    if (-not (Test-WorkflowKernelTimestamp -Value $Command.issued_at)) {
        throw 'timestamp_invalid'
    }
    if ([bool]$WorkflowIr.runtime_switch_enabled) {
        throw 'runtime_switch_must_remain_disabled'
    }
    $policy = Get-WorkflowKernelProperty -Object $WorkflowIr -Name 'shadow_execution_policy'
    if (
        @($policy.authorized_routes) -notcontains 'hotspot' -or
        [string]$policy.hotspot_execution_scope -ne 'hotspot_positive_wait_resume_freshness_and_reversal' -or
        [string]$policy.hotspot_resume_mode -ne 'append_command_reconcile_persisted_outcome_before_retry' -or
        [bool]$policy.current_write_performed -or
        [bool]$policy.runtime_certification
    ) {
        throw 'hotspot_shadow_policy_invalid'
    }

    $commandMode = [string]$Command.command_mode
    if ($commandMode -eq 'start') {
        if ($null -ne $Command.prior_command_sha256 -or $null -ne $ExistingSession) {
            throw 'hotspot_start_contract_invalid'
        }
    }
    elseif ($commandMode -eq 'resume') {
        if ($null -eq $ExistingSession) {
            throw 'hotspot_resume_session_missing'
        }
        if (
            -not (Test-WorkflowKernelHash -Value $Command.prior_command_sha256) -or
            [string]$Command.prior_command_sha256 -ne [string]$ExistingSession.last_command_sha256
        ) {
            throw 'hotspot_prior_command_digest_mismatch'
        }
        foreach ($name in @('shadow_run_id', 'shadow_session_id', 'source_session_id')) {
            if ([string]$Command.PSObject.Properties[$name].Value -ne [string]$ExistingSession.PSObject.Properties[$name].Value) {
                throw 'hotspot_resume_identity_mismatch'
            }
        }
    }
    else {
        throw 'hotspot_command_mode_invalid'
    }

    $input = Get-WorkflowKernelProperty -Object $Command -Name 'input'
    Assert-WorkflowKernelAllowedProperties -Object $input -AllowedProperties @('input_id', 'relative_path', 'sha256') -FailureCode 'input_contract_invalid'
    if (
        -not (Test-WorkflowKernelId -Value $input.input_id) -or
        -not (Test-WorkflowKernelHash -Value $input.sha256)
    ) {
        throw 'input_contract_invalid'
    }
    $inputPath = Resolve-WorkflowKernelRelativePath -Root $CommandDirectory -RelativePath ([string]$input.relative_path) -FailureCode 'input_path_invalid'
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw 'input_file_missing'
    }
    if ((Get-WorkflowKernelSha256 -Path $inputPath) -ne [string]$input.sha256) {
        throw 'input_digest_mismatch'
    }
    if ($null -ne $ExistingSession -and [string]$ExistingSession.input_sha256 -ne [string]$input.sha256) {
        throw 'hotspot_resume_input_mismatch'
    }

    $route = Get-WorkflowKernelRoute -WorkflowIr $WorkflowIr -RouteId 'hotspot'
    $componentMap = Get-WorkflowKernelComponentMap -Catalog $ComponentCatalog
    $profile = Get-WorkflowKernelProperty -Object $ComponentCatalog -Name 'm3_hotspot_progress_profile' -FailureCode 'm3_hotspot_progress_profile_missing'
    if (
        [string]$profile.route_id -ne 'hotspot' -or
        [string]$profile.resume_mode -ne 'append_command_reconcile_persisted_outcome_before_retry'
    ) {
        throw 'm3_hotspot_progress_profile_invalid'
    }
    $expectedResults = @(Get-WorkflowKernelExpectedResults -Route $route)
    $existingAccepted = @(Get-WorkflowKernelHotspotAcceptedEvents -Events $ExistingEvents)
    $newResults = @(Get-WorkflowKernelProperty -Object $Command -Name 'component_results')
    if (($existingAccepted.Count + $newResults.Count) -gt $expectedResults.Count) {
        throw 'component_result_sequence_invalid'
    }
    for ($index = 0; $index -lt $newResults.Count; $index++) {
        $expected = $expectedResults[$existingAccepted.Count + $index]
        Assert-WorkflowKernelHotspotResult `
            -Result $newResults[$index] `
            -Expected $expected `
            -ComponentMap $componentMap `
            -ProgressStatusMap $profile.progress_statuses_by_component `
            -TerminalBranchMap $profile.terminal_branch_statuses_by_component `
            -RequestDirectory $CommandDirectory
    }

    $existingActivityState = Get-WorkflowKernelHotspotActivityState -Events $ExistingEvents
    $records = @(Get-WorkflowKernelProperty -Object $Command -Name 'external_activity_records')
    $recordMap = @{}
    foreach ($record in $records) {
        Assert-WorkflowKernelHotspotActivity -Record $record -ExistingState $existingActivityState -CommandMode $commandMode
        $componentId = [string]$record.component_id
        if ($recordMap.ContainsKey($componentId)) {
            throw 'external_activity_duplicate_component'
        }
        $recordMap[$componentId] = $record
    }
    foreach ($result in $newResults) {
        $componentId = [string]$result.component_id
        if (@('hotspot_research', 'delivery_topic_freshness_review') -contains $componentId) {
            $reconciled = $false
            foreach ($stateValue in @($existingActivityState.Values)) {
                if ([string]$stateValue.component_id -eq $componentId -and [bool]$stateValue.outcome_reconciled) {
                    $reconciled = $true
                }
            }
            if ($recordMap.ContainsKey($componentId) -and [string]$recordMap[$componentId].activity_status -eq 'outcome_reconciled') {
                $reconciled = $true
            }
            if (-not $reconciled) {
                throw 'external_outcome_required_before_consumer'
            }
        }
    }

    $stop = Get-WorkflowKernelProperty -Object $Command -Name 'stop'
    Assert-WorkflowKernelAllowedProperties -Object $stop -AllowedProperties @(
        'stage_id',
        'component_id',
        'stop_reason',
        'resume_from_component_id',
        'occurred_at'
    ) -FailureCode 'hotspot_stop_contract_invalid'
    if (-not (Test-WorkflowKernelTimestamp -Value $stop.occurred_at)) {
        throw 'timestamp_invalid'
    }
    $acceptedAfter = $existingAccepted.Count + $newResults.Count
    $nextExpectedComponent = if ($acceptedAfter -lt $expectedResults.Count) { [string]$expectedResults[$acceptedAfter].component_id } else { 'final_human_decision_gate' }
    $nextExpectedStage = if ($acceptedAfter -lt $expectedResults.Count) { [string]$expectedResults[$acceptedAfter].stage_id } else { 'final_decision' }
    $stopReason = [string]$stop.stop_reason
    $expectedResume = $nextExpectedComponent

    if ($stopReason -eq 'waiting_external') {
        if (
            @('hotspot_research', 'delivery_topic_freshness_review') -notcontains $nextExpectedComponent -or
            [string]$stop.component_id -ne $nextExpectedComponent -or
            [string]$stop.stage_id -ne $nextExpectedStage -or
            -not $recordMap.ContainsKey($nextExpectedComponent) -or
            [string]$recordMap[$nextExpectedComponent].activity_status -ne 'attempt_started'
        ) {
            throw 'hotspot_waiting_external_contract_invalid'
        }
    }
    elseif ($stopReason -eq 'topic_gate') {
        if (
            $nextExpectedComponent -ne 'topic_human_gate' -or
            [string]$stop.component_id -ne 'topic_human_gate' -or
            [string]$stop.stage_id -ne 'research_topic'
        ) {
            throw 'hotspot_topic_gate_contract_invalid'
        }
    }
    elseif ($stopReason -eq 'waiting_human') {
        if (
            $acceptedAfter -ne $expectedResults.Count -or
            [string]$stop.component_id -ne 'final_human_decision_gate' -or
            [string]$stop.stage_id -ne 'final_decision'
        ) {
            throw 'hotspot_final_wait_contract_invalid'
        }
    }
    elseif (@('semantic_update_replan', 'topic_revalidation_replan') -contains $stopReason) {
        if ($newResults.Count -eq 0) {
            throw 'hotspot_replan_contract_invalid'
        }
        $lastResult = $newResults[-1]
        if (
            [string]$lastResult.component_id -ne 'delivery_topic_freshness_apply' -or
            [string]$lastResult.result_status -ne $stopReason -or
            [string]$stop.component_id -ne 'delivery_topic_freshness_apply' -or
            [string]$stop.stage_id -ne 'delivery_compile'
        ) {
            throw 'hotspot_replan_contract_invalid'
        }
        $expectedResume = if ($stopReason -eq 'semantic_update_replan') { 'hotspot_content_brief' } else { 'hotspot_research' }
    }
    else {
        throw 'hotspot_stop_reason_invalid'
    }
    if ([string]$stop.resume_from_component_id -ne $expectedResume) {
        throw 'hotspot_resume_target_invalid'
    }

    foreach ($record in $records) {
        $componentId = [string]$record.component_id
        $usedByResult = @($newResults | Where-Object { [string]$_.component_id -eq $componentId }).Count -eq 1
        $usedByWait = $stopReason -eq 'waiting_external' -and [string]$stop.component_id -eq $componentId
        if (-not $usedByResult -and -not $usedByWait) {
            throw 'external_activity_not_consumed'
        }
    }

    $comparisonMode = [string]$Command.comparison_mode
    if ($comparisonMode -eq 'frozen_legacy_contract_fixture') {
        if ($null -eq $Command.legacy_observation) {
            throw 'legacy_observation_required'
        }
        $legacy = $Command.legacy_observation
        if (
            [string]$legacy.schema_id -ne 'taoge://workflow-kernel/hotspot-shadow-observation/v0.1' -or
            [string]$legacy.observation_kind -ne 'frozen_legacy_contract_fixture' -or
            [bool]$legacy.real_legacy_runtime_executed
        ) {
            throw 'legacy_observation_invalid'
        }
        foreach ($hashName in @('input_sha256', 'artifact_projection_sha256', 'event_projection_sha256')) {
            if (-not (Test-WorkflowKernelHash -Value $legacy.PSObject.Properties[$hashName].Value)) {
                throw 'legacy_observation_invalid'
            }
        }
        if ($null -ne $legacy.final_html_sha256 -and -not (Test-WorkflowKernelHash -Value $legacy.final_html_sha256)) {
            throw 'legacy_observation_invalid'
        }
    }
    elseif ($comparisonMode -eq 'contract_only') {
        if ($null -ne $Command.legacy_observation) {
            throw 'contract_only_legacy_observation_must_be_null'
        }
    }
    else {
        throw 'comparison_mode_invalid'
    }

    return [pscustomobject][ordered]@{
        route = $route
        stage_map = Get-WorkflowKernelHotspotStageMap -Route $route
        component_map = $componentMap
        expected_results = $expectedResults
        existing_accepted = $existingAccepted
        existing_activity_state = $existingActivityState
        input_path = $inputPath
        component_results = $newResults
        activity_records = $records
        stop = $stop
    }
}

function Add-WorkflowKernelHotspotActivityEvents {
    param(
        [Parameter(Mandatory = $true)][string]$EventLogPath,
        [Parameter(Mandatory = $true)][string]$ShadowSessionId,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][object]$Record,
        [Parameter(Mandatory = $true)][string]$CommandId,
        [bool]$IncludeAttemptEvents = $false
    )

    $activity = [pscustomobject][ordered]@{
        activity_id = [string]$Record.activity_id
        request_id = [string]$Record.request_id
        request_sha256 = [string]$Record.request_sha256
        attempt_id = [string]$Record.attempt_id
        attempt_no = [int]$Record.attempt_no
        outcome_id = $Record.outcome_id
        outcome_sha256 = $Record.outcome_sha256
        output_artifact_id = $Record.output_artifact_id
    }
    $current = $Sequence
    if ([string]$Record.activity_status -eq 'attempt_started' -or $IncludeAttemptEvents) {
        Add-WorkflowKernelEvent -EventLogPath $EventLogPath -Event (New-WorkflowKernelHotspotEvent `
            -ShadowSessionId $ShadowSessionId `
            -Sequence $current `
            -EventType 'external.request.recorded' `
            -OccurredAt ([string]$Record.started_at) `
            -StageId '' `
            -ComponentId ([string]$Record.component_id) `
            -Activity $activity `
            -CommandId $CommandId)
        $current++
        Add-WorkflowKernelEvent -EventLogPath $EventLogPath -Event (New-WorkflowKernelHotspotEvent `
            -ShadowSessionId $ShadowSessionId `
            -Sequence $current `
            -EventType 'external.attempt.started' `
            -OccurredAt ([string]$Record.started_at) `
            -StageId '' `
            -ComponentId ([string]$Record.component_id) `
            -ResultStatus 'started' `
            -Activity $activity `
            -CommandId $CommandId)
        $current++
    }
    if ([string]$Record.activity_status -eq 'outcome_reconciled') {
        Add-WorkflowKernelEvent -EventLogPath $EventLogPath -Event (New-WorkflowKernelHotspotEvent `
            -ShadowSessionId $ShadowSessionId `
            -Sequence $current `
            -EventType 'external.outcome.reconciled' `
            -OccurredAt ([string]$Record.completed_at) `
            -StageId '' `
            -ComponentId ([string]$Record.component_id) `
            -ResultStatus 'succeeded' `
            -Activity $activity `
            -CommandId $CommandId)
        $current++
        Add-WorkflowKernelEvent -EventLogPath $EventLogPath -Event (New-WorkflowKernelHotspotEvent `
            -ShadowSessionId $ShadowSessionId `
            -Sequence $current `
            -EventType 'external.output.accepted' `
            -OccurredAt ([string]$Record.accepted_at) `
            -StageId '' `
            -ComponentId ([string]$Record.component_id) `
            -ResultStatus 'accepted' `
            -Activity $activity `
            -CommandId $CommandId)
        $current++
    }
    return $current
}

function Write-WorkflowKernelHotspotProjections {
    param(
        [Parameter(Mandatory = $true)][string]$ShadowRoot,
        [Parameter(Mandatory = $true)][object]$Session,
        [Parameter(Mandatory = $true)][object]$LatestCommand
    )

    $events = @(Read-WorkflowKernelEvents -EventLogPath (Join-Path $ShadowRoot 'events.jsonl'))
    $artifactProjection = New-Object System.Collections.Generic.List[object]
    $eventProjection = New-Object System.Collections.Generic.List[object]
    $completedStages = New-Object System.Collections.Generic.List[string]
    $finalHtmlSha256 = $null
    $attemptCount = 0
    $outcomeCount = 0
    $lastWait = $null

    foreach ($event in $events) {
        $activityId = ''
        $outcomeId = ''
        if ($null -ne $event.PSObject.Properties['activity'] -and $null -ne $event.activity) {
            $activityId = [string]$event.activity.activity_id
            $outcomeId = [string]$event.activity.outcome_id
        }
        $eventProjection.Add([pscustomobject][ordered]@{
            event_type = [string]$event.event_type
            stage_id = [string]$event.stage_id
            component_id = [string]$event.component_id
            result_status = [string]$event.result_status
            artifact_id = if ($null -eq $event.artifact) { '' } else { [string]$event.artifact.artifact_id }
            activity_id = $activityId
            outcome_id = $outcomeId
            stop_reason = [string]$event.stop_reason
            command_id = [string]$event.command_id
        })
        if ([string]$event.event_type -eq 'component.result.accepted') {
            if ($null -eq $event.artifact) {
                throw 'event_artifact_reference_missing'
            }
            $artifactPath = Resolve-WorkflowKernelRelativePath -Root $ShadowRoot -RelativePath ([string]$event.artifact.relative_path) -FailureCode 'event_artifact_path_invalid'
            if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
                throw 'event_artifact_missing'
            }
            $actualHash = Get-WorkflowKernelSha256 -Path $artifactPath
            if ($actualHash -ne [string]$event.artifact.sha256) {
                throw 'event_artifact_digest_mismatch'
            }
            $artifactProjection.Add([pscustomobject][ordered]@{
                stage_id = [string]$event.stage_id
                component_id = [string]$event.component_id
                artifact_type = [string]$event.artifact.artifact_type
                artifact_id = [string]$event.artifact.artifact_id
                artifact_revision = [int64]$event.artifact.artifact_revision
                result_status = [string]$event.result_status
                sha256 = $actualHash
            })
            if ([string]$event.artifact.artifact_type -eq 'final_delivery') {
                $finalHtmlSha256 = $actualHash
            }
        }
        elseif ([string]$event.event_type -eq 'stage.completed') {
            if (-not $completedStages.Contains([string]$event.stage_id)) {
                $completedStages.Add([string]$event.stage_id)
            }
        }
        elseif ([string]$event.event_type -eq 'external.attempt.started') {
            $attemptCount++
        }
        elseif ([string]$event.event_type -eq 'external.outcome.reconciled') {
            $outcomeCount++
        }
        elseif ([string]$event.event_type -eq 'run.waiting') {
            $lastWait = $event
        }
    }
    if ($null -eq $lastWait) {
        throw 'stop_reason_missing'
    }

    $artifactProjectionArray = $artifactProjection.ToArray()
    $eventProjectionArray = $eventProjection.ToArray()
    $artifactProjectionSha256 = Get-WorkflowKernelValueSha256 -Value $artifactProjectionArray
    $eventProjectionSha256 = Get-WorkflowKernelValueSha256 -Value $eventProjectionArray
    $stopReason = [string]$lastWait.stop_reason
    $nextComponentId = [string]$lastWait.component_id
    if (@('semantic_update_replan', 'topic_revalidation_replan') -contains $stopReason) {
        $nextComponentId = [string]$LatestCommand.stop.resume_from_component_id
    }

    $runState = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/run-state/v0.1'
        shadow_session_id = [string]$Session.shadow_session_id
        route_id = 'hotspot'
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'legacy_r7'
        runtime_switch_enabled = $false
        current_write_performed = $false
        status = if (@('semantic_update_replan', 'topic_revalidation_replan') -contains $stopReason) { 'replan_required' } else { 'waiting' }
        current_stage_id = [string]$lastWait.stage_id
        stop_reason = $stopReason
        completed_stage_ids = $completedStages.ToArray()
        artifact_count = $artifactProjectionArray.Count
        event_count = $eventProjectionArray.Count
        external_attempt_count = $attemptCount
        external_outcome_reconcile_count = $outcomeCount
        external_retry_count = 0
        last_event_id = [string]$events[-1].event_id
        last_event_at = [string]$events[-1].occurred_at
        last_command_id = [string]$Session.last_command_id
        last_command_sha256 = [string]$Session.last_command_sha256
    }
    $resumeSummary = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/resume-summary/v0.1'
        shadow_session_id = [string]$Session.shadow_session_id
        resume_from_stage_id = [string]$lastWait.stage_id
        stop_reason = $stopReason
        next_component_id = $nextComponentId
        reconcile_before_retry = $true
        external_retry_authorized = $false
        current_runtime_untouched = $true
        source_event_id = [string]$events[-1].event_id
    }
    $observation = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/hotspot-shadow-observation/v0.1'
        schema_version = '0.1'
        observation_kind = 'kernel_v1_shadow_observation'
        real_legacy_runtime_executed = $false
        input_sha256 = [string]$Session.input_sha256
        artifact_projection_sha256 = $artifactProjectionSha256
        event_projection_sha256 = $eventProjectionSha256
        stop_reason = $stopReason
        current_stage_id = [string]$lastWait.stage_id
        next_component_id = $nextComponentId
        final_html_sha256 = $finalHtmlSha256
        shadow_session_id = [string]$Session.shadow_session_id
        source_session_id = [string]$Session.source_session_id
        artifact_count = $artifactProjectionArray.Count
        event_count = $eventProjectionArray.Count
        external_attempt_count = $attemptCount
        external_outcome_reconcile_count = $outcomeCount
        external_retry_count = 0
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'legacy_r7'
        runtime_switch_enabled = $false
        current_write_performed = $false
    }

    $checks = New-Object System.Collections.Generic.List[object]
    $status = 'pass'
    $code = 'hotspot_shadow_contract_pass'
    if ([string]$LatestCommand.comparison_mode -eq 'frozen_legacy_contract_fixture') {
        $legacy = $LatestCommand.legacy_observation
        foreach ($definition in @(
            @('input_sha256', [string]$legacy.input_sha256, [string]$observation.input_sha256, 'input_projection_mismatch'),
            @('artifact_projection_sha256', [string]$legacy.artifact_projection_sha256, [string]$observation.artifact_projection_sha256, 'artifact_projection_mismatch'),
            @('event_projection_sha256', [string]$legacy.event_projection_sha256, [string]$observation.event_projection_sha256, 'event_projection_mismatch'),
            @('stop_reason', [string]$legacy.stop_reason, [string]$observation.stop_reason, 'stop_reason_mismatch'),
            @('final_html_sha256', [string]$legacy.final_html_sha256, [string]$observation.final_html_sha256, 'final_html_mismatch')
        )) {
            $passed = [string]$definition[1] -eq [string]$definition[2]
            $checks.Add([pscustomobject][ordered]@{
                check_id = [string]$definition[0]
                expected = [string]$definition[1]
                actual = [string]$definition[2]
                passed = $passed
                failure_code = [string]$definition[3]
            })
        }
        $failed = @($checks | Where-Object { -not [bool]$_.passed })
        if ($failed.Count -gt 0) {
            $status = 'fail'
            $code = [string]$failed[0].failure_code
        }
        else {
            $code = 'hotspot_shadow_parity_pass'
        }
    }
    else {
        $checks.Add([pscustomobject][ordered]@{
            check_id = 'contract_integrity'
            expected = 'pass'
            actual = 'pass'
            passed = $true
            failure_code = ''
        })
    }
    $parityReport = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/hotspot-shadow-parity-report/v0.1'
        architecture_change_id = 'ARCH-20260718-002'
        status = $status
        code = $code
        comparison_mode = [string]$LatestCommand.comparison_mode
        shadow_only = $true
        runtime_certification = $false
        real_legacy_runtime_executed = $false
        current_runtime_untouched = $true
        checks = $checks.ToArray()
        evidence = [pscustomobject][ordered]@{
            event_log = 'events.jsonl'
            run_state = 'run-state.json'
            resume_summary = 'resume-summary.json'
            shadow_observation = 'shadow-observation.json'
            artifact_projection = 'artifact-projection.json'
            event_projection = 'event-projection.json'
        }
    }

    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'artifact-projection.json') -Value $artifactProjectionArray -Depth 30
    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'event-projection.json') -Value $eventProjectionArray -Depth 30
    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'run-state.json') -Value $runState -Depth 30
    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'resume-summary.json') -Value $resumeSummary -Depth 30
    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'shadow-observation.json') -Value $observation -Depth 30
    Write-WorkflowKernelAtomicJson -Path (Join-Path $ShadowRoot 'parity-report.json') -Value $parityReport -Depth 30

    return [pscustomobject][ordered]@{
        parity_status = $status
        parity_code = $code
        observation = $observation
        parity_report = $parityReport
    }
}

function Invoke-WorkflowKernelHotspotShadow {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$CommandPath,
        [Parameter(Mandatory = $true)][string]$ShadowRoot
    )

    try {
        $projectRootFull = Get-WorkflowKernelFullPath -Path $ProjectRoot
        $commandPathFull = Get-WorkflowKernelFullPath -Path $CommandPath
        $shadowRootFull = Get-WorkflowKernelFullPath -Path $ShadowRoot
        $commandContainment = Resolve-TaogeContainedPath -AllowedRoot $projectRootFull -CandidatePath $commandPathFull -RejectReparsePoints
        if ([string]$commandContainment.status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code 'command_path_outside_project' -Message 'Command path must stay inside the project root.'
        }
        $allowedShadowRoot = Join-Path $projectRootFull 'state\checks'
        if (-not (Test-WorkflowKernelPathContained -Root $allowedShadowRoot -Candidate $shadowRootFull)) {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_root_outside_project' -Message 'M3 shadow output must stay under state/checks.'
        }

        $workflowIrPath = Join-Path $projectRootFull 'routes\current-workflow-ir.json'
        $componentCatalogPath = Join-Path $projectRootFull 'routes\component-catalog.json'
        $workflowIr = Read-WorkflowKernelJson -Path $workflowIrPath -FailureCode 'workflow_ir_read_failed'
        $componentCatalog = Read-WorkflowKernelJson -Path $componentCatalogPath -FailureCode 'component_catalog_read_failed'
        $command = Read-WorkflowKernelJson -Path $commandPathFull -FailureCode 'command_read_failed'
        $commandDirectory = Split-Path -Parent $commandPathFull
        $commandSha256 = Get-WorkflowKernelSha256 -Path $commandPathFull
        $commandReceiptPath = Join-Path (Join-Path $shadowRootFull 'commands') ([string]$command.command_id + '.json')

        if (Test-Path -LiteralPath $commandReceiptPath -PathType Leaf) {
            if ((Get-WorkflowKernelSha256 -Path $commandReceiptPath) -ne $commandSha256) {
                return New-WorkflowKernelResult -Success $false -Code 'command_id_conflict' -Message 'The command id already exists with different content.'
            }
            $existingParityPath = Join-Path $shadowRootFull 'parity-report.json'
            if (-not (Test-Path -LiteralPath $existingParityPath -PathType Leaf)) {
                return New-WorkflowKernelResult -Success $false -Code 'hotspot_command_incomplete' -Message 'The command receipt exists, but its projection result is incomplete.'
            }
            $existingParity = Read-WorkflowKernelJson -Path $existingParityPath -FailureCode 'shadow_parity_read_failed'
            if ([string]$existingParity.status -ne 'pass') {
                return New-WorkflowKernelResult -Success $false -Code ([string]$existingParity.code) -Message 'Existing failed shadow evidence was preserved and was not reclassified as success.'
            }
            return New-WorkflowKernelResult -Success $true -Code 'hotspot_command_reused' -Message 'Existing append command result reused without new events.' -Data ([pscustomobject][ordered]@{
                shadow_root = $shadowRootFull
                command_receipt = $commandReceiptPath
            })
        }

        $sessionPath = Join-Path $shadowRootFull 'kernel-session.json'
        $existingSession = $null
        $existingEvents = @()
        if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
            $existingSession = Read-WorkflowKernelJson -Path $sessionPath -FailureCode 'shadow_session_read_failed'
            $existingEvents = @(Read-WorkflowKernelEvents -EventLogPath (Join-Path $shadowRootFull 'events.jsonl'))
        }
        elseif ([string]$command.command_mode -eq 'resume') {
            return New-WorkflowKernelResult -Success $false -Code 'hotspot_resume_session_missing' -Message 'Resume requires an existing hotspot shadow session.'
        }

        $validated = Test-WorkflowKernelHotspotCommand `
            -Command $command `
            -CommandDirectory $commandDirectory `
            -WorkflowIr $workflowIr `
            -ComponentCatalog $componentCatalog `
            -ExistingEvents $existingEvents `
            -ExistingSession $existingSession

        $preflightRelativePaths = [System.Collections.Generic.List[string]]::new()
        foreach ($relativePath in @(
            'events.jsonl',
            'kernel-session.json',
            'artifact-projection.json',
            'event-projection.json',
            'run-state.json',
            'resume-summary.json',
            'shadow-observation.json',
            'parity-report.json',
            ('commands/' + [string]$command.command_id + '.json')
        )) {
            $preflightRelativePaths.Add($relativePath)
        }
        foreach ($result in @($validated.component_results)) {
            $preflightRelativePaths.Add((Get-WorkflowKernelArtifactRelativePath -Result $result -Component $validated.component_map[[string]$result.component_id]))
        }
        $environmentPreflight = Invoke-TaogeEnvironmentPreflight `
            -ProjectRoot $projectRootFull `
            -AllowedRoot $allowedShadowRoot `
            -TargetRoot $shadowRootFull `
            -RelativePaths $preflightRelativePaths.ToArray() `
            -RequiredFreeBytes 1048576 `
            -RecommendedInstallationRootMaxChars 90 `
            -ClassicPathMaxChars 259 `
            -ProbeWrite
        if ([string]$environmentPreflight.status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_environment_preflight_failed' -Message 'M3 path, containment, writable temp space, or disk preflight failed.'
        }

        if ([string]$command.command_mode -eq 'start') {
            if (Test-Path -LiteralPath $shadowRootFull) {
                $existingItems = @(Get-ChildItem -LiteralPath $shadowRootFull -Force -ErrorAction SilentlyContinue)
                if ($existingItems.Count -gt 0) {
                    return New-WorkflowKernelResult -Success $false -Code 'shadow_root_not_empty' -Message 'Existing non-reusable shadow evidence was preserved.'
                }
            }
            New-Item -ItemType Directory -Force -Path $shadowRootFull | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $shadowRootFull 'inputs') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $shadowRootFull 'commands') | Out-Null
            Copy-WorkflowKernelAtomicFile -SourcePath ([string]$validated.input_path) -TargetPath (Join-Path $shadowRootFull ('inputs\' + [System.IO.Path]::GetFileName([string]$validated.input_path)))
            $session = [pscustomobject][ordered]@{
                schema_id = 'taoge://workflow-kernel/hotspot-shadow-session/v0.1'
                architecture_change_id = 'ARCH-20260718-002'
                shadow_run_id = [string]$command.shadow_run_id
                shadow_session_id = [string]$command.shadow_session_id
                source_session_id = [string]$command.source_session_id
                route_id = 'hotspot'
                route_version = '0.1'
                runtime_generation = 'kernel_v1_shadow'
                current_runtime_generation = 'legacy_r7'
                runtime_switch_enabled = $false
                current_write_performed = $false
                input_sha256 = [string]$command.input.sha256
                workflow_ir_sha256 = Get-WorkflowKernelSha256 -Path $workflowIrPath
                component_catalog_sha256 = Get-WorkflowKernelSha256 -Path $componentCatalogPath
                time_source = 'caller_materialized_only'
                worker_execution_mode = 'validated_result_envelope_replay'
                runtime_certification = $false
                command_count = 0
                last_command_id = $null
                last_command_sha256 = $null
            }
        }
        else {
            $session = $existingSession
        }

        $eventLogPath = Join-Path $shadowRootFull 'events.jsonl'
        $sequence = if ($existingEvents.Count -eq 0) { 1 } else { [int]$existingEvents[-1].sequence + 1 }
        if ([string]$command.command_mode -eq 'start') {
            Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelHotspotEvent `
                -ShadowSessionId ([string]$command.shadow_session_id) `
                -Sequence $sequence `
                -EventType 'run.initialized' `
                -OccurredAt ([string]$command.issued_at) `
                -CommandId ([string]$command.command_id))
        }
        else {
            Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelHotspotEvent `
                -ShadowSessionId ([string]$command.shadow_session_id) `
                -Sequence $sequence `
                -EventType 'run.resumed' `
                -OccurredAt ([string]$command.issued_at) `
                -CommandId ([string]$command.command_id))
        }
        $sequence++

        $recordMap = @{}
        foreach ($record in @($validated.activity_records)) {
            $recordMap[[string]$record.component_id] = $record
        }
        $stageMap = $validated.stage_map
        foreach ($result in @($validated.component_results)) {
            $componentId = [string]$result.component_id
            if ($recordMap.ContainsKey($componentId)) {
                $activityId = [string]$recordMap[$componentId].activity_id
                $sequence = Add-WorkflowKernelHotspotActivityEvents `
                    -EventLogPath $eventLogPath `
                    -ShadowSessionId ([string]$command.shadow_session_id) `
                    -Sequence $sequence `
                    -Record $recordMap[$componentId] `
                    -CommandId ([string]$command.command_id) `
                    -IncludeAttemptEvents (-not $validated.existing_activity_state.ContainsKey($activityId))
            }
            $component = $validated.component_map[$componentId]
            $artifact = Write-WorkflowKernelArtifact -ShadowRoot $shadowRootFull -RequestDirectory $commandDirectory -Result $result -Component $component
            Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelHotspotEvent `
                -ShadowSessionId ([string]$command.shadow_session_id) `
                -Sequence $sequence `
                -EventType 'component.result.accepted' `
                -OccurredAt ([string]$result.occurred_at) `
                -StageId ([string]$result.stage_id) `
                -ComponentId $componentId `
                -ResultStatus ([string]$result.result_status) `
                -Artifact $artifact `
                -CommandId ([string]$command.command_id))
            $sequence++
            $stageIds = @($stageMap[[string]$result.stage_id])
            if (
                $stageIds.Count -gt 0 -and
                $componentId -eq [string]$stageIds[-1] -and
                @('semantic_update_replan', 'topic_revalidation_replan') -notcontains [string]$result.result_status
            ) {
                Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelHotspotEvent `
                    -ShadowSessionId ([string]$command.shadow_session_id) `
                    -Sequence $sequence `
                    -EventType 'stage.completed' `
                    -OccurredAt ([string]$result.occurred_at) `
                    -StageId ([string]$result.stage_id) `
                    -CommandId ([string]$command.command_id))
                $sequence++
            }
        }
        if ([string]$command.stop.stop_reason -eq 'waiting_external') {
            $waitComponentId = [string]$command.stop.component_id
            $sequence = Add-WorkflowKernelHotspotActivityEvents `
                -EventLogPath $eventLogPath `
                -ShadowSessionId ([string]$command.shadow_session_id) `
                -Sequence $sequence `
                -Record $recordMap[$waitComponentId] `
                -CommandId ([string]$command.command_id)
        }
        Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelHotspotEvent `
            -ShadowSessionId ([string]$command.shadow_session_id) `
            -Sequence $sequence `
            -EventType 'run.waiting' `
            -OccurredAt ([string]$command.stop.occurred_at) `
            -StageId ([string]$command.stop.stage_id) `
            -ComponentId ([string]$command.stop.component_id) `
            -StopReason ([string]$command.stop.stop_reason) `
            -CommandId ([string]$command.command_id))

        Copy-WorkflowKernelAtomicFile -SourcePath $commandPathFull -TargetPath $commandReceiptPath
        $session.command_count = [int]$session.command_count + 1
        $session.last_command_id = [string]$command.command_id
        $session.last_command_sha256 = $commandSha256
        Write-WorkflowKernelAtomicJson -Path $sessionPath -Value $session -Depth 30

        $projection = Write-WorkflowKernelHotspotProjections -ShadowRoot $shadowRootFull -Session $session -LatestCommand $command
        if ([string]$projection.parity_status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code ([string]$projection.parity_code) -Message 'Hotspot shadow evidence was preserved, but parity failed.' -Data ([pscustomobject][ordered]@{
                shadow_root = $shadowRootFull
                parity_report = (Join-Path $shadowRootFull 'parity-report.json')
            })
        }
        return New-WorkflowKernelResult -Success $true -Code ([string]$projection.parity_code) -Message 'Hotspot shadow command was appended and projected.' -Data ([pscustomobject][ordered]@{
            shadow_root = $shadowRootFull
            parity_report = (Join-Path $shadowRootFull 'parity-report.json')
            observation = (Join-Path $shadowRootFull 'shadow-observation.json')
            command_receipt = $commandReceiptPath
        })
    }
    catch {
        $diagnostic = [string]$_.Exception.Message
        $code = $diagnostic
        if ([string]::IsNullOrWhiteSpace($code) -or $code -match '\s') {
            $code = 'workflow_kernel_unhandled_error'
        }
        return New-WorkflowKernelResult -Success $false -Code $code -Message 'Hotspot shadow runtime stopped before a false success.' -Data ([pscustomobject][ordered]@{
            diagnostic = $diagnostic
            exception_type = $_.Exception.GetType().FullName
            script_stack = [string]$_.ScriptStackTrace
        })
    }
}

function Invoke-WorkflowKernelHotspotProjectionRebuild {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ShadowRoot
    )

    try {
        $projectRootFull = Get-WorkflowKernelFullPath -Path $ProjectRoot
        $shadowRootFull = Get-WorkflowKernelFullPath -Path $ShadowRoot
        $allowedShadowRoot = Join-Path $projectRootFull 'state\checks'
        if (-not (Test-WorkflowKernelPathContained -Root $allowedShadowRoot -Candidate $shadowRootFull)) {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_root_outside_project' -Message 'M3 shadow output must stay under state/checks.'
        }
        $session = Read-WorkflowKernelJson -Path (Join-Path $shadowRootFull 'kernel-session.json') -FailureCode 'shadow_session_read_failed'
        if (
            [string]$session.schema_id -ne 'taoge://workflow-kernel/hotspot-shadow-session/v0.1' -or
            [string]$session.route_id -ne 'hotspot' -or
            [bool]$session.runtime_switch_enabled
        ) {
            throw 'shadow_session_contract_invalid'
        }
        $latestCommandPath = Join-Path (Join-Path $shadowRootFull 'commands') ([string]$session.last_command_id + '.json')
        $latestCommand = Read-WorkflowKernelJson -Path $latestCommandPath -FailureCode 'latest_command_missing'
        if ((Get-WorkflowKernelSha256 -Path $latestCommandPath) -ne [string]$session.last_command_sha256) {
            throw 'latest_command_digest_mismatch'
        }
        $projection = Write-WorkflowKernelHotspotProjections -ShadowRoot $shadowRootFull -Session $session -LatestCommand $latestCommand
        if ([string]$projection.parity_status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code ([string]$projection.parity_code) -Message 'Hotspot projection rebuilt, but parity failed.'
        }
        return New-WorkflowKernelResult -Success $true -Code 'hotspot_projection_rebuild_pass' -Message 'Hotspot projections were rebuilt from persisted commands, events, and artifacts.'
    }
    catch {
        $diagnostic = [string]$_.Exception.Message
        $code = $diagnostic
        if ([string]::IsNullOrWhiteSpace($code) -or $code -match '\s') {
            $code = 'workflow_kernel_unhandled_error'
        }
        return New-WorkflowKernelResult -Success $false -Code $code -Message 'Hotspot projection rebuild stopped before a false success.' -Data ([pscustomobject][ordered]@{
            diagnostic = $diagnostic
            exception_type = $_.Exception.GetType().FullName
            script_stack = [string]$_.ScriptStackTrace
        })
    }
}
