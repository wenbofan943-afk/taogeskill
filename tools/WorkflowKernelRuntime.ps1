Set-StrictMode -Version 2.0

$helperPath = Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw "workflow_kernel_helper_missing"
}
. $helperPath
$preflightPath = Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1'
if (-not (Test-Path -LiteralPath $preflightPath -PathType Leaf)) {
    throw "workflow_kernel_preflight_missing"
}
. $preflightPath

function New-WorkflowKernelResult {
    param(
        [bool]$Success,
        [string]$Code,
        [string]$Message,
        [object]$Data = $null
    )

    return [pscustomobject][ordered]@{
        success = $Success
        code = $Code
        message = $Message
        data = $Data
    }
}

function Get-WorkflowKernelFullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-WorkflowKernelPathContained {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate
    )

    $rootFull = (Get-WorkflowKernelFullPath -Path $Root).TrimEnd('\', '/')
    $candidateFull = Get-WorkflowKernelFullPath -Path $Candidate
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-WorkflowKernelRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string]$FailureCode = 'relative_path_invalid'
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw $FailureCode
    }

    $resolved = Get-WorkflowKernelFullPath -Path (Join-Path $Root $RelativePath)
    $containment = Resolve-TaogeContainedPath -AllowedRoot $Root -CandidatePath $resolved -RejectReparsePoints
    if ([string]$containment.status -ne 'pass') {
        throw $FailureCode
    }
    return [string]$containment.resolved_path
}

function Get-WorkflowKernelSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    return (Get-TaogeFileSha256 -Path $Path).ToLowerInvariant()
}

function Complete-WorkflowKernelAtomicFile {
    param(
        [Parameter(Mandatory = $true)][string]$TemporaryPath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
        $parent = Split-Path -Parent $TargetPath
        $backupPath = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($TargetPath) + '.' + [guid]::NewGuid().ToString('N') + '.bak')
        try {
            [System.IO.File]::Replace($TemporaryPath, $TargetPath, $backupPath)
        }
        finally {
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                Remove-Item -LiteralPath $backupPath -Force
            }
        }
    }
    else {
        [System.IO.File]::Move($TemporaryPath, $TargetPath)
    }
}

function Write-WorkflowKernelAtomicText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowEmptyString()][string]$Text = ''
    )

    $fullPath = Get-WorkflowKernelFullPath -Path $Path
    $parent = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Write-TaogeUtf8NoBomText -Path $temporaryPath -Text $Text
        Complete-WorkflowKernelAtomicFile -TemporaryPath $temporaryPath -TargetPath $fullPath
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-WorkflowKernelAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value,
        [int]$Depth = 30
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    Write-WorkflowKernelAtomicText -Path $Path -Text ($json + [Environment]::NewLine)
}

function Copy-WorkflowKernelAtomicFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $targetFull = Get-WorkflowKernelFullPath -Path $TargetPath
    $parent = Split-Path -Parent $targetFull
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($targetFull) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::Copy($SourcePath, $temporaryPath, $false)
        Complete-WorkflowKernelAtomicFile -TemporaryPath $temporaryPath -TargetPath $targetFull
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Get-WorkflowKernelValueSha256 {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 100 -Compress
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Read-WorkflowKernelJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$FailureCode = 'json_read_failed'
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw $FailureCode
    }
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        throw $FailureCode
    }
}

function Test-WorkflowKernelTimestamp {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }
    $text = [string]$Value
    if ($text -notmatch '(Z|[+-][0-9]{2}:[0-9]{2})$') {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse(
        $text,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
}

function Get-WorkflowKernelProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FailureCode = 'request_contract_invalid'
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw $FailureCode
    }
    return $property.Value
}

function Assert-WorkflowKernelAllowedProperties {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$AllowedProperties,
        [string]$FailureCode = 'request_contract_invalid'
    )

    $unknown = @($Object.PSObject.Properties.Name | Where-Object { $AllowedProperties -notcontains [string]$_ })
    if ($unknown.Count -gt 0) {
        throw $FailureCode
    }
}

function Get-WorkflowKernelComponentMap {
    param(
        [Parameter(Mandatory = $true)][object]$Catalog
    )

    $map = @{}
    foreach ($component in @($Catalog.components)) {
        $id = [string]$component.component_id
        if ([string]::IsNullOrWhiteSpace($id) -or $map.ContainsKey($id)) {
            throw 'component_catalog_invalid'
        }
        $map[$id] = $component
    }
    return $map
}

function Get-WorkflowKernelRoute {
    param(
        [Parameter(Mandatory = $true)][object]$WorkflowIr,
        [Parameter(Mandatory = $true)][string]$RouteId
    )

    $matches = @($WorkflowIr.routes | Where-Object { [string]$_.route_id -eq $RouteId })
    if ($matches.Count -ne 1) {
        throw 'route_not_found'
    }
    return $matches[0]
}

function Get-WorkflowKernelExpectedResults {
    param(
        [Parameter(Mandatory = $true)][object]$Route
    )

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($binding in @($Route.stage_bindings)) {
        $stageId = [string]$binding.stage_id
        if ($stageId -eq 'final_decision') {
            continue
        }
        if ([string]$binding.mode -eq 'skip') {
            continue
        }
        foreach ($componentId in @($binding.component_refs)) {
            $results.Add([pscustomobject][ordered]@{
                stage_id = $stageId
                component_id = [string]$componentId
            })
        }
    }
    return $results.ToArray()
}

