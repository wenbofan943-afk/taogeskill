function Get-R8H5SchemaProperty {
  param([object]$Object,[string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) {
      Write-Output -NoEnumerate $Object[$Name]
      return
    }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  Write-Output -NoEnumerate $property.Value
}

function Test-R8H5SchemaHasProperty {
  param([object]$Object,[string]$Name)
  if ($null -eq $Object) { return $false }
  if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
  return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-R8H5SchemaPropertyNames {
  param([object]$Object)
  if ($null -eq $Object) { return }
  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in $Object.Keys) { Write-Output ([string]$key) }
    return
  }
  foreach ($property in $Object.PSObject.Properties) { Write-Output ([string]$property.Name) }
}

function Get-R8H5SchemaItems {
  param([object]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [System.Array]) {
    foreach ($item in $Value) { Write-Output -NoEnumerate $item }
    return
  }
  Write-Output -NoEnumerate $Value
}

function Test-R8H5SchemaType {
  param([object]$Value,[string]$TypeName)
  switch ($TypeName) {
    'null' { return $null -eq $Value }
    'string' { return $Value -is [string] }
    'boolean' { return $Value -is [bool] }
    'integer' {
      return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or
        $Value -is [int64] -or $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64]
    }
    'number' {
      return (Test-R8H5SchemaType $Value 'integer') -or $Value -is [single] -or
        $Value -is [double] -or $Value -is [decimal]
    }
    'array' { return $Value -is [System.Array] }
    'object' {
      return $null -ne $Value -and $Value -isnot [string] -and
        $Value -isnot [System.Array] -and $Value -isnot [bool] -and $Value -isnot [ValueType]
    }
    default { return $false }
  }
}

function Resolve-R8H5SchemaReference {
  param([object]$RootSchema,[string]$Reference)
  if (-not $Reference.StartsWith('#/')) { throw "unsupported_schema_reference:$Reference" }
  $value = $RootSchema
  foreach ($rawSegment in $Reference.Substring(2).Split('/')) {
    $segment = $rawSegment.Replace('~1','/').Replace('~0','~')
    $value = Get-R8H5SchemaProperty $value $segment
    if ($null -eq $value) { throw "schema_reference_not_found:$Reference" }
  }
  return $value
}

