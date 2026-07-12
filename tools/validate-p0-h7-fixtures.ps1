param(
  [string]$FixturePath = 'examples/p0-runtime-v0.3-fixture',
  [string]$ReportPath = 'state/checks/p0-h7-fixture-report.json'
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
$runtimeHost=Get-P0PowerShellHost

function Add-H7FixtureResult([Collections.Generic.List[object]]$Results,[Collections.Generic.List[string]]$Failures,[string]$Id,[bool]$Pass,[string]$Evidence){
  $Results.Add([ordered]@{check_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence})
  if(-not $Pass){$Failures.Add("$Id $Evidence")}
}
function Invoke-H7FixtureRuntime([string]$Runtime,[string]$Session,[string]$Mode){
  $lines=@(& $runtimeHost -NoProfile -ExecutionPolicy Bypass -File $Runtime -SessionPath $Session -Mode $Mode 2>&1|ForEach-Object{[string]$_})
  [pscustomobject]@{ExitCode=$LASTEXITCODE;Text=[string]::Join("`n",$lines)}
}
function Copy-H7Fixture([string]$Source,[string]$ChecksRoot,[string]$Name){
  $target=[IO.Path]::GetFullPath((Join-Path $ChecksRoot $Name))
  if(-not $target.StartsWith($ChecksRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw "unsafe_fixture_target:$target"}
  if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse -Force}
  Copy-Item -LiteralPath $Source -Destination $target -Recurse
  $target
}
function Write-H7FixtureJson([string]$Path,[object]$Value){[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 60)+"`n"),[Text.UTF8Encoding]::new($false))}

