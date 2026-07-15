Set-StrictMode -Version 2.0

if (-not (Get-Command Test-P0PlanContract -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
}
if (-not (Get-Command Write-P0EvidenceEvent -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
}

function New-P0V2Result {
  param([int]$ExitCode, [string[]]$Lines)
  return [pscustomobject]@{ ExitCode = $ExitCode; Lines = [object[]]$Lines }
}

function Get-P0V2Hash {
  param([string]$Path)
  return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-P0V2TextHash {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant()) }
  finally { $sha.Dispose() }
}

function ConvertTo-P0V2JsonText {
  param([object]$Value)
  return ($Value | ConvertTo-Json -Depth 50).TrimEnd("`r", "`n") + "`n"
}

function Write-P0V2AtomicText {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $temporary = "$Path.tmp-$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($temporary, $Text, [System.Text.UTF8Encoding]::new($false))
  try {
    if (Test-Path -LiteralPath $Path) {
      try { [System.IO.File]::Replace($temporary, $Path, $null) }
      catch { Move-Item -LiteralPath $temporary -Destination $Path -Force }
    } else {
      [System.IO.File]::Move($temporary, $Path)
    }
  } finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
  }
}

function Get-P0V2Events {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $events = [System.Collections.Generic.List[object]]::new()
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $events.Add(($line | ConvertFrom-Json))
  }
  return [object[]]$events.ToArray()
}

function Get-P0V2Step {
  param([object]$Plan, [string]$Operation, [hashtable]$Succeeded)
  $matches = @($Plan.steps | Where-Object { (Test-P0HasProperty $_ 'operation') -and $_.operation -eq $Operation })
  if ($matches.Count -eq 0) { return $null }
  if ($null -ne $Succeeded) {
    $pending = @($matches | Where-Object { -not $Succeeded.ContainsKey([string]$_.step_id) })
    $readyPending = @($pending | Where-Object {
      $ready = $true
      foreach ($requiredStep in @($_.requires_step_ids)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$requiredStep) -and -not $Succeeded.ContainsKey([string]$requiredStep)) { $ready = $false; break }
      }
      $ready
    })
    if ($readyPending.Count) { return $readyPending[0] }
    if ($pending.Count) { return $pending[0] }
  }
  return $matches[-1]
}

function Get-P0V2SucceededMap {
  param([object[]]$Events)
  $map = @{}
  foreach ($event in @($Events)) {
    if ($event.state_after -eq 'succeeded') { $map[[string]$event.step_id] = $event }
  }
  return $map
}

