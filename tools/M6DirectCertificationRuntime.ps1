Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R8H5SchemaRuntime.ps1')

function Initialize-M6DirectCertificationRuntime {
  param([Parameter(Mandatory=$true)][string]$ProjectRoot)
  $script:M6DirectProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
  $script:M6DirectChecksRoot = [System.IO.Path]::GetFullPath((Join-Path $script:M6DirectProjectRoot 'state/checks')).TrimEnd('\','/')
}

function Read-M6DirectJson {
  param([Parameter(Mandatory=$true)][string]$Path)
  Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-M6DirectSha256 {
  param([Parameter(Mandatory=$true)][string]$Path)
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-M6DirectTimestamp {
  param([AllowEmptyString()][string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '(Z|[+-]\d{2}:\d{2})$') { return $false }
  $parsed = [datetimeoffset]::MinValue
  [datetimeoffset]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Assert-M6DirectContained {
  param([Parameter(Mandatory=$true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  $prefix = $script:M6DirectChecksRoot + [System.IO.Path]::DirectorySeparatorChar
  if ($full -eq $script:M6DirectChecksRoot -or -not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'm6_direct_output_must_be_under_state_checks'
  }
  $full
}

function Get-M6DirectComponentMap {
  param([Parameter(Mandatory=$true)][object]$Catalog)
  $map = @{}
  foreach ($component in @($Catalog.components)) {
    $id = [string]$component.component_id
    if ([string]::IsNullOrWhiteSpace($id) -or $map.ContainsKey($id)) {
      throw 'direct_component_catalog_invalid'
    }
    $map[$id] = $component
  }
  $map
}

function Get-M6DirectRouteSequence {
  param([Parameter(Mandatory=$true)][object]$WorkflowIr)
  $routes = @($WorkflowIr.routes | Where-Object { [string]$_.route_id -eq 'direct' })
  if ($routes.Count -ne 1) { throw 'direct_route_missing' }
  $sequence = [Collections.Generic.List[object]]::new()
  foreach ($binding in @($routes[0].stage_bindings)) {
    if ([string]$binding.mode -eq 'skip') { continue }
    foreach ($componentId in @($binding.component_refs)) {
      $sequence.Add([pscustomobject][ordered]@{
        stage_id = [string]$binding.stage_id
        component_id = [string]$componentId
      })
    }
  }
  $sequence.ToArray()
}

function New-M6DirectCertificationRequest {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRevision,
    [Parameter(Mandatory=$true)][string]$SessionId,
    [Parameter(Mandatory=$true)][string]$OutputPath
  )
  $fixtureRoot = Join-Path $script:M6DirectProjectRoot 'examples/m6-direct-certification-fixtures'
  $catalogPath = Join-Path $fixtureRoot 'catalog.json'
  $sourcePath = Join-Path $fixtureRoot 'source-content.md'
  $finalHtmlPath = Join-Path $fixtureRoot 'expected-final-delivery.html'
  $workflowIr = Read-M6DirectJson (Join-Path $script:M6DirectProjectRoot 'routes/current-workflow-ir.json')
  $componentCatalog = Read-M6DirectJson (Join-Path $script:M6DirectProjectRoot 'routes/component-catalog.json')
  $fixture = Read-M6DirectJson $catalogPath
  if ([string]$fixture.suite_id -ne 'M6-DIRECT-CERTIFICATION-0.1' -or
      [string]$fixture.route_id -ne 'direct' -or
      [string]$fixture.runtime_generation -ne 'kernel_v1_current') {
    throw 'direct_fixture_catalog_invalid'
  }
  if ([string]$workflowIr.runtime_generation -ne 'kernel_v1_current' -or -not [bool]$workflowIr.runtime_switch_enabled) {
    throw 'direct_current_runtime_not_active'
  }
  foreach ($name in @('initialized_at','waiting_at','resumed_at','completed_at')) {
    if (-not (Test-M6DirectTimestamp ([string]$fixture.timestamps.$name))) {
      throw 'direct_fixture_timestamp_invalid'
    }
  }
  $routeSequence = @(Get-M6DirectRouteSequence $workflowIr)
  $expectations = @($fixture.component_expectations)
  if ($routeSequence.Count -ne 25 -or $expectations.Count -ne $routeSequence.Count) {
    throw 'direct_component_cardinality_mismatch'
  }
  $componentMap = Get-M6DirectComponentMap $componentCatalog
  $results = [Collections.Generic.List[object]]::new()
  for ($index=0; $index -lt $routeSequence.Count; $index++) {
    $expected = $expectations[$index]
    $routeItem = $routeSequence[$index]
    if ([string]$expected.stage_id -ne [string]$routeItem.stage_id -or
        [string]$expected.component_id -ne [string]$routeItem.component_id) {
      throw 'direct_component_sequence_mismatch'
    }
    if (-not $componentMap.ContainsKey([string]$expected.component_id)) {
      throw 'direct_component_not_registered'
    }
    $component = $componentMap[[string]$expected.component_id]
    if (@($component.allowed_result_statuses) -notcontains [string]$expected.result_status) {
      throw 'direct_result_status_not_allowed'
    }
    if ([string]$component.output_contract_ref -ne [string]$expected.output_contract_ref) {
      throw 'direct_output_contract_mismatch'
    }
    if (-not (Test-M6DirectTimestamp ([string]$expected.occurred_at))) {
      throw 'direct_result_timestamp_invalid'
    }
    $payloadKind = if ($null -ne $expected.PSObject.Properties['payload_kind']) { [string]$expected.payload_kind } else { 'json_inline' }
    $result = [ordered]@{
      stage_id = [string]$expected.stage_id
      component_id = [string]$expected.component_id
      component_kind = [string]$component.component_kind
      artifact_id = ('M6-DIRECT-{0:D2}-{1}' -f ($index + 1),([string]$expected.component_id).ToUpperInvariant())
      artifact_revision = 1
      result_status = [string]$expected.result_status
      output_contract_ref = [string]$expected.output_contract_ref
      occurred_at = [string]$expected.occurred_at
      validation_receipt = [ordered]@{
        validation_status = 'pass'
        contract_ref = [string]$expected.output_contract_ref
        validator_id = 'm6-direct-fixture-validator-v0.1'
      }
      fixture_adapter_id = 'm6-direct-fixture-adapter-v0.1'
      payload_kind = $payloadKind
    }
    if ($payloadKind -eq 'file_ref') {
      $result.payload_relative_path = 'expected-final-delivery.html'
    } else {
      $result.payload = [ordered]@{
        fixture_case_id = [string]$fixture.case_id
        component_id = [string]$expected.component_id
        external_side_effect_performed = $false
      }
    }
    $results.Add([pscustomobject]$result)
  }
  $request = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/m6/direct-certification-request/v0.1'
    schema_version = '0.1'
    certification_case_id = [string]$fixture.case_id
    session_id = $SessionId
    route_id = 'direct'
    runtime_generation = 'kernel_v1_current'
    source_revision = $SourceRevision
    initialized_at = [string]$fixture.timestamps.initialized_at
    waiting_at = [string]$fixture.timestamps.waiting_at
    resumed_at = [string]$fixture.timestamps.resumed_at
    completed_at = [string]$fixture.timestamps.completed_at
    input = [pscustomobject][ordered]@{
      input_id = 'M6-DIRECT-INPUT-001'
      relative_path = 'source-content.md'
      sha256 = Get-M6DirectSha256 $sourcePath
    }
    component_results = $results.ToArray()
  }
  $schema = Join-Path $script:M6DirectProjectRoot 'templates/schema/m6/direct-certification-request.v0.1.schema.json'
  $schemaErrors = @(Test-R8H5JsonSchemaValue $schema $request)
  if ($schemaErrors.Count -gt 0) {
    throw "direct_request_schema_invalid:$([string]::Join(',',@($schemaErrors)))"
  }
  $target = Assert-M6DirectContained $OutputPath
  Write-TaogeUtf8NoBomJson -Path $target -Value $request -Depth 30
  [pscustomobject][ordered]@{
    request = $request
    request_path = $target
    fixture_root = $fixtureRoot
    source_path = $sourcePath
    final_html_path = $finalHtmlPath
    expected = $fixture.expected
    negative_cases = @($fixture.negative_cases)
  }
}

function Test-M6DirectCertificationRequest {
  param(
    [Parameter(Mandatory=$true)][object]$Request,
    [Parameter(Mandatory=$true)][string]$FixtureRoot
  )
  $schema = Join-Path $script:M6DirectProjectRoot 'templates/schema/m6/direct-certification-request.v0.1.schema.json'
  $schemaErrors = @(Test-R8H5JsonSchemaValue $schema $Request)
  if ($schemaErrors.Count -gt 0) { throw 'direct_request_schema_invalid' }
  $workflowIr = Read-M6DirectJson (Join-Path $script:M6DirectProjectRoot 'routes/current-workflow-ir.json')
  $componentCatalog = Read-M6DirectJson (Join-Path $script:M6DirectProjectRoot 'routes/component-catalog.json')
  $sequence = @(Get-M6DirectRouteSequence $workflowIr)
  $results = @($Request.component_results)
  if ($sequence.Count -ne 25 -or $results.Count -ne $sequence.Count) {
    throw 'direct_component_cardinality_mismatch'
  }
  $componentMap = Get-M6DirectComponentMap $componentCatalog
  for ($index=0; $index -lt $sequence.Count; $index++) {
    $expected = $sequence[$index]
    $result = $results[$index]
    if ([string]$result.stage_id -ne [string]$expected.stage_id -or
        [string]$result.component_id -ne [string]$expected.component_id) {
      throw 'direct_component_sequence_mismatch'
    }
    if (-not $componentMap.ContainsKey([string]$result.component_id)) { throw 'direct_component_not_registered' }
    $component = $componentMap[[string]$result.component_id]
    if ([string]$result.component_kind -ne [string]$component.component_kind) { throw 'direct_component_kind_mismatch' }
    if (@($component.allowed_result_statuses) -notcontains [string]$result.result_status) { throw 'direct_result_status_not_allowed' }
    if ([string]$result.output_contract_ref -ne [string]$component.output_contract_ref -or
        [string]$result.validation_receipt.contract_ref -ne [string]$component.output_contract_ref) {
      throw 'direct_output_contract_mismatch'
    }
    if ([string]$result.validation_receipt.validation_status -ne 'pass' -or
        [string]$result.validation_receipt.validator_id -ne 'm6-direct-fixture-validator-v0.1' -or
        [string]$result.fixture_adapter_id -ne 'm6-direct-fixture-adapter-v0.1') {
      throw 'direct_validation_receipt_invalid'
    }
    if (-not (Test-M6DirectTimestamp ([string]$result.occurred_at))) { throw 'direct_result_timestamp_invalid' }
  }
  $sourcePath = Join-Path $FixtureRoot ([string]$Request.input.relative_path)
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
      [string]$Request.input.sha256 -ne (Get-M6DirectSha256 $sourcePath)) {
    throw 'direct_input_digest_mismatch'
  }
  $fileResults = @($results | Where-Object { [string]$_.payload_kind -eq 'file_ref' })
  if ($fileResults.Count -ne 1 -or [string]$fileResults[0].component_id -ne 'final_delivery_render_h7') {
    throw 'direct_file_payload_contract_invalid'
  }
  $filePath = Join-Path $FixtureRoot ([string]$fileResults[0].payload_relative_path)
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { throw 'direct_file_payload_missing' }
  $true
}

function Test-M6DirectSessionBinding {
  param([Parameter(Mandatory=$true)][string]$SessionRoot,[Parameter(Mandatory=$true)][string]$SessionId)
  $bindingPath = Join-Path $SessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json'
  $markerPath = Join-Path $SessionRoot 'intermediate/workflow-kernel/session-runtime-binding.sha256'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf) -or
      -not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    throw 'direct_session_binding_missing'
  }
  $binding = Read-M6DirectJson $bindingPath
  $marker = (Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8).Trim().ToLowerInvariant()
  if ([string]$binding.session_id -ne $SessionId -or
      [string]$binding.route_id -ne 'direct' -or
      [string]$binding.runtime_generation -ne 'kernel_v1_current' -or
      [string]$binding.runtime_entry_ref -ne 'tools/invoke-workflow-session-entry.ps1' -or
      $null -ne $binding.PSObject.Properties['compatibility_catalog_sha256'] -or
      $marker -ne (Get-M6DirectSha256 $bindingPath)) {
    throw 'direct_session_binding_invalid'
  }
  $binding
}

function Add-M6DirectEvent {
  param([string]$Path,[int]$Sequence,[string]$Type,[string]$OccurredAt,[string]$StageId='',[string]$ComponentId='',[object]$Artifact=$null,[string]$StopReason='')
  $event = [ordered]@{
    sequence = $Sequence
    event_id = ('M6-DIRECT-EVT-{0:D3}' -f $Sequence)
    event_type = $Type
    occurred_at = $OccurredAt
  }
  if (-not [string]::IsNullOrWhiteSpace($StageId)) { $event.stage_id = $StageId }
  if (-not [string]::IsNullOrWhiteSpace($ComponentId)) { $event.component_id = $ComponentId }
  if ($null -ne $Artifact) { $event.artifact = $Artifact }
  if (-not [string]::IsNullOrWhiteSpace($StopReason)) { $event.stop_reason = $StopReason }
  Add-TaogeUtf8NoBomLine -Path $Path -Line (([pscustomobject]$event | ConvertTo-Json -Depth 20 -Compress))
}

function Write-M6DirectArtifact {
  param([string]$ExecutionRoot,[string]$FixtureRoot,[object]$Result)
  $extension = if ([string]$Result.payload_kind -eq 'file_ref') { '.html' } else { '.json' }
  $relative = ('artifacts/{0}-r{1}{2}' -f [string]$Result.artifact_id,[int]$Result.artifact_revision,$extension)
  $path = Join-Path $ExecutionRoot ($relative -replace '/','\')
  if ([string]$Result.payload_kind -eq 'file_ref') {
    $source = Join-Path $FixtureRoot ([string]$Result.payload_relative_path)
    $directory = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [IO.File]::WriteAllBytes($path,[IO.File]::ReadAllBytes($source))
  } else {
    Write-TaogeUtf8NoBomJson -Path $path -Value $Result.payload -Depth 20
  }
  [pscustomobject][ordered]@{
    artifact_id = [string]$Result.artifact_id
    artifact_revision = [int]$Result.artifact_revision
    artifact_type = [string]$Result.component_id
    relative_path = $relative
    sha256 = 'sha256:' + (Get-M6DirectSha256 $path)
    producer_component_id = [string]$Result.component_id
    producer_writer_id = 'm6-direct-certification-runtime-v0.1'
  }
}

function Read-M6DirectEvents {
  param([Parameter(Mandatory=$true)][string]$EventPath)
  if (-not (Test-Path -LiteralPath $EventPath -PathType Leaf)) { return @() }
  @(
    Get-Content -LiteralPath $EventPath -Encoding UTF8 |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_ | ConvertFrom-Json }
  )
}

function Write-M6DirectProjections {
  param([string]$ExecutionRoot,[string]$TargetRoot='')
  $eventPath = Join-Path $ExecutionRoot 'events.jsonl'
  $events = @(Read-M6DirectEvents $eventPath)
  for ($index=0; $index -lt $events.Count; $index++) {
    if ([int]$events[$index].sequence -ne ($index + 1)) { throw 'direct_event_sequence_invalid' }
  }
  $artifacts = @(
    $events |
      Where-Object { $null -ne $_.PSObject.Properties['artifact'] } |
      ForEach-Object { $_.artifact }
  )
  $completed = @($events | Where-Object { [string]$_.event_type -eq 'route.completed' }).Count -eq 1
  $waiting = @($events | Where-Object { [string]$_.event_type -eq 'run.waiting' } | Select-Object -Last 1)
  $state = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/direct-certification-state/v0.1'
    route_id = 'direct'
    runtime_generation = 'kernel_v1_current'
    status = if ($completed) { 'completed' } else { 'waiting_human' }
    stop_reason = if ($completed) { 'completed' } else { 'waiting_human' }
    current_stage = 'final_decision'
    event_count = $events.Count
    artifact_count = $artifacts.Count
    next_component_id = if ($completed) { '' } else { 'final_human_decision_gate' }
  }
  $resume = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/direct-certification-resume/v0.1'
    status = if ($completed) { 'completed' } else { 'resume_ready' }
    stop_reason = [string]$state.stop_reason
    next_stage_id = if ($completed) { '' } else { 'final_decision' }
    next_component_id = [string]$state.next_component_id
    event_count = $events.Count
  }
  $eventProjection = @($events | ForEach-Object {
    [pscustomobject][ordered]@{
      sequence = [int]$_.sequence
      event_id = [string]$_.event_id
      event_type = [string]$_.event_type
    }
  })
  $root = if ([string]::IsNullOrWhiteSpace($TargetRoot)) { $ExecutionRoot } else { $TargetRoot }
  Write-TaogeUtf8NoBomJson -Path (Join-Path $root 'artifact-projection.json') -Value $artifacts -Depth 20
  Write-TaogeUtf8NoBomJson -Path (Join-Path $root 'event-projection.json') -Value $eventProjection -Depth 20
  Write-TaogeUtf8NoBomJson -Path (Join-Path $root 'run-state.json') -Value $state -Depth 20
  Write-TaogeUtf8NoBomJson -Path (Join-Path $root 'resume-summary.json') -Value $resume -Depth 20
  [pscustomobject][ordered]@{events=$events;artifacts=$artifacts;state=$state;resume=$resume}
}

function Write-M6DirectWriterLedger {
  param([string]$ExecutionRoot)
  $relativePaths = @(
    Get-ChildItem -LiteralPath $ExecutionRoot -File -Recurse -Force |
      ForEach-Object { $_.FullName.Substring($ExecutionRoot.Length).TrimStart('\').Replace('\','/') } |
      Where-Object { $_ -ne 'writer-ledger.json' } |
      Sort-Object
  )
  $ledger = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/direct-certification-writer-ledger/v0.1'
    writer_id = 'm6-direct-certification-runtime-v0.1'
    allowed_relative_paths = @($relativePaths + 'writer-ledger.json' | Sort-Object)
  }
  Write-TaogeUtf8NoBomJson -Path (Join-Path $ExecutionRoot 'writer-ledger.json') -Value $ledger -Depth 20
  $ledger
}

function Test-M6DirectRegisteredWriters {
  param([string]$ExecutionRoot)
  $ledgerPath = Join-Path $ExecutionRoot 'writer-ledger.json'
  if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
    return [pscustomobject]@{result='fail';fingerprint='direct_writer_ledger_missing';unexpected=@()}
  }
  $ledger = Read-M6DirectJson $ledgerPath
  $actual = @(
    Get-ChildItem -LiteralPath $ExecutionRoot -File -Recurse -Force |
      ForEach-Object { $_.FullName.Substring($ExecutionRoot.Length).TrimStart('\').Replace('\','/') } |
      Sort-Object
  )
  $expected = @($ledger.allowed_relative_paths | Sort-Object)
  $unexpected = @($actual | Where-Object { $expected -notcontains $_ })
  $missing = @($expected | Where-Object { $actual -notcontains $_ })
  if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
    return [pscustomobject]@{result='fail';fingerprint='direct_unregistered_writer_detected';unexpected=$unexpected;missing=$missing}
  }
  [pscustomobject]@{result='pass';fingerprint='';unexpected=@();missing=@()}
}

function Invoke-M6DirectAdvance {
  param([string]$SessionRoot,[string]$RequestPath,[string]$FixtureRoot)
  $request = Read-M6DirectJson $RequestPath
  [void](Test-M6DirectCertificationRequest -Request $request -FixtureRoot $FixtureRoot)
  [void](Test-M6DirectSessionBinding -SessionRoot $SessionRoot -SessionId ([string]$request.session_id))
  $executionRoot = Assert-M6DirectContained (Join-Path $SessionRoot 'intermediate/workflow-kernel/direct-certification')
  if (Test-Path -LiteralPath (Join-Path $executionRoot 'run-state.json')) {
    $state = Read-M6DirectJson (Join-Path $executionRoot 'run-state.json')
    if ([string]$state.status -eq 'waiting_human') {
      return [pscustomobject]@{result='reused';status='waiting_human';execution_root=$executionRoot}
    }
    throw 'direct_advance_existing_state_invalid'
  }
  if (Test-Path -LiteralPath $executionRoot) {
    if (@(Get-ChildItem -LiteralPath $executionRoot -Force).Count -gt 0) { throw 'direct_execution_root_not_empty' }
  } else {
    New-Item -ItemType Directory -Path $executionRoot -Force | Out-Null
  }
  $inputs = Join-Path $executionRoot 'inputs'
  New-Item -ItemType Directory -Path $inputs -Force | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $inputs 'direct-certification-request.json'),[IO.File]::ReadAllBytes($RequestPath))
  [IO.File]::WriteAllBytes((Join-Path $inputs 'source-content.md'),[IO.File]::ReadAllBytes((Join-Path $FixtureRoot 'source-content.md')))
  $eventPath = Join-Path $executionRoot 'events.jsonl'
  $sequence = 1
  Add-M6DirectEvent $eventPath $sequence 'route.started' ([string]$request.initialized_at);$sequence++
  $results = @($request.component_results)
  $index = 0
  $workflowIr = Read-M6DirectJson (Join-Path $script:M6DirectProjectRoot 'routes/current-workflow-ir.json')
  $direct = @($workflowIr.routes | Where-Object { [string]$_.route_id -eq 'direct' })[0]
  foreach ($binding in @($direct.stage_bindings)) {
    $stage = [string]$binding.stage_id
    if ($stage -eq 'final_decision') {
      Add-M6DirectEvent $eventPath $sequence 'run.waiting' ([string]$request.waiting_at) $stage 'final_human_decision_gate' $null 'waiting_human'
      $sequence++
      break
    }
    if ([string]$binding.mode -eq 'skip') {
      Add-M6DirectEvent $eventPath $sequence 'stage.skipped' ([string]$request.initialized_at) $stage
      $sequence++
      continue
    }
    Add-M6DirectEvent $eventPath $sequence 'stage.started' ([string]$results[$index].occurred_at) $stage;$sequence++
    foreach ($componentId in @($binding.component_refs)) {
      $result = $results[$index]
      if ([string]$result.component_id -ne [string]$componentId -or [string]$result.stage_id -ne $stage) {
        throw 'direct_component_sequence_mismatch'
      }
      $artifact = Write-M6DirectArtifact $executionRoot $FixtureRoot $result
      Add-M6DirectEvent $eventPath $sequence 'component.result.accepted' ([string]$result.occurred_at) $stage ([string]$result.component_id) $artifact
      $sequence++;$index++
    }
    Add-M6DirectEvent $eventPath $sequence 'stage.completed' ([string]$results[$index-1].occurred_at) $stage;$sequence++
  }
  $projection = Write-M6DirectProjections $executionRoot
  [void](Write-M6DirectWriterLedger $executionRoot)
  [pscustomobject]@{result='advanced';status=[string]$projection.state.status;execution_root=$executionRoot;event_count=@($projection.events).Count;artifact_count=@($projection.artifacts).Count}
}

