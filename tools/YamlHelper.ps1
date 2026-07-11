param(
  [string]$Operation = '',
  [string]$FilePath = '',
  [string]$YamlText = '',
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

function Test-YamlModule {
  $module = Get-Module -Name powershell-yaml -ListAvailable
  return $module -ne $null
}

function Install-YamlModule {
  if (-not (Test-YamlModule)) {
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force -SkipPublisherCheck
  }
  Import-Module powershell-yaml
}

function Read-YamlFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "File not found: $Path"
    return $null
  }

  if (Test-YamlModule) {
    Import-Module powershell-yaml -ErrorAction SilentlyContinue
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Yaml
  }

  return Read-YamlFallback $Path
}

function Read-YamlFallback {
  param([string]$Path)

  $records = New-Object System.Collections.Generic.List[object]
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#') -or $trimmed -eq '---') {
      continue
    }
    if ($line.Contains("`t")) {
      throw "Fallback YAML parser does not allow tab indentation."
    }
    $records.Add([pscustomobject]@{
      indent = $line.Length - $line.TrimStart().Length
      text = $trimmed
    })
  }

  if ($records.Count -eq 0) { return [ordered]@{} }
  $index = 0
  return Parse-YamlBlock -Records $records.ToArray() -Index ([ref]$index) -Indent $records[0].indent
}

function ConvertFrom-YamlScalar {
  param([string]$Value)

  $value = $Value.Trim()
  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    return $value.Substring(1, $value.Length - 2)
  }
  if ($value -match '^(true|false)$') { return [bool]::Parse($value) }
  if ($value -match '^(null|~)$') { return $null }
  if ($value -match '^-?\d+$') { return [long]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture) }
  if ($value -match '^-?\d+\.\d+$') { return [double]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture) }
  if ($value.StartsWith('[') -and $value.EndsWith(']')) {
    $inner = $value.Substring(1, $value.Length - 2).Trim()
    if ([string]::IsNullOrWhiteSpace($inner)) { return @() }
    return @($inner -split ',' | ForEach-Object { ConvertFrom-YamlScalar $_ })
  }
  return $value
}

function Parse-YamlBlock {
  param(
    [object[]]$Records,
    [ref]$Index,
    [int]$Indent
  )

  if ($Records[$Index.Value].text.StartsWith('-')) {
    $items = New-Object System.Collections.Generic.List[object]
    while ($Index.Value -lt $Records.Count) {
      $record = $Records[$Index.Value]
      if ($record.indent -ne $Indent -or -not $record.text.StartsWith('-')) { break }
      $payload = $record.text.Substring(1).Trim()

      if ([string]::IsNullOrWhiteSpace($payload)) {
        $Index.Value++
        if ($Index.Value -lt $Records.Count -and $Records[$Index.Value].indent -gt $Indent) {
          $items.Add((Parse-YamlBlock -Records $Records -Index $Index -Indent $Records[$Index.Value].indent))
        } else {
          $items.Add($null)
        }
        continue
      }

      if ($payload -match '^([A-Za-z0-9_.-]+):\s*(.*)$') {
        $item = [ordered]@{}
        $key = $matches[1]
        $rawValue = $matches[2]
        $Index.Value++
        if ([string]::IsNullOrWhiteSpace($rawValue)) {
          if ($Index.Value -lt $Records.Count -and $Records[$Index.Value].indent -gt $Indent) {
            $item[$key] = Parse-YamlBlock -Records $Records -Index $Index -Indent $Records[$Index.Value].indent
          } else {
            $item[$key] = [ordered]@{}
          }
        } else {
          $item[$key] = ConvertFrom-YamlScalar $rawValue
        }

        if ($Index.Value -lt $Records.Count -and $Records[$Index.Value].indent -gt $Indent) {
          $extra = Parse-YamlBlock -Records $Records -Index $Index -Indent $Records[$Index.Value].indent
          if ($extra -is [System.Collections.IDictionary]) {
            foreach ($extraKey in $extra.Keys) { $item[$extraKey] = $extra[$extraKey] }
          }
        }
        $items.Add($item)
      } else {
        $items.Add((ConvertFrom-YamlScalar $payload))
        $Index.Value++
      }
    }
    return ,$items.ToArray()
  }

  $map = [ordered]@{}
  while ($Index.Value -lt $Records.Count) {
    $record = $Records[$Index.Value]
    if ($record.indent -ne $Indent -or $record.text.StartsWith('-')) { break }
    if ($record.text -notmatch '^([A-Za-z0-9_.-]+):\s*(.*)$') {
      throw "Unsupported YAML line: $($record.text)"
    }

    $key = $matches[1]
    $rawValue = $matches[2].Trim()
    $Index.Value++
    if ($rawValue -in @('>', '|')) {
      $parts = New-Object System.Collections.Generic.List[string]
      while ($Index.Value -lt $Records.Count -and $Records[$Index.Value].indent -gt $Indent) {
        $parts.Add($Records[$Index.Value].text)
        $Index.Value++
      }
      $separator = if ($rawValue -eq '>') { ' ' } else { "`n" }
      $map[$key] = [string]::Join($separator, $parts)
    } elseif ([string]::IsNullOrWhiteSpace($rawValue)) {
      if ($Index.Value -lt $Records.Count -and $Records[$Index.Value].indent -gt $Indent) {
        $map[$key] = Parse-YamlBlock -Records $Records -Index $Index -Indent $Records[$Index.Value].indent
      } else {
        $map[$key] = [ordered]@{}
      }
    } else {
      $map[$key] = ConvertFrom-YamlScalar $rawValue
    }
  }
  return $map
}