function Test-WorkflowKernelId {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }
    return ([string]$Value -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')
}

function Test-WorkflowKernelHash {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }
    return ([string]$Value -match '^[a-f0-9]{64}$')
}

function Test-WorkflowKernelRequest {
    param(
        [Parameter(Mandatory = $true)][object]$Request,
        [Parameter(Mandatory = $true)][string]$RequestDirectory,
        [Parameter(Mandatory = $true)][object]$WorkflowIr,
        [Parameter(Mandatory = $true)][object]$ComponentCatalog
    )

    Assert-WorkflowKernelAllowedProperties -Object $Request -AllowedProperties @(
        'schema_id',
        'schema_version',
        'architecture_change_id',
        'shadow_run_id',
        'shadow_session_id',
        'source_session_id',
        'runtime_generation',
        'source_runtime_generation',
        'route_id',
        'route_version',
        'initialized_at',
        'waiting_at',
        'stage_timestamps',
        'input',
        'component_results',
        'final_decision_results',
        'legacy_observation'
    )
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'schema_id') -ne 'taoge://workflow-kernel/direct-shadow-run-request/v0.1') {
        throw 'request_schema_invalid'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'schema_version') -ne '0.1') {
        throw 'request_schema_invalid'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'architecture_change_id') -ne 'ARCH-20260718-002') {
        throw 'architecture_change_id_mismatch'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'runtime_generation') -ne 'kernel_v1_shadow') {
        throw 'runtime_generation_invalid'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'source_runtime_generation') -ne 'legacy_r7') {
        throw 'source_runtime_generation_invalid'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'route_id') -ne 'direct') {
        throw 'route_not_authorized_for_m2'
    }
    if ([string](Get-WorkflowKernelProperty -Object $Request -Name 'route_version') -ne '0.1') {
        throw 'route_version_invalid'
    }
    foreach ($idName in @('shadow_run_id', 'shadow_session_id', 'source_session_id')) {
        if (-not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $Request -Name $idName))) {
            throw 'request_id_invalid'
        }
    }
    foreach ($timestampName in @('initialized_at', 'waiting_at')) {
        if (-not (Test-WorkflowKernelTimestamp -Value (Get-WorkflowKernelProperty -Object $Request -Name $timestampName))) {
            throw 'timestamp_invalid'
        }
    }

    if ([bool]$WorkflowIr.runtime_switch_enabled) {
        throw 'runtime_switch_must_remain_disabled'
    }
    if ([string]$WorkflowIr.runtime_generation -ne 'kernel_v1_shadow') {
        throw 'workflow_ir_generation_invalid'
    }
    $shadowPolicy = Get-WorkflowKernelProperty -Object $WorkflowIr -Name 'shadow_execution_policy' -FailureCode 'shadow_execution_policy_missing'
    if (
        @($shadowPolicy.authorized_routes) -notcontains 'direct' -or
        [string]$shadowPolicy.result_intake_mode -ne 'validated_typed_result_envelope' -or
        [string]$shadowPolicy.execution_scope -ne 'direct_positive_path_to_final_human_wait' -or
        [string]$shadowPolicy.intermediate_non_progress_behavior -ne 'block_before_shadow_write' -or
        [string]$shadowPolicy.final_decision_mode -ne 'stop_waiting_human' -or
        [bool]$shadowPolicy.current_write_performed -or
        [bool]$shadowPolicy.runtime_certification
    ) {
        throw 'shadow_execution_policy_invalid'
    }

    $route = Get-WorkflowKernelRoute -WorkflowIr $WorkflowIr -RouteId 'direct'
    $stageTimestampObject = Get-WorkflowKernelProperty -Object $Request -Name 'stage_timestamps'
    Assert-WorkflowKernelAllowedProperties -Object $stageTimestampObject -AllowedProperties @(
        'intake',
        'research_topic',
        'script_design',
        'visual_plan',
        'asset_production',
        'delivery_compile'
    ) -FailureCode 'timestamp_contract_invalid'
    foreach ($binding in @($route.stage_bindings)) {
        $stageId = [string]$binding.stage_id
        if ($stageId -eq 'final_decision') {
            continue
        }
        $stageTimestampProperty = $stageTimestampObject.PSObject.Properties[$stageId]
        if ($null -eq $stageTimestampProperty -or -not (Test-WorkflowKernelTimestamp -Value $stageTimestampProperty.Value)) {
            throw 'timestamp_invalid'
        }
    }

    $input = Get-WorkflowKernelProperty -Object $Request -Name 'input'
    Assert-WorkflowKernelAllowedProperties -Object $input -AllowedProperties @('input_id', 'relative_path', 'sha256') -FailureCode 'input_contract_invalid'
    if (-not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $input -Name 'input_id'))) {
        throw 'input_contract_invalid'
    }
    $inputRelativePath = [string](Get-WorkflowKernelProperty -Object $input -Name 'relative_path')
    $inputPath = Resolve-WorkflowKernelRelativePath -Root $RequestDirectory -RelativePath $inputRelativePath -FailureCode 'input_path_invalid'
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw 'input_file_missing'
    }
    $expectedInputHash = [string](Get-WorkflowKernelProperty -Object $input -Name 'sha256')
    if (-not (Test-WorkflowKernelHash -Value $expectedInputHash)) {
        throw 'input_digest_invalid'
    }
    if ((Get-WorkflowKernelSha256 -Path $inputPath) -ne $expectedInputHash) {
        throw 'input_digest_mismatch'
    }

    $componentMap = Get-WorkflowKernelComponentMap -Catalog $ComponentCatalog
    $progressProfile = Get-WorkflowKernelProperty -Object $ComponentCatalog -Name 'm2_direct_progress_profile' -FailureCode 'm2_progress_profile_missing'
    if (
        [string]$progressProfile.route_id -ne 'direct' -or
        [string]$progressProfile.non_progress_behavior -ne 'block_before_shadow_write'
    ) {
        throw 'm2_progress_profile_invalid'
    }
    $progressStatusMap = Get-WorkflowKernelProperty -Object $progressProfile -Name 'progress_statuses_by_component' -FailureCode 'm2_progress_profile_invalid'
    $expectedResults = @(Get-WorkflowKernelExpectedResults -Route $route)
    $expectedProgressIds = @($expectedResults | ForEach-Object { [string]$_.component_id } | Sort-Object)
    $actualProgressIds = @($progressStatusMap.PSObject.Properties.Name | ForEach-Object { [string]$_ } | Sort-Object)
    if (($expectedProgressIds -join '|') -ne ($actualProgressIds -join '|')) {
        throw 'm2_progress_profile_invalid'
    }
    $actualResults = @(Get-WorkflowKernelProperty -Object $Request -Name 'component_results')
    if ($actualResults.Count -ne $expectedResults.Count) {
        throw 'component_result_sequence_invalid'
    }

    for ($index = 0; $index -lt $expectedResults.Count; $index++) {
        $expected = $expectedResults[$index]
        $result = $actualResults[$index]
        Assert-WorkflowKernelAllowedProperties -Object $result -AllowedProperties @(
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
        $componentId = [string](Get-WorkflowKernelProperty -Object $result -Name 'component_id')
        $stageId = [string](Get-WorkflowKernelProperty -Object $result -Name 'stage_id')
        if ($componentId -eq 'final_human_decision_gate' -or $componentId -eq 'final_delivery_decision_apply') {
            throw 'final_decision_execution_not_authorized'
        }
        if ($componentId -ne [string]$expected.component_id -or $stageId -ne [string]$expected.stage_id) {
            throw 'component_result_sequence_invalid'
        }
        if (-not $componentMap.ContainsKey($componentId)) {
            throw 'component_catalog_reference_missing'
        }
        $component = $componentMap[$componentId]

        $artifactId = Get-WorkflowKernelProperty -Object $result -Name 'artifact_id'
        if (-not (Test-WorkflowKernelId -Value $artifactId)) {
            throw 'artifact_id_invalid'
        }
        $revision = Get-WorkflowKernelProperty -Object $result -Name 'artifact_revision'
        if (-not ($revision -is [int]) -and -not ($revision -is [long])) {
            throw 'artifact_revision_invalid'
        }
        if ([int64]$revision -lt 1) {
            throw 'artifact_revision_invalid'
        }

        $resultStatus = [string](Get-WorkflowKernelProperty -Object $result -Name 'result_status')
        if (@($component.allowed_result_statuses) -notcontains $resultStatus) {
            throw 'component_result_status_invalid'
        }
        $progressProperty = $progressStatusMap.PSObject.Properties[$componentId]
        if ($null -eq $progressProperty) {
            throw 'm2_progress_profile_invalid'
        }
        if (@($progressProperty.Value) -notcontains $resultStatus) {
            throw 'm2_non_progress_result_requires_separate_shadow_case'
        }
        $contractRef = [string](Get-WorkflowKernelProperty -Object $result -Name 'output_contract_ref')
        if ($contractRef -ne [string]$component.output_contract_ref) {
            throw 'component_result_contract_invalid'
        }
        if (-not (Test-WorkflowKernelTimestamp -Value (Get-WorkflowKernelProperty -Object $result -Name 'occurred_at'))) {
            throw 'timestamp_invalid'
        }

        $receipt = Get-WorkflowKernelProperty -Object $result -Name 'validation_receipt'
        Assert-WorkflowKernelAllowedProperties -Object $receipt -AllowedProperties @(
            'validation_status',
            'contract_ref',
            'validator_id'
        ) -FailureCode 'validation_receipt_invalid'
        if ([string](Get-WorkflowKernelProperty -Object $receipt -Name 'validation_status') -ne 'pass') {
            throw 'validation_receipt_invalid'
        }
        if ([string](Get-WorkflowKernelProperty -Object $receipt -Name 'contract_ref') -ne $contractRef) {
            throw 'validation_receipt_invalid'
        }
        if (-not (Test-WorkflowKernelId -Value (Get-WorkflowKernelProperty -Object $receipt -Name 'validator_id'))) {
            throw 'validation_receipt_invalid'
        }

        $payloadKind = [string](Get-WorkflowKernelProperty -Object $result -Name 'payload_kind')
        if ($payloadKind -eq 'json_inline') {
            [void](Get-WorkflowKernelProperty -Object $result -Name 'payload')
            if ($null -ne $result.PSObject.Properties['payload_relative_path']) {
                throw 'component_result_shape_invalid'
            }
        }
        elseif ($payloadKind -eq 'file_ref') {
            if ($null -ne $result.PSObject.Properties['payload']) {
                throw 'component_result_shape_invalid'
            }
            $payloadRelativePath = [string](Get-WorkflowKernelProperty -Object $result -Name 'payload_relative_path')
            $payloadPath = Resolve-WorkflowKernelRelativePath -Root $RequestDirectory -RelativePath $payloadRelativePath -FailureCode 'payload_path_invalid'
            if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
                throw 'payload_file_missing'
            }
        }
        else {
            throw 'payload_kind_invalid'
        }
    }

    $finalDecisionProperty = $Request.PSObject.Properties['final_decision_results']
    if ($null -ne $finalDecisionProperty) {
        $finalDecisionResults = @($finalDecisionProperty.Value)
        if ($finalDecisionResults.Count -gt 0) {
            throw 'final_decision_execution_not_authorized'
        }
    }

    $legacy = Get-WorkflowKernelProperty -Object $Request -Name 'legacy_observation'
    Assert-WorkflowKernelAllowedProperties -Object $legacy -AllowedProperties @(
        'schema_id',
        'schema_version',
        'observation_kind',
        'real_legacy_runtime_executed',
        'input_sha256',
        'artifact_projection_sha256',
        'event_projection_sha256',
        'stop_reason',
        'final_html_sha256'
    ) -FailureCode 'legacy_observation_invalid'
    if ([string](Get-WorkflowKernelProperty -Object $legacy -Name 'schema_id') -ne 'taoge://workflow-kernel/direct-shadow-observation/v0.1') {
        throw 'legacy_observation_invalid'
    }
    if (
        [string](Get-WorkflowKernelProperty -Object $legacy -Name 'observation_kind') -ne 'frozen_legacy_contract_fixture' -or
        [bool](Get-WorkflowKernelProperty -Object $legacy -Name 'real_legacy_runtime_executed')
    ) {
        throw 'legacy_observation_invalid'
    }
    foreach ($hashName in @('input_sha256', 'artifact_projection_sha256', 'event_projection_sha256', 'final_html_sha256')) {
        if (-not (Test-WorkflowKernelHash -Value (Get-WorkflowKernelProperty -Object $legacy -Name $hashName))) {
            throw 'legacy_observation_invalid'
        }
    }
    if ([string](Get-WorkflowKernelProperty -Object $legacy -Name 'stop_reason') -ne 'waiting_human') {
        throw 'legacy_observation_invalid'
    }

    return [pscustomobject][ordered]@{
        route = $route
        component_map = $componentMap
        input_path = $inputPath
        component_results = $actualResults
    }
}

