$ErrorActionPreference = 'Stop'
$script:R6RuntimeFile = $MyInvocation.MyCommand.Path
$script:R6TemplateIdentity = 'r6-evidence-pip-svg-v0.1|1080x1350|source-region|source-strip|creator-commentary-strip'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Test-R6HasProperty {
  param([object]$Value, [Parameter(Mandatory=$true)][string]$Name)
  return $null -ne $Value -and @($Value.PSObject.Properties.Name) -contains $Name
}

function Add-R6ValidationError {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors,
    [Parameter(Mandatory=$true)][string]$Code
  )
  if (-not $Errors.Contains($Code)) { $Errors.Add($Code) }
}

function Test-R6IdValue {
  param([AllowNull()][object]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value) -and [string]$Value -match '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$'
}

function Test-R6Sha256Value {
  param([AllowNull()][object]$Value)
  return [string]$Value -match '^[A-Fa-f0-9]{64}$'
}

function Test-R6RelativePathValue {
  param([AllowNull()][object]$Value)
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { return $false }
  if ([System.IO.Path]::IsPathRooted($text)) { return $false }
  if ($text -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
  return $true
}

function Test-R6DirectContentIntake {
  param([Parameter(Mandatory=$true)][object]$Data)

  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @(
    'schema_id','schema_version','intake_id','content_source_id','session_id','account',
    'content_origin','topic_origin','direct_intent','revision_policy','structural_rewrite_requested',
    'original_draft','content_goal','target_audiences','claim_map','direct_content_status',
    'human_gate','next_skill','lineage'
  )
  foreach ($name in $required) {
    if (-not (Test-R6HasProperty -Value $Data -Name $name)) { Add-R6ValidationError $errors "missing_field:$name" }
  }
  if ($errors.Count -gt 0) { return [pscustomobject]@{status='fail';errors=[object[]]$errors.ToArray()} }

  if ($Data.schema_id -ne 'taoge://r6/direct-content-intake/v0.1') { Add-R6ValidationError $errors 'schema_id_invalid' }
  if ($Data.schema_version -ne '0.1.0') { Add-R6ValidationError $errors 'schema_version_invalid' }
  foreach ($name in @('intake_id','content_source_id','session_id')) {
    if (-not (Test-R6IdValue $Data.$name)) { Add-R6ValidationError $errors "invalid_id:$name" }
  }
  if ($Data.content_origin -ne 'user_supplied_draft') { Add-R6ValidationError $errors 'content_origin_invalid' }
  if ($Data.topic_origin -ne 'direct_user_input') { Add-R6ValidationError $errors 'topic_origin_invalid' }
  if ($Data.direct_intent -notin @('direct_delivery','direct_polish','direct_evidence_enrichment','direct_to_radar')) { Add-R6ValidationError $errors 'direct_intent_invalid' }
  if ($Data.revision_policy -notin @('preserve_voice','polish_allowed','rewrite_allowed')) { Add-R6ValidationError $errors 'revision_policy_invalid' }
  if (Test-R6HasProperty -Value $Data -Name 'topic_id') { Add-R6ValidationError $errors 'fake_topic_id_forbidden' }
  if (Test-R6HasProperty -Value $Data -Name 'source_research_run_id') { Add-R6ValidationError $errors 'fake_source_research_run_id_forbidden' }

  foreach ($name in @('account_id','account_slug','account_display_name','identity_binding_id','account_snapshot_id')) {
    if (-not (Test-R6HasProperty -Value $Data.account -Name $name) -or [string]::IsNullOrWhiteSpace([string]$Data.account.$name)) {
      Add-R6ValidationError $errors "account_field_missing:$name"
    }
  }
  foreach ($name in @('artifact_id','relative_path','sha256','character_count')) {
    if (-not (Test-R6HasProperty -Value $Data.original_draft -Name $name)) { Add-R6ValidationError $errors "original_draft_missing:$name" }
  }
  if (Test-R6HasProperty -Value $Data.original_draft -Name 'artifact_id') {
    if (-not (Test-R6IdValue $Data.original_draft.artifact_id)) { Add-R6ValidationError $errors 'original_draft_artifact_id_invalid' }
  }
  if (Test-R6HasProperty -Value $Data.original_draft -Name 'relative_path') {
    if (-not (Test-R6RelativePathValue $Data.original_draft.relative_path)) { Add-R6ValidationError $errors 'original_draft_path_invalid' }
  }
  if (Test-R6HasProperty -Value $Data.original_draft -Name 'sha256') {
    if (-not (Test-R6Sha256Value $Data.original_draft.sha256)) { Add-R6ValidationError $errors 'original_draft_sha256_invalid' }
  }
  if ([int]$Data.original_draft.character_count -lt 1) { Add-R6ValidationError $errors 'original_draft_empty' }
  if ([string]::IsNullOrWhiteSpace([string]$Data.content_goal)) { Add-R6ValidationError $errors 'content_goal_missing' }
  if (@($Data.target_audiences).Count -lt 1) { Add-R6ValidationError $errors 'target_audiences_missing' }

  foreach ($claim in @($Data.claim_map)) {
    foreach ($name in @('claim_id','source_text','claim_type','claim_evidence_status')) {
      if (-not (Test-R6HasProperty -Value $claim -Name $name)) { Add-R6ValidationError $errors "claim_missing:$name" }
    }
    if ($claim.claim_type -notin @('opinion','experience','factual_claim','quote','statistic','prediction')) { Add-R6ValidationError $errors 'claim_type_invalid' }
    if ($claim.claim_evidence_status -notin @('not_required','supported','refuted','not_enough_info','contested','not_checked')) { Add-R6ValidationError $errors 'claim_evidence_status_invalid' }
    if ($claim.claim_type -in @('opinion','experience','prediction') -and $claim.claim_evidence_status -ne 'not_required') {
      Add-R6ValidationError $errors 'nonfactual_claim_initial_status_invalid'
    }
    if ($claim.claim_type -in @('factual_claim','quote','statistic') -and $claim.claim_evidence_status -ne 'not_checked') {
      Add-R6ValidationError $errors 'factual_claim_cannot_be_preverified_at_intake'
    }
  }

  $expectedNext = 'content-brief-compiler'
  $expectedGate = $false
  $expectedStatus = 'direct_content_ready'
  if ([bool]$Data.structural_rewrite_requested -and $Data.revision_policy -eq 'preserve_voice') {
    $expectedNext = 'human_confirm'
    $expectedGate = $true
    $expectedStatus = 'needs_rewrite_confirmation'
  } elseif ($Data.direct_intent -eq 'direct_to_radar') {
    $expectedNext = 'hotspot-topic-research'
  }
  if ($Data.next_skill -ne $expectedNext) { Add-R6ValidationError $errors 'next_skill_mismatch' }
  if ([bool]$Data.human_gate -ne $expectedGate) { Add-R6ValidationError $errors 'human_gate_mismatch' }
  if ($Data.direct_content_status -ne $expectedStatus) { Add-R6ValidationError $errors 'direct_content_status_mismatch' }

  foreach ($name in @('producer_skill','consumer_skill','input_artifact_ids','output_artifact_ids')) {
    if (-not (Test-R6HasProperty -Value $Data.lineage -Name $name)) { Add-R6ValidationError $errors "lineage_missing:$name" }
  }
  if ($Data.lineage.producer_skill -ne 'direct-content-intake') { Add-R6ValidationError $errors 'producer_skill_mismatch' }
  if ($Data.lineage.consumer_skill -ne $Data.next_skill) { Add-R6ValidationError $errors 'consumer_skill_mismatch' }
  if (@($Data.lineage.output_artifact_ids) -notcontains $Data.content_source_id) { Add-R6ValidationError $errors 'content_source_lineage_missing' }
  if (@($Data.lineage.input_artifact_ids) -notcontains $Data.original_draft.artifact_id) { Add-R6ValidationError $errors 'original_draft_lineage_missing' }

  return [pscustomobject]@{status=$(if($errors.Count -eq 0){'pass'}else{'fail'});errors=[object[]]$errors.ToArray()}
}

function Test-R6EvidenceBundle {
  param(
    [Parameter(Mandatory=$true)][object]$Data,
    [string]$SessionRoot = ''
  )

  if ($Data.schema_id -eq 'taoge://r6/news-evidence-pip/v0.2') {
    if (-not (Get-Command Test-R6EvidenceBundleV02 -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'JointVisualRevisionContract.ps1')
    }
    $v02Errors = @(Test-R6EvidenceBundleV02 -Data $Data -SessionRoot $SessionRoot)
    return [pscustomobject]@{status=$(if($v02Errors.Count -eq 0){'pass'}else{'fail'});errors=[object[]]$v02Errors}
  }

  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in @('schema_id','schema_version','session_id','account','claim','source','capture','binding','pip','lineage')) {
    if (-not (Test-R6HasProperty -Value $Data -Name $name)) { Add-R6ValidationError $errors "missing_field:$name" }
  }
  if ($errors.Count -gt 0) { return [pscustomobject]@{status='fail';errors=[object[]]$errors.ToArray()} }
  if ($Data.schema_id -ne 'taoge://r6/news-evidence-pip/v0.1') { Add-R6ValidationError $errors 'schema_id_invalid' }
  if ($Data.schema_version -ne '0.1.0') { Add-R6ValidationError $errors 'schema_version_invalid' }
  if (-not (Test-R6IdValue $Data.session_id)) { Add-R6ValidationError $errors 'session_id_invalid' }

  foreach ($name in @('account_id','account_slug','account_display_name','account_snapshot_id','evidence_visual_grammar')) {
    if (-not (Test-R6HasProperty -Value $Data.account -Name $name)) { Add-R6ValidationError $errors "account_field_missing:$name" }
  }
  foreach ($name in @('source_label','commentary_label','source_color','commentary_color')) {
    if (-not (Test-R6HasProperty -Value $Data.account.evidence_visual_grammar -Name $name) -or [string]::IsNullOrWhiteSpace([string]$Data.account.evidence_visual_grammar.$name)) {
      Add-R6ValidationError $errors "evidence_visual_grammar_missing:$name"
    }
  }
  foreach ($name in @('source_color','commentary_color')) {
    if ([string]$Data.account.evidence_visual_grammar.$name -notmatch '^#[A-Fa-f0-9]{6}$') { Add-R6ValidationError $errors "evidence_visual_color_invalid:$name" }
  }

  if ($Data.claim.claim_type -notin @('factual_claim','quote','statistic')) { Add-R6ValidationError $errors 'claim_type_not_evidence_eligible' }
  if ([string]::IsNullOrWhiteSpace([string]$Data.claim.source_text)) { Add-R6ValidationError $errors 'claim_text_missing' }
  if ([string]::IsNullOrWhiteSpace([string]$Data.source.publisher)) { Add-R6ValidationError $errors 'publisher_missing' }
  if ([string]::IsNullOrWhiteSpace([string]$Data.source.title)) { Add-R6ValidationError $errors 'source_title_missing' }
  if ([string]$Data.source.canonical_url -notmatch '^https?://') { Add-R6ValidationError $errors 'canonical_url_not_public_http' }
  if ($Data.source.source_access_status -notin @('accessible','unavailable','blocked')) { Add-R6ValidationError $errors 'source_access_status_invalid' }

  foreach ($name in @('capture_id','source_id','captured_url','fixture_mode','capture_at','viewport','selected_target','screenshot_path','sha256','attempt_number','attempt_history','capture_status','capture_integrity_status','image_production_path')) {
    if (-not (Test-R6HasProperty -Value $Data.capture -Name $name)) { Add-R6ValidationError $errors "capture_field_missing:$name" }
  }
  if ($Data.capture.image_production_path -ne 'source_capture') { Add-R6ValidationError $errors 'generated_source_capture_forbidden' }
  if (-not [bool]$Data.capture.fixture_mode -and $Data.capture.captured_url -ne $Data.source.canonical_url) { Add-R6ValidationError $errors 'captured_url_source_mismatch' }
  if ([bool]$Data.capture.fixture_mode -and [string]$Data.capture.captured_url -notmatch '^(file|local-file-url-disabled):') { Add-R6ValidationError $errors 'fixture_capture_url_invalid' }
  if (-not (Test-R6RelativePathValue $Data.capture.screenshot_path)) { Add-R6ValidationError $errors 'screenshot_path_invalid' }
  if (-not (Test-R6Sha256Value $Data.capture.sha256)) { Add-R6ValidationError $errors 'capture_sha256_invalid' }
  if ([int]$Data.capture.attempt_number -lt 1) { Add-R6ValidationError $errors 'capture_attempt_number_invalid' }
  foreach ($priorAttempt in @($Data.capture.attempt_history)) {
    if ([int]$priorAttempt.attempt_number -lt 1 -or $priorAttempt.capture_status -notin @('capture_failed','interrupted_no_output')) { Add-R6ValidationError $errors 'capture_attempt_history_invalid' }
  }
  if ($Data.capture.capture_status -notin @('captured','reused_verified','capture_failed')) { Add-R6ValidationError $errors 'capture_status_invalid' }
  if ($Data.capture.capture_integrity_status -notin @('verified','failed','not_checked')) { Add-R6ValidationError $errors 'capture_integrity_status_invalid' }
  if ($Data.capture.source_id -ne $Data.source.source_id) { Add-R6ValidationError $errors 'capture_source_id_mismatch' }
  if ($Data.binding.claim_id -ne $Data.claim.claim_id) { Add-R6ValidationError $errors 'binding_claim_id_mismatch' }
  if ($Data.binding.source_id -ne $Data.source.source_id) { Add-R6ValidationError $errors 'binding_source_id_mismatch' }
  if ($Data.binding.capture_id -ne $Data.capture.capture_id) { Add-R6ValidationError $errors 'binding_capture_id_mismatch' }
  if ($Data.pip.binding_id -ne $Data.binding.binding_id) { Add-R6ValidationError $errors 'pip_binding_id_mismatch' }

  $crop = $Data.capture.selected_target.crop
  foreach ($name in @('selector','visible_quote','crop')) {
    if (-not (Test-R6HasProperty -Value $Data.capture.selected_target -Name $name)) { Add-R6ValidationError $errors "selected_target_missing:$name" }
  }
  if ([int]$crop.width -lt 1 -or [int]$crop.height -lt 1) { Add-R6ValidationError $errors 'crop_size_invalid' }
  if ([int]$crop.x -lt 0 -or [int]$crop.y -lt 0) { Add-R6ValidationError $errors 'crop_origin_invalid' }
  if (([int]$crop.x + [int]$crop.width) -gt [int]$Data.capture.viewport.width -or ([int]$crop.y + [int]$crop.height) -gt [int]$Data.capture.viewport.height) {
    Add-R6ValidationError $errors 'crop_outside_viewport'
  }

  $role = [string]$Data.pip.asset_role
  $relation = [string]$Data.binding.claim_evidence_status
  if ($role -eq 'evidence_support') {
    if ($relation -ne 'supported') { Add-R6ValidationError $errors 'evidence_support_requires_supported_relation' }
    if ($Data.source.source_access_status -ne 'accessible') { Add-R6ValidationError $errors 'evidence_support_source_not_accessible' }
    if ($Data.capture.capture_status -notin @('captured','reused_verified')) { Add-R6ValidationError $errors 'evidence_support_capture_missing' }
    if ($Data.capture.capture_integrity_status -ne 'verified') { Add-R6ValidationError $errors 'evidence_support_integrity_not_verified' }
    foreach ($name in @('copyright_review_status','privacy_review_status','publish_risk_status')) {
      if ($Data.pip.$name -ne 'approved') { Add-R6ValidationError $errors "evidence_support_gate_not_approved:$name" }
    }
  }
  if ($relation -in @('not_enough_info','refuted','not_checked') -and $role -eq 'evidence_support') { Add-R6ValidationError $errors 'insufficient_or_negative_relation_cannot_be_evidence_support' }
  if ($relation -eq 'contested' -and $role -eq 'evidence_support') { Add-R6ValidationError $errors 'contested_requires_context_signal' }
  if ($Data.pip.render_status -eq 'rendered') {
    if (-not (Test-R6RelativePathValue $Data.pip.asset_path)) { Add-R6ValidationError $errors 'rendered_asset_path_missing' }
    if (-not (Test-R6Sha256Value $Data.pip.asset_sha256)) { Add-R6ValidationError $errors 'rendered_asset_sha256_missing' }
  }
  foreach ($name in @('renderer_digest','template_digest')) {
    if (-not (Test-R6Sha256Value $Data.pip.$name)) { Add-R6ValidationError $errors "pip_digest_invalid:$name" }
  }
  if ($Data.lineage.producer_skill -ne 'news-evidence-pip') { Add-R6ValidationError $errors 'producer_skill_mismatch' }
  if ($Data.lineage.consumer_skill -ne 'copywriting-quality-review') { Add-R6ValidationError $errors 'consumer_skill_mismatch' }
  foreach ($id in @($Data.claim.claim_id,$Data.source.source_id,$Data.capture.capture_id,$Data.binding.binding_id)) {
    if (@($Data.lineage.input_artifact_ids) -notcontains $id) { Add-R6ValidationError $errors "lineage_input_missing:$id" }
  }

  if (-not [string]::IsNullOrWhiteSpace($SessionRoot) -and (Test-R6RelativePathValue $Data.capture.screenshot_path)) {
    $rootFull = [System.IO.Path]::GetFullPath($SessionRoot)
    $screenshotFull = [System.IO.Path]::GetFullPath((Join-Path $rootFull ([string]$Data.capture.screenshot_path)))
    $rootPrefix = $rootFull.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $screenshotFull.StartsWith($rootPrefix,[System.StringComparison]::OrdinalIgnoreCase)) {
      Add-R6ValidationError $errors 'screenshot_root_escape'
    } elseif (-not (Test-Path -LiteralPath $screenshotFull -PathType Leaf)) {
      Add-R6ValidationError $errors 'screenshot_file_missing'
    } else {
      $actualHash = Get-TaogeFileSha256 -Path $screenshotFull
      if ($actualHash -ne [string]$Data.capture.sha256) { Add-R6ValidationError $errors 'capture_hash_mismatch' }
    }
  }

  return [pscustomobject]@{status=$(if($errors.Count -eq 0){'pass'}else{'fail'});errors=[object[]]$errors.ToArray()}
}

