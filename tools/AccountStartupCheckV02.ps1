Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'AccountStartupCheck.ps1')
. (Join-Path $PSScriptRoot 'AccountIdentityBinding.ps1')

function Resolve-R5H6AccountStartupCheck {
  param([Parameter(Mandatory=$true)]$InputObject)
  $account = Get-R5H6PropertyValue $InputObject 'account'
  $directoryKey = [string](Get-R5H6PropertyValue $account 'account_slug')
  $sessionId = [string](Get-R5H6PropertyValue $InputObject 'session_id')
  $taskType = [string](Get-R5H6PropertyValue $InputObject 'task_type')
  if ($taskType -notin @('hotspot_research','topic_selection','content_production','visual_delivery')) { throw "task_type_invalid:$taskType" }
  if (-not (Test-R5H6NonEmptyString $directoryKey)) { throw 'account_directory_key_missing' }
  if (-not (Test-R5H6NonEmptyString $sessionId)) { throw 'session_id_missing' }
  $identity = Test-R5AccountIdentityBinding -InputObject $InputObject
  $preflightErrors = @((Get-R5H6PropertyValue $InputObject 'identity_preflight_errors') | Where-Object { Test-R5H6NonEmptyString $_ })
  if ($preflightErrors.Count -gt 0) {
    $identity.identity_verified = $false
    $identity.errors = @($identity.errors) + @($preflightErrors | ForEach-Object { [string]$_ })
  }
  $snapshotRef = [string](Get-R5H6PropertyValue $InputObject 'account_snapshot_ref')
  if (-not (Test-R5H6NonEmptyString $snapshotRef)) { $snapshotRef = "accounts/$directoryKey/runs/$sessionId/intermediate/account-startup/account-snapshot.v0.2.json" }
  $previous = Get-R5H6PropertyValue $InputObject 'previous_account_snapshot'
  $previousIdentity = [string](Get-R5H6PropertyValue $previous 'account_identity_id')
  $switchIsolated = (Test-R5H6NonEmptyString $previousIdentity) -and $previousIdentity -ne $identity.account_identity_id

  if (-not $identity.identity_verified) {
    return [ordered]@{
      schema_id='taoge://account/startup-check/v0.2'; schema_version=0.2
      account_slug=$directoryKey; account_identity_id=$identity.account_identity_id; account_technical_slug=$identity.account_technical_slug
      account_display_name=[string](Get-R5H6PropertyValue $account 'account_display_name'); identity_binding_ref=[string](Get-R5H6PropertyValue $InputObject 'identity_binding_ref')
      identity_binding_digest=$identity.binding_digest; identity_verified=$false; identity_errors=@($identity.errors)
      session_id=$sessionId; task_type=$taskType; startup_result='account_identity_inconsistent'; account_snapshot_ref=$snapshotRef
      account_snapshot_status='snapshot_identity_inconsistent'; snapshot_write_allowed=$false; snapshot_write_status='not_written'
      source_account_slug=$directoryKey; account_switch_isolated=$false; missing_fields=@(); blocking_fields=@('account_identity_binding')
      non_blocking_fields=@(); unasked_blocking_fields=@(); question_set_id="QSET-$directoryKey-$taskType-v0.2"; questions=@()
      high_risk_topic_policy=$null; next_skill='propagation-router'; human_gate_required=$true
    }
  }

  $base = Resolve-R5AccountStartupCheck -InputObject $InputObject
  return [ordered]@{
    schema_id='taoge://account/startup-check/v0.2'; schema_version=0.2
    account_slug=$directoryKey; account_identity_id=$identity.account_identity_id; account_technical_slug=$identity.account_technical_slug
    account_display_name=[string](Get-R5H6PropertyValue $account 'account_display_name'); identity_binding_ref=[string](Get-R5H6PropertyValue $InputObject 'identity_binding_ref')
    identity_binding_digest=$identity.binding_digest; identity_verified=$true; identity_errors=@()
    session_id=$base.session_id; task_type=$base.task_type; startup_result=$base.startup_result; account_snapshot_ref=$snapshotRef
    account_snapshot_status=$base.account_snapshot_status; snapshot_write_allowed=($base.startup_result -eq 'account_ready'); snapshot_write_status='not_written'
    source_account_slug=$directoryKey; account_switch_isolated=$switchIsolated; missing_fields=@($base.missing_fields); blocking_fields=@($base.blocking_fields)
    non_blocking_fields=@($base.non_blocking_fields); unasked_blocking_fields=@($base.unasked_blocking_fields); question_set_id="QSET-$directoryKey-$taskType-v0.2"
    questions=@($base.questions); high_risk_topic_policy=$base.high_risk_topic_policy; next_skill=$base.next_skill; human_gate_required=$base.human_gate_required
  }
}