function New-WorkflowKernelEvent {
    param(
        [Parameter(Mandatory = $true)][string]$ShadowSessionId,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$OccurredAt,
        [AllowNull()][string]$StageId = $null,
        [AllowNull()][string]$ComponentId = $null,
        [AllowNull()][string]$ResultStatus = $null,
        [AllowNull()][object]$Artifact = $null,
        [AllowNull()][string]$StopReason = $null
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
    }
}

function Add-WorkflowKernelEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventLogPath,
        [Parameter(Mandatory = $true)][object]$Event
    )

    $line = $Event | ConvertTo-Json -Depth 30 -Compress
    Add-TaogeUtf8NoBomLine -Path $EventLogPath -Line $line
}

function Get-WorkflowKernelArtifactRelativePath {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][object]$Component
    )

    $artifactType = [string]$Component.output_artifact_type
    $artifactId = [string]$Result.artifact_id
    $revision = [int64]$Result.artifact_revision
    $extension = '.json'
    if ([string]$Result.payload_kind -eq 'file_ref') {
        $extension = [System.IO.Path]::GetExtension([string]$Result.payload_relative_path)
        if ([string]::IsNullOrWhiteSpace($extension)) {
            $extension = '.bin'
        }
    }
    return (Join-Path (Join-Path (Join-Path 'artifacts' $artifactType) ('r{0}' -f $revision)) ($artifactId + $extension))
}

