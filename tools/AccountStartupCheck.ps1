Set-StrictMode -Version Latest

function Get-R5H5PropertyValue {
  param(
    [Parameter(Mandatory=$false)]$Object,
    [Parameter(Mandatory=$true)][string]$Name
  )
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Test-R5H5NonEmptyString {
  param([Parameter(Mandatory=$false)]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Get-R5H5NonEmptyArray {
  param([Parameter(Mandatory=$false)]$Value)
  $items = @($Value | Where-Object { Test-R5H5NonEmptyString $_ })
  return ,$items
}

function Resolve-R5AccountStartupCheck {
  param([Parameter(Mandatory=$true)]$InputObject)

  $account = Get-R5H5PropertyValue $InputObject 'account'
  $accountSlug = [string](Get-R5H5PropertyValue $account 'account_slug')
  $sessionId = [string](Get-R5H5PropertyValue $InputObject 'session_id')
  $taskType = [string](Get-R5H5PropertyValue $InputObject 'task_type')
  $previousAccountSlug = [string](Get-R5H5PropertyValue $InputObject 'previous_account_slug')
  $missingFields = [System.Collections.Generic.List[string]]::new()
  $blockingFields = [System.Collections.Generic.List[string]]::new()
  $nonBlockingFields = [System.Collections.Generic.List[string]]::new()
  $unaskedBlockingFields = [System.Collections.Generic.List[string]]::new()
  $questions = [System.Collections.Generic.List[object]]::new()

  if ($taskType -notin @('hotspot_research', 'topic_selection', 'content_production', 'visual_delivery')) {
    throw "task_type_invalid:$taskType"
  }
  if (-not (Test-R5H5NonEmptyString $accountSlug)) { throw 'account_slug_missing' }
  if (-not (Test-R5H5NonEmptyString $sessionId)) { throw 'session_id_missing' }

  function Add-R5H5Question {
    param([string]$QuestionId, [string[]]$Fields, [string]$Question)
    foreach ($field in $Fields) {
      if (-not $missingFields.Contains($field)) { $missingFields.Add($field) }
      if (-not $blockingFields.Contains($field)) { $blockingFields.Add($field) }
    }
    if ($questions.Count -lt 3) {
      $questions.Add([ordered]@{
        question_id = $QuestionId
        fields = @($Fields)
        question = $Question
      })
    } else {
      foreach ($field in $Fields) {
        if (-not $unaskedBlockingFields.Contains($field)) { $unaskedBlockingFields.Add($field) }
      }
    }
  }

  $platforms = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'publishing_platforms')
  $targetDuration = Get-R5H5PropertyValue $account 'target_duration'
  $publishingContextMissing = [System.Collections.Generic.List[string]]::new()
  if ($platforms.Count -eq 0) { $publishingContextMissing.Add('publishing_platforms') }
  if (-not (Test-R5H5NonEmptyString $targetDuration)) { $publishingContextMissing.Add('target_duration') }
  if ($publishingContextMissing.Count -gt 0) {
    Add-R5H5Question 'publishing_context' @($publishingContextMissing) '这个账号这段时间主要发在哪些平台？一条内容你希望大致控制在多长时间？'
  }

  $audiencePriority = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'audience_priority')
  if ($audiencePriority.Count -eq 0) {
    Add-R5H5Question 'audience_priority' @('audience_priority') '买车消费者、卖车用户和车商都可以讲；这段时间希望优先服务哪一类，还是三者均衡？'
  }

  $riskPolicy = [string](Get-R5H5PropertyValue $account 'high_risk_topic_policy')
  if ($riskPolicy -notin @('verify_mechanism_only', 'named_fact_with_sources')) {
    Add-R5H5Question 'high_risk_topic_policy' @('high_risk_topic_policy') '遇到代理履约、资金链、维权或事故等高风险话题，我默认只做交叉核验和行业机制拆解、不直接点名下结论；这条规则是否按此执行？'
  }

  $requiresRadarPolicy = $taskType -in @('hotspot_research', 'topic_selection', 'content_production', 'visual_delivery')
  $radarPolicyRef = [string](Get-R5H5PropertyValue $account 'radar_policy_ref')
  $queryLexiconRef = [string](Get-R5H5PropertyValue $account 'query_lexicon_ref')
  $radarPolicyStatus = [string](Get-R5H5PropertyValue $account 'radar_policy_status')
  $policyIncomplete = $requiresRadarPolicy -and (
    -not (Test-R5H5NonEmptyString $radarPolicyRef) -or
    -not (Test-R5H5NonEmptyString $queryLexiconRef) -or
    $radarPolicyStatus -ne 'policy_active'
  )
  if ($policyIncomplete) {
    Add-R5H5Question 'radar_policy_setup' @('radar_policy_ref', 'query_lexicon_ref', 'radar_policy_status') '这个账号的热点策略或词库还没就绪；请先确认二手车优先策略和词库引用，再开始找热点。'
  }

  $requiresVisualIdentity = $taskType -eq 'visual_delivery'
  $visualIdentityRef = [string](Get-R5H5PropertyValue $account 'visual_identity_ref')
  $visualIdentityStatus = [string](Get-R5H5PropertyValue $account 'visual_identity_status')
  $columnTemplates = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'column_visual_template_refs')
  $visualIncomplete = -not (Test-R5H5NonEmptyString $visualIdentityRef) -or $visualIdentityStatus -ne 'identity_active' -or $columnTemplates.Count -eq 0
  if ($requiresVisualIdentity -and $visualIncomplete) {
    Add-R5H5Question 'visual_identity' @('visual_identity_ref', 'visual_identity_status', 'column_visual_template_refs') '这次要进入视觉交付；请先补齐这个账号的视觉身份和栏目模板，避免沿用别的账号的画面风格。'
  } elseif ($visualIncomplete) {
    foreach ($field in @('visual_identity_ref', 'visual_identity_status', 'column_visual_template_refs')) {
      $nonBlockingFields.Add($field)
    }
  }

  $blockedReason = [string](Get-R5H5PropertyValue $account 'startup_blocked_reason')
  $accountBlocked = (Test-R5H5NonEmptyString $blockedReason) -or $radarPolicyStatus -eq 'policy_blocked'
  if ($accountBlocked) {
    $result = 'account_blocked'
    $snapshotStatus = 'snapshot_blocked'
  } elseif ($policyIncomplete) {
    $result = 'account_policy_incomplete'
    $snapshotStatus = 'snapshot_policy_incomplete'
  } elseif ($blockingFields.Count -gt 0) {
    $result = 'account_needs_input'
    $snapshotStatus = 'snapshot_needs_input'
  } else {
    $result = 'account_ready'
    $snapshotStatus = 'snapshot_ready'
  }

  $snapshotRef = [string](Get-R5H5PropertyValue $InputObject 'account_snapshot_ref')
  if (-not (Test-R5H5NonEmptyString $snapshotRef)) {
    $snapshotRef = "accounts/$accountSlug/runs/$sessionId/intermediate/account-startup/account-snapshot.v0.1.json"
  }
  $nextSkill = if ($result -ne 'account_ready') {
    'propagation-router'
  } elseif ($taskType -eq 'hotspot_research') {
    'hotspot-topic-research'
  } elseif ($taskType -eq 'visual_delivery') {
    'static-visual-director'
  } else {
    'propagation-router'
  }

  return [ordered]@{
    schema_id = 'taoge://account/startup-check/v0.1'
    schema_version = 0.1
    account_slug = $accountSlug
    session_id = $sessionId
    task_type = $taskType
    startup_result = $result
    account_snapshot_ref = $snapshotRef
    account_snapshot_status = $snapshotStatus
    snapshot_write_allowed = ($result -eq 'account_ready')
    snapshot_write_status = 'not_written'
    source_account_slug = $accountSlug
    account_switch_isolated = ((Test-R5H5NonEmptyString $previousAccountSlug) -and $previousAccountSlug -ne $accountSlug)
    missing_fields = @($missingFields)
    blocking_fields = @($blockingFields)
    non_blocking_fields = @($nonBlockingFields | Select-Object -Unique)
    unasked_blocking_fields = @($unaskedBlockingFields)
    question_set_id = "QSET-$accountSlug-$taskType-v0.1"
    questions = @($questions)
    high_risk_topic_policy = if ($riskPolicy -in @('verify_mechanism_only', 'named_fact_with_sources')) { $riskPolicy } else { $null }
    next_skill = $nextSkill
    human_gate_required = ($result -ne 'account_ready')
  }
}