try{
  $root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $fixtureCandidate=if([IO.Path]::IsPathRooted($FixturePath)){$FixturePath}else{Join-Path $root $FixturePath};$fixture=(Resolve-Path $fixtureCandidate).Path
  $checksCandidate=Join-Path $root 'state/checks';if(-not(Test-Path $checksCandidate)){New-Item -ItemType Directory $checksCandidate -Force|Out-Null};$checksRoot=(Resolve-Path $checksCandidate).Path
  $runtime=Join-Path $PSScriptRoot 'invoke-workflow-runtime.ps1';$semantic=Join-Path $PSScriptRoot 'validate-p0-h7-delivery.ps1'
  $results=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[string]]::new()

  $valid=Copy-H7Fixture $fixture $checksRoot 'p0-h7-fixture-valid'
  $plan=Read-P0JsonFile (Join-Path $valid 'intermediate/p0/session-execution-plan.json');$planErrors=@(Test-P0PlanContract $plan)
  Add-H7FixtureResult $results $failures 'H7-FIX-001-plan-v03' ($planErrors.Count-eq0-and$plan.plan_schema_id-eq'taoge://schemas/p0/session-execution-plan/v0.3') ($planErrors-join';')
  $compile=Invoke-H7FixtureRuntime $runtime $valid 'compile_render_input';$render=Invoke-H7FixtureRuntime $runtime $valid 'render_final_delivery'
  Add-H7FixtureResult $results $failures 'H7-FIX-002-compile-render' ($compile.ExitCode-eq0-and$render.ExitCode-eq0-and$render.Text.Contains('DELIVERY_REVISION_ID=DREV-H7-001')) ($compile.Text+';'+$render.Text)
  $semanticLines=@(& $runtimeHost -NoProfile -ExecutionPolicy Bypass -File $semantic -SessionPath $valid -ReportPath (Join-Path $checksRoot 'p0-h7-fixture-valid-semantic.json') 2>&1|ForEach-Object{[string]$_});$semanticExit=$LASTEXITCODE
  Add-H7FixtureResult $results $failures 'H7-FIX-003-semantic-gate' ($semanticExit-eq0-and([string]::Join("`n",$semanticLines)).Contains('CHECK_COUNT=20')) ([string]::Join(';',$semanticLines))
  $finalizer=Join-Path $PSScriptRoot 'complete-p0-h7-delivery.ps1';$finalizeLines=@(& $runtimeHost -NoProfile -ExecutionPolicy Bypass -File $finalizer -SessionPath $valid -ReportPath (Join-Path $checksRoot 'p0-h7-fixture-finalize-semantic.json') 2>&1|ForEach-Object{[string]$_});$finalizeExit=$LASTEXITCODE;$projection=if($finalizeExit-eq0){Read-P0JsonFile (Join-Path $valid 'intermediate/p0/state-projection.json')}else{$null};$manifestText=if($finalizeExit-eq0){Get-Content (Join-Path $valid 'manifest.yaml') -Raw -Encoding UTF8}else{''}
  Add-H7FixtureResult $results $failures 'H7-FIX-010-finalize-state-closure' ($finalizeExit-eq0-and$projection.projected_through_sequence_no-eq3-and$projection.current_state-eq'completed'-and$manifestText.Contains('contract_set_version: p0-contract-bundle-v0.3')) ([string]::Join(';',$finalizeLines))
  $eventPath=Join-Path $valid 'intermediate/p0/execution-events.jsonl';$before=@(Get-Content $eventPath|Where-Object{$_.Trim()}).Count;$reuse=Invoke-H7FixtureRuntime $runtime $valid 'render_final_delivery';$after=@(Get-Content $eventPath|Where-Object{$_.Trim()}).Count
  Add-H7FixtureResult $results $failures 'H7-FIX-004-idempotent-commit' ($reuse.ExitCode-eq0-and$reuse.Text.Contains('skipped_reused')-and$before-eq$after) "before=$before;after=$after;$($reuse.Text)"
  $html=Get-Content (Join-Path $valid 'deliverables/final-delivery.html') -Raw -Encoding UTF8
  Add-H7FixtureResult $results $failures 'H7-FIX-005-offline-user-page' (-not($html-match'(?is)<\s*script\b|复制按钮|platform_cover|ready_with_warnings')) 'no script, false copy control, or raw user-layer enum'

  $warningWork=Copy-H7Fixture $fixture $checksRoot 'h7-fix-007-warning-union-derived';$warningPath=Join-Path $warningWork 'deliverables/p0/final-delivery-render-candidate.json';$warningDoc=Read-P0JsonFile $warningPath;$warningDoc.production_status.warning_codes=@();Write-H7FixtureJson $warningPath $warningDoc;$warningCompile=Invoke-H7FixtureRuntime $runtime $warningWork 'compile_render_input';$warningOutput=if($warningCompile.ExitCode-eq0){Read-P0JsonFile (Join-Path $warningWork 'deliverables/p0/final-delivery-render-input.json')}else{$null}
  Add-H7FixtureResult $results $failures 'H7-FIX-007-warning-union-derived' ($warningCompile.ExitCode-eq0-and(@($warningOutput.production_status.warning_codes)-join'|')-eq'fixture_not_published') $warningCompile.Text

  foreach($case in @(
    @{Id='H7-FIX-006-cover-title-mismatch';Mutate={param($d)$d.platform_delivery_units[0].cover_title='另一套封面标题'};Expected='platform_unit_field_mismatch'},
    @{Id='H7-FIX-008-duration-unproven';Mutate={param($d)$d.duration_estimate.duration_estimate_status='derived_range'};Expected='duration_range_fields_invalid'},
    @{Id='H7-FIX-009-duplicate-source';Mutate={param($d)$d.source_artifact_ids=@($d.source_artifact_ids)+@($d.source_artifact_ids[0])};Expected='source_artifact_ids_duplicate'}
  )){
    $work=Copy-H7Fixture $fixture $checksRoot ($case.Id.ToLowerInvariant());$path=Join-Path $work 'deliverables/p0/final-delivery-render-candidate.json';$doc=Read-P0JsonFile $path;& $case.Mutate $doc;Write-H7FixtureJson $path $doc
    $result=Invoke-H7FixtureRuntime $runtime $work 'compile_render_input';Add-H7FixtureResult $results $failures $case.Id ($result.ExitCode-ne0-and$result.Text.Contains([string]$case.Expected)) $result.Text
  }

  $report=[ordered]@{schema_id='taoge://reports/p0/h7-fixtures/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$(if($failures.Count){'fail'}else{'pass'});check_count=$results.Count;failure_count=$failures.Count;checks=[object[]]$results.ToArray();failures=[object[]]$failures.ToArray();real_account_data_executed=$false;image_provider_called=$false;publishing_executed=$false}
  $target=if([IO.Path]::IsPathRooted($ReportPath)){$ReportPath}else{Join-Path $root $ReportPath};$parent=Split-Path -Parent $target;if(-not(Test-Path $parent)){New-Item -ItemType Directory $parent -Force|Out-Null};Write-H7FixtureJson $target $report
  foreach($item in $results){Write-Output "$($item.check_id) $($item.status) $($item.evidence)"};Write-Output "P0_H7_FIXTURES=$($report.overall_result)";Write-Output "CHECK_COUNT=$($results.Count)";Write-Output "REPORT=$target"
  if($failures.Count){exit 1};exit 0
}catch{Write-Error("P0_H7_FIXTURE_ERROR="+$_.Exception.Message);exit 3}