function Invoke-M6DirectResume {
  param([string]$SessionRoot,[string]$RequestPath,[string]$FixtureRoot)
  $request = Read-M6DirectJson $RequestPath
  [void](Test-M6DirectCertificationRequest -Request $request -FixtureRoot $FixtureRoot)
  [void](Test-M6DirectSessionBinding -SessionRoot $SessionRoot -SessionId ([string]$request.session_id))
  $executionRoot = Assert-M6DirectContained (Join-Path $SessionRoot 'intermediate/workflow-kernel/direct-certification')
  $statePath = Join-Path $executionRoot 'run-state.json'
  $state = Read-M6DirectJson $statePath
  if ([string]$state.status -eq 'completed') {
    return [pscustomobject]@{result='reused';status='completed';execution_root=$executionRoot;event_count=[int]$state.event_count;artifact_count=[int]$state.artifact_count}
  }
  if ([string]$state.status -ne 'waiting_human' -or [string]$state.next_component_id -ne 'final_human_decision_gate') {
    throw 'direct_resume_state_invalid'
  }
  $eventPath = Join-Path $executionRoot 'events.jsonl'
  $events = @(Read-M6DirectEvents $eventPath)
  $sequence = $events.Count + 1
  $finalResults = @($request.component_results | Where-Object { [string]$_.stage_id -eq 'final_decision' })
  if ($finalResults.Count -ne 2) { throw 'direct_final_result_count_invalid' }
  Add-M6DirectEvent $eventPath $sequence 'stage.started' ([string]$request.resumed_at) 'final_decision';$sequence++
  foreach ($result in $finalResults) {
    $artifact = Write-M6DirectArtifact $executionRoot $FixtureRoot $result
    Add-M6DirectEvent $eventPath $sequence 'component.result.accepted' ([string]$result.occurred_at) 'final_decision' ([string]$result.component_id) $artifact
    $sequence++
  }
  Add-M6DirectEvent $eventPath $sequence 'stage.completed' ([string]$finalResults[-1].occurred_at) 'final_decision';$sequence++
  Add-M6DirectEvent $eventPath $sequence 'route.completed' ([string]$request.completed_at)
  $projection = Write-M6DirectProjections $executionRoot
  [void](Write-M6DirectWriterLedger $executionRoot)
  [pscustomobject]@{result='resumed';status=[string]$projection.state.status;execution_root=$executionRoot;event_count=@($projection.events).Count;artifact_count=@($projection.artifacts).Count}
}

function Invoke-M6DirectRebuild {
  param([string]$SessionRoot)
  $executionRoot = Assert-M6DirectContained (Join-Path $SessionRoot 'intermediate/workflow-kernel/direct-certification')
  $rebuildRoot = Assert-M6DirectContained (Join-Path $SessionRoot 'intermediate/workflow-kernel/direct-certification-rebuild')
  if (Test-Path -LiteralPath $rebuildRoot) {
    $resolved = Assert-M6DirectContained $rebuildRoot
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
  New-Item -ItemType Directory -Path $rebuildRoot -Force | Out-Null
  [void](Write-M6DirectProjections -ExecutionRoot $executionRoot -TargetRoot $rebuildRoot)
  $names = @('artifact-projection.json','event-projection.json','run-state.json','resume-summary.json')
  $mismatches = @($names | Where-Object { (Get-M6DirectSha256 (Join-Path $executionRoot $_)) -ne (Get-M6DirectSha256 (Join-Path $rebuildRoot $_)) })
  if ($mismatches.Count -gt 0) { throw 'direct_projection_rebuild_mismatch' }
  [pscustomobject]@{result='pass_byte_stable';rebuild_root=$rebuildRoot;file_count=$names.Count}
}
