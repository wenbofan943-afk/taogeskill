param(
  [string]$FixturePath = 'examples/windows-runtime-helper-fixture/fixture.json',
  [string]$ReportPath = 'state/checks/windows-runtime-helper-report.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')

function Resolve-WinH2Path {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Add-WinH2Check {
  param([System.Collections.Generic.List[object]]$Checks,[string]$Id,[bool]$Passed,[string]$Evidence)
  $Checks.Add([ordered]@{ check_id=$Id; status=$(if($Passed){'pass'}else{'fail'}); evidence=$Evidence })
}

function Test-WinH2NoBom {
  param([string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  return -not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

try {
  $fixtureFull = Resolve-WinH2Path $FixturePath
  $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $workRoot = Join-Path $projectRoot 'state/checks/windows-runtime-helper-work/空格 中文'
  if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
  New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
  $checks = [System.Collections.Generic.List[object]]::new()

  $textPath = Join-Path $workRoot '文本.txt'
  Write-TaogeUtf8NoBomText -Path $textPath -Text ([string]$fixture.text_value) -EnsureFinalNewline
  $textActual = [System.IO.File]::ReadAllText($textPath, (Get-TaogeUtf8NoBomEncoding))
  Add-WinH2Check $checks 'WIN-H2-001-text-no-bom' ((Test-WinH2NoBom $textPath) -and $textActual -ceq ([string]$fixture.text_value + "`n")) "bytes=$((Get-Item $textPath).Length);text=$textActual"

  $linesPath = Join-Path $workRoot '行.txt'
  Write-TaogeUtf8NoBomLines -Path $linesPath -Lines @($fixture.lines)
  Add-TaogeUtf8NoBomLine -Path $linesPath -Line '追加行'
  $linesActual = [System.IO.File]::ReadAllText($linesPath, (Get-TaogeUtf8NoBomEncoding))
  $linesExpected = [string]::Join("`n", @($fixture.lines | ForEach-Object { [string]$_ })) + "`n追加行`n"
  Add-WinH2Check $checks 'WIN-H2-002-lines-append-no-bom' ((Test-WinH2NoBom $linesPath) -and $linesActual -ceq $linesExpected) "text=$linesActual"

  $jsonPath = Join-Path $workRoot '对象.json'
  $jsonValue = [ordered]@{ fixture_id=[string]$fixture.fixture_id; text=[string]$fixture.text_value; count=@($fixture.lines).Count }
  Write-TaogeUtf8NoBomJson -Path $jsonPath -Value $jsonValue -Depth 10
  $jsonActual = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Add-WinH2Check $checks 'WIN-H2-003-json-no-bom' ((Test-WinH2NoBom $jsonPath) -and [string]$jsonActual.fixture_id -ceq [string]$fixture.fixture_id -and [int]$jsonActual.count -eq @($fixture.lines).Count) "fixture_id=$($jsonActual.fixture_id);count=$($jsonActual.count)"

  $probePath = Join-Path $workRoot '参数 probe.ps1'
  $probeOutputPath = Join-Path $workRoot '参数 output.json'
  $probeStdout = Join-Path $workRoot '参数 stdout.txt'
  $probeStderr = Join-Path $workRoot '参数 stderr.txt'
  $probeText = @'
param([string]$OutputPath)
$payload = [ordered]@{ values = [object[]]@($args) }
[System.IO.File]::WriteAllText($OutputPath, (($payload | ConvertTo-Json -Depth 10) + "`n"), [System.Text.UTF8Encoding]::new($false))
'@
  [System.IO.File]::WriteAllText($probePath, $probeText, [System.Text.UTF8Encoding]::new($true))
  $runtimeHost = Get-P0PowerShellHost
  $argumentValues = @($fixture.arguments | ForEach-Object { [string]$_ })
  $probeProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$probePath,'-OutputPath',$probeOutputPath) + $argumentValues) -StandardOutputPath $probeStdout -StandardErrorPath $probeStderr -Wait -Hidden
  $probeActual = if (Test-Path -LiteralPath $probeOutputPath) { @((Get-Content -LiteralPath $probeOutputPath -Raw -Encoding UTF8 | ConvertFrom-Json).values | ForEach-Object { [string]$_ }) } else { @() }
  $probeMatch = [int]$probeProcess.ExitCode -eq 0 -and $probeActual.Count -eq $argumentValues.Count
  if ($probeMatch) { for($i=0;$i-lt$argumentValues.Count;$i++){if($probeActual[$i]-cne$argumentValues[$i]){$probeMatch=$false;break}} }
  Add-WinH2Check $checks 'WIN-H2-004-shared-process-argv' $probeMatch "host=$runtimeHost;exit=$($probeProcess.ExitCode);actual=$($probeActual|ConvertTo-Json -Compress)"

  $yamlProbePath = Join-Path $workRoot 'yaml fallback probe.ps1'
  $yamlOutputPath = Join-Path $workRoot 'yaml output.json'
  $yamlStdout = Join-Path $workRoot 'yaml stdout.txt'
  $yamlStderr = Join-Path $workRoot 'yaml stderr.txt'
  $yamlHelperPath = Join-Path $PSScriptRoot 'YamlHelper.ps1'
  $yamlFixturePath = Join-Path (Split-Path -Parent $fixtureFull) 'fallback.yaml'
  $yamlProbeText = @'
param([string]$HelperPath,[string]$InputPath,[string]$OutputPath)
$env:PSModulePath = ''
& $HelperPath -Operation read -FilePath $InputPath -OutputPath $OutputPath
exit $LASTEXITCODE
'@
  [System.IO.File]::WriteAllText($yamlProbePath, $yamlProbeText, [System.Text.UTF8Encoding]::new($true))
  $yamlProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$yamlProbePath,'-HelperPath',$yamlHelperPath,'-InputPath',$yamlFixturePath,'-OutputPath',$yamlOutputPath) -StandardOutputPath $yamlStdout -StandardErrorPath $yamlStderr -Wait -Hidden
  $yamlActual = if (Test-Path -LiteralPath $yamlOutputPath) { Get-Content -LiteralPath $yamlOutputPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
  Add-WinH2Check $checks 'WIN-H2-005-yaml-offline-fallback' ([int]$yamlProcess.ExitCode -eq 0 -and $null-ne$yamlActual -and [string]$yamlActual.fixture_id -ceq 'R4-WIN-H2-YAML-001' -and $yamlActual.enabled -eq $true) "exit=$($yamlProcess.ExitCode);fixture_id=$($yamlActual.fixture_id)"

  $scriptFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools') -Filter '*.ps1' -File
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'skills') -Filter '*.ps1' -File -Recurse
  ) | Where-Object { $_.Name -ne 'validate-windows-runtime-helper.ps1' }
  $unsafeEncoding = @($scriptFiles | Select-String -Pattern '(?:Set|Add)-Content[^\r\n]*-Encoding\s+UTF8(?:\s|$)' -AllMatches)
  $silentInstalls = @($scriptFiles | Select-String -Pattern '\bInstall-Module\b' -AllMatches)
  Add-WinH2Check $checks 'WIN-H2-006-no-host-default-utf8-writes' ($unsafeEncoding.Count -eq 0) ([string]::Join(';',@($unsafeEncoding|ForEach-Object{"$($_.Path):$($_.LineNumber)"})))
  Add-WinH2Check $checks 'WIN-H2-007-no-silent-module-install' ($silentInstalls.Count -eq 0) ([string]::Join(';',@($silentInstalls|ForEach-Object{"$($_.Path):$($_.LineNumber)"})))

  $h4Text = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/validate-p0-h4-evidence.ps1') -Raw -Encoding UTF8
  Add-WinH2Check $checks 'WIN-H2-008-h4-uses-shared-process-helper' ($h4Text.Contains(". (Join-Path `$PSScriptRoot 'WindowsRuntimeHelper.ps1')") -and $h4Text.Contains('Start-TaogeProcess') -and -not $h4Text.Contains('function ConvertTo-H4WindowsCommandLineArgument')) 'H4 must use shared helper without local argument serializer'

  $directProcessStarts = @($scriptFiles | Where-Object { $_.Name -ne 'WindowsRuntimeHelper.ps1' } | Select-String -Pattern '\bStart-Process\b' -AllMatches)
  Add-WinH2Check $checks 'WIN-H2-009-no-direct-start-process' ($directProcessStarts.Count -eq 0) ([string]::Join(';',@($directProcessStarts|ForEach-Object{"$($_.Path):$($_.LineNumber)"})))

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $report = [ordered]@{
    schema_id='taoge://reports/windows-runtime-helper/v0.1'
    fixture_id=[string]$fixture.fixture_id
    generated_at=[DateTimeOffset]::UtcNow.ToString('o')
    powershell_edition=[string]$PSVersionTable.PSEdition
    powershell_version=[string]$PSVersionTable.PSVersion
    result=$(if($failed.Count){'fail'}else{'pass'})
    check_count=$checks.Count
    pass_count=@($checks|Where-Object{$_.status-eq'pass'}).Count
    fail_count=$failed.Count
    checks=[object[]]$checks.ToArray()
    network_called=$false
    module_installed=$false
  }
  $reportFull = Resolve-WinH2Path $ReportPath
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 20
  foreach($check in $checks){Write-Output "$($check.check_id) $($check.status) $($check.evidence)"}
  Write-Output "WINDOWS_RUNTIME_HELPER_CHECK=$($report.result)"
  Write-Output "WINDOWS_RUNTIME_HELPER_CHECK_COUNT=$($report.check_count)"
  Write-Output "WINDOWS_RUNTIME_HELPER_REPORT=$ReportPath"
  if($failed.Count){exit 1}
  exit 0
} catch {
  Write-Error ("WINDOWS_RUNTIME_HELPER_ERROR=" + $_.Exception.Message)
  exit 3
}