function Get-R6StringSha256 {
  param([AllowEmptyString()][string]$Text)
  $encoding = [System.Text.UTF8Encoding]::new($false)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $algorithm.ComputeHash($encoding.GetBytes($Text))
    return ([System.BitConverter]::ToString($bytes) -replace '-','').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function ConvertTo-R6XmlText {
  param([AllowEmptyString()][string]$Text)
  if ($null -eq $Text) { return '' }
  return [System.Security.SecurityElement]::Escape($Text)
}

function Get-R6TextExcerpt {
  param([AllowEmptyString()][string]$Text, [int]$MaxLength = 44)
  if ([string]::IsNullOrWhiteSpace($Text)) { return '未标注' }
  $singleLine = ($Text -replace '[\r\n\t]+',' ').Trim()
  if ($singleLine.Length -le $MaxLength) { return $singleLine }
  return $singleLine.Substring(0,$MaxLength - 1) + '…'
}

function Get-R6RelativePath {
  param([Parameter(Mandatory=$true)][string]$Root, [Parameter(Mandatory=$true)][string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
  if ($pathFull.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)) {
    return $pathFull.Substring($prefix.Length).Replace('\','/')
  }
  return $pathFull
}

function Test-R6EvidenceAnchorAnnotationRequest {
  param([Parameter(Mandatory=$true)][object]$Request)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in @('schema_id','schema_version','annotation_id','session_id','claim_ref','visible_quote','original_capture_ref','capture_viewport','normalized_region','emphasis_style','source_fact_layer','creator_commentary_layer','output_artifact_id','output_relative_path','requested_at')) {
    if (-not (Test-R6HasProperty -Value $Request -Name $name)) { Add-R6ValidationError $errors "annotation_request_missing:$name" }
  }
  if ($errors.Count -gt 0) { return [object[]]$errors.ToArray() }
  if ($Request.schema_id -ne 'taoge://r6/evidence-anchor-annotation-request/v0.1' -or [string]$Request.schema_version -ne '0.1.0') { Add-R6ValidationError $errors 'annotation_request_version_invalid' }
  if (-not (Test-R6IdValue $Request.annotation_id) -or -not (Test-R6IdValue $Request.session_id) -or -not (Test-R6IdValue $Request.output_artifact_id)) { Add-R6ValidationError $errors 'annotation_request_id_invalid' }
  if (-not (Test-R6RelativePathValue $Request.original_capture_ref.relative_path) -or -not (Test-R6RelativePathValue $Request.output_relative_path)) { Add-R6ValidationError $errors 'annotation_request_path_invalid' }
  if (-not (Test-R6Sha256Value (([string]$Request.original_capture_ref.sha256) -replace '^sha256:',''))) { Add-R6ValidationError $errors 'annotation_request_capture_digest_invalid' }
  if ([int]$Request.capture_viewport.width -lt 320 -or [int]$Request.capture_viewport.height -lt 320) { Add-R6ValidationError $errors 'annotation_request_viewport_invalid' }
  foreach ($axis in @('x','y','width','height')) {
    [double]$value = $Request.normalized_region.$axis
    if ($value -lt 0 -or $value -gt 1) { Add-R6ValidationError $errors "annotation_request_region_invalid:$axis" }
  }
  if ([double]$Request.normalized_region.width -le 0 -or [double]$Request.normalized_region.height -le 0 -or ([double]$Request.normalized_region.x + [double]$Request.normalized_region.width) -gt 1.000001 -or ([double]$Request.normalized_region.y + [double]$Request.normalized_region.height) -gt 1.000001) { Add-R6ValidationError $errors 'annotation_request_region_outside_capture' }
  if ($Request.emphasis_style -notin @('underline','highlight','box','circle','magnify','table_row','table_column','none_proven_visible')) { Add-R6ValidationError $errors 'annotation_request_style_invalid' }
  if ([string]$Request.visible_quote.extraction_method -eq 'visual_verified' -and ([string]$Request.visible_quote.verification_actor -notin @('codex_visual_review','human_review') -or [string]::IsNullOrWhiteSpace([string]$Request.visible_quote.review_ref) -or [string]::IsNullOrWhiteSpace([string]$Request.visible_quote.actual_observation))) { Add-R6ValidationError $errors 'annotation_request_visual_verification_missing' }
  if ([string]$Request.source_fact_layer.label -eq [string]$Request.creator_commentary_layer.label) { Add-R6ValidationError $errors 'annotation_request_layers_not_distinct' }
  return [object[]]$errors.ToArray()
}

function Get-R6AnnotationRequestDigest {
  param([Parameter(Mandatory=$true)][object]$Request)
  $stable = [ordered]@{
    schema_id=$Request.schema_id;schema_version=$Request.schema_version;annotation_id=$Request.annotation_id;session_id=$Request.session_id
    claim_ref=$Request.claim_ref;visible_quote=$Request.visible_quote;original_capture_ref=$Request.original_capture_ref;capture_viewport=$Request.capture_viewport
    normalized_region=$Request.normalized_region;emphasis_style=$Request.emphasis_style;source_fact_layer=$Request.source_fact_layer
    creator_commentary_layer=$Request.creator_commentary_layer;output_artifact_id=$Request.output_artifact_id;output_relative_path=$Request.output_relative_path
  }
  return 'sha256:' + (Get-R6StringSha256 -Text ($stable | ConvertTo-Json -Depth 20 -Compress))
}

function Test-R6AnnotationSvgIntegrity {
  param([string]$Path,[string]$RequestDigest)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  try {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $text -match '</svg>\s*$' -and $text.Contains($RequestDigest)
  } catch { return $false }
}

function Invoke-R6EvidenceAnchorAnnotation {
  param(
    [Parameter(Mandatory=$true)][object]$Request,
    [Parameter(Mandatory=$true)][string]$SessionRoot,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$RecordPath
  )
  $errors = @(Test-R6EvidenceAnchorAnnotationRequest -Request $Request)
  if ($errors.Count -gt 0) { throw "annotation_request_invalid:$([string]::Join(',',@($errors)))" }
  $rootFull = [System.IO.Path]::GetFullPath($SessionRoot).TrimEnd('\','/')
  $rootPrefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
  $captureFull = [System.IO.Path]::GetFullPath((Join-Path $rootFull ([string]$Request.original_capture_ref.relative_path)))
  $outputFull = [System.IO.Path]::GetFullPath($OutputPath)
  $recordFull = [System.IO.Path]::GetFullPath($RecordPath)
  foreach ($path in @($captureFull,$outputFull,$recordFull)) { if (-not $path.StartsWith($rootPrefix,[System.StringComparison]::OrdinalIgnoreCase)) { throw "annotation_root_escape:$path" } }
  if (-not (Test-Path -LiteralPath $captureFull -PathType Leaf)) { throw 'annotation_capture_missing' }
  $captureHash = Get-TaogeFileSha256 -Path $captureFull
  $expectedCaptureHash = ([string]$Request.original_capture_ref.sha256) -replace '^sha256:',''
  if ($captureHash -ne $expectedCaptureHash) { throw 'annotation_capture_hash_mismatch' }
  $requestDigest = Get-R6AnnotationRequestDigest -Request $Request
  $attempts = @();$attemptNo = 1
  if (Test-Path -LiteralPath $recordFull -PathType Leaf) {
    $previous = Get-Content -LiteralPath $recordFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$previous.annotation_id -ne [string]$Request.annotation_id -or [string]$previous.request_digest -ne $requestDigest -or [string]$previous.output_relative_path -ne [string]$Request.output_relative_path) { throw 'annotation_revision_required:request_identity_changed' }
    $attempts = @($previous.attempts)
    $attemptNo = $attempts.Count + 1
    if ([string]$previous.operation_status -in @('succeeded','reconciled') -and (Test-R6AnnotationSvgIntegrity -Path $outputFull -RequestDigest $requestDigest)) {
      $actualHash = Get-TaogeFileSha256 -Path $outputFull
      if ($actualHash -ne (([string]$previous.annotation.annotated_asset_ref.sha256) -replace '^sha256:','')) { throw 'annotation_revision_required:completed_output_hash_mismatch' }
      return [pscustomobject]@{status='pass';action='reused_verified';annotation=$previous.annotation;record_path=(Get-R6RelativePath $rootFull $recordFull);asset_path=(Get-R6RelativePath $rootFull $outputFull);asset_sha256=$actualHash}
    }
    if ([string]$previous.operation_status -eq 'started' -and (Test-R6AnnotationSvgIntegrity -Path $outputFull -RequestDigest $requestDigest)) {
      $assetHash = Get-TaogeFileSha256 -Path $outputFull
      $attempt = [pscustomobject][ordered]@{attempt_id="ATT-$($Request.annotation_id)-$attemptNo";attempt_no=$attemptNo;status='reconciled';outcome_ref="OUT-$($Request.annotation_id)-$attemptNo"}
      $attempts += @($attempt)
      $annotation = [pscustomobject][ordered]@{annotation_id=[string]$Request.annotation_id;claim_ref=$Request.claim_ref;visible_quote=$Request.visible_quote;original_capture_ref=$Request.original_capture_ref;normalized_region=$Request.normalized_region;emphasis_style=[string]$Request.emphasis_style;source_fact_layer=$Request.source_fact_layer;creator_commentary_layer=$Request.creator_commentary_layer;overlay_spec_digest=$requestDigest;annotated_asset_ref=[pscustomobject]@{artifact_id=[string]$Request.output_artifact_id;relative_path=[string]$Request.output_relative_path;sha256='sha256:'+$assetHash};attempts=[object[]]$attempts;current_outcome=[pscustomobject]@{status='reconciled';output_ref=[pscustomobject]@{artifact_id=[string]$Request.output_artifact_id;relative_path=[string]$Request.output_relative_path;sha256='sha256:'+$assetHash}}}
      $record = [pscustomobject][ordered]@{schema_id='taoge://r6/evidence-anchor-annotation-record/v0.1';schema_version='0.1.0';annotation_id=[string]$Request.annotation_id;session_id=[string]$Request.session_id;request_digest=$requestDigest;output_relative_path=[string]$Request.output_relative_path;operation_status='reconciled';annotation=$annotation;attempts=[object[]]$attempts;completed_at=[DateTimeOffset]::UtcNow.ToString('o')}
      Write-TaogeUtf8NoBomJson -Path $recordFull -Value $record -Depth 30
      return [pscustomobject]@{status='pass';action='reconciled_existing_output';annotation=$annotation;record_path=(Get-R6RelativePath $rootFull $recordFull);asset_path=(Get-R6RelativePath $rootFull $outputFull);asset_sha256=$assetHash}
    }
  }
  $attemptId = "ATT-$($Request.annotation_id)-$attemptNo"
  $startedAttempt = [pscustomobject][ordered]@{attempt_id=$attemptId;attempt_no=$attemptNo;status='started';outcome_ref=$null}
  $attempts += @($startedAttempt)
  $startedRecord = [pscustomobject][ordered]@{schema_id='taoge://r6/evidence-anchor-annotation-record/v0.1';schema_version='0.1.0';annotation_id=[string]$Request.annotation_id;session_id=[string]$Request.session_id;request_digest=$requestDigest;output_relative_path=[string]$Request.output_relative_path;operation_status='started';annotation=$null;attempts=[object[]]$attempts;started_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-TaogeUtf8NoBomJson -Path $recordFull -Value $startedRecord -Depth 30
  try {
    $bytes = [System.IO.File]::ReadAllBytes($captureFull);$base64 = [System.Convert]::ToBase64String($bytes)
    $extension = [System.IO.Path]::GetExtension($captureFull).ToLowerInvariant();$mime = if ($extension -in @('.jpg','.jpeg')) { 'image/jpeg' } else { 'image/png' }
    [double]$canvasW=[int]$Request.capture_viewport.width;[double]$canvasH=[int]$Request.capture_viewport.height
    [double]$x=[Math]::Round([double]$Request.normalized_region.x*$canvasW,2);[double]$y=[Math]::Round([double]$Request.normalized_region.y*$canvasH,2)
    [double]$w=[Math]::Round([double]$Request.normalized_region.width*$canvasW,2);[double]$h=[Math]::Round([double]$Request.normalized_region.height*$canvasH,2)
    $stroke='#F59E0B';$markup=switch([string]$Request.emphasis_style){
      'underline'{'<line x1="{0}" y1="{1}" x2="{2}" y2="{1}" stroke="{3}" stroke-width="10" stroke-linecap="round"/>'-f$x,[Math]::Round($y+$h-4,2),[Math]::Round($x+$w,2),$stroke}
      'highlight'{'<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.25"/>'-f$x,$y,$w,$h,$stroke}
      'box'{'<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="none" stroke="{4}" stroke-width="8" rx="8"/>'-f$x,$y,$w,$h,$stroke}
      'circle'{'<ellipse cx="{0}" cy="{1}" rx="{2}" ry="{3}" fill="none" stroke="{4}" stroke-width="8"/>'-f[Math]::Round($x+$w/2,2),[Math]::Round($y+$h/2,2),[Math]::Round($w/2,2),[Math]::Round($h/2,2),$stroke}
      'magnify'{'<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="none" stroke="{4}" stroke-width="12" rx="12"/>'-f$x,$y,$w,$h,$stroke}
      'table_row'{'<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.18" stroke="{4}" stroke-width="5"/>'-f$x,$y,$w,$h,$stroke}
      'table_column'{'<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.18" stroke="{4}" stroke-width="5"/>'-f$x,$y,$w,$h,$stroke}
      default{''}
    }
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{1}" viewBox="0 0 {0} {1}"><metadata>{2}</metadata><image href="data:{3};base64,{4}" x="0" y="0" width="{0}" height="{1}" preserveAspectRatio="none"/>{5}</svg>' -f [int]$canvasW,[int]$canvasH,$requestDigest,$mime,$base64,$markup
    Write-TaogeUtf8NoBomText -Path $outputFull -Text $svg -EnsureFinalNewline
    if (-not (Test-R6AnnotationSvgIntegrity -Path $outputFull -RequestDigest $requestDigest)) { throw 'annotation_output_integrity_failed' }
    $assetHash = Get-TaogeFileSha256 -Path $outputFull;$outcomeId="OUT-$($Request.annotation_id)-$attemptNo"
    $attempts[-1] = [pscustomobject][ordered]@{attempt_id=$attemptId;attempt_no=$attemptNo;status='succeeded';outcome_ref=$outcomeId}
    $assetRef=[pscustomobject]@{artifact_id=[string]$Request.output_artifact_id;relative_path=[string]$Request.output_relative_path;sha256='sha256:'+$assetHash}
    $annotation=[pscustomobject][ordered]@{annotation_id=[string]$Request.annotation_id;claim_ref=$Request.claim_ref;visible_quote=$Request.visible_quote;original_capture_ref=$Request.original_capture_ref;normalized_region=$Request.normalized_region;emphasis_style=[string]$Request.emphasis_style;source_fact_layer=$Request.source_fact_layer;creator_commentary_layer=$Request.creator_commentary_layer;overlay_spec_digest=$requestDigest;annotated_asset_ref=$assetRef;attempts=[object[]]$attempts;current_outcome=[pscustomobject]@{status='succeeded';output_ref=$assetRef}}
    $record=[pscustomobject][ordered]@{schema_id='taoge://r6/evidence-anchor-annotation-record/v0.1';schema_version='0.1.0';annotation_id=[string]$Request.annotation_id;session_id=[string]$Request.session_id;request_digest=$requestDigest;output_relative_path=[string]$Request.output_relative_path;operation_status='succeeded';annotation=$annotation;attempts=[object[]]$attempts;completed_at=[DateTimeOffset]::UtcNow.ToString('o')}
    Write-TaogeUtf8NoBomJson -Path $recordFull -Value $record -Depth 30
    return [pscustomobject]@{status='pass';action='rendered';annotation=$annotation;record_path=(Get-R6RelativePath $rootFull $recordFull);asset_path=(Get-R6RelativePath $rootFull $outputFull);asset_sha256=$assetHash}
  } catch {
    $attempts[-1] = [pscustomobject][ordered]@{attempt_id=$attemptId;attempt_no=$attemptNo;status='failed';outcome_ref=$null}
    $failed=[pscustomobject][ordered]@{schema_id='taoge://r6/evidence-anchor-annotation-record/v0.1';schema_version='0.1.0';annotation_id=[string]$Request.annotation_id;session_id=[string]$Request.session_id;request_digest=$requestDigest;output_relative_path=[string]$Request.output_relative_path;operation_status='failed';annotation=$null;attempts=[object[]]$attempts;failed_at=[DateTimeOffset]::UtcNow.ToString('o');error_category='evidence_annotation_error';error_message=[string]$_.Exception.Message}
    Write-TaogeUtf8NoBomJson -Path $recordFull -Value $failed -Depth 30
    throw
  }
}

function Render-R6EvidencePip {
  param(
    [Parameter(Mandatory=$true)][object]$Bundle,
    [Parameter(Mandatory=$true)][string]$SessionRoot,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$SidecarPath
  )

  $validation = Test-R6EvidenceBundle -Data $Bundle -SessionRoot $SessionRoot
  if ($validation.status -ne 'pass') { throw "evidence_bundle_invalid:$([string]::Join(',',@($validation.errors)))" }
  if ($Bundle.pip.asset_role -ne 'evidence_support') { throw 'evidence_bundle_not_render_eligible' }

  $rootFull = [System.IO.Path]::GetFullPath($SessionRoot)
  $outputFull = [System.IO.Path]::GetFullPath($OutputPath)
  $sidecarFull = [System.IO.Path]::GetFullPath($SidecarPath)
  $rootPrefix = $rootFull.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
  foreach ($path in @($outputFull,$sidecarFull)) {
    if (-not $path.StartsWith($rootPrefix,[System.StringComparison]::OrdinalIgnoreCase)) { throw "output_root_escape:$path" }
  }

  $screenshotFull = [System.IO.Path]::GetFullPath((Join-Path $rootFull ([string]$Bundle.capture.screenshot_path)))
  $screenshotHash = Get-TaogeFileSha256 -Path $screenshotFull
  $rendererDigest = Get-TaogeFileSha256 -Path $script:R6RuntimeFile
  $templateDigest = Get-R6StringSha256 -Text $script:R6TemplateIdentity
  $businessInput = [ordered]@{
    schema_id=$Bundle.schema_id
    schema_version=$Bundle.schema_version
    session_id=$Bundle.session_id
    account_snapshot_id=$Bundle.account.account_snapshot_id
    evidence_visual_grammar=$Bundle.account.evidence_visual_grammar
    claim=$Bundle.claim
    source=$Bundle.source
    capture=[ordered]@{
      capture_id=$Bundle.capture.capture_id
      source_id=$Bundle.capture.source_id
      captured_url=$Bundle.capture.captured_url
      fixture_mode=$Bundle.capture.fixture_mode
      capture_at=$Bundle.capture.capture_at
      viewport=$Bundle.capture.viewport
      selected_target=$Bundle.capture.selected_target
      screenshot_path=$Bundle.capture.screenshot_path
      sha256=$Bundle.capture.sha256
      attempt_number=$Bundle.capture.attempt_number
      attempt_history=$Bundle.capture.attempt_history
      capture_status=$Bundle.capture.capture_status
      capture_integrity_status=$Bundle.capture.capture_integrity_status
      image_production_path=$Bundle.capture.image_production_path
    }
    binding=$Bundle.binding
    evidence_anchor_annotation=$(if(Test-R6HasProperty -Value $Bundle -Name 'evidence_anchor_annotation'){$Bundle.evidence_anchor_annotation}else{$null})
    semantic_normalization_registry_ref=$(if(Test-R6HasProperty -Value $Bundle -Name 'semantic_normalization_registry_ref'){$Bundle.semantic_normalization_registry_ref}else{$null})
    semantic_fact_bindings=$(if(Test-R6HasProperty -Value $Bundle -Name 'semantic_fact_bindings'){$Bundle.semantic_fact_bindings}else{@()})
    semantic_parity_result=$(if(Test-R6HasProperty -Value $Bundle -Name 'semantic_parity_result'){$Bundle.semantic_parity_result}else{$null})
    pip=[ordered]@{
      pip_id=$Bundle.pip.pip_id
      binding_id=$Bundle.pip.binding_id
      asset_role=$Bundle.pip.asset_role
      creator_commentary=$Bundle.pip.creator_commentary
      copyright_review_status=$Bundle.pip.copyright_review_status
      privacy_review_status=$Bundle.pip.privacy_review_status
      publish_risk_status=$Bundle.pip.publish_risk_status
    }
    screenshot_sha256=$screenshotHash
    renderer_digest=$rendererDigest
    template_digest=$templateDigest
  }
  $cacheMaterial = $businessInput | ConvertTo-Json -Depth 30 -Compress
  $cacheKey = Get-R6StringSha256 -Text $cacheMaterial

  if ((Test-Path -LiteralPath $outputFull -PathType Leaf) -and (Test-Path -LiteralPath $sidecarFull -PathType Leaf)) {
    try {
      $previous = Get-Content -LiteralPath $sidecarFull -Raw -Encoding UTF8 | ConvertFrom-Json
      $existingHash = Get-TaogeFileSha256 -Path $outputFull
      if ($previous.cache_key -eq $cacheKey -and $previous.asset_sha256 -eq $existingHash) {
        return [pscustomobject]@{status='pass';action='reused_verified';asset_path=(Get-R6RelativePath $rootFull $outputFull);asset_sha256=$existingHash;sidecar_path=(Get-R6RelativePath $rootFull $sidecarFull);cache_key=$cacheKey}
      }
    } catch {
      # A malformed prior sidecar is not reusable; render a new deterministic revision at the requested path.
    }
  }

  $bytes = [System.IO.File]::ReadAllBytes($screenshotFull)
  $base64 = [System.Convert]::ToBase64String($bytes)
  $extension = [System.IO.Path]::GetExtension($screenshotFull).ToLowerInvariant()
  $mime = if ($extension -eq '.jpg' -or $extension -eq '.jpeg') { 'image/jpeg' } else { 'image/png' }

  $crop = $Bundle.capture.selected_target.crop
  [double]$targetX = 60
  [double]$targetY = 60
  [double]$targetW = 960
  [double]$targetH = 760
  [double]$scaleX = $targetW / [double]$crop.width
  [double]$scaleY = $targetH / [double]$crop.height
  [double]$scale = [Math]::Min($scaleX,$scaleY)
  [double]$visibleW = [double]$crop.width * $scale
  [double]$visibleH = [double]$crop.height * $scale
  [double]$imageX = $targetX + (($targetW - $visibleW) / 2) - ([double]$crop.x * $scale)
  [double]$imageY = $targetY + (($targetH - $visibleH) / 2) - ([double]$crop.y * $scale)
  [double]$imageW = [double]$Bundle.capture.viewport.width * $scale
  [double]$imageH = [double]$Bundle.capture.viewport.height * $scale

  $sourceLabel = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.account.evidence_visual_grammar.source_label) 16)
  $commentaryLabel = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.account.evidence_visual_grammar.commentary_label) 16)
  $publisher = [string]$Bundle.source.publisher
  $title = [string]$Bundle.source.title
  $published = if ($null -eq $Bundle.source.published_at -or [string]::IsNullOrWhiteSpace([string]$Bundle.source.published_at)) { '未标注' } else { ([string]$Bundle.source.published_at).Substring(0,[Math]::Min(10,([string]$Bundle.source.published_at).Length)) }
  $captured = ([string]$Bundle.capture.capture_at).Substring(0,[Math]::Min(10,([string]$Bundle.capture.capture_at).Length))
  $sourceMeta = ConvertTo-R6XmlText (Get-R6TextExcerpt "$publisher · $title" 30)
  $dateMeta = ConvertTo-R6XmlText "发布 $published · 捕获 $captured"
  $commentary = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.pip.creator_commentary) 25)
  $claimExcerpt = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.claim.source_text) 52)
  $claimIdDisplay = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.claim.claim_id) 18)
  $captureIdDisplay = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$Bundle.capture.capture_id) 18)
  $sourceColor = [string]$Bundle.account.evidence_visual_grammar.source_color
  $commentaryColor = [string]$Bundle.account.evidence_visual_grammar.commentary_color
  $annotationMarkup = ''
  $sourceFactText = $claimExcerpt
  $creatorCommentaryText = $commentary
  if ((Test-R6HasProperty -Value $Bundle -Name 'evidence_anchor_annotation') -and $null -ne $Bundle.evidence_anchor_annotation) {
    $annotation = $Bundle.evidence_anchor_annotation
    $sourceFactText = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$annotation.source_fact_layer.text) 34)
    $creatorCommentaryText = ConvertTo-R6XmlText (Get-R6TextExcerpt ([string]$annotation.creator_commentary_layer.text) 25)
    $region = $annotation.normalized_region
    [double]$regionX = $imageX + ([double]$region.x * [double]$Bundle.capture.viewport.width * $scale)
    [double]$regionY = $imageY + ([double]$region.y * [double]$Bundle.capture.viewport.height * $scale)
    [double]$regionW = [double]$region.width * [double]$Bundle.capture.viewport.width * $scale
    [double]$regionH = [double]$region.height * [double]$Bundle.capture.viewport.height * $scale
    [double]$left = [Math]::Max($targetX,[Math]::Min($targetX + $targetW,$regionX))
    [double]$top = [Math]::Max($targetY,[Math]::Min($targetY + $targetH,$regionY))
    [double]$right = [Math]::Max($left,[Math]::Min($targetX + $targetW,$regionX + $regionW))
    [double]$bottom = [Math]::Max($top,[Math]::Min($targetY + $targetH,$regionY + $regionH))
    [double]$displayW = $right - $left
    [double]$displayH = $bottom - $top
    if ($displayW -gt 1 -and $displayH -gt 1) {
      $x=[Math]::Round($left,2);$y=[Math]::Round($top,2);$w=[Math]::Round($displayW,2);$h=[Math]::Round($displayH,2)
      $annotationMarkup = switch ([string]$annotation.emphasis_style) {
        'underline' { '<line x1="{0}" y1="{1}" x2="{2}" y2="{1}" stroke="{3}" stroke-width="10" stroke-linecap="round"/>' -f $x,[Math]::Round($bottom-4,2),[Math]::Round($right,2),$commentaryColor }
        'highlight' { '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.25"/>' -f $x,$y,$w,$h,$commentaryColor }
        'box' { '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="none" stroke="{4}" stroke-width="8" rx="8"/>' -f $x,$y,$w,$h,$commentaryColor }
        'circle' { '<ellipse cx="{0}" cy="{1}" rx="{2}" ry="{3}" fill="none" stroke="{4}" stroke-width="8"/>' -f [Math]::Round($left+$displayW/2,2),[Math]::Round($top+$displayH/2,2),[Math]::Round($displayW/2,2),[Math]::Round($displayH/2,2),$commentaryColor }
        'magnify' { '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="none" stroke="{4}" stroke-width="12" rx="12"/>' -f $x,$y,$w,$h,$commentaryColor }
        'table_row' { '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.18" stroke="{4}" stroke-width="5"/>' -f $x,$y,$w,$h,$commentaryColor }
        'table_column' { '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" fill-opacity="0.18" stroke="{4}" stroke-width="5"/>' -f $x,$y,$w,$h,$commentaryColor }
        default { '' }
      }
    }
  }

  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350" viewBox="0 0 1080 1350" role="img" aria-labelledby="title desc">
  <title id="title">新闻证据画中画：$claimExcerpt</title>
  <desc id="desc">来源事实与创作者解读分层展示，来源截图未使用生成式图片。</desc>
  <defs><clipPath id="sourceClip"><rect x="60" y="60" width="960" height="760" rx="28"/></clipPath></defs>
  <rect width="1080" height="1350" fill="#0b0f19"/>
  <g clip-path="url(#sourceClip)">
    <rect x="60" y="60" width="960" height="760" fill="#f7f8fa"/>
    <image href="data:$mime;base64,$base64" x="$([Math]::Round($imageX,2))" y="$([Math]::Round($imageY,2))" width="$([Math]::Round($imageW,2))" height="$([Math]::Round($imageH,2))" preserveAspectRatio="none"/>
    $annotationMarkup
  </g>
  <rect x="60" y="60" width="960" height="760" rx="28" fill="none" stroke="$sourceColor" stroke-width="8"/>
  <rect x="60" y="850" width="960" height="170" rx="26" fill="$sourceColor"/>
  <text x="100" y="892" fill="#ffffff" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="28" font-weight="700">$sourceLabel</text>
  <text x="100" y="932" fill="#ffffff" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="26" font-weight="700">$sourceFactText</text>
  <text x="100" y="972" fill="#ffffff" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="24">$sourceMeta</text>
  <text x="100" y="1006" fill="#ffffff" opacity="0.86" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="21">$dateMeta</text>
  <rect x="60" y="1045" width="960" height="245" rx="26" fill="$commentaryColor"/>
  <text x="100" y="1102" fill="#ffffff" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="30" font-weight="700">$commentaryLabel</text>
  <text x="100" y="1165" fill="#ffffff" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="34" font-weight="700">$creatorCommentaryText</text>
  <text x="100" y="1252" fill="#ffffff" opacity="0.75" font-family="Consolas, monospace" font-size="19">claim $claimIdDisplay · capture $captureIdDisplay</text>
  <text x="60" y="1328" fill="#aab2c0" font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" font-size="18">页面截图仅记录来源在捕获时点的可见内容；事实判断见交付页证据状态。</text>