function Write-WorkflowKernelArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$ShadowRoot,
        [Parameter(Mandatory = $true)][string]$RequestDirectory,
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][object]$Component
    )

    $artifactType = [string]$Component.output_artifact_type
    $artifactId = [string]$Result.artifact_id
    $revision = [int64]$Result.artifact_revision
    if (-not (Test-WorkflowKernelId -Value $artifactType)) {
        throw 'artifact_type_invalid'
    }

    $relativePath = Get-WorkflowKernelArtifactRelativePath -Result $Result -Component $Component
    $targetPath = Join-Path $ShadowRoot $relativePath
    $targetDirectory = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    if ([string]$Result.payload_kind -eq 'json_inline') {
        $json = $Result.payload | ConvertTo-Json -Depth 100
        Write-WorkflowKernelAtomicText -Path $targetPath -Text ($json + [Environment]::NewLine)
    }
    else {
        $sourcePath = Resolve-WorkflowKernelRelativePath -Root $RequestDirectory -RelativePath ([string]$Result.payload_relative_path) -FailureCode 'payload_path_invalid'
        Copy-WorkflowKernelAtomicFile -SourcePath $sourcePath -TargetPath $targetPath
    }

    $hash = Get-WorkflowKernelSha256 -Path $targetPath
    return [pscustomobject][ordered]@{
        artifact_id = $artifactId
        artifact_type = $artifactType
        artifact_revision = $revision
        relative_path = ($relativePath -replace '\\', '/')
        sha256 = $hash
        output_contract_ref = [string]$Result.output_contract_ref
    }
}

