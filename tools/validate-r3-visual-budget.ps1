param(
  [string]$FixturePath = 'examples/r3-visual-budget-fixtures/fixtures.json',
  [string]$PlanPath = '',
  [string]$ReportPath = 'state/checks/r3-visual-budget-report.json'
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R3VisualBudget.ps1')
function Resolve-R3BudgetPath([string]$Path){if([System.IO.Path]::IsPathRooted($Path)){return $Path};return Join-Path $projectRoot $Path}
function Add-R3BudgetResult($List,[string]$Id,[string]$Expected,[object[]]$Errors,[string]$Evidence){$actual=if($Errors.Count){'fail'}else{'pass'};$List.Add([ordered]@{fixture_id=$Id;expected_result=$Expected;actual_result=$actual;expectation_met=($actual -eq $Expected);errors=$Errors;evidence=$Evidence})}
try{
  $fixtureFull=Resolve-R3BudgetPath $FixturePath; if(-not(Test-Path -LiteralPath $fixtureFull)){Write-Error 'fixture_missing';exit 4}
  $fixture=Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8|ConvertFrom-Json
  $results=[System.Collections.Generic.List[object]]::new()
  foreach($case in @($fixture.cases)){$errors=@(Test-R3VisualBudgetContract $case.document);Add-R3BudgetResult $results ([string]$case.fixture_id) ([string]$case.expected_result) $errors $fixtureFull}
  if(-not[string]::IsNullOrWhiteSpace($PlanPath)){$planFull=Resolve-R3BudgetPath $PlanPath;if(-not(Test-Path -LiteralPath $planFull)){Write-Error 'plan_missing';exit 4};$errors=@(Test-R3VisualBudgetContract (Get-Content -LiteralPath $planFull -Raw -Encoding UTF8|ConvertFrom-Json));Add-R3BudgetResult $results 'R3VB-REAL-PLAN' 'pass' $errors $planFull}
  $coverage=@(
    @{id='LEGACY-SCHEMA';path='templates/schema/r3/visual-budget.v0.1.schema.json';tokens=@('expected_provider_call_count','selected_optional_count','prompt_sha256')},
    @{id='LEGACY-FIXTURE-NOTE';path='examples/r3-visual-budget-fixtures/README.md';tokens=@('visual-budget','fixture')}
  )
  foreach($item in $coverage){$full=Join-Path $projectRoot $item.path;$missing=@();if(-not(Test-Path -LiteralPath $full)){$missing=@('file_missing')}else{$text=Get-Content -LiteralPath $full -Raw -Encoding UTF8;$missing=@($item.tokens|Where-Object{-not$text.Contains($_)})};$errors=@($missing|ForEach-Object{"coverage_token_missing:$_"});Add-R3BudgetResult $results $item.id 'pass' $errors $item.path}
  $failed=@($results|Where-Object{-not$_.expectation_met});$overall=if($failed.Count){'fail'}else{'pass'}
  $report=[ordered]@{schema_id='taoge://reports/r3/visual-budget/v0.1';schema_version='0.1';contract_status='history_only_compatibility';superseded_by='taoge://schemas/r3/visual-need-analysis/v0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$overall;case_count=$results.Count;failure_count=$failed.Count;results=[object[]]$results.ToArray()}
  $reportFull=Resolve-R3BudgetPath $ReportPath;$parent=Split-Path -Parent $reportFull;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($reportFull,(($report|ConvertTo-Json -Depth 50)+"`n"),[Text.UTF8Encoding]::new($false))
  Write-Output "R3_VISUAL_BUDGET_CHECK=$overall";Write-Output "CASE_COUNT=$($results.Count)";Write-Output "FAILURE_COUNT=$($failed.Count)";Write-Output "REPORT=$reportFull";if($failed.Count){$failed|ForEach-Object{Write-Output "ERROR=$($_.fixture_id):$([string]::Join(',',@($_.errors)))"};exit 1};exit 0
}catch{Write-Error ('R3_VISUAL_BUDGET_CHECKER_ERROR='+$_.Exception.Message);exit 3}
