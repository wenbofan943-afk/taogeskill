param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function Get-MapValue($Map, [string]$Key) {
  if ($Map -is [System.Collections.IDictionary]) { return $Map[$Key] }
  $property = $Map.PSObject.Properties[$Key]
  if ($null -ne $property) { return $property.Value }
  return $null
}

try {
  if (-not (Test-Path -LiteralPath $SessionPath)) { Write-Error "SessionPath not found: $SessionPath"; exit 4 }
  $session = (Resolve-Path -LiteralPath $SessionPath).Path
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) { $HumanReportPath = Join-Path $session 'workflow-lineage-report.md' }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) { $MachineReportPath = Join-Path $session 'workflow-lineage-report.json' }
  $manifestPath = Join-Path $session 'manifest.yaml'
  if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Error "manifest.yaml not found"; exit 4 }
  $manifest = Read-YamlFile $manifestPath
  $blockers = [System.Collections.Generic.List[string]]::new()
  $warnings = [System.Collections.Generic.List[string]]::new()
  $checks = [System.Collections.Generic.List[object]]::new()
  $requiredArtifacts = @('execution_trace','research_run_record','topic_card','content_brief','draft','visual_plan','quality_review','platform_package','content_delivery_record','html_embed_manifest','final_delivery')
  $artifacts = Get-MapValue $manifest 'artifacts'
  foreach ($name in $requiredArtifacts) {
    $relative = [string](Get-MapValue $artifacts $name)
    $exists = -not [string]::IsNullOrWhiteSpace($relative) -and (Test-Path -LiteralPath (Join-Path $session $relative))
    $checks.Add([pscustomobject]@{ check='artifact_exists'; artifact=$name; path=$relative; status=if($exists){'pass'}else{'fail'} })
    if (-not $exists) { $blockers.Add("artifact_missing:$name") }
  }
  foreach ($name in @('session_id','account','source_research_run_id','current_stage','session_status')) {
    $value = [string](Get-MapValue $manifest $name)
    $checks.Add([pscustomobject]@{ check='manifest_field'; field=$name; status=if($value){'pass'}else{'fail'} })
    if (-not $value) { $blockers.Add("manifest_field_missing:$name") }
  }
  $ids = Get-MapValue $manifest 'ids'; foreach ($name in @('topic_id','brief_id','draft_id','review_id','package_id','delivery_id','final_delivery_id')) {
    if (-not [string](Get-MapValue $ids $name)) { $blockers.Add("lineage_id_missing:$name") }
  }
  $deliveryRelative = [string](Get-MapValue $artifacts 'content_delivery_record')
  if ($deliveryRelative) {
    $deliveryText = Get-Content -LiteralPath (Join-Path $session $deliveryRelative) -Raw -Encoding UTF8
    foreach ($name in @('source_research_run_id','topic_id','brief_id','draft_id','review_id','package_id','delivery_id')) {
      $expected = if ($name -eq 'source_research_run_id') { [string](Get-MapValue $manifest $name) } else { [string](Get-MapValue $ids $name) }
      if ($expected -and $deliveryText -notmatch [regex]::Escape($expected)) { $blockers.Add("delivery_lineage_missing:$name") }
    }
  }
  $finalRelative = [string](Get-MapValue $artifacts 'final_delivery')
  if ($finalRelative -and (Test-Path -LiteralPath (Join-Path $session $finalRelative))) {
    $html = Get-Content -LiteralPath (Join-Path $session $finalRelative) -Raw -Encoding UTF8
    if ($html -notmatch 'html_builder_mode.{0,80}skill_template_rendered') { $warnings.Add('final_delivery_not_template_rendered') }
  }
  $overall = if ($blockers.Count) {'fail'} elseif ($warnings.Count) {'pass_with_warnings'} else {'pass'}
  $report = [ordered]@{ workflow_lineage_report=[ordered]@{ report_id=('LINEAGE-'+(Get-Date -Format 'yyyyMMdd-HHmmss')); session_id=[string](Get-MapValue $manifest 'session_id'); session_path=$session; overall_result=$overall; blocker_count=$blockers.Count; warning_count=$warnings.Count; checks=@($checks); blocker_reasons=@($blockers); warning_reasons=@($warnings); next_action=if($blockers.Count){'repair_lineage_blockers'}elseif($warnings.Count){'render_with_deterministic_renderer'}else{'eligible_for_final_review'} } }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8
  @('# Workflow Lineage Report','', '```yaml', "session_id: $([string](Get-MapValue $manifest 'session_id'))", "overall_result: $overall", "blocker_count: $($blockers.Count)", "warning_count: $($warnings.Count)",'```','', '## Blockers','') + $(if($blockers.Count){$blockers|ForEach-Object{"- $_"}}else{'None'}) + @('','## Warnings','') + $(if($warnings.Count){$warnings|ForEach-Object{"- $_"}}else{'None'}) | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8
  Write-Output "WORKFLOW_LINEAGE_RESULT=$overall"; if($blockers.Count){exit 1}; exit 0
} catch { Write-Error $_; exit 3 }