function New-R5AccountSessionSnapshot {
  param(
    [Parameter(Mandatory=$true)]$InputObject,
    [Parameter(Mandatory=$true)]$StartupCheck
  )
  $account = Get-R5H5PropertyValue $InputObject 'account'
  $publishingPlatforms = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'publishing_platforms')
  $audiencePriority = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'audience_priority')
  $columnVisualTemplates = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'column_visual_template_refs')
  return [ordered]@{
    schema_id = 'taoge://account/session-snapshot/v0.1'
    schema_version = 0.1
    snapshot_id = "AS-$($StartupCheck.session_id)-001"
    account_slug = $StartupCheck.account_slug
    session_id = $StartupCheck.session_id
    task_type = $StartupCheck.task_type
    account_profile_ref = [string](Get-R5H5PropertyValue $account 'account_profile_ref')
    account_snapshot_status = $StartupCheck.account_snapshot_status
    startup_result = $StartupCheck.startup_result
    source_account_slug = $StartupCheck.source_account_slug
    account_switch_isolated = [bool]$StartupCheck.account_switch_isolated
    captured_fields = [ordered]@{
      publishing_platforms = $publishingPlatforms
      target_duration = [string](Get-R5H5PropertyValue $account 'target_duration')
      audience_priority = $audiencePriority
      high_risk_topic_policy = $StartupCheck.high_risk_topic_policy
      radar_policy_ref = [string](Get-R5H5PropertyValue $account 'radar_policy_ref')
      query_lexicon_ref = [string](Get-R5H5PropertyValue $account 'query_lexicon_ref')
      visual_identity_ref = [string](Get-R5H5PropertyValue $account 'visual_identity_ref')
      column_visual_template_refs = $columnVisualTemplates
    }
    missing_fields = @($StartupCheck.missing_fields)
    blocking_fields = @($StartupCheck.blocking_fields)
    non_blocking_fields = @($StartupCheck.non_blocking_fields)
    question_set_id = $StartupCheck.question_set_id
    questions = @($StartupCheck.questions)
    next_skill = $StartupCheck.next_skill
  }
}
