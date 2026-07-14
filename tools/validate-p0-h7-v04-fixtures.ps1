param(
  [string]$FixturePath='examples/p0-runtime-v0.4-fixture',
  [string]$ReportPath='state/checks/p0-h7-v04-fixture-report.json'
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
$runtimeHost=Get-P0PowerShellHost
function Add-H7V04Fixture([Collections.Generic.List[object]]$Checks,[Collections.Generic.List[string]]$Failures,[string]$Id,[bool]$Pass,[string]$Evidence){$Checks.Add([ordered]@{check_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence});if(-not$Pass){$Failures.Add("${Id}:$Evidence")}}
function Write-H7V04FixtureJson([string]$Path,[object]$Value){[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 60)+"`n"),[Text.UTF8Encoding]::new($false))}
function Copy-H7V04Fixture([string]$Source,[string]$ChecksRoot,[string]$Name){$target=[IO.Path]::GetFullPath((Join-Path $ChecksRoot $Name));if(-not$target.StartsWith($ChecksRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw "unsafe_fixture_target:$target"};if(Test-Path $target){Remove-Item -LiteralPath $target -Recurse -Force};Copy-Item -LiteralPath $Source -Destination $target -Recurse;return $target}
function Invoke-H7V04Runtime([string]$Runtime,[string]$Session,[string]$Mode){$lines=@(& $runtimeHost -NoProfile -ExecutionPolicy Bypass -File $Runtime -SessionPath $Session -Mode $Mode 2>&1|ForEach-Object{[string]$_});return [pscustomobject]@{ExitCode=$LASTEXITCODE;Text=[string]::Join("`n",$lines)}}

try{
  $root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path;$fixtureCandidate=if([IO.Path]::IsPathRooted($FixturePath)){$FixturePath}else{Join-Path $root $FixturePath};$fixture=(Resolve-Path $fixtureCandidate).Path;$checksCandidate=Join-Path $root 'state/checks';if(-not(Test-Path $checksCandidate)){New-Item -ItemType Directory $checksCandidate -Force|Out-Null};$checksRoot=(Resolve-Path $checksCandidate).Path
  $runtime=Join-Path $PSScriptRoot 'invoke-workflow-runtime.ps1';$semantic=Join-Path $PSScriptRoot 'validate-p0-h7-v04-delivery.ps1';$checks=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[string]]::new()
  $valid=Copy-H7V04Fixture $fixture $checksRoot 'p0-h7-v04-fixture-valid';$plan=Read-P0JsonFile (Join-Path $valid 'intermediate/p0/session-execution-plan.json');$planErrors=@(Test-P0PlanContract $plan);Add-H7V04Fixture $checks $failures 'H7V04-FIX-001-plan' ($planErrors.Count-eq0-and$plan.plan_schema_id-eq'taoge://schemas/p0/session-execution-plan/v0.4') ($planErrors-join';')
  $compile=Invoke-H7V04Runtime $runtime $valid 'compile_render_input';$render=Invoke-H7V04Runtime $runtime $valid 'render_final_delivery';Add-H7V04Fixture $checks $failures 'H7V04-FIX-002-compile-render' ($compile.ExitCode-eq0-and$render.ExitCode-eq0-and$render.Text.Contains('p0-single-runtime-v0.2+h7-v0.4')) ($compile.Text+';'+$render.Text)
  if($compile.ExitCode-ne0-or$render.ExitCode-ne0){throw "h7_v04_compile_render_failed:$($compile.Text);$($render.Text)"}
  $semanticLines=@(& $runtimeHost -NoProfile -ExecutionPolicy Bypass -File $semantic -SessionPath $valid -ReportPath (Join-Path $checksRoot 'p0-h7-v04-semantic.json') 2>&1|ForEach-Object{[string]$_});$semanticExit=$LASTEXITCODE;Add-H7V04Fixture $checks $failures 'H7V04-FIX-003-semantic' ($semanticExit-eq0-and([string]::Join("`n",$semanticLines)).Contains('CHECK_COUNT=13')) ([string]::Join(';',$semanticLines))
  $eventPath=Join-Path $valid 'intermediate/p0/execution-events.jsonl';$before=@(Get-Content $eventPath|Where-Object{$_.Trim()}).Count;$reuse=Invoke-H7V04Runtime $runtime $valid 'render_final_delivery';$after=@(Get-Content $eventPath|Where-Object{$_.Trim()}).Count;Add-H7V04Fixture $checks $failures 'H7V04-FIX-004-idempotent' ($reuse.ExitCode-eq0-and$reuse.Text.Contains('skipped_reused')-and$before-eq$after) "before=$before;after=$after;$($reuse.Text)"
  foreach($case in @(
    @{Id='H7V04-FIX-005-false-visual-pass';Expected='cover_card_v04_false_visual_pass';Mutate={param($d)$d.cover_cards[0].reviewer_type='deterministic_tool'}},
    @{Id='H7V04-FIX-006-preview-type';Expected='cover_card_v04_preview_type_invalid';Mutate={param($d)$d.cover_cards[0].preview_evidence_type='unknown_preview';$d.platform_delivery_units[0].preview_evidence_type='unknown_preview'}},
    @{Id='H7V04-FIX-007-slot-bounds';Expected='visual_insert_card_slot:CARD-H7-V04-VISUAL-001_out_of_bounds';Mutate={param($d)$d.visual_insert_cards[0].placement_slot.x=0.6;$d.visual_insert_cards[0].placement_slot.width=0.8}},
    @{Id='H7V04-FIX-008-preview-hash';Expected='materialized_cover_preview_sha256_mismatch';Mutate={param($d)$d.cover_cards[0].preview_sha256='sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';$d.platform_delivery_units[0].cover_preview_sha256='sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'}}
  )){
    $work=Copy-H7V04Fixture $fixture $checksRoot ($case.Id.ToLowerInvariant());$path=Join-Path $work 'deliverables/p0/final-delivery-render-candidate.json';$doc=Read-P0JsonFile $path;& $case.Mutate $doc;Write-H7V04FixtureJson $path $doc
    if($case.Id-eq'H7V04-FIX-005-false-visual-pass'){$reviewPath=Join-Path $work 'assets/cover-v04.review.json';$review=Read-P0JsonFile $reviewPath;$review.reviewer_type='deterministic_tool';Write-H7V04FixtureJson $reviewPath $review}
    $result=Invoke-H7V04Runtime $runtime $work 'compile_render_input';Add-H7V04Fixture $checks $failures $case.Id ($result.ExitCode-ne0-and$result.Text.Contains([string]$case.Expected)) $result.Text
  }
  $overall=if($failures.Count){'fail'}else{'pass'};$report=[ordered]@{schema_id='taoge://reports/p0/h7-v04-fixtures/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$overall;check_count=$checks.Count;failure_count=$failures.Count;checks=[object[]]$checks.ToArray();failures=[object[]]$failures.ToArray();real_account_data_executed=$false;image_provider_called=$false;publishing_executed=$false};$target=if([IO.Path]::IsPathRooted($ReportPath)){$ReportPath}else{Join-Path $root $ReportPath};Write-H7V04FixtureJson $target $report
  $checks|ForEach-Object{Write-Output "$($_.check_id) $($_.status) $($_.evidence)"};Write-Output "P0_H7_V04_FIXTURES=$overall";Write-Output "CHECK_COUNT=$($checks.Count)";Write-Output "REPORT=$target";if($failures.Count){exit 1};exit 0
}catch{Write-Error("P0_H7_V04_FIXTURE_ERROR="+$_.Exception.Message);exit 3}
