param(
  [string]$FixturePath='examples/r3-visual-need-fixtures/fixtures.json',
  [string]$AnalysisPath='',
  [string]$ReportPath='state/checks/r3-visual-need-report.json'
)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2.0
$projectRoot=(Resolve-Path(Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R3VisualNeed.ps1')
function Resolve-R3VNPath([string]$Path){if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)};return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))}
function Add-R3VNResult($List,[string]$Id,[string]$Expected,[object[]]$Errors,[string]$Evidence){$actual=if($Errors.Count){'fail'}else{'pass'};$List.Add([ordered]@{fixture_id=$Id;expected_result=$Expected;actual_result=$actual;expectation_met=($actual-eq$Expected);errors=$Errors;evidence=$Evidence})}
function Copy-R3VNObject([object]$Value){return($Value|ConvertTo-Json -Depth 60|ConvertFrom-Json)}
function Set-R3VNMutation([object]$Document,[object]$Mutation){
  $tokens=@(([string]$Mutation.path).Split('.'));$cursor=$Document
  for($i=0;$i-lt$tokens.Count-1;$i++){$token=$tokens[$i];if($token-match'^\d+$'){$cursor=@($cursor)[[int]$token]}else{$cursor=$cursor.$token}}
  $leaf=$tokens[-1];$remove=(Test-R3VNHasProperty $Mutation 'remove')-and[bool]$Mutation.remove
  if($leaf-match'^\d+$'){throw 'mutation_array_leaf_not_supported'}
  if($remove){$cursor.PSObject.Properties.Remove($leaf)}elseif(Test-R3VNHasProperty $cursor $leaf){$cursor.$leaf=$Mutation.value}else{$cursor|Add-Member -NotePropertyName $leaf -NotePropertyValue $Mutation.value}
}
function Expand-R3VNGeneratedTasks([object]$Document,[int]$Count){
  if($Count-lt1){throw 'repeat_generate_count_invalid'}
  $candidateTemplate=@($Document.candidates)[0];$taskTemplate=@($Document.accepted_visual_tasks)[0];$candidates=@();$tasks=@()
  for($i=1;$i-le$Count;$i++){
    $candidate=Copy-R3VNObject $candidateTemplate;$task=Copy-R3VNObject $taskTemplate
    $candidate.visual_need_candidate_id="VN-CAND-$i";$candidate.trigger_text="视觉需求节点 $i";$candidate.insert_after_text="节点 $i 前";$candidate.insert_before_text="节点 $i 后";$candidate.decision_reason="第 $i 个独立理解任务通过"
    $task.image_task_id="VN-TASK-$i";$task.visual_need_candidate_id=$candidate.visual_need_candidate_id
    $candidates+=$candidate;$tasks+=$task
  }
  $Document.candidates=$candidates;$Document.accepted_visual_tasks=$tasks;$Document.derived_visual_count=$Count
}
try{
  $fixtureFull=Resolve-R3VNPath $FixturePath;if(-not(Test-Path -LiteralPath $fixtureFull)){Write-Error 'fixture_missing';exit 4}
  $fixture=Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8|ConvertFrom-Json
  $results=[Collections.Generic.List[object]]::new()
  $templates=@{};foreach($template in @($fixture.templates)){$templates[[string]$template.template_id]=$template.document}
  foreach($case in @($fixture.cases)){
    $document=if(Test-R3VNHasProperty $case 'document'){Copy-R3VNObject $case.document}else{if(-not$templates.ContainsKey([string]$case.template_id)){throw "fixture_template_missing:$($case.template_id)"};Copy-R3VNObject $templates[[string]$case.template_id]}
    if(Test-R3VNHasProperty $case 'repeat_generate_count'){Expand-R3VNGeneratedTasks $document ([int]$case.repeat_generate_count)}
    foreach($mutation in @($case.mutations)){Set-R3VNMutation $document $mutation}
    $errors=@(Test-R3VisualNeedAnalysis $document);Add-R3VNResult $results ([string]$case.fixture_id) ([string]$case.expected_result) $errors $fixtureFull
  }
  if(-not[string]::IsNullOrWhiteSpace($AnalysisPath)){$full=Resolve-R3VNPath $AnalysisPath;if(-not(Test-Path -LiteralPath $full)){Write-Error 'analysis_missing';exit 4};$errors=@(Test-R3VisualNeedAnalysis(Get-Content -LiteralPath $full -Raw -Encoding UTF8|ConvertFrom-Json));Add-R3VNResult $results 'R3VN-REAL' 'pass' $errors $full}
  $coverage=@(
    @{id='COVERAGE-PRODUCT';path='docs/product/R3-产品总览.md';tokens=@('content_derived_unbounded','允许 0 到 N 张','viewer_problem_without_visual','generate_all_accepted','auto_continue_all_accepted_without_human_confirmation')},
    @{id='COVERAGE-DICTIONARY';path='交接物字段词典.md';tokens=@('visual_need_analysis','accepted_visual_tasks','zero_visual_reason','provider_call_limit=null','human_confirmation_required=false')},
    @{id='COVERAGE-STATIC-CONTRACT';path='skills/static-visual-director/CONTRACT.md';tokens=@('R3-C71-R3-C80','visual_need_analysis','accepted_visual_tasks','superseded_pending_recompile','pass_must_auto_continue_to_image_prompt_compiler')},
    @{id='COVERAGE-FACADE';path='skills/talking-head-image-pip/SKILL.md';tokens=@('0 to N','generate all accepted','Image 2','no cost or call-count gate','accepted_task_dispatch_policy')},
    @{id='COVERAGE-PROMPT';path='skills/image-prompt-compiler/SKILL.md';tokens=@('accepted_visual_tasks','generate decision','complete prompt text','human_confirmation_required=false')},
    @{id='COVERAGE-ASSET';path='skills/image-asset-producer/SKILL.md';tokens=@('all accepted tasks','no provider call limit','actual_provider_execution_count','not a pre-generation confirmation gate')},
    @{id='COVERAGE-QUALITY';path='skills/copywriting-quality-review/SKILL.md';tokens=@('viewer_problem_without_visual','visual_need_analysis','zero_visual_reason')},
    @{id='COVERAGE-SCHEMA';path='templates/schema/r3/visual-need-analysis.v0.1.schema.json';tokens=@('content_derived_unbounded','generate_all_accepted','provider_call_limit','accepted_visual_tasks','auto_continue_all_accepted_without_human_confirmation','human_confirmation_required')}
  )
  foreach($item in $coverage){$full=Join-Path $projectRoot $item.path;$missing=@();if(-not(Test-Path -LiteralPath $full)){$missing=@('file_missing')}else{$text=Get-Content -LiteralPath $full -Raw -Encoding UTF8;$missing=@($item.tokens|Where-Object{-not$text.Contains($_)})};Add-R3VNResult $results $item.id 'pass' @($missing|ForEach-Object{"coverage_token_missing:$_"}) $item.path}
  $failed=@($results|Where-Object{-not$_.expectation_met});$overall=if($failed.Count){'fail'}else{'pass'}
  $report=[ordered]@{schema_id='taoge://reports/r3/visual-need/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$overall;case_count=$results.Count;failure_count=$failed.Count;results=[object[]]$results.ToArray()}
  $out=Resolve-R3VNPath $ReportPath;$parent=Split-Path -Parent $out;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($out,(($report|ConvertTo-Json -Depth 60)+"`n"),[Text.UTF8Encoding]::new($false))
  Write-Output "R3_VISUAL_NEED_CHECK=$overall";Write-Output "CASE_COUNT=$($results.Count)";Write-Output "FAILURE_COUNT=$($failed.Count)";Write-Output "REPORT=$out";if($failed.Count){$failed|ForEach-Object{Write-Output "ERROR=$($_.fixture_id):$([string]::Join(',',@($_.errors)))"};exit 1};exit 0
}catch{Write-Error('R3_VISUAL_NEED_CHECKER_ERROR='+$_.Exception.Message);exit 3}