</svg>
"@

  Write-TaogeUtf8NoBomText -Path $outputFull -Text $svg -EnsureFinalNewline
  $assetHash = Get-TaogeFileSha256 -Path $outputFull
  $sidecar = [ordered]@{
    schema_id='taoge://r6/evidence-pip-sidecar/v0.1'
    schema_version='0.1.0'
    pip_id=$Bundle.pip.pip_id
    claim_id=$Bundle.claim.claim_id
    claim_text=[string]$Bundle.claim.source_text
    source_id=$Bundle.source.source_id
    publisher=[string]$Bundle.source.publisher
    canonical_url=[string]$Bundle.source.canonical_url
    source_title=[string]$Bundle.source.title
    published_at=$Bundle.source.published_at
    source_access_status=[string]$Bundle.source.source_access_status
    capture_id=$Bundle.capture.capture_id
    capture_at=[string]$Bundle.capture.capture_at
    capture_attempt_number=[int]$Bundle.capture.attempt_number
    capture_attempt_history=@($Bundle.capture.attempt_history)
    binding_id=$Bundle.binding.binding_id
    image_production_path='source_capture'
    source_screenshot_sha256=$screenshotHash
    renderer_digest=$rendererDigest
    template_digest=$templateDigest
    cache_key=$cacheKey
    asset_path=(Get-R6RelativePath $rootFull $outputFull)
    asset_sha256=$assetHash
    source_label=[string]$Bundle.account.evidence_visual_grammar.source_label
    commentary_label=[string]$Bundle.account.evidence_visual_grammar.commentary_label
    creator_commentary=[string]$Bundle.pip.creator_commentary
    claim_evidence_status=[string]$Bundle.binding.claim_evidence_status
    binding_rationale=[string]$Bundle.binding.rationale
    render_status='rendered'
  }
  Write-TaogeUtf8NoBomJson -Path $sidecarFull -Value $sidecar -Depth 12
  return [pscustomobject]@{status='pass';action='rendered';asset_path=$sidecar.asset_path;asset_sha256=$assetHash;sidecar_path=(Get-R6RelativePath $rootFull $sidecarFull);cache_key=$cacheKey}
}
