Set-StrictMode -Version Latest

function Get-R5H6PropertyValue {
  param([Parameter(Mandatory=$false)]$Object,[Parameter(Mandatory=$true)][string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Test-R5H6NonEmptyString {
  param([Parameter(Mandatory=$false)]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Get-R5H6BindingDigest {
  param([Parameter(Mandatory=$true)]$Binding)
  $copy = [ordered]@{}
  if ($Binding -is [Collections.IDictionary]) {
    foreach ($key in $Binding.Keys) { if ([string]$key -ne 'binding_digest') { $copy[$key] = $Binding[$key] } }
  } else {
    foreach ($property in $Binding.PSObject.Properties) {
      if ($property.Name -ne 'binding_digest') { $copy[$property.Name] = $property.Value }
    }
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($copy | ConvertTo-Json -Depth 16 -Compress))
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($algorithm.ComputeHash($bytes)) -replace '-','').ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}

function Test-R5H6AccountRef {
  param([string]$Reference,[string]$AccountDirectoryKey)
  if (-not (Test-R5H6NonEmptyString $Reference)) { return $false }
  $normalized = $Reference.Replace('\','/').Trim()
  if ($normalized.StartsWith('/') -or $normalized.Contains('../') -or $normalized.Contains('//')) { return $false }
  return $normalized.StartsWith("accounts/$AccountDirectoryKey/")
}

function Test-R5AccountIdentityBinding {
  param([Parameter(Mandatory=$true)]$InputObject)
  $errors = [Collections.Generic.List[string]]::new()
  $account = Get-R5H6PropertyValue $InputObject 'account'
  $binding = Get-R5H6PropertyValue $InputObject 'identity_binding'
  $directoryKey = [string](Get-R5H6PropertyValue $account 'account_slug')
  $displayName = [string](Get-R5H6PropertyValue $account 'account_display_name')
  if (-not (Test-R5H6NonEmptyString $directoryKey)) { $errors.Add('account_directory_key_missing') }
  if (-not (Test-R5H6NonEmptyString $displayName)) { $errors.Add('account_display_name_missing') }
  if ($null -eq $binding) { $errors.Add('identity_binding_missing') }
  if ($errors.Count -gt 0) { return [ordered]@{ identity_verified=$false; errors=@($errors); binding_digest=$null; account_identity_id=$null; account_technical_slug=$null } }

  if ([string](Get-R5H6PropertyValue $binding 'schema_id') -ne 'taoge://account/identity-binding/v0.1') { $errors.Add('identity_binding_schema_invalid') }
  $identityId = [string](Get-R5H6PropertyValue $binding 'account_identity_id')
  $technicalSlug = [string](Get-R5H6PropertyValue $binding 'account_technical_slug')
  if (-not (Test-R5H6NonEmptyString $identityId)) { $errors.Add('account_identity_id_missing') }
  if ($technicalSlug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { $errors.Add('account_technical_slug_invalid') }
  if ([string](Get-R5H6PropertyValue $binding 'account_directory_key') -ne $directoryKey) { $errors.Add('binding_directory_key_mismatch') }
  if ([string](Get-R5H6PropertyValue $binding 'account_display_name') -ne $displayName) { $errors.Add('binding_display_name_mismatch') }
  if (-not (Test-R5H6AccountRef -Reference ([string](Get-R5H6PropertyValue $binding 'account_profile_ref')) -AccountDirectoryKey $directoryKey)) { $errors.Add('account_profile_ref_outside_account_root') }
  $declaredDigest = [string](Get-R5H6PropertyValue $binding 'binding_digest')
  if (-not (Test-R5H6NonEmptyString $declaredDigest)) { $errors.Add('binding_digest_missing') }
  elseif ($declaredDigest -ne (Get-R5H6BindingDigest -Binding $binding)) { $errors.Add('binding_digest_mismatch') }

  foreach ($field in @('account_identity_id','account_technical_slug')) {
    $provided = [string](Get-R5H6PropertyValue $account $field)
    $expected = if ($field -eq 'account_identity_id') { $identityId } else { $technicalSlug }
    if (-not (Test-R5H6NonEmptyString $provided)) { $errors.Add("account_$field`_missing") }
    elseif ($provided -ne $expected) { $errors.Add("account_$field`_mismatch") }
  }

  $assetBindings = @((Get-R5H6PropertyValue $binding 'asset_bindings'))
  if ($assetBindings.Count -eq 0) { $errors.Add('asset_bindings_missing') }
  $seen = @{}
  foreach ($asset in $assetBindings) {
    $assetType = [string](Get-R5H6PropertyValue $asset 'asset_type')
    $relativeRef = [string](Get-R5H6PropertyValue $asset 'relative_ref')
    $key = "$assetType|$relativeRef"
    if ($seen.ContainsKey($key)) { $errors.Add("asset_binding_duplicate:$key") } else { $seen[$key] = $true }
    if ($assetType -notin @('radar_policy','query_lexicon','hotspot_memory','visual_identity','column_visual_templates')) { $errors.Add("asset_type_invalid:$assetType") }
    if (-not (Test-R5H6AccountRef -Reference $relativeRef -AccountDirectoryKey $directoryKey)) { $errors.Add("asset_ref_outside_account_root:$assetType") }
    if ([string](Get-R5H6PropertyValue $asset 'account_identity_id') -ne $identityId) { $errors.Add("asset_identity_mismatch:$assetType") }
    if ([string](Get-R5H6PropertyValue $asset 'account_technical_slug') -ne $technicalSlug) { $errors.Add("asset_technical_slug_mismatch:$assetType") }
    if (-not (Test-R5H6NonEmptyString (Get-R5H6PropertyValue $asset 'sha256'))) { $errors.Add("asset_sha256_missing:$assetType") }
  }

  $accountRefs = [ordered]@{ radar_policy_ref='radar_policy'; query_lexicon_ref='query_lexicon'; visual_identity_ref='visual_identity' }
  foreach ($entry in $accountRefs.GetEnumerator()) {
    $reference = [string](Get-R5H6PropertyValue $account $entry.Key)
    if (Test-R5H6NonEmptyString $reference) {
      $match = @($assetBindings | Where-Object { [string](Get-R5H6PropertyValue $_ 'asset_type') -eq $entry.Value -and [string](Get-R5H6PropertyValue $_ 'relative_ref') -eq $reference })
      if ($match.Count -ne 1) { $errors.Add("account_ref_unbound:$($entry.Key)") }
    }
  }

  $previous = Get-R5H6PropertyValue $InputObject 'previous_account_snapshot'
  if ($null -ne $previous) {
    $previousDirectory = [string](Get-R5H6PropertyValue $previous 'source_account_slug')
    $previousIdentity = [string](Get-R5H6PropertyValue $previous 'account_identity_id')
    if ((Test-R5H6NonEmptyString $previousDirectory) -and $previousDirectory -ne $directoryKey -and $previousIdentity -eq $identityId) { $errors.Add('previous_snapshot_identity_reused_across_directory') }
  }

  return [ordered]@{
    identity_verified = ($errors.Count -eq 0)
    errors = @($errors)
    binding_digest = $declaredDigest
    account_identity_id = $identityId
    account_technical_slug = $technicalSlug
  }
}

function New-R5AccountIdentityBinding {
  param([Parameter(Mandatory=$true)]$Candidate)
  $binding = [ordered]@{
    schema_id = 'taoge://account/identity-binding/v0.1'
    schema_version = 0.1
    binding_id = [string](Get-R5H6PropertyValue $Candidate 'binding_id')
    binding_version = [string](Get-R5H6PropertyValue $Candidate 'binding_version')
    account_identity_id = [string](Get-R5H6PropertyValue $Candidate 'account_identity_id')
    account_technical_slug = [string](Get-R5H6PropertyValue $Candidate 'account_technical_slug')
    account_display_name = [string](Get-R5H6PropertyValue $Candidate 'account_display_name')
    account_directory_key = [string](Get-R5H6PropertyValue $Candidate 'account_directory_key')
    account_profile_ref = [string](Get-R5H6PropertyValue $Candidate 'account_profile_ref')
    account_profile_sha256 = [string](Get-R5H6PropertyValue $Candidate 'account_profile_sha256')
    asset_bindings = @((Get-R5H6PropertyValue $Candidate 'asset_bindings'))
  }
  $binding.binding_digest = Get-R5H6BindingDigest -Binding ([pscustomobject]$binding)
  return $binding
}