function Write-YamlFile {
  param(
    [object]$Data,
    [string]$Path
  )

  if (Test-YamlModule) {
    Import-Module powershell-yaml -ErrorAction SilentlyContinue
    $Data | ConvertTo-Yaml | Set-Content -LiteralPath $Path -Encoding UTF8
    return
  }

  Write-YamlFallback $Data $Path
}

function Write-YamlFallback {
  param(
    [object]$Data,
    [string]$Path
  )

  $lines = @('---')
  Write-YamlNode $Data 0 $lines
  $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-YamlNode {
  param(
    [object]$Node,
    [int]$Indent,
    [System.Collections.Generic.List[string]]$Lines
  )

  $prefix = ' ' * ($Indent * 2)

  if ($Node -is [ordered] -or $Node -is [hashtable]) {
    foreach ($key in $Node.Keys) {
      $value = $Node[$key]
      if ($value -is [ordered] -or $value -is [hashtable]) {
        $Lines.Add("${prefix}${key}:")
        Write-YamlNode $value ($Indent + 1) $Lines
      } elseif ($value -is [array]) {
        $Lines.Add("${prefix}${key}:")
        foreach ($item in $value) {
          if ($item -is [string]) {
            $Lines.Add("${prefix}  - `"$item`"")
          } else {
            $Lines.Add("${prefix}  -")
            Write-YamlNode $item ($Indent + 2) $Lines
          }
        }
      } elseif ($value -is [bool]) {
        $Lines.Add("${prefix}${key}: $($value.ToString().ToLower())")
      } else {
        $Lines.Add("${prefix}${key}: `"$value`"")
      }
    }
  }
}

function Test-YamlStructure {
  param(
    [object]$Data,
    [string[]]$RequiredKeys
  )

  $missing = @()
  foreach ($key in $RequiredKeys) {
    if (-not $Data.PSObject.Properties.Name.Contains($key)) {
      $missing += $key
    }
  }
  return $missing
}

if ([string]::IsNullOrWhiteSpace($Operation)) {
  return
}

try {
  switch ($Operation) {
    'read' {
      if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        $result = Read-YamlFile $FilePath
        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
          $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        } else {
          $result | ConvertTo-Json -Depth 10
        }
      } elseif (-not [string]::IsNullOrWhiteSpace($YamlText)) {
        if (Test-YamlModule) {
          Import-Module powershell-yaml -ErrorAction SilentlyContinue
          $YamlText | ConvertFrom-Yaml | ConvertTo-Json -Depth 10
        } else {
          Write-Error "powershell-yaml module not available for direct text parsing"
          exit 1
        }
      }
    }
    'write' {
      if (-not [string]::IsNullOrWhiteSpace($YamlText)) {
        if (Test-YamlModule) {
          Import-Module powershell-yaml -ErrorAction SilentlyContinue
          $data = $YamlText | ConvertFrom-Yaml
          Write-YamlFile $data $OutputPath
        } else {
          Write-Error "powershell-yaml module not available"
          exit 1
        }
      }
    }
    'test-module' {
      if (Test-YamlModule) {
        Write-Output "YAML module: available"
        exit 0
      } else {
        Write-Output "YAML module: not available"
        exit 1
      }
    }
    'install-module' {
      Install-YamlModule
      Write-Output "YAML module installed"
      exit 0
    }
    default {
      Write-Error "Unknown operation: $Operation"
      exit 1
    }
  }
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