function Read-WorkflowKernelEvents {
    param(
        [Parameter(Mandatory = $true)][string]$EventLogPath
    )

    if (-not (Test-Path -LiteralPath $EventLogPath -PathType Leaf)) {
        throw 'event_log_missing'
    }
    $events = New-Object System.Collections.Generic.List[object]
    $sequence = 0
    $previousId = $null
    foreach ($line in @(Get-Content -LiteralPath $EventLogPath -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $event = $line | ConvertFrom-Json
        }
        catch {
            throw 'event_log_invalid'
        }
        $sequence++
        if ([int]$event.sequence -ne $sequence) {
            throw 'event_sequence_invalid'
        }
        if ($sequence -eq 1) {
            if ($null -ne $event.previous_event_id -and -not [string]::IsNullOrWhiteSpace([string]$event.previous_event_id)) {
                throw 'event_sequence_invalid'
            }
        }
        elseif ([string]$event.previous_event_id -ne $previousId) {
            throw 'event_sequence_invalid'
        }
        if (-not (Test-WorkflowKernelTimestamp -Value $event.occurred_at)) {
            throw 'timestamp_invalid'
        }
        $previousId = [string]$event.event_id
        $events.Add($event)
    }
    if ($events.Count -eq 0) {
        throw 'event_log_empty'
    }
    return $events.ToArray()
}

function Write-WorkflowKernelProjections {
    param(
        [Parameter(Mandatory = $true)][string]$ShadowRoot,
        [Parameter(Mandatory = $true)][object]$Request,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $eventLogPath = Join-Path $ShadowRoot 'events.jsonl'
    $events = @(Read-WorkflowKernelEvents -EventLogPath $eventLogPath)
    $artifactProjection = New-Object System.Collections.Generic.List[object]
    $eventProjection = New-Object System.Collections.Generic.List[object]
    $completedStages = New-Object System.Collections.Generic.List[string]
    $currentStageId = 'intake'
    $stopReason = $null
    $waitingComponentId = $null
    $finalHtmlSha256 = $null

    foreach ($event in $events) {
        $eventProjection.Add([pscustomobject][ordered]@{
            event_type = [string]$event.event_type
            stage_id = [string]$event.stage_id
            component_id = [string]$event.component_id
            result_status = [string]$event.result_status
            artifact_id = if ($null -eq $event.artifact) { '' } else { [string]$event.artifact.artifact_id }
            stop_reason = [string]$event.stop_reason
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
        elseif ([string]$event.event_type -eq 'stage.completed' -or [string]$event.event_type -eq 'stage.skipped') {
            $completedStages.Add([string]$event.stage_id)
        }
        elseif ([string]$event.event_type -eq 'run.waiting') {
            $currentStageId = [string]$event.stage_id
            $waitingComponentId = [string]$event.component_id
            $stopReason = [string]$event.stop_reason
        }
    }

    if ([string]::IsNullOrWhiteSpace($stopReason)) {
        throw 'stop_reason_missing'
    }
    if ([string]::IsNullOrWhiteSpace($finalHtmlSha256)) {
        throw 'final_html_artifact_missing'
    }
    if ([string]::IsNullOrWhiteSpace($waitingComponentId)) {
        throw 'waiting_component_missing'
    }

    $artifactProjectionArray = $artifactProjection.ToArray()
    $eventProjectionArray = $eventProjection.ToArray()
    $artifactProjectionSha256 = Get-WorkflowKernelValueSha256 -Value $artifactProjectionArray
    $eventProjectionSha256 = Get-WorkflowKernelValueSha256 -Value $eventProjectionArray

    $runState = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/run-state/v0.1'
        shadow_session_id = [string]$Request.shadow_session_id
        route_id = [string]$Request.route_id
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'legacy_r7'
        runtime_switch_enabled = $false
        current_write_performed = $false
        status = 'waiting'
        current_stage_id = $currentStageId
        stop_reason = $stopReason
        completed_stage_ids = $completedStages.ToArray()
        artifact_count = $artifactProjectionArray.Count
        event_count = $eventProjectionArray.Count
        last_event_id = [string]$events[-1].event_id
        last_event_at = [string]$events[-1].occurred_at
    }
    $resumeSummary = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/resume-summary/v0.1'
        shadow_session_id = [string]$Request.shadow_session_id
        resume_from_stage_id = $currentStageId
        stop_reason = $stopReason
        next_component_id = $waitingComponentId
        required_human_input = 'typed_final_delivery_decision'
        reconcile_before_retry = $true
        current_runtime_untouched = $true
        source_event_id = [string]$events[-1].event_id
    }
    $observation = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/direct-shadow-observation/v0.1'
        schema_version = '0.1'
        shadow_session_id = [string]$Request.shadow_session_id
        source_session_id = [string]$Request.source_session_id
        observation_kind = 'kernel_v1_shadow_observation'
        real_legacy_runtime_executed = $false
        input_sha256 = [string]$Request.input.sha256
        artifact_projection_sha256 = $artifactProjectionSha256
        event_projection_sha256 = $eventProjectionSha256
        stop_reason = $stopReason
        final_html_sha256 = $finalHtmlSha256
        artifact_count = $artifactProjectionArray.Count
        event_count = $eventProjectionArray.Count
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'legacy_r7'
        runtime_switch_enabled = $false
        current_write_performed = $false
    }

    $legacy = $Request.legacy_observation
    $checks = New-Object System.Collections.Generic.List[object]
    foreach ($definition in @(
        @('input_sha256', [string]$legacy.input_sha256, [string]$observation.input_sha256, 'input_projection_mismatch'),
        @('artifact_projection_sha256', [string]$legacy.artifact_projection_sha256, [string]$observation.artifact_projection_sha256, 'artifact_projection_mismatch'),
        @('event_projection_sha256', [string]$legacy.event_projection_sha256, [string]$observation.event_projection_sha256, 'event_projection_mismatch'),
        @('stop_reason', [string]$legacy.stop_reason, [string]$observation.stop_reason, 'stop_reason_mismatch'),
        @('final_html_sha256', [string]$legacy.final_html_sha256, [string]$observation.final_html_sha256, 'final_html_mismatch')
    )) {
        $checks.Add([pscustomobject][ordered]@{
            check_id = [string]$definition[0]
            expected = [string]$definition[1]
            actual = [string]$definition[2]
            passed = ([string]$definition[1] -eq [string]$definition[2])
            failure_code = [string]$definition[3]
        })
    }
    $failed = @($checks | Where-Object { -not [bool]$_.passed })
    $parityStatus = 'pass'
    $parityCode = 'shadow_parity_pass'
    if ($failed.Count -gt 0) {
        $parityStatus = 'fail'
        $parityCode = [string]$failed[0].failure_code
    }
    $parityReport = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/direct-shadow-parity-report/v0.1'
        architecture_change_id = 'ARCH-20260718-002'
        status = $parityStatus
        code = $parityCode
        comparison_scope = @('artifact', 'event', 'stop_reason', 'final_html')
        shadow_only = $true
        runtime_certification = $false
        comparison_baseline_kind = [string]$legacy.observation_kind
        real_legacy_runtime_executed = [bool]$legacy.real_legacy_runtime_executed
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
        parity_status = $parityStatus
        parity_code = $parityCode
        observation = $observation
        parity_report = $parityReport
    }
}