function Test-R8H5SchemaNode {
  param(
    [object]$Value,
    [object]$Schema,
    [object]$RootSchema,
    [string]$Path,
    [System.Collections.Generic.List[string]]$Errors
  )
  $reference = [string](Get-R8H5SchemaProperty $Schema '$ref')
  if (-not [string]::IsNullOrWhiteSpace($reference)) {
    Test-R8H5SchemaNode $Value (Resolve-R8H5SchemaReference $RootSchema $reference) $RootSchema $Path $Errors
    return
  }

  foreach ($keyword in @('allOf','anyOf','oneOf')) {
    $branches = @(Get-R8H5SchemaItems (Get-R8H5SchemaProperty $Schema $keyword))
    if ($branches.Count -eq 0) { continue }
    $passCount = 0
    foreach ($branch in $branches) {
      $branchErrors = [System.Collections.Generic.List[string]]::new()
      Test-R8H5SchemaNode $Value $branch $RootSchema $Path $branchErrors
      if ($branchErrors.Count -eq 0) { $passCount++ }
    }
    if (($keyword -eq 'allOf' -and $passCount -ne $branches.Count) -or
        ($keyword -eq 'anyOf' -and $passCount -lt 1) -or
        ($keyword -eq 'oneOf' -and $passCount -ne 1)) {
      $Errors.Add("${keyword}:$Path")
      return
    }
  }

  $types = @(Get-R8H5SchemaItems (Get-R8H5SchemaProperty $Schema 'type') | ForEach-Object { [string]$_ })
  if ($types.Count -gt 0) {
    $typeMatch = $false
    foreach ($typeName in $types) {
      if (Test-R8H5SchemaType $Value $typeName) { $typeMatch = $true; break }
    }
    if (-not $typeMatch) {
      $Errors.Add("type:$Path expected=$([string]::Join('|',$types))")
      return
    }
  }
  if ($null -eq $Value) { return }

  if (Test-R8H5SchemaHasProperty $Schema 'const') {
    if ((ConvertTo-R8H5CanonicalJson $Value) -ne (ConvertTo-R8H5CanonicalJson (Get-R8H5SchemaProperty $Schema 'const'))) {
      $Errors.Add("const:$Path")
    }
  }
  $enum = @(Get-R8H5SchemaItems (Get-R8H5SchemaProperty $Schema 'enum'))
  if ($enum.Count -gt 0) {
    $actual = ConvertTo-R8H5CanonicalJson $Value
    if ($actual -notin @($enum | ForEach-Object { ConvertTo-R8H5CanonicalJson $_ })) {
      $Errors.Add("enum:$Path")
    }
  }

  if ($Value -is [string]) {
    $minLength = Get-R8H5SchemaProperty $Schema 'minLength'
    if ($null -ne $minLength -and $Value.Length -lt [int]$minLength) { $Errors.Add("minLength:$Path") }
    $pattern = [string](Get-R8H5SchemaProperty $Schema 'pattern')
    if (-not [string]::IsNullOrWhiteSpace($pattern) -and $Value -notmatch $pattern) { $Errors.Add("pattern:$Path") }
    if ([string](Get-R8H5SchemaProperty $Schema 'format') -eq 'date-time') {
      $parsed = [DateTimeOffset]::MinValue
      if (-not [DateTimeOffset]::TryParse($Value,[ref]$parsed) -or $Value -notmatch '(Z|[+-]\d{2}:\d{2})$') {
        $Errors.Add("format_date_time:$Path")
      }
    }
  }
  if (Test-R8H5SchemaType $Value 'number') {
    $minimum = Get-R8H5SchemaProperty $Schema 'minimum'
    if ($null -ne $minimum -and [decimal]$Value -lt [decimal]$minimum) { $Errors.Add("minimum:$Path") }
  }

  if ($Value -is [System.Array]) {
    $items = @($Value)
    $minItems = Get-R8H5SchemaProperty $Schema 'minItems'
    if ($null -ne $minItems -and $items.Count -lt [int]$minItems) { $Errors.Add("minItems:$Path") }
    if ((Get-R8H5SchemaProperty $Schema 'uniqueItems') -eq $true) {
      $normalized = @($items | ForEach-Object { ConvertTo-R8H5CanonicalJson $_ })
      if (@($normalized | Select-Object -Unique).Count -ne $normalized.Count) { $Errors.Add("uniqueItems:$Path") }
    }
    $itemSchema = Get-R8H5SchemaProperty $Schema 'items'
    if ($null -ne $itemSchema) {
      for ($index = 0; $index -lt $items.Count; $index++) {
        Test-R8H5SchemaNode $items[$index] $itemSchema $RootSchema "$Path[$index]" $Errors
      }
    }
  }

  if (Test-R8H5SchemaType $Value 'object') {
    $names = @(Get-R8H5SchemaPropertyNames $Value)
    $minProperties = Get-R8H5SchemaProperty $Schema 'minProperties'
    if ($null -ne $minProperties -and $names.Count -lt [int]$minProperties) { $Errors.Add("minProperties:$Path") }
    foreach ($requiredName in @(Get-R8H5SchemaItems (Get-R8H5SchemaProperty $Schema 'required'))) {
      if (-not (Test-R8H5SchemaHasProperty $Value ([string]$requiredName))) { $Errors.Add("required:$Path.$requiredName") }
    }
    $properties = Get-R8H5SchemaProperty $Schema 'properties'
    $additional = Get-R8H5SchemaProperty $Schema 'additionalProperties'
    foreach ($name in $names) {
      $childSchema = Get-R8H5SchemaProperty $properties $name
      if ($null -ne $childSchema) {
        Test-R8H5SchemaNode (Get-R8H5SchemaProperty $Value $name) $childSchema $RootSchema "$Path.$name" $Errors
      } elseif ($additional -eq $false) {
        $Errors.Add("additionalProperties:$Path.$name")
      } elseif ($null -ne $additional -and $additional -ne $true) {
        Test-R8H5SchemaNode (Get-R8H5SchemaProperty $Value $name) $additional $RootSchema "$Path.$name" $Errors
      }
    }
  }
}

function Test-R8H5JsonSchemaValue {
  param([string]$SchemaPath,[object]$Value)
  $schema = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $errors = [System.Collections.Generic.List[string]]::new()
  Test-R8H5SchemaNode $Value $schema $schema '$' $errors
  return @($errors)
}