function Test-P0V2PlanEvents {
  param([object]$Plan, [object[]]$Events)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($validationError in (Test-P0PlanContract $Plan)) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0EventLogContract $Events)) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $steps = @{}
  foreach ($step in @($Plan.steps)) { $steps[[string]$step.step_id] = $step }
  foreach ($event in @($Events)) {
    if (-not $steps.ContainsKey([string]$event.step_id)) { $errors.Add("event_step_unknown:$($event.step_id)"); continue }
    if ($event.state_after -eq 'succeeded') {
      $expectedSources = switch ([string]$steps[[string]$event.step_id].step_kind) {
        'deterministic_tool' { @('runner','reconciler') }
        'agent_required' { @('agent_recorder') }
        'human_gate' { @('human_recorder') }
        'external_side_effect' { @('external_recorder','reconciler') }
      }
      if ($event.event_source -notin $expectedSources) { $errors.Add("event_source_step_kind_mismatch:$($event.step_id)") }
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0V2Prerequisites {
  param([object]$Step, [hashtable]$Succeeded)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = if (Test-P0HasProperty $Step 'requires_step_ids') { @($Step.requires_step_ids) } else { @() }
  foreach ($stepId in $required) {
    if (-not $Succeeded.ContainsKey([string]$stepId)) { $errors.Add("prerequisite_not_succeeded:$stepId") }
  }
  return [object[]]$errors.ToArray()
}

function Get-P0V2PrivacyClass {
  param([string]$SessionId)
  if ($SessionId -match '(?i)fixture|sample') { return 'public_sample' }
  return 'local_private'
}

function Add-P0V2SucceededEvent {
  param(
    [string]$EventPath,
    [object[]]$Events,
    [object]$Plan,
    [object]$Step,
    [string]$InputDigest,
    [string]$PayloadDigest,
    [string[]]$OutputArtifactIds,
    [string]$ResultCode,
    [string]$SafeSummary
  )
  $safeSession = ([string]$Plan.session_id -replace '[^A-Za-z0-9_-]','-')
  $safeStep = ([string]$Step.step_id -replace '[^A-Za-z0-9_-]','-')
  $shortDigest = $InputDigest.Substring([Math]::Max(0, $InputDigest.Length - 12))
  $write = Write-P0EvidenceEvent -EventPath $EventPath -Plan $Plan -StepId ([string]$Step.step_id) -EventType 'step.succeeded.v1' -EventSource 'runner' -StateBefore 'running' -StateAfter 'succeeded' -PayloadDigest $PayloadDigest -IdempotencyKey "$($Plan.session_id):$($Step.step_id):$InputDigest" -ExpectedLastSequenceNo @($Events).Count -ResultCode $ResultCode -SafeSummary $SafeSummary -OutputArtifactIds $OutputArtifactIds -InputDigest $InputDigest -ExecutionAttemptId "ATT-$safeSession-$safeStep-1" -CorrelationId "CMD-$safeSession-$safeStep-$shortDigest"
  if ($write.ExitCode -ne 0) { throw ('event_append_failed:' + $write.ResultCode + ':' + [string]::Join(';', @($write.Errors))) }
  return $write.Event
}

function Resolve-P0V2SessionReference {
  param([string]$Session, [string]$RelativePath, [string]$HtmlBasePath)
  if (-not (Test-P0RelativePath $RelativePath)) { throw "unsafe_session_reference:$RelativePath" }
  $sessionRoot = [System.IO.Path]::GetFullPath($Session).TrimEnd('\')
  $full = [System.IO.Path]::GetFullPath((Join-Path $sessionRoot $RelativePath))
  if ($full -ne $sessionRoot -and -not $full.StartsWith($sessionRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "session_reference_escape:$RelativePath" }
  $base = [System.IO.Path]::GetFullPath($HtmlBasePath).TrimEnd('\') + '\'
  $baseUri = [uri]$base
  $targetUri = [uri]$full
  $htmlPath = [uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
  return [pscustomobject]@{ FullPath = $full; HtmlPath = $htmlPath }
}

function Test-P0V2MaterializedReferences {
  param([object]$RenderInput, [string]$Session)
  $errors = [System.Collections.Generic.List[string]]::new()
  $visualCards = if ([string]$RenderInput.schema_version -in @('typed_components_v0.4','typed_components_v0.5')) { @($RenderInput.visual_insert_cards) } else { @($RenderInput.pip_cards) }
  foreach ($card in @($RenderInput.cover_cards) + $visualCards) {
    if ($card.asset_status -notin @('generated','reused_verified')) { continue }
    foreach ($pair in @(@('relative_path','asset'), @('sidecar_path','sidecar'))) {
      try {
        $reference = Resolve-P0V2SessionReference $Session ([string]$card.($pair[0])) (Join-Path $Session 'deliverables')
        if (-not (Test-Path -LiteralPath $reference.FullPath)) { $errors.Add("materialized_$($pair[1])_missing:$($card.card_id)") }
      } catch { $errors.Add("materialized_$($pair[1])_path_invalid:$($card.card_id)") }
    }
    try {
      $assetReference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) (Join-Path $Session 'deliverables')
      if ((Test-Path -LiteralPath $assetReference.FullPath) -and (Get-P0V2Hash $assetReference.FullPath) -ne [string]$card.sha256) { $errors.Add("materialized_asset_sha256_mismatch:$($card.card_id)") }
    } catch { }
    if ([string]$RenderInput.schema_version -in @('typed_components_v0.3','typed_components_v0.4','typed_components_v0.5') -and $card.card_type -in @('picture_in_picture','visual_insert')) {
      foreach ($field in @('prompt_path','generation_record_path')) {
        try {
          $traceReference = Resolve-P0V2SessionReference $Session ([string]$card.$field) (Join-Path $Session 'deliverables')
          if (-not (Test-Path -LiteralPath $traceReference.FullPath)) { $errors.Add("materialized_pip_trace_missing:$($card.card_id):$field") }
        } catch { $errors.Add("materialized_pip_trace_path_invalid:$($card.card_id):$field") }
      }
    }
    if ([string]$RenderInput.schema_version -in @('typed_components_v0.4','typed_components_v0.5') -and $card.card_type -eq 'cover') {
      foreach ($pair in @(@('preview_path','cover_preview'),@('visual_review_record_path','cover_visual_review'))) {
        try {
          $reference = Resolve-P0V2SessionReference $Session ([string]$card.($pair[0])) (Join-Path $Session 'deliverables')
          if (-not (Test-Path -LiteralPath $reference.FullPath)) { $errors.Add("materialized_$($pair[1])_missing:$($card.card_id)") }
          elseif ($pair[0] -eq 'preview_path' -and (Get-P0V2Hash $reference.FullPath) -ne [string]$card.preview_sha256) { $errors.Add("materialized_cover_preview_sha256_mismatch:$($card.card_id)") }
        } catch { $errors.Add("materialized_$($pair[1])_path_invalid:$($card.card_id)") }
      }
      try {
        $reviewRef = Resolve-P0V2SessionReference $Session ([string]$card.visual_review_record_path) (Join-Path $Session 'deliverables')
        if (Test-Path -LiteralPath $reviewRef.FullPath) {
          $review = Read-P0JsonFile $reviewRef.FullPath
          if ([string]$review.output_sha256 -ne [string]$card.sha256 -or [string]$review.preview_sha256 -ne [string]$card.preview_sha256 -or [string]$review.visual_review_status -ne [string]$card.visual_review_status -or [string]$review.reviewer_type -ne [string]$card.reviewer_type) { $errors.Add("materialized_cover_review_binding_mismatch:$($card.card_id)") }
        }
      } catch { $errors.Add("materialized_cover_review_parse_failed:$($card.card_id)") }
    }
  }
  foreach ($card in @($RenderInput.trace_cards)) {
    if ($card.materialization_status -ne 'materialized') { continue }
    try {
      $reference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) (Join-Path $Session 'deliverables')
      if (-not (Test-Path -LiteralPath $reference.FullPath)) { $errors.Add("trace_artifact_missing:$($card.card_id)"); continue }
      if ((Test-P0HasProperty $card 'sha256') -and (Get-P0V2Hash $reference.FullPath) -ne [string]$card.sha256) { $errors.Add("trace_artifact_sha256_mismatch:$($card.card_id)") }
    } catch { $errors.Add("trace_artifact_path_invalid:$($card.card_id)") }
  }
  return [object[]]$errors.ToArray()
}

function Get-P0V2DeliveryReadiness {
  param([object]$RenderInput)
  $blockers = [System.Collections.Generic.List[string]]::new()
  $actions = [System.Collections.Generic.List[string]]::new()
  $warnings = [System.Collections.Generic.List[string]]::new()
  if ([string]$RenderInput.schema_version -eq 'typed_components_v0.3') {
    foreach ($warning in @($RenderInput.warning_items | Where-Object { $_.resolution_status -ne 'resolved' })) {
      if ($warning.severity -eq 'blocking') { $blockers.Add([string]$warning.warning_code) }
      else { $warnings.Add([string]$warning.warning_code) }
    }
  } else {
    foreach ($code in @($RenderInput.production_status.warning_codes)) { if (-not [string]::IsNullOrWhiteSpace([string]$code)) { $warnings.Add([string]$code) } }
  }
  if ([string]::IsNullOrWhiteSpace([string]$RenderInput.script_card.final_text)) { $blockers.Add('final_script_missing') }
  if (@($RenderInput.platform_cards).Count -eq 0) { $blockers.Add('target_platform_missing') }
  if ($RenderInput.production_status.overall_quality_status -eq 'fail') { $blockers.Add('overall_quality_failed') }
  if ($RenderInput.production_status.overall_quality_status -eq 'not_run') { $actions.Add('overall_quality_not_run') }
  if ($RenderInput.production_status.cover_quality_status -eq 'fail') { $blockers.Add('cover_quality_failed') }
  if (@($RenderInput.cover_cards).Count -gt 0 -and $RenderInput.production_status.cover_quality_status -eq 'not_run') { $actions.Add('cover_quality_not_run') }
  foreach ($card in @($RenderInput.cover_cards) + @($RenderInput.pip_cards) + @($RenderInput.platform_cards)) {
    if ($card.status -eq 'blocked') { $blockers.Add("card_blocked:$($card.card_id)") }
    if ($card.status -eq 'needs_action') { $actions.Add("card_needs_action:$($card.card_id)") }
    if ($card.status -eq 'ready_with_warnings' -and [string]$RenderInput.schema_version -ne 'typed_components_v0.3') { $warnings.Add("card_warning:$($card.card_id)") }
    if ((Test-P0HasProperty $card 'asset_status') -and $card.asset_status -eq 'rejected' -and $card.status -ne 'trace_only') { $blockers.Add("rejected_asset_in_delivery:$($card.card_id)") }
    if ((Test-P0HasProperty $card 'asset_status') -and $card.asset_status -in @('pending_external','generation_failed','manual_required')) {
      if ($card.status -eq 'ready_with_warnings' -and [string]$RenderInput.schema_version -ne 'typed_components_v0.3') { $warnings.Add("asset_pending_non_blocking:$($card.card_id)") } else { $actions.Add("asset_action_required:$($card.card_id)") }
    }
  }
  $readiness = if ($blockers.Count) { 'blocked' } elseif ($actions.Count) { 'needs_action' } elseif ($warnings.Count) { 'ready_with_warnings' } else { 'ready' }
  return [pscustomobject]@{
    delivery_readiness = $readiness
    blocker_codes = [object[]]@($blockers | Sort-Object -Unique)
    action_codes = [object[]]@($actions | Sort-Object -Unique)
    warning_codes = [object[]]@($warnings | Sort-Object -Unique)
  }
}

function Encode-P0V2Html {
  param([object]$Value)
  return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-P0V2TraceId {
  param([object]$RenderInput, [string]$ArtifactType)
  $card = @($RenderInput.trace_cards | Where-Object { $_.artifact_type -eq $ArtifactType }) | Select-Object -First 1
  if ($null -eq $card) { return 'not_applicable' }
  return [string]$card.artifact_id
}

function Convert-P0V2CoverSections {
  param([object]$RenderInput, [string]$Session, [string]$HtmlBasePath)
  $strategy = [System.Collections.Generic.List[string]]::new()
  $ready = [System.Collections.Generic.List[string]]::new()
  $background = [System.Collections.Generic.List[string]]::new()
  $prompt = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($RenderInput.cover_cards | Sort-Object display_order)) {
    $strategy.Add(('<article class="item" id="{0}"><span class="label">{1}</span><strong>{2}</strong><p>{3}</p></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.platform), (Encode-P0V2Html $card.cover_role), (Encode-P0V2Html $card.usage_note)))
    if ($card.asset_status -in @('generated','reused_verified')) {
      $reference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBasePath
      $alt = if ((Test-P0HasProperty $card 'title_text') -and -not [string]::IsNullOrWhiteSpace([string]$card.title_text)) { [string]$card.title_text } else { [string]$card.usage_note }
      $assetHtml = '<article class="item" id="{0}-asset"><div class="asset-status-badge">{1}</div><img src="{2}" alt="{3}"><p>{4}</p><a href="{2}" download>下载图片</a></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.asset_status), (Encode-P0V2Html $reference.HtmlPath), (Encode-P0V2Html $alt), (Encode-P0V2Html $card.usage_note)
      if ($card.cover_role -eq 'background') { $background.Add($assetHtml) } else { $ready.Add($assetHtml) }
    } else {
      $promptText = if (Test-P0HasProperty $card 'prompt_text') { [string]$card.prompt_text } else { '需要人工处理，未提供自动生成提示词。' }
      $prompt.Add(('<article class="item pending-card" id="{0}-prompt"><div class="asset-status-badge">{1}</div><p>{2}</p><textarea readonly>{3}</textarea></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.asset_status), (Encode-P0V2Html $card.usage_note), (Encode-P0V2Html $promptText)))
    }
  }
  $empty = if (Test-P0HasProperty $RenderInput 'cover_empty_reason') { Encode-P0V2Html $RenderInput.cover_empty_reason } else { '无' }
  return [pscustomobject]@{
    Strategy = $(if ($strategy.Count) { [string]::Join("`n", $strategy) } else { '<div class="item">{0}</div>' -f $empty })
    Ready = $(if ($ready.Count) { [string]::Join("`n", $ready) } else { '<div class="item">无可上传封面成品</div>' })
    Background = $(if ($background.Count) { [string]::Join("`n", $background) } else { '<div class="item">无封面底图</div>' })
    Prompt = $(if ($prompt.Count) { [string]::Join("`n", $prompt) } else { '<div class="item">无待外部生成封面</div>' })
  }
}

function Convert-P0V2PipHtml {
  param([object]$RenderInput, [string]$Session, [string]$HtmlBasePath)
  $cards = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($RenderInput.pip_cards | Sort-Object display_order)) {
    if ($card.asset_status -in @('generated','reused_verified')) {
      $reference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBasePath
      $cards.Add(('<article class="item" id="{0}"><div class="asset-status-badge">{1}</div><span class="label">插入位置</span><p>{2}</p><img src="{3}" alt="{4}"><p>{5}</p><a href="{3}" download>下载图片</a></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.asset_status), (Encode-P0V2Html $card.placement), (Encode-P0V2Html $reference.HtmlPath), (Encode-P0V2Html $card.preview_alt), (Encode-P0V2Html $card.narrative_function)))
    } else {
      $promptText = if (Test-P0HasProperty $card 'prompt_text') { [string]$card.prompt_text } else { '需要人工处理，未提供自动生成提示词。' }
      $cards.Add(('<article class="item pending-card" id="{0}"><div class="asset-status-badge">{1}</div><span class="label">插入位置</span><p>{2}</p><p>{3}</p><textarea readonly>{4}</textarea></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.asset_status), (Encode-P0V2Html $card.placement), (Encode-P0V2Html $card.narrative_function), (Encode-P0V2Html $promptText)))
    }
  }
  if ($cards.Count) { return [string]::Join("`n", $cards) }
  $reason = if (Test-P0HasProperty $RenderInput 'pip_empty_reason') { Encode-P0V2Html $RenderInput.pip_empty_reason } else { '无画中画' }
  return '<div class="item">{0}</div>' -f $reason
}

function Convert-P0V2PlatformHtml {
  param([object]$RenderInput)
  $cards = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($RenderInput.platform_cards | Sort-Object display_order)) {
    $hashtags = [string]::Join(' ', @($card.hashtags | ForEach-Object { Encode-P0V2Html $_ }))
    $cards.Add(('<article class="item" id="{0}"><h3>{1}</h3><span class="label">封面标题</span><textarea readonly>{2}</textarea><span class="label">视频标题</span><textarea readonly>{3}</textarea><span class="label">发布描述</span><textarea readonly>{4}</textarea><span class="label">话题标签</span><p>{5}</p><span class="label">发布准备状态</span><strong>{6}</strong></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.platform), (Encode-P0V2Html $card.cover_title), (Encode-P0V2Html $card.video_title), (Encode-P0V2Html $card.publish_description), $hashtags, (Encode-P0V2Html $card.publish_readiness)))
  }
  return [string]::Join("`n", $cards)
}

function Convert-P0V2TraceHtml {
  param([object]$RenderInput, [string]$Session, [string]$HtmlBasePath)
  $cards = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($RenderInput.trace_cards | Sort-Object display_order)) {
    $reference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBasePath
    $cards.Add(('<article class="item" id="{0}"><span class="label">{1} · {2}</span><a href="{3}">{4}</a><p>{5}</p></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.artifact_type), (Encode-P0V2Html $card.artifact_id), (Encode-P0V2Html $reference.HtmlPath), (Encode-P0V2Html $card.label), (Encode-P0V2Html $card.materialization_status)))
  }
  return [string]::Join("`n", $cards)
}

function Convert-P0V2ActionHtml {
  param([object]$RenderInput)
  $cards = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($RenderInput.action_cards | Sort-Object display_order)) {
    $cards.Add(('<article class="item" id="{0}"><h3>{1}</h3><p>{2}</p><span class="label">可直接回复</span><code>{3}</code></article>' -f (Encode-P0V2Html $card.card_id), (Encode-P0V2Html $card.label), (Encode-P0V2Html $card.instruction), (Encode-P0V2Html $card.reply_example)))
  }
  return [string]::Join("`n", $cards)
}

function Get-P0V2BrokenReferences {
  param([string]$Html, [string]$OutputPath, [string]$Session)
  $errors = [System.Collections.Generic.List[string]]::new()
  $base = Split-Path -Parent $OutputPath
  $sessionRoot = [System.IO.Path]::GetFullPath($Session).TrimEnd('\')
  foreach ($match in [regex]::Matches($Html, '(href|src)=["'']([^"''#]+)["'']', 'IgnoreCase')) {
    $attribute = $match.Groups[1].Value.ToLowerInvariant()
    $reference = [System.Net.WebUtility]::HtmlDecode($match.Groups[2].Value)
    if ($reference -match '^(?i)(?:javascript:|data:|mailto:)') { $errors.Add("unsafe_or_external_reference:$reference"); continue }
    if ($reference -match '^(?i)https?://') {
      if ($attribute -eq 'href') { continue }
      $errors.Add("unsafe_external_resource_reference:$reference")
      continue
    }
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $base (($reference -split '[?#]', 2)[0])))
    if (-not $candidate.StartsWith($sessionRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $errors.Add("reference_escape:$reference"); continue }
    if (-not (Test-Path -LiteralPath $candidate)) { $errors.Add("broken_reference:$reference") }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0V2RenderedHtml {
  param([string]$Html, [string]$OutputPath, [string]$Session)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($Html -match '\{\{[^}]+\}\}') { $errors.Add('unresolved_template_token') }
  if ($Html -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') { $errors.Add('unsafe_html_output') }
  if ([regex]::Matches($Html, '<h1\b', 'IgnoreCase').Count -ne 1) { $errors.Add('page_h1_count_invalid') }
  if ($Html -notmatch '(?i)<main\b' -or $Html -notmatch '(?i)<details\b' -or $Html -notmatch '(?i)<summary\b') { $errors.Add('page_semantic_structure_missing') }
  foreach ($validationError in (Get-P0V2BrokenReferences $Html $OutputPath $Session)) { $errors.Add($validationError) }
  return [object[]]$errors.ToArray()
}

function Test-P0V2RenderReceipt {
  param([object]$Receipt)
  $errors = [System.Collections.Generic.List[string]]::new()
  $fields = @('schema_id','schema_version','receipt_id','render_input_sha256','renderer_version','template_sha256','included_card_ids','included_asset_ids','warning_codes','output_html_sha256')
  foreach ($validationError in (Test-P0RequiredProperties $Receipt $fields 'render_receipt')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Receipt $fields 'render_receipt')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Receipt.schema_id -ne 'taoge://schemas/p0/render-receipt/v0.2' -or $Receipt.schema_version -ne '0.2') { $errors.Add('render_receipt_schema_invalid') }
  if ($Receipt.renderer_version -ne 'final-delivery-renderer-v0.2') { $errors.Add('render_receipt_renderer_version_invalid') }
  foreach ($field in @('render_input_sha256','template_sha256','output_html_sha256')) { if (-not (Test-P0Digest $Receipt.$field)) { $errors.Add("render_receipt_digest_invalid:$field") } }
  if (@($Receipt.included_card_ids).Count -eq 0) { $errors.Add('render_receipt_card_ids_empty') }
  foreach ($field in @('included_card_ids','included_asset_ids','warning_codes')) {
    $values = @($Receipt.$field)
    if (@($values | Sort-Object -Unique).Count -ne $values.Count) { $errors.Add("render_receipt_values_duplicate:$field") }
  }
  return [object[]]$errors.ToArray()
}

function Write-P0V2ArtifactChecks {
  param([string]$Path, [string]$TargetArtifactId, [string[]]$CheckIds, [string]$EvidencePath)
  $timestamp = [DateTimeOffset]::UtcNow.ToString('o')
  $checks = [System.Collections.Generic.List[object]]::new()
  foreach ($checkId in $CheckIds) {
    $checks.Add([ordered]@{ check_id=$checkId; check_version='p0-h2-v0.2'; target_artifact_id=$TargetArtifactId; status='pass'; severity='blocker'; evidence_path=$EvidencePath; executed_at=$timestamp; execution_source='deterministic_tool' })
  }
  $document = [ordered]@{ schema_id='taoge://schemas/p0/artifact-check-set/v0.2'; schema_version='0.2'; check_set_id="CHECKSET-$TargetArtifactId"; checks=[object[]]$checks.ToArray() }
  Write-P0V2AtomicText $Path (ConvertTo-P0V2JsonText $document)
}

function Invoke-P0RuntimeV02 {
  param([string]$Session, [object]$Plan, [string]$EventPath, [string]$Mode, [string]$ProjectRoot)
  $events = @(Get-P0V2Events $EventPath)
  $contractErrors = @(Test-P0V2PlanEvents $Plan $events)
  if ($contractErrors.Count) { return New-P0V2Result 1 @($contractErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
  $succeeded = Get-P0V2SucceededMap $events
  $pending = @($Plan.steps | Where-Object { -not $succeeded.ContainsKey([string]$_.step_id) })
  if ($Mode -eq 'validate') {
    return New-P0V2Result 0 @(('WORKFLOW_RUNTIME_RESULT=' + $(if ($pending.Count) { 'plan_valid_waiting_steps' } else { 'plan_valid_completed' })), 'WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2')
  }
  if ($Mode -eq 'resume_report') {
    return New-P0V2Result 0 @(('WORKFLOW_RUNTIME_RESULT=' + $(if ($pending.Count) { 'resume_ready' } else { 'completed' })), ('RESUME_NEXT_STEP=' + $(if ($pending.Count) { $pending[0].step_id } else { 'none' })), 'WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2')
  }

  $p0Delivery = Join-Path $Session 'deliverables/p0'
  if (-not (Test-Path -LiteralPath $p0Delivery)) { New-Item -ItemType Directory -Path $p0Delivery -Force | Out-Null }
  if ($Mode -eq 'compile_render_input') {
    $step = Get-P0V2Step $Plan 'compile_render_input' $succeeded
    if ($null -eq $step) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=compile_render_input_step_missing') }
    $prerequisiteErrors = @(Test-P0V2Prerequisites $step $succeeded)
    if ($prerequisiteErrors.Count) { return New-P0V2Result 1 @($prerequisiteErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    $candidatePath = Join-Path $p0Delivery 'final-delivery-render-candidate.json'
    $outputPath = Join-Path $p0Delivery 'final-delivery-render-input.json'
    if (-not (Test-Path -LiteralPath $candidatePath)) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=render_candidate_missing') }
    $inputDigest = Get-P0V2Hash $candidatePath
    $prior = @($events | Where-Object { $_.step_id -eq $step.step_id -and $_.state_after -eq 'succeeded' -and (Test-P0HasProperty $_ 'input_digest') -and $_.input_digest -eq $inputDigest }) | Select-Object -First 1
    if ($prior -and (Test-Path -LiteralPath $outputPath)) {
      $existingErrors = @(Test-P0RenderInputContract (Read-P0JsonFile $outputPath))
      if ($existingErrors.Count -eq 0) { return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=skipped_reused','WORKFLOW_RUNTIME_OPERATION=compile_render_input') }
    }
    try { $candidate = Read-P0JsonFile $candidatePath } catch { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=render_candidate_parse_failed') }
    $candidate = (($candidate | ConvertTo-Json -Depth 50) | ConvertFrom-Json)
    if ([string]$candidate.session_id -ne [string]$Plan.session_id) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=render_candidate_session_mismatch') }
    $referenceErrors = @(Test-P0V2MaterializedReferences $candidate $Session)
    if ($referenceErrors.Count) { return New-P0V2Result 1 @($referenceErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    if ([string]$candidate.schema_version -eq 'typed_components_v0.5' -and -not (Get-Command Get-P0V5DeliveryReadiness -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'P0ContractV05.ps1') }
    if ([string]$candidate.schema_version -eq 'typed_components_v0.4' -and -not (Get-Command Get-P0V4DeliveryReadiness -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'P0ContractV04.ps1') }
    $readiness = if ([string]$candidate.schema_version -eq 'typed_components_v0.5') { Get-P0V5DeliveryReadiness $candidate } elseif ([string]$candidate.schema_version -eq 'typed_components_v0.4') { Get-P0V4DeliveryReadiness $candidate } else { Get-P0V2DeliveryReadiness $candidate }
    $candidate.production_status.delivery_readiness = $readiness.delivery_readiness
    if ([string]$candidate.schema_version -in @('typed_components_v0.4','typed_components_v0.5')) { $candidate.production_status.platform_delivery_scope_status = $readiness.platform_delivery_scope_status }
    $candidate.production_status.derived_by = $(if ([string]$candidate.schema_version -eq 'typed_components_v0.5') { 'derive_delivery_readiness_v0.5' } elseif ([string]$candidate.schema_version -eq 'typed_components_v0.4') { 'derive_delivery_readiness_v0.4' } elseif ([string]$candidate.schema_version -eq 'typed_components_v0.3') { 'derive_delivery_readiness_v0.3' } else { 'derive_delivery_readiness' })
    $candidate.production_status.warning_codes = [object[]]$readiness.warning_codes
    if ([string]$candidate.schema_version -in @('typed_components_v0.3','typed_components_v0.4','typed_components_v0.5')) {
      $candidate.delivery_revision.revision_status = 'compiled'
      $candidate.delivery_revision.semantic_gate_status = 'pass'
    }
    $renderErrors = @(Test-P0RenderInputContract $candidate)
    if ($renderErrors.Count) { return New-P0V2Result 1 @($renderErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    Write-P0V2AtomicText $outputPath (ConvertTo-P0V2JsonText $candidate)
    $outputDigest = Get-P0V2Hash $outputPath
    $event = Add-P0V2SucceededEvent $EventPath $events $Plan $step $inputDigest $outputDigest @([string]$candidate.render_input_id) 'render_input_compiled' 'typed render input 已确定性编译'
    $quality = switch ([string]$candidate.production_status.overall_quality_status) { 'pass' {'pass'} 'pass_with_warnings' {'pass_with_warnings'} 'fail' {'fail'} default {'not_run'} }
    $eligibility = switch ([string]$readiness.delivery_readiness) { 'ready' {'ready_for_delivery'} 'ready_with_warnings' {'ready_for_delivery'} 'ready_all_target_platforms' {'ready_for_delivery'} 'primary_ready_secondary_pending' {'preview_only'} 'needs_action' {'preview_only'} default {'blocked'} }
    $lineage = [ordered]@{ schema_id='taoge://schemas/p0/artifact-lineage/v0.2'; schema_version='0.2'; artifact_lineage_manifest=[ordered]@{ artifact_id=[string]$candidate.render_input_id; artifact_type='deterministic_final_delivery_render_input'; producer_event_id=[string]$event.event_id; input_artifact_ids=[object[]]@($candidate.source_artifact_ids); materialization_status='materialized'; quality_status=$quality; delivery_eligibility=$eligibility; path='deliverables/p0/final-delivery-render-input.json'; sha256=$outputDigest; check_ids=@('CHECK-P0-H2-INPUT-CONTRACT','CHECK-P0-H2-READINESS') } }
    Write-P0V2AtomicText (Join-Path $p0Delivery 'render-input-lineage.json') (ConvertTo-P0V2JsonText $lineage)
    Write-P0V2ArtifactChecks (Join-Path $p0Delivery 'artifact-checks.json') ([string]$candidate.render_input_id) @('CHECK-P0-H2-INPUT-CONTRACT','CHECK-P0-H2-READINESS') 'deliverables/p0/final-delivery-render-input.json'
    return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=render_input_compiled', ('DELIVERY_READINESS=' + $readiness.delivery_readiness), ('RENDER_INPUT_SHA256=' + $outputDigest))
  }

  if ($Mode -eq 'render_final_delivery') {
    $step = Get-P0V2Step $Plan 'render_final_delivery' $succeeded
    if ($null -eq $step) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=render_final_delivery_step_missing') }
    $prerequisiteErrors = @(Test-P0V2Prerequisites $step $succeeded)
    if ($prerequisiteErrors.Count) { return New-P0V2Result 1 @($prerequisiteErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    $inputPath = Join-Path $p0Delivery 'final-delivery-render-input.json'
    if (-not (Test-Path -LiteralPath $inputPath)) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=typed_render_input_missing') }
    $renderInput = Read-P0JsonFile $inputPath
    $renderErrors = @(Test-P0RenderInputContract $renderInput)
    if ($renderErrors.Count) { return New-P0V2Result 1 @($renderErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    $referenceErrors = @(Test-P0V2MaterializedReferences $renderInput $Session)
    if ($referenceErrors.Count) { return New-P0V2Result 1 @($referenceErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    $inputDigest = Get-P0V2Hash $inputPath
    $outputPath = Join-Path $Session 'deliverables/final-delivery.html'
    $receiptPath = Join-Path $p0Delivery 'render-receipt.json'
    if ([string]$renderInput.schema_version -eq 'typed_components_v0.5') {
      . (Join-Path $PSScriptRoot 'P0FinalDeliveryV05.ps1')
      $templatePathV5 = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.5.template.html'
      $templateDigestV5 = Get-P0V2Hash $templatePathV5
      $operationDigestV5 = Get-P0V2TextHash ($inputDigest + '|' + $templateDigestV5 + '|final-delivery-renderer-v0.5')
      $priorV5 = @($events | Where-Object { $_.step_id -eq $step.step_id -and $_.state_after -eq 'succeeded' -and (Test-P0HasProperty $_ 'input_digest') -and $_.input_digest -eq $operationDigestV5 }) | Select-Object -First 1
      if ($priorV5 -and (Test-P0V5RevisionClosure $Session $renderInput $inputDigest $ProjectRoot)) {
        $receiptV5 = Read-P0JsonFile $receiptPath
        return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=skipped_reused','WORKFLOW_RUNTIME_OPERATION=render_final_delivery',('OUTPUT_HTML_SHA256=' + $receiptV5.output_view_sha256.final_html),('DELIVERY_REVISION_ID=' + $renderInput.delivery_revision.delivery_revision_id))
      }
      try { $renderedV5 = Write-P0V5DeliveryViews $renderInput $Session $ProjectRoot $inputDigest }
      catch { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=' + $_.Exception.Message) }
      $eventV5 = Add-P0V2SucceededEvent $EventPath $events $Plan $step $operationDigestV5 ([string]$renderedV5.HtmlSha256) @([string]$renderInput.final_delivery_id,[string]$renderInput.delivery_revision.delivery_revision_id) 'final_delivery_revision_committed' 'v0.5 delivery views committed'
      $qualityV5 = switch ([string]$renderInput.production_status.overall_quality_status) { 'pass' {'pass'} 'pass_with_warnings' {'pass_with_warnings'} 'fail' {'fail'} default {'not_run'} }
      $eligibilityV5 = if ($renderInput.production_status.delivery_readiness -eq 'ready_all_target_platforms') { 'ready_for_delivery' } elseif ($renderInput.production_status.delivery_readiness -eq 'primary_ready_secondary_pending') { 'preview_only' } else { 'blocked' }
      $lineageV5 = [ordered]@{ schema_id='taoge://schemas/p0/artifact-lineage/v0.2'; schema_version='0.2'; artifact_lineage_manifest=[ordered]@{ artifact_id=[string]$renderInput.final_delivery_id; artifact_type='final_delivery'; producer_event_id=[string]$eventV5.event_id; input_artifact_ids=@([string]$renderInput.render_input_id,[string]$renderInput.delivery_revision.delivery_revision_id); materialization_status='materialized'; quality_status=$qualityV5; delivery_eligibility=$eligibilityV5; path='deliverables/final-delivery.html'; sha256=[string]$renderedV5.HtmlSha256; check_ids=@('CHECK-P0-R6-V05-REVISION','CHECK-P0-R6-V05-SEMANTIC','CHECK-P0-R6-V05-COVERAGE') } }
      Write-P0V2AtomicText (Join-Path $p0Delivery 'artifact-lineage-manifest.json') (ConvertTo-P0V2JsonText $lineageV5)
      Write-P0V2ArtifactChecks (Join-Path $p0Delivery 'artifact-checks.json') ([string]$renderInput.final_delivery_id) @('CHECK-P0-R6-V05-REVISION','CHECK-P0-R6-V05-SEMANTIC','CHECK-P0-R6-V05-COVERAGE') 'deliverables/p0/delivery-revision.json'
      return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=rendered','WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2+r6-v0.5',('OUTPUT_HTML_SHA256=' + [string]$renderedV5.HtmlSha256),('DELIVERY_REVISION_ID=' + [string]$renderInput.delivery_revision.delivery_revision_id),('RENDER_RECEIPT=deliverables/p0/render-receipt.json'))
    }
    if ([string]$renderInput.schema_version -eq 'typed_components_v0.4') {
      . (Join-Path $PSScriptRoot 'P0FinalDeliveryV04.ps1')
      $templatePathV4 = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.4.template.html'
      $templateDigestV4 = Get-P0V2Hash $templatePathV4
      $operationDigestV4 = Get-P0V2TextHash ($inputDigest + '|' + $templateDigestV4 + '|final-delivery-renderer-v0.4')
      $priorV4 = @($events | Where-Object { $_.step_id -eq $step.step_id -and $_.state_after -eq 'succeeded' -and (Test-P0HasProperty $_ 'input_digest') -and $_.input_digest -eq $operationDigestV4 }) | Select-Object -First 1
      if ($priorV4 -and (Test-P0V4RevisionClosure $Session $renderInput $inputDigest $ProjectRoot)) {
        $receiptV4 = Read-P0JsonFile $receiptPath
        return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=skipped_reused','WORKFLOW_RUNTIME_OPERATION=render_final_delivery',('OUTPUT_HTML_SHA256=' + $receiptV4.output_view_sha256.final_html),('DELIVERY_REVISION_ID=' + $renderInput.delivery_revision.delivery_revision_id))
      }
      try { $renderedV4 = Write-P0V4DeliveryViews $renderInput $Session $ProjectRoot $inputDigest }
      catch { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=' + $_.Exception.Message) }
      $eventV4 = Add-P0V2SucceededEvent $EventPath $events $Plan $step $operationDigestV4 ([string]$renderedV4.HtmlSha256) @([string]$renderInput.final_delivery_id,[string]$renderInput.delivery_revision.delivery_revision_id) 'final_delivery_revision_committed' '发布执行工作台及同 revision 交付视图已提交'
      $qualityV4 = switch ([string]$renderInput.production_status.overall_quality_status) { 'pass' {'pass'} 'pass_with_warnings' {'pass_with_warnings'} 'fail' {'fail'} default {'not_run'} }
      $eligibilityV4 = if ($renderInput.production_status.delivery_readiness -eq 'ready_all_target_platforms') { 'ready_for_delivery' } elseif ($renderInput.production_status.delivery_readiness -eq 'primary_ready_secondary_pending') { 'preview_only' } else { 'blocked' }
      $lineageV4 = [ordered]@{ schema_id='taoge://schemas/p0/artifact-lineage/v0.2'; schema_version='0.2'; artifact_lineage_manifest=[ordered]@{ artifact_id=[string]$renderInput.final_delivery_id; artifact_type='final_delivery'; producer_event_id=[string]$eventV4.event_id; input_artifact_ids=@([string]$renderInput.render_input_id,[string]$renderInput.delivery_revision.delivery_revision_id); materialization_status='materialized'; quality_status=$qualityV4; delivery_eligibility=$eligibilityV4; path='deliverables/final-delivery.html'; sha256=[string]$renderedV4.HtmlSha256; check_ids=@('CHECK-P0-H7-V04-REVISION','CHECK-P0-H7-V04-SEMANTIC','CHECK-P0-H7-V04-VISUAL') } }
      Write-P0V2AtomicText (Join-Path $p0Delivery 'artifact-lineage-manifest.json') (ConvertTo-P0V2JsonText $lineageV4)
      Write-P0V2ArtifactChecks (Join-Path $p0Delivery 'artifact-checks.json') ([string]$renderInput.final_delivery_id) @('CHECK-P0-H7-V04-REVISION','CHECK-P0-H7-V04-SEMANTIC','CHECK-P0-H7-V04-VISUAL') 'deliverables/p0/delivery-revision.json'
      return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=rendered','WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2+h7-v0.4',('OUTPUT_HTML_SHA256=' + [string]$renderedV4.HtmlSha256),('DELIVERY_REVISION_ID=' + [string]$renderInput.delivery_revision.delivery_revision_id),('RENDER_RECEIPT=deliverables/p0/render-receipt.json'))
    }
    if ([string]$renderInput.schema_version -eq 'typed_components_v0.3') {
      . (Join-Path $PSScriptRoot 'P0FinalDeliveryV03.ps1')
      $templatePathV3 = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.3.template.html'
      $templateDigestV3 = Get-P0V2Hash $templatePathV3
      $operationDigestV3 = Get-P0V2TextHash ($inputDigest + '|' + $templateDigestV3 + '|final-delivery-renderer-v0.3')
      $priorV3 = @($events | Where-Object { $_.step_id -eq $step.step_id -and $_.state_after -eq 'succeeded' -and (Test-P0HasProperty $_ 'input_digest') -and $_.input_digest -eq $operationDigestV3 }) | Select-Object -First 1
      if ($priorV3 -and (Test-P0V3RevisionClosure $Session $renderInput $inputDigest $ProjectRoot)) {
        $receiptV3 = Read-P0JsonFile $receiptPath
        return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=skipped_reused','WORKFLOW_RUNTIME_OPERATION=render_final_delivery',('OUTPUT_HTML_SHA256=' + $receiptV3.output_view_sha256.final_html),('DELIVERY_REVISION_ID=' + $renderInput.delivery_revision.delivery_revision_id))
      }
      try { $renderedV3 = Write-P0V3DeliveryViews $renderInput $Session $ProjectRoot $inputDigest }
      catch { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=' + $_.Exception.Message) }
      $eventV3 = Add-P0V2SucceededEvent $EventPath $events $Plan $step $operationDigestV3 ([string]$renderedV3.HtmlSha256) @([string]$renderInput.final_delivery_id,[string]$renderInput.delivery_revision.delivery_revision_id) 'final_delivery_revision_committed' '发布执行工作台及同 revision 交付视图已提交'
      $qualityV3 = switch ([string]$renderInput.production_status.overall_quality_status) { 'pass' {'pass'} 'pass_with_warnings' {'pass_with_warnings'} 'fail' {'fail'} default {'not_run'} }
      $eligibilityV3 = if ($renderInput.production_status.delivery_readiness -in @('ready','ready_with_warnings')) { 'ready_for_delivery' } elseif ($renderInput.production_status.delivery_readiness -eq 'needs_action') { 'preview_only' } else { 'blocked' }
      $lineageV3 = [ordered]@{ schema_id='taoge://schemas/p0/artifact-lineage/v0.2'; schema_version='0.2'; artifact_lineage_manifest=[ordered]@{ artifact_id=[string]$renderInput.final_delivery_id; artifact_type='final_delivery'; producer_event_id=[string]$eventV3.event_id; input_artifact_ids=@([string]$renderInput.render_input_id,[string]$renderInput.delivery_revision.delivery_revision_id); materialization_status='materialized'; quality_status=$qualityV3; delivery_eligibility=$eligibilityV3; path='deliverables/final-delivery.html'; sha256=[string]$renderedV3.HtmlSha256; check_ids=@('CHECK-P0-H7-REVISION','CHECK-P0-H7-SEMANTIC','CHECK-P0-H7-LINKS','CHECK-P0-H7-SECURITY') } }
      Write-P0V2AtomicText (Join-Path $p0Delivery 'artifact-lineage-manifest.json') (ConvertTo-P0V2JsonText $lineageV3)
      Write-P0V2ArtifactChecks (Join-Path $p0Delivery 'artifact-checks.json') ([string]$renderInput.final_delivery_id) @('CHECK-P0-H7-REVISION','CHECK-P0-H7-SEMANTIC','CHECK-P0-H7-LINKS','CHECK-P0-H7-SECURITY') 'deliverables/p0/delivery-revision.json'
      return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=rendered','WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2+h7-v0.3',('OUTPUT_HTML_SHA256=' + [string]$renderedV3.HtmlSha256),('DELIVERY_REVISION_ID=' + [string]$renderInput.delivery_revision.delivery_revision_id),('RENDER_RECEIPT=deliverables/p0/render-receipt.json'))
    }
    $templatePath = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.template.html'
    if (-not (Test-Path -LiteralPath $templatePath)) { return New-P0V2Result 1 @('WORKFLOW_RUNTIME_ERROR=final_delivery_template_missing') }
    $prior = @($events | Where-Object { $_.step_id -eq $step.step_id -and $_.state_after -eq 'succeeded' -and (Test-P0HasProperty $_ 'input_digest') -and $_.input_digest -eq $inputDigest }) | Select-Object -First 1
    if ($prior -and (Test-Path -LiteralPath $outputPath) -and (Test-Path -LiteralPath $receiptPath)) {
      $receipt = Read-P0JsonFile $receiptPath
      $receiptErrors = @(Test-P0V2RenderReceipt $receipt)
      if ($receiptErrors.Count -eq 0 -and $receipt.render_input_sha256 -eq $inputDigest -and $receipt.template_sha256 -eq (Get-P0V2Hash $templatePath) -and $receipt.output_html_sha256 -eq (Get-P0V2Hash $outputPath)) { return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=skipped_reused','WORKFLOW_RUNTIME_OPERATION=render_final_delivery',('OUTPUT_HTML_SHA256=' + $receipt.output_html_sha256)) }
    }
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $htmlBase = Split-Path -Parent $outputPath
    $cover = Convert-P0V2CoverSections $renderInput $Session $htmlBase
    $pipHtml = Convert-P0V2PipHtml $renderInput $Session $htmlBase
    $platformHtml = Convert-P0V2PlatformHtml $renderInput
    $traceHtml = Convert-P0V2TraceHtml $renderInput $Session $htmlBase
    $actionHtml = Convert-P0V2ActionHtml $renderInput
    $uploadReady = @($renderInput.cover_cards | Where-Object { $_.cover_role -eq 'platform_cover' -and $_.asset_status -in @('generated','reused_verified') }).Count
    $promptOnly = @($renderInput.cover_cards | Where-Object { $_.asset_status -notin @('generated','reused_verified') }).Count
    $pipSummary = if (@($renderInput.pip_cards).Count) { [string]::Join('；', @($renderInput.pip_cards | ForEach-Object { [string]$_.narrative_function })) } else { [string]$renderInput.pip_empty_reason }
    $hookText = if (Test-P0HasProperty $renderInput.script_card 'hook_text') { [string]$renderInput.script_card.hook_text } else { '未单独提供 Hook 字段；以完整口播首段为准。' }
    $humanPrompt = '可执行操作：' + [string]::Join(' / ', @($renderInput.action_cards | Sort-Object display_order | ForEach-Object { [string]$_.label }))
    $warnings = if (@($renderInput.production_status.warning_codes).Count) { [string]::Join(', ', @($renderInput.production_status.warning_codes)) } else { 'none' }
    $finalStatus = if ($renderInput.production_status.delivery_readiness -eq 'blocked') { 'blocked' } else { 'html_ready' }
    $replacements = [ordered]@{
      title = Encode-P0V2Html $renderInput.topic.title
      account = Encode-P0V2Html $renderInput.account_name
      session_id = Encode-P0V2Html $renderInput.session_id
      source_research_run_id = Encode-P0V2Html $renderInput.research_run_id
      delivery_page_mode = 'project_local'
      final_delivery_status = $finalStatus
      delivery_readiness = Encode-P0V2Html $renderInput.production_status.delivery_readiness
      delivery_warning_codes = Encode-P0V2Html $warnings
      image_assets_status = Encode-P0V2Html $renderInput.production_status.image_assets_status
      visual_text_plan_id = Encode-P0V2Html (Get-P0V2TraceId $renderInput 'visual_text_plan')
      visual_text_quality_gate_status = Encode-P0V2Html $renderInput.production_status.overall_quality_status
      cover_design_package_id = Encode-P0V2Html (Get-P0V2TraceId $renderInput 'cover_design_package')
      upload_ready_cover_count = [string]$uploadReady
      prompt_only_cover_count = [string]$promptOnly
      html_builder_mode = 'skill_template_rendered'
      html_template_source = 'templates/final-delivery/final-delivery.template.html'
      topic_title = Encode-P0V2Html $renderInput.topic.title
      topic_rationale = Encode-P0V2Html ($renderInput.topic.why_now + '｜内容形式：' + $renderInput.topic.content_format)
      hook_text = Encode-P0V2Html $hookText
      final_script = Encode-P0V2Html $renderInput.script_card.final_text
      cover_design_summary = Encode-P0V2Html ("封面卡 $(@($renderInput.cover_cards).Count) 张；可上传 $uploadReady 张；待处理 $promptOnly 张。")
      cover_quality_summary = Encode-P0V2Html $renderInput.production_status.cover_quality_status
      platform_cover_strategy = $cover.Strategy
      cover_ready_assets = $cover.Ready
      cover_background_assets = $cover.Background
      cover_prompt_only_assets = $cover.Prompt
      visual_text_delivery_summary = Encode-P0V2Html $pipSummary
      picture_in_picture_assets = $pipHtml
      platform_package = $platformHtml
      trace_links = $traceHtml
      human_prompt = Encode-P0V2Html $humanPrompt
      human_actions = $actionHtml
    }
    foreach ($key in $replacements.Keys) { $template = $template.Replace('{{' + $key + '}}', [string]$replacements[$key]) }
    $html = $template.TrimEnd("`r", "`n") + "`n"
    $htmlErrors = @(Test-P0V2RenderedHtml $html $outputPath $Session)
    if ($htmlErrors.Count) { return New-P0V2Result 1 @($htmlErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    Write-P0V2AtomicText $outputPath $html
    $outputDigest = Get-P0V2Hash $outputPath
    $cardIds = [System.Collections.Generic.List[string]]::new()
    $cardIds.Add([string]$renderInput.script_card.card_id)
    foreach ($card in @($renderInput.cover_cards) + @($renderInput.pip_cards) + @($renderInput.platform_cards) + @($renderInput.trace_cards) + @($renderInput.action_cards)) {
      $cardIds.Add([string]$card.card_id)
    }
    $assetIds = [System.Collections.Generic.List[string]]::new()
    foreach ($card in @($renderInput.cover_cards) + @($renderInput.pip_cards)) {
      if ((Test-P0HasProperty $card 'asset_id') -and -not [string]::IsNullOrWhiteSpace([string]$card.asset_id)) { $assetIds.Add([string]$card.asset_id) }
    }
    $receipt = [ordered]@{
      schema_id = 'taoge://schemas/p0/render-receipt/v0.2'
      schema_version = '0.2'
      receipt_id = 'RCP-' + [string]$renderInput.final_delivery_id
      render_input_sha256 = $inputDigest
      renderer_version = 'final-delivery-renderer-v0.2'
      template_sha256 = Get-P0V2Hash $templatePath
      included_card_ids = [object[]]@($cardIds.ToArray() | Sort-Object -Unique)
      included_asset_ids = [object[]]@($assetIds.ToArray() | Sort-Object -Unique)
      warning_codes = [object[]]@($renderInput.production_status.warning_codes | Sort-Object -Unique)
      output_html_sha256 = $outputDigest
    }
    $receiptErrors = @(Test-P0V2RenderReceipt ([pscustomobject]$receipt))
    if ($receiptErrors.Count) { return New-P0V2Result 1 @($receiptErrors | ForEach-Object { "WORKFLOW_RUNTIME_ERROR=$_" }) }
    Write-P0V2AtomicText $receiptPath (ConvertTo-P0V2JsonText $receipt)
    $event = Add-P0V2SucceededEvent $EventPath $events $Plan $step $inputDigest $outputDigest @([string]$renderInput.final_delivery_id) 'final_delivery_rendered' 'typed final delivery HTML 已确定性渲染'
    $quality = switch ([string]$renderInput.production_status.overall_quality_status) { 'pass' {'pass'} 'pass_with_warnings' {'pass_with_warnings'} 'fail' {'fail'} default {'not_run'} }
    $eligibility = if ($renderInput.production_status.delivery_readiness -in @('ready','ready_with_warnings')) { 'ready_for_delivery' } elseif ($renderInput.production_status.delivery_readiness -eq 'needs_action') { 'preview_only' } else { 'blocked' }
    $lineage = [ordered]@{ schema_id='taoge://schemas/p0/artifact-lineage/v0.2'; schema_version='0.2'; artifact_lineage_manifest=[ordered]@{ artifact_id=[string]$renderInput.final_delivery_id; artifact_type='final_delivery'; producer_event_id=[string]$event.event_id; input_artifact_ids=@([string]$renderInput.render_input_id); materialization_status='materialized'; quality_status=$quality; delivery_eligibility=$eligibility; path='deliverables/final-delivery.html'; sha256=$outputDigest; check_ids=@('CHECK-P0-H2-INPUT-CONTRACT','CHECK-P0-H2-LINKS','CHECK-P0-H2-SECURITY','CHECK-P0-H2-PAGE-STRUCTURE','CHECK-P0-H2-RECEIPT') } }
    Write-P0V2AtomicText (Join-Path $p0Delivery 'artifact-lineage-manifest.json') (ConvertTo-P0V2JsonText $lineage)
    Write-P0V2ArtifactChecks (Join-Path $p0Delivery 'artifact-checks.json') ([string]$renderInput.final_delivery_id) @('CHECK-P0-H2-INPUT-CONTRACT','CHECK-P0-H2-LINKS','CHECK-P0-H2-SECURITY','CHECK-P0-H2-PAGE-STRUCTURE','CHECK-P0-H2-RECEIPT') 'deliverables/p0/render-receipt.json'
    return New-P0V2Result 0 @('WORKFLOW_RUNTIME_RESULT=rendered','WORKFLOW_RUNTIME_VERSION=p0-single-runtime-v0.2',('OUTPUT_HTML_SHA256=' + $outputDigest),('RENDER_RECEIPT=deliverables/p0/render-receipt.json'))
  }
  return New-P0V2Result 4 @("WORKFLOW_RUNTIME_ERROR=unsupported_mode:$Mode")
}