function Invoke-WorkflowKernelDirectShadow {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RequestPath,
        [Parameter(Mandatory = $true)][string]$ShadowRoot
    )

    try {
        $projectRootFull = Get-WorkflowKernelFullPath -Path $ProjectRoot
        $requestPathFull = Get-WorkflowKernelFullPath -Path $RequestPath
        $shadowRootFull = Get-WorkflowKernelFullPath -Path $ShadowRoot
        $requestContainment = Resolve-TaogeContainedPath -AllowedRoot $projectRootFull -CandidatePath $requestPathFull -RejectReparsePoints
        if ([string]$requestContainment.status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code 'request_path_outside_project' -Message 'Request path must stay inside the project root.'
        }
        $allowedShadowRoot = Join-Path $projectRootFull 'state\checks'
        if (-not (Test-WorkflowKernelPathContained -Root $allowedShadowRoot -Candidate $shadowRootFull)) {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_root_outside_project' -Message 'M2 shadow output must stay under state/checks.'
        }

        $workflowIrPath = Join-Path $projectRootFull 'routes\current-workflow-ir.json'
        $componentCatalogPath = Join-Path $projectRootFull 'routes\component-catalog.json'
        $workflowIr = Read-WorkflowKernelJson -Path $workflowIrPath -FailureCode 'workflow_ir_read_failed'
        $componentCatalog = Read-WorkflowKernelJson -Path $componentCatalogPath -FailureCode 'component_catalog_read_failed'
        $request = Read-WorkflowKernelJson -Path $requestPathFull -FailureCode 'request_read_failed'
        $requestDirectory = Split-Path -Parent $requestPathFull
        $validated = Test-WorkflowKernelRequest -Request $request -RequestDirectory $requestDirectory -WorkflowIr $workflowIr -ComponentCatalog $componentCatalog
        $requestSha256 = Get-WorkflowKernelSha256 -Path $requestPathFull

        $preflightRelativePaths = [System.Collections.Generic.List[string]]::new()
        foreach ($relativePath in @(
            'events.jsonl',
            'artifact-projection.json',
            'event-projection.json',
            'run-state.json',
            'resume-summary.json',
            'shadow-observation.json',
            'parity-report.json'
        )) {
            $preflightRelativePaths.Add($relativePath)
        }
        foreach ($result in @($validated.component_results)) {
            $component = $validated.component_map[[string]$result.component_id]
            $preflightRelativePaths.Add((Get-WorkflowKernelArtifactRelativePath -Result $result -Component $component))
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
            return New-WorkflowKernelResult -Success $false -Code 'shadow_environment_preflight_failed' -Message 'Path, containment, writable temp space, or disk preflight failed.' -Data ([pscustomobject][ordered]@{
                failure_categories = @($environmentPreflight.failure_categories)
            })
        }

        if (Test-Path -LiteralPath $shadowRootFull) {
            $sessionPath = Join-Path $shadowRootFull 'kernel-session.json'
            $parityPath = Join-Path $shadowRootFull 'parity-report.json'
            if ((Test-Path -LiteralPath $sessionPath -PathType Leaf) -and (Test-Path -LiteralPath $parityPath -PathType Leaf)) {
                $existingSession = Read-WorkflowKernelJson -Path $sessionPath -FailureCode 'shadow_session_read_failed'
                $existingParity = Read-WorkflowKernelJson -Path $parityPath -FailureCode 'shadow_parity_read_failed'
                if (
                    [string]$existingSession.request_sha256 -eq $requestSha256 -and
                    [string]$existingSession.shadow_session_id -eq [string]$request.shadow_session_id -and
                    [string]$existingParity.status -eq 'pass'
                ) {
                    return New-WorkflowKernelResult -Success $true -Code 'shadow_run_reused' -Message 'Existing byte-stable shadow result reused.' -Data ([pscustomobject][ordered]@{
                        shadow_root = $shadowRootFull
                        parity_report = $parityPath
                    })
                }
            }
            $existingItems = @(Get-ChildItem -LiteralPath $shadowRootFull -Force -ErrorAction SilentlyContinue)
            if ($existingItems.Count -gt 0) {
                return New-WorkflowKernelResult -Success $false -Code 'shadow_root_not_empty' -Message 'Existing non-reusable shadow evidence was preserved.'
            }
        }

        New-Item -ItemType Directory -Force -Path $shadowRootFull | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $shadowRootFull 'inputs') | Out-Null
        $requestCopyPath = Join-Path $shadowRootFull 'inputs\shadow-run-request.json'
        Copy-WorkflowKernelAtomicFile -SourcePath $requestPathFull -TargetPath $requestCopyPath
        $inputCopyPath = Join-Path $shadowRootFull ('inputs\' + [System.IO.Path]::GetFileName([string]$validated.input_path))
        Copy-WorkflowKernelAtomicFile -SourcePath ([string]$validated.input_path) -TargetPath $inputCopyPath

        $session = [pscustomobject][ordered]@{
            schema_id = 'taoge://workflow-kernel/shadow-session/v0.1'
            architecture_change_id = 'ARCH-20260718-002'
            shadow_run_id = [string]$request.shadow_run_id
            shadow_session_id = [string]$request.shadow_session_id
            source_session_id = [string]$request.source_session_id
            route_id = 'direct'
            route_version = '0.1'
            runtime_generation = 'kernel_v1_shadow'
            current_runtime_generation = 'legacy_r7'
            runtime_switch_enabled = $false
            current_write_performed = $false
            request_sha256 = $requestSha256
            workflow_ir_sha256 = Get-WorkflowKernelSha256 -Path $workflowIrPath
            component_catalog_sha256 = Get-WorkflowKernelSha256 -Path $componentCatalogPath
            time_source = 'caller_materialized_only'
            worker_execution_mode = 'validated_result_envelope_replay'
            runtime_certification = $false
        }
        Write-WorkflowKernelAtomicJson -Path (Join-Path $shadowRootFull 'kernel-session.json') -Value $session -Depth 30

        $eventLogPath = Join-Path $shadowRootFull 'events.jsonl'
        $sequence = 1
        Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelEvent -ShadowSessionId ([string]$request.shadow_session_id) -Sequence $sequence -EventType 'run.initialized' -OccurredAt ([string]$request.initialized_at))
        $sequence++

        $resultIndex = 0
        foreach ($binding in @($validated.route.stage_bindings)) {
            $stageId = [string]$binding.stage_id
            if ($stageId -eq 'final_decision') {
                $waitingComponentId = [string](@($binding.component_refs)[0])
                Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelEvent -ShadowSessionId ([string]$request.shadow_session_id) -Sequence $sequence -EventType 'run.waiting' -OccurredAt ([string]$request.waiting_at) -StageId $stageId -ComponentId $waitingComponentId -StopReason 'waiting_human')
                $sequence++
                break
            }
            $stageAt = [string]$request.stage_timestamps.PSObject.Properties[$stageId].Value
            if ([string]$binding.mode -eq 'skip') {
                Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelEvent -ShadowSessionId ([string]$request.shadow_session_id) -Sequence $sequence -EventType 'stage.skipped' -OccurredAt $stageAt -StageId $stageId)
                $sequence++
                continue
            }

            foreach ($componentIdValue in @($binding.component_refs)) {
                $result = $validated.component_results[$resultIndex]
                $componentId = [string]$componentIdValue
                $component = $validated.component_map[$componentId]
                $artifact = Write-WorkflowKernelArtifact -ShadowRoot $shadowRootFull -RequestDirectory $requestDirectory -Result $result -Component $component
                Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelEvent -ShadowSessionId ([string]$request.shadow_session_id) -Sequence $sequence -EventType 'component.result.accepted' -OccurredAt ([string]$result.occurred_at) -StageId $stageId -ComponentId $componentId -ResultStatus ([string]$result.result_status) -Artifact $artifact)
                $sequence++
                $resultIndex++
            }
            Add-WorkflowKernelEvent -EventLogPath $eventLogPath -Event (New-WorkflowKernelEvent -ShadowSessionId ([string]$request.shadow_session_id) -Sequence $sequence -EventType 'stage.completed' -OccurredAt $stageAt -StageId $stageId)
            $sequence++
        }

        $projection = Write-WorkflowKernelProjections -ShadowRoot $shadowRootFull -Request $request -ProjectRoot $projectRootFull
        if ([string]$projection.parity_status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code ([string]$projection.parity_code) -Message 'Shadow evidence was preserved, but legacy parity failed.' -Data ([pscustomobject][ordered]@{
                shadow_root = $shadowRootFull
                parity_report = (Join-Path $shadowRootFull 'parity-report.json')
            })
        }
        return New-WorkflowKernelResult -Success $true -Code 'shadow_parity_pass' -Message 'Direct shadow runtime matched the frozen legacy observation.' -Data ([pscustomobject][ordered]@{
            shadow_root = $shadowRootFull
            parity_report = (Join-Path $shadowRootFull 'parity-report.json')
            observation = (Join-Path $shadowRootFull 'shadow-observation.json')
        })
    }
    catch {
        $diagnostic = [string]$_.Exception.Message
        $code = $diagnostic
        if ([string]::IsNullOrWhiteSpace($code) -or $code -match '\s') {
            $code = 'workflow_kernel_unhandled_error'
        }
        return New-WorkflowKernelResult -Success $false -Code $code -Message 'Direct shadow runtime stopped before a false success.' -Data ([pscustomobject][ordered]@{
            diagnostic = $diagnostic
            exception_type = $_.Exception.GetType().FullName
            script_stack = [string]$_.ScriptStackTrace
        })
    }
}