function New-R5H6AccountSessionSnapshot {
  param([Parameter(Mandatory=$true)]$InputObject,[Parameter(Mandatory=$true)]$StartupCheck)
  $account = Get-R5H6PropertyValue $InputObject 'account'
  $snapshotAt = [string](Get-R5H6PropertyValue $InputObject 'requested_at')
  if (-not (Test-R5H6NonEmptyString $snapshotAt)) { throw 'snapshot_time_missing' }
  $parsedSnapshotAt = [DateTimeOffset]::MinValue
  $timestampHasOffset = $snapshotAt -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
  if (-not $timestampHasOffset -or -not [DateTimeOffset]::TryParse($snapshotAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsedSnapshotAt)) { throw 'snapshot_time_invalid' }
  $platforms = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'publishing_platforms')
  $audiences = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'audience_priority')
  $templates = Get-R5H5NonEmptyArray (Get-R5H5PropertyValue $account 'column_visual_template_refs')
  return [ordered]@{
    schema_id='taoge://account/session-snapshot/v0.2'; schema_version=0.2; snapshot_id="AS-$($StartupCheck.session_id)-002"; snapshot_at=$snapshotAt
    account_slug=$StartupCheck.account_slug; account_identity_id=$StartupCheck.account_identity_id; account_technical_slug=$StartupCheck.account_technical_slug
    account_display_name=$StartupCheck.account_display_name; identity_binding_ref=$StartupCheck.identity_binding_ref; identity_binding_digest=$StartupCheck.identity_binding_digest
    identity_verified=[bool]$StartupCheck.identity_verified; identity_errors=@($StartupCheck.identity_errors); session_id=$StartupCheck.session_id; task_type=$StartupCheck.task_type
    account_profile_ref=[string](Get-R5H5PropertyValue $account 'account_profile_ref'); account_snapshot_status=$StartupCheck.account_snapshot_status; startup_result=$StartupCheck.startup_result
    source_account_slug=$StartupCheck.source_account_slug; account_switch_isolated=[bool]$StartupCheck.account_switch_isolated
    captured_fields=[ordered]@{ publishing_platforms=$platforms; target_duration=[string](Get-R5H5PropertyValue $account 'target_duration'); audience_priority=$audiences; high_risk_topic_policy=$StartupCheck.high_risk_topic_policy; radar_policy_ref=[string](Get-R5H5PropertyValue $account 'radar_policy_ref'); query_lexicon_ref=[string](Get-R5H5PropertyValue $account 'query_lexicon_ref'); visual_identity_ref=[string](Get-R5H5PropertyValue $account 'visual_identity_ref'); column_visual_template_refs=$templates }
    missing_fields=@($StartupCheck.missing_fields); blocking_fields=@($StartupCheck.blocking_fields); non_blocking_fields=@($StartupCheck.non_blocking_fields)
    question_set_id=$StartupCheck.question_set_id; questions=@($StartupCheck.questions); next_skill=$StartupCheck.next_skill
  }
}
