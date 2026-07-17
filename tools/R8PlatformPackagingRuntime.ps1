Set-StrictMode -Version 2.0

function Get-R8PlatformValue {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-R8PlatformStrings {
  param([object]$Value)
  $items = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Value) { return [string[]]$items.ToArray() }
  foreach ($item in @($Value)) {
    $text = [string]$item
    if (-not [string]::IsNullOrWhiteSpace($text)) {
      $items.Add($text.Trim())
    }
  }
  return [string[]]$items.ToArray()
}

function Test-R8PlatformPackageTargetContract {
  param(
    [Parameter(Mandatory = $true)][object]$Payload,
    [Parameter(Mandatory = $true)][object]$AccountSnapshot,
    [Parameter(Mandatory = $true)][string[]]$SupportedPlatforms
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $captured = Get-R8PlatformValue $AccountSnapshot 'captured_fields'
  $targets = @(Get-R8PlatformStrings (Get-R8PlatformValue $captured 'publishing_platforms'))
  $supported = @(Get-R8PlatformStrings $SupportedPlatforms | Select-Object -Unique)

  if ($supported.Count -eq 0) {
    $errors.Add('platform_supported_set_missing_or_empty')
  }

  if ($targets.Count -eq 0) {
    $errors.Add('platform_target_set_missing_or_empty')
  }
  $duplicateTargets = @($targets | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
  foreach ($item in $duplicateTargets) {
    $errors.Add("platform_target_duplicate:$item")
  }
  foreach ($target in @($targets | Select-Object -Unique)) {
    if ($target -notin @($supported)) {
      $errors.Add("platform_target_not_supported_by_current_contract:$target")
    }
  }

  $packages = @((Get-R8PlatformValue $Payload 'packages'))
  $actual = [System.Collections.Generic.List[string]]::new()
  foreach ($package in $packages) {
    $platform = [string](Get-R8PlatformValue $package 'platform')
    if ([string]::IsNullOrWhiteSpace($platform)) {
      $errors.Add('platform_package_item_platform_missing')
    } else {
      $actual.Add($platform.Trim())
    }
  }
  if ($actual.Count -eq 0) {
    $errors.Add('platform_package_set_missing_or_empty')
  }
  $duplicateActual = @($actual | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
  foreach ($item in $duplicateActual) {
    $errors.Add("platform_package_duplicate:$item")
  }

  foreach ($target in @($targets | Select-Object -Unique)) {
    if ($target -notin @($actual)) {
      $errors.Add("platform_package_selected_target_missing:$target")
    }
  }
  foreach ($platform in @($actual | Select-Object -Unique)) {
    if ($platform -notin @($targets)) {
      $errors.Add("platform_package_unselected_target_present:$platform")
    }
  }

  $primary = [string](Get-R8PlatformValue $Payload 'primary_platform')
  if ([string]::IsNullOrWhiteSpace($primary) -or $primary -notin @($targets)) {
    $errors.Add("platform_package_primary_not_selected:$primary")
  }
  if ($targets.Count -ne $packages.Count) {
    $errors.Add("platform_package_count_mismatch:expected=$($targets.Count);actual=$($packages.Count)")
  }

  return [string[]]$errors.ToArray()
}