function Invoke-WorkflowKernelProjectionRebuild {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ShadowRoot
    )

    try {
        $projectRootFull = Get-WorkflowKernelFullPath -Path $ProjectRoot
        $shadowRootFull = Get-WorkflowKernelFullPath -Path $ShadowRoot
        $allowedShadowRoot = Join-Path $projectRootFull 'state\checks'
        if (-not (Test-WorkflowKernelPathContained -Root $allowedShadowRoot -Candidate $shadowRootFull)) {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_root_outside_project' -Message 'M2 shadow output must stay under state/checks.'
        }
        $sessionPath = Join-Path $shadowRootFull 'kernel-session.json'
        $requestPath = Join-Path $shadowRootFull 'inputs\shadow-run-request.json'
        $session = Read-WorkflowKernelJson -Path $sessionPath -FailureCode 'shadow_session_read_failed'
        if ([string]$session.runtime_generation -ne 'kernel_v1_shadow' -or [bool]$session.runtime_switch_enabled) {
            throw 'shadow_session_contract_invalid'
        }
        $environmentPreflight = Invoke-TaogeEnvironmentPreflight `
            -ProjectRoot $projectRootFull `
            -AllowedRoot $allowedShadowRoot `
            -TargetRoot $shadowRootFull `
            -RelativePaths @(
                'artifact-projection.json',
                'event-projection.json',
                'run-state.json',
                'resume-summary.json',
                'shadow-observation.json',
                'parity-report.json'
            ) `
            -RequiredFreeBytes 1048576 `
            -RecommendedInstallationRootMaxChars 90 `
            -ClassicPathMaxChars 259 `
            -ProbeWrite
        if ([string]$environmentPreflight.status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code 'shadow_environment_preflight_failed' -Message 'Projection rebuild environment preflight failed.'
        }
        $request = Read-WorkflowKernelJson -Path $requestPath -FailureCode 'request_read_failed'
        $projection = Write-WorkflowKernelProjections -ShadowRoot $shadowRootFull -Request $request -ProjectRoot $projectRootFull
        if ([string]$projection.parity_status -ne 'pass') {
            return New-WorkflowKernelResult -Success $false -Code ([string]$projection.parity_code) -Message 'Projection rebuilt, but legacy parity failed.'
        }
        return New-WorkflowKernelResult -Success $true -Code 'projection_rebuild_pass' -Message 'State, resume, and parity projections were rebuilt from immutable evidence.'
    }
    catch {
        $diagnostic = [string]$_.Exception.Message
        $code = $diagnostic
        if ([string]::IsNullOrWhiteSpace($code) -or $code -match '\s') {
            $code = 'workflow_kernel_unhandled_error'
        }
        return New-WorkflowKernelResult -Success $false -Code $code -Message 'Projection rebuild stopped before a false success.' -Data ([pscustomobject][ordered]@{
            diagnostic = $diagnostic
            exception_type = $_.Exception.GetType().FullName
            script_stack = [string]$_.ScriptStackTrace
        })
    }
}
