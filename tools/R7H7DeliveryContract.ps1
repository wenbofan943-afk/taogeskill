Set-StrictMode -Version 2.0

if (-not (Get-Command Get-R7RuntimeHash -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
}
if (-not (Get-Command Read-R7JsonFile -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
}

function Test-R7H7ObjectProperty {
  param([object]$Object,[string]$Name)
  if ($null -eq $Object) { return $false }
  if ($Object -is [Collections.IDictionary]) { return $Object.Contains($Name) }
  return @($Object.PSObject.Properties.Name) -contains $Name
}

function Get-R7H7RefDigest {
  param([object]$Ref)
  if ($null -eq $Ref -or -not (Test-R7H7ObjectProperty $Ref 'sha256')) { return $null }
  return ([string]$Ref.sha256).ToLowerInvariant()
}

function Test-R7H7ImageAssetSetV03 {
  param([string]$SessionRoot,[object]$AssetSet)
  $errors=[Collections.Generic.List[string]]::new()
  if ([string]$AssetSet.schema_id -ne 'taoge://schemas/r7/image-asset-set/v0.3') { $errors.Add('h7_asset_set_version_invalid') }
  $assetById=@{};$bindingByTask=@{}
  foreach($asset in @($AssetSet.assets)){
    $id=[string]$asset.asset_id
    if([string]::IsNullOrWhiteSpace($id)-or$assetById.ContainsKey($id)){$errors.Add("h7_asset_id_duplicate:$id");continue}
    $assetById[$id]=$asset
    try{
      $path=Resolve-R7RuntimePath $SessionRoot ([string]$asset.relative_path)
      if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("h7_asset_file_missing:$id")}
      elseif((Get-R7RuntimeHash $path)-ne([string]$asset.sha256).ToLowerInvariant()){$errors.Add("h7_asset_digest_mismatch:$id")}
    }catch{$errors.Add("h7_asset_path_invalid:$id")}
    foreach($pair in @(@('sidecar_path','sidecar_sha256'),@('generation_record_path','generation_record_sha256'))){
      try{$evidencePath=Resolve-R7RuntimePath $SessionRoot ([string]$asset.($pair[0]));if(-not(Test-Path -LiteralPath $evidencePath -PathType Leaf)){$errors.Add("h7_asset_evidence_missing:${id}:$($pair[0])")}elseif((Get-R7RuntimeHash $evidencePath)-ne[string]$asset.($pair[1])){$errors.Add("h7_asset_evidence_digest_mismatch:${id}:$($pair[0])")}}catch{$errors.Add("h7_asset_evidence_invalid:${id}:$($pair[0])")}
    }
    if(@($asset.postprocess.completed_steps).Count){
      if([string]::IsNullOrWhiteSpace([string]$asset.postprocess_record_path)-or[string]$asset.postprocess_record_sha256-notmatch'^sha256:[a-f0-9]{64}$'){$errors.Add("h7_postprocess_record_missing:$id")}
      else{try{$postPath=Resolve-R7RuntimePath $SessionRoot ([string]$asset.postprocess_record_path);if(-not(Test-Path -LiteralPath $postPath -PathType Leaf)-or(Get-R7RuntimeHash $postPath)-ne[string]$asset.postprocess_record_sha256){$errors.Add("h7_postprocess_record_digest_mismatch:$id")}}catch{$errors.Add("h7_postprocess_record_invalid:$id")}}
    }
  }
  foreach($binding in @($AssetSet.delivery_bindings)){
    $taskId=[string]$binding.visual_task_id
    if([string]::IsNullOrWhiteSpace($taskId)-or$bindingByTask.ContainsKey($taskId)){$errors.Add("h7_delivery_binding_duplicate:$taskId");continue}
    $bindingByTask[$taskId]=$binding
    $baseId=[string]$binding.base_asset_ref.asset_id
    if(-not$assetById.ContainsKey($baseId)){$errors.Add("h7_base_asset_missing:$taskId");continue}
    $base=$assetById[$baseId]
    if([string]$base.asset_role-ne'base'){$errors.Add("h7_base_asset_role_invalid:$taskId")}
    if((Get-R7H7RefDigest $binding.base_asset_ref)-ne([string]$base.sha256).ToLowerInvariant()){$errors.Add("h7_base_asset_ref_digest_mismatch:$taskId")}
    if($null-eq$binding.delivery_asset_ref){$errors.Add("h7_delivery_asset_ref_missing:$taskId");continue}
    $deliveryId=[string]$binding.delivery_asset_ref.asset_id
    if(-not$assetById.ContainsKey($deliveryId)){$errors.Add("h7_delivery_asset_missing:$taskId");continue}
    $delivery=$assetById[$deliveryId]
    if((Get-R7H7RefDigest $binding.delivery_asset_ref)-ne([string]$delivery.sha256).ToLowerInvariant()){$errors.Add("h7_delivery_asset_ref_digest_mismatch:$taskId")}
    $required=@($binding.required_postprocess|ForEach-Object{[string]$_})
    $completed=if(Test-R7H7ObjectProperty $delivery.postprocess 'completed_steps'){@($delivery.postprocess.completed_steps|ForEach-Object{[string]$_})}else{@()}
    foreach($step in $required){if($step-notin$completed){$errors.Add("h7_required_postprocess_incomplete:${taskId}:$step")}}
    if($required.Count-gt0){
      if([string]$delivery.asset_role-ne'derived_rendition'){$errors.Add("h7_base_used_as_final_with_required_postprocess:$taskId")}
      if($null-eq$delivery.parent_asset_ref-or[string]$delivery.parent_asset_ref.asset_id-ne$baseId){$errors.Add("h7_delivery_parent_mismatch:$taskId")}
    }
    if($null-eq$delivery.visual_review_ref){$errors.Add("h7_delivery_visual_review_missing:$taskId");continue}
    try{
      $reviewPath=Resolve-R7RuntimePath $SessionRoot ([string]$delivery.visual_review_ref.path)
      if(-not(Test-Path -LiteralPath $reviewPath -PathType Leaf)){$errors.Add("h7_delivery_visual_review_file_missing:$taskId")}
      else{
        $reviewDigest=Get-R7RuntimeHash $reviewPath
        if($reviewDigest-ne(Get-R7H7RefDigest $delivery.visual_review_ref)){$errors.Add("h7_delivery_visual_review_digest_mismatch:$taskId")}
        $review=Read-R7JsonFile $reviewPath
        if([string]$review.visual_review_status-ne'pass'){$errors.Add("h7_delivery_visual_review_not_pass:$taskId")}
        if(([string]$review.output_sha256).ToLowerInvariant()-ne([string]$delivery.sha256).ToLowerInvariant()){$errors.Add("h7_delivery_visual_review_output_mismatch:$taskId")}
      }
    }catch{$errors.Add("h7_delivery_visual_review_invalid:$taskId")}
  }
  foreach($taskId in @($AssetSet.assets|ForEach-Object{[string]$_.visual_task_id}|Sort-Object -Unique)){if(-not$bindingByTask.ContainsKey($taskId)){$errors.Add("h7_delivery_binding_missing:$taskId")}}
  return [object[]]$errors.ToArray()
}

function New-R7H7ImageAssetDeliverySet {
  param([string]$SessionRoot,[object]$AssetSet,[string]$AssetSetSha256)
  $errors=@(Test-R7H7ImageAssetSetV03 $SessionRoot $AssetSet)
  if($AssetSetSha256 -notmatch '^sha256:[a-f0-9]{64}$'){$errors+=@('h7_asset_set_digest_missing')}
  $requestedAt=[string]$AssetSet.finalize_requested_at
  try{[void][DateTimeOffset]::Parse($requestedAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)}catch{$errors+=@('h7_finalize_requested_at_invalid')}
  if($errors.Count){return [pscustomobject]@{ResultCode='final_asset_binding_error';ExitCode=1;Data=$null;Errors=$errors}}
  $sessionId=Split-Path -Leaf $SessionRoot;$delivery=[Collections.Generic.List[object]]::new();$records=[Collections.Generic.List[object]]::new();$recordWrites=[Collections.Generic.List[object]]::new()
  foreach($binding in @($AssetSet.delivery_bindings)){
    $asset=@($AssetSet.assets|Where-Object{[string]$_.asset_id-eq[string]$binding.delivery_asset_ref.asset_id})|Select-Object -First 1
    $recordId="AFR-$sessionId-$($binding.visual_task_id)"
    $delivery.Add([ordered]@{visual_task_id=[string]$binding.visual_task_id;base_asset_ref=$binding.base_asset_ref;delivery_asset_ref=$binding.delivery_asset_ref;required_postprocess=[object[]]@($binding.required_postprocess);visual_review_ref=$asset.visual_review_ref})
    $record=[ordered]@{schema_id='taoge://schemas/r7/asset-finalize-record/v0.1';schema_version='0.1';finalize_record_id=$recordId;visual_task_id=[string]$binding.visual_task_id;base_asset_ref=$binding.base_asset_ref;delivery_asset_ref=$binding.delivery_asset_ref;required_postprocess=[object[]]@($binding.required_postprocess);completed_postprocess=[object[]]@($asset.postprocess.completed_steps);visual_review_ref=$asset.visual_review_ref;finalized_at=$requestedAt;finalize_status='finalized'}
    $recordText=ConvertTo-P0EvidenceJsonText ([pscustomobject](($record|ConvertTo-Json -Depth 30)|ConvertFrom-Json));$recordPath="intermediate/r7/finalize/$recordId.json";$recordDigest=Get-R7RuntimeTextDigest $recordText
    $records.Add([ordered]@{artifact_id=$recordId;artifact_type='asset_finalize_record';relative_path=$recordPath;sha256=$recordDigest})
    $recordWrites.Add([pscustomobject]@{RelativePath=$recordPath;Text=$recordText;Sha256=$recordDigest})
  }
  $payload=[ordered]@{schema_id='taoge://schemas/r7/image-asset-delivery-set/v0.1';schema_version='0.1';delivery_asset_set_id="DAS-$sessionId-001";image_asset_set_ref=[ordered]@{artifact_id=[string]$AssetSet.image_asset_set_id;sha256=$AssetSetSha256};session_id=$sessionId;delivery_assets=[object[]]$delivery.ToArray();finalize_record_refs=[object[]]$records.ToArray();delivery_asset_count=$delivery.Count;finalize_status='finalized';next_skill='copywriting-quality-review'}
  return [pscustomobject]@{ResultCode='finalized';ExitCode=0;Data=[pscustomobject](($payload|ConvertTo-Json -Depth 30)|ConvertFrom-Json);RecordWrites=[object[]]$recordWrites.ToArray();Errors=@()}
}

function New-R7L3ImageAssetDeliverySet {
  param([string]$SessionRoot,[object]$AssetSet,[string]$AssetSetSha256,[object]$ReviewSet,[string]$ReviewSetSha256)
  $errors=[Collections.Generic.List[string]]::new()
  if([string]$AssetSet.schema_id-ne'taoge://schemas/r7/image-asset-set/v0.4'){$errors.Add('l3_asset_set_version_invalid')}
  if([string]$ReviewSet.stage-ne'visual_asset_review'){$errors.Add('l3_review_set_stage_invalid')}
  if([string]$AssetSetSha256-notmatch'^sha256:[a-f0-9]{64}$'-or[string]$ReviewSetSha256-notmatch'^sha256:[a-f0-9]{64}$'){$errors.Add('l3_finalize_input_digest_invalid')}
  $assets=@($AssetSet.assets);$bindings=@($AssetSet.delivery_bindings);$reviews=@($ReviewSet.records)
  if([string]$AssetSet.asset_set_status-eq'no_visual_waiting_review'){
    if($assets.Count-ne0-or$bindings.Count-ne0-or$reviews.Count-ne0-or[string]$ReviewSet.set_status-ne'complete_no_visual'){$errors.Add('l3_no_visual_bundle_invalid')}
  }else{
    if($bindings.Count-lt1-or$reviews.Count-ne$bindings.Count){$errors.Add('l3_review_binding_count_mismatch')}
  }
  $assetById=@{};foreach($asset in $assets){$id=[string]$asset.asset_id;if([string]::IsNullOrWhiteSpace($id)-or$assetById.ContainsKey($id)){$errors.Add("l3_asset_id_duplicate:$id");continue};$assetById[$id]=$asset;try{$path=Resolve-R7RuntimePath $SessionRoot ([string]$asset.relative_path);if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-R7RuntimeHash $path)-ne[string]$asset.sha256){$errors.Add("l3_asset_file_or_digest_invalid:$id")}}catch{$errors.Add("l3_asset_path_invalid:$id")}}
  $reviewByTask=@{};foreach($review in $reviews){$taskId=[string]$review.visual_task_id;if($reviewByTask.ContainsKey($taskId)){$errors.Add("l3_review_task_duplicate:$taskId");continue};$reviewByTask[$taskId]=$review;if([string]$review.review_status-ne'pass'-or[string]$review.freshness_status-ne'current'){$errors.Add("l3_review_not_current_pass:$taskId")}}
  foreach($binding in $bindings){$taskId=[string]$binding.visual_task_id;$deliveryId=[string]$binding.delivery_asset_ref.asset_id;if(-not$assetById.ContainsKey($deliveryId)){$errors.Add("l3_delivery_asset_missing:$taskId");continue};if(-not$reviewByTask.ContainsKey($taskId)){$errors.Add("l3_delivery_review_missing:$taskId");continue};$review=$reviewByTask[$taskId];if([string]$review.asset_ref.asset_id-ne$deliveryId-or[string]$review.asset_ref.sha256-ne[string]$assetById[$deliveryId].sha256){$errors.Add("l3_delivery_review_binding_mismatch:$taskId")}}
  $requestedAt=[string]$AssetSet.finalize_requested_at;try{[void][DateTimeOffset]::Parse($requestedAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)}catch{$errors.Add('l3_finalize_requested_at_invalid')}
  if($errors.Count){return [pscustomobject]@{ResultCode='final_asset_binding_error';ExitCode=1;Data=$null;RecordWrites=@();Errors=[object[]]$errors.ToArray()}}
  $sessionId=Split-Path -Leaf $SessionRoot;$delivery=[Collections.Generic.List[object]]::new();$recordRefs=[Collections.Generic.List[object]]::new();$recordWrites=[Collections.Generic.List[object]]::new()
  foreach($binding in $bindings){
    $taskId=[string]$binding.visual_task_id;$asset=$assetById[[string]$binding.delivery_asset_ref.asset_id];$review=$reviewByTask[$taskId];$recordId="AFR-$sessionId-$taskId"
    $reviewRef=[ordered]@{artifact_id=[string]$review.visual_asset_review_id;sha256=$ReviewSetSha256}
    $delivery.Add([ordered]@{visual_task_id=$taskId;base_asset_ref=$binding.base_asset_ref;delivery_asset_ref=$binding.delivery_asset_ref;required_postprocess=[object[]]@($binding.required_postprocess);visual_review_ref=$reviewRef})
    $record=[ordered]@{schema_id='taoge://schemas/r7/asset-finalize-record/v0.1';schema_version='0.1';finalize_record_id=$recordId;visual_task_id=$taskId;base_asset_ref=$binding.base_asset_ref;delivery_asset_ref=$binding.delivery_asset_ref;required_postprocess=[object[]]@($binding.required_postprocess);completed_postprocess=[object[]]@($asset.postprocess.completed_steps);visual_review_ref=$reviewRef;finalized_at=$requestedAt;finalize_status='finalized'}
    $recordText=ConvertTo-P0EvidenceJsonText ([pscustomobject](($record|ConvertTo-Json -Depth 30)|ConvertFrom-Json));$recordPath="intermediate/r7/finalize/$recordId.json";$recordDigest=Get-R7RuntimeTextDigest $recordText
    $recordRefs.Add([ordered]@{artifact_id=$recordId;artifact_type='asset_finalize_record';relative_path=$recordPath;sha256=$recordDigest});$recordWrites.Add([pscustomobject]@{RelativePath=$recordPath;Text=$recordText;Sha256=$recordDigest})
  }
  $status=$(if($delivery.Count-eq0){'finalized_no_visual'}else{'finalized'});$payload=[ordered]@{schema_id='taoge://schemas/r7/image-asset-delivery-set/v0.2';schema_version='0.2';delivery_asset_set_id="DAS-$sessionId-001";image_asset_set_ref=[ordered]@{artifact_id=[string]$AssetSet.image_asset_set_id;sha256=$AssetSetSha256};visual_asset_review_set_ref=[ordered]@{artifact_id=[string]$ReviewSet.stage_set_id;sha256=$ReviewSetSha256};session_id=$sessionId;delivery_assets=[object[]]$delivery.ToArray();finalize_record_refs=[object[]]$recordRefs.ToArray();delivery_asset_count=$delivery.Count;finalize_status=$status;next_skill='copywriting-quality-review'}
  return [pscustomobject]@{ResultCode=$status;ExitCode=0;Data=[pscustomobject](($payload|ConvertTo-Json -Depth 30)|ConvertFrom-Json);RecordWrites=[object[]]$recordWrites.ToArray();Errors=@()}
}

function Test-R7H7ViewportV02 {
  param([object]$Report)
  $errors=[Collections.Generic.List[string]]::new()
  if([string]$Report.schema_id-ne'taoge://schemas/r7/viewport-acceptance/v0.2'){$errors.Add('h7_viewport_version_invalid')}
  if(Test-R7H7ObjectProperty $Report 'visual_acceptance_status'){$errors.Add('h7_viewport_visual_status_forbidden')}
  if([string]$Report.technical_viewport_status-eq'pass' -and [string]$Report.overall_result-ne'pass'){$errors.Add('h7_viewport_status_derivation_invalid')}
  if([string]$Report.technical_viewport_status-eq'pass'){
    if(@($Report.profiles).Count-lt2){$errors.Add('h7_viewport_profiles_missing')}
    foreach($profile in @($Report.profiles)){
      if([int]$profile.overflow_offender_count-ne0-or[int]$profile.failed_image_count-ne0-or[int]$profile.failed_request_count-ne0){$errors.Add("h7_viewport_false_pass:$($profile.profile_id)")}
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7H7BusinessDeliveryAcceptance {
  param([object]$Review,[object]$ViewportReport)
  $errors=[Collections.Generic.List[string]]::new();$required=@('information_hierarchy','delivery_title_quality','final_asset_binding','readiness_truthfulness','visual_human_review','action_usability');$seen=@{}
  if([string]$Review.schema_id-ne'taoge://schemas/r7/business-delivery-acceptance/v0.1'){$errors.Add('h7_business_acceptance_version_invalid')}
  if([string]$Review.html_sha256-ne[string]$ViewportReport.html_sha256){$errors.Add('h7_business_html_digest_mismatch')}
  foreach($d in @($Review.dimensions)){$id=[string]$d.dimension_id;if($seen.ContainsKey($id)){$errors.Add("h7_business_dimension_duplicate:$id")}else{$seen[$id]=$d}}
  foreach($id in $required){if(-not$seen.ContainsKey($id)){$errors.Add("h7_business_dimension_missing:$id")}}
  $profileById=@{};foreach($p in @($ViewportReport.profiles)){$profileById[[string]$p.profile_id]=$p}
  foreach($pair in @(@('desktop_screenshot_ref','desktop-1440x1000'),@('mobile_screenshot_ref','mobile-390x844'))){$ref=$Review.review_evidence.($pair[0]);if(-not$profileById.ContainsKey($pair[1])-or[string]$ref.sha256-ne[string]$profileById[$pair[1]].screenshot_sha256){$errors.Add("h7_business_screenshot_binding_mismatch:$($pair[1])")}}
  if(-not[bool]$Review.review_evidence.actual_images_viewed){$errors.Add('h7_business_actual_visual_review_missing')}
  $failCount=@($Review.dimensions|Where-Object{$_.status-eq'fail'}).Count;$warningCount=@($Review.dimensions|Where-Object{$_.status-eq'warning'}).Count
  $expected=if($failCount){'business_delivery_rejected'}elseif($warningCount){'pass_with_warnings'}else{'pass'}
  if([string]$Review.business_delivery_status-ne$expected){$errors.Add('h7_business_status_derivation_invalid')}
  return [object[]]$errors.ToArray()
}

function ConvertTo-R7H7PlatformUnitsHtml {
  param([object]$Document,[string]$SessionRoot,[string]$HtmlBase)
  $items=[Collections.Generic.List[string]]::new()
  foreach($unit in @($Document.platform_delivery_units|Sort-Object display_order)){
    $asset=Resolve-P0V2SessionReference $SessionRoot ([string]$unit.cover_asset_path) $HtmlBase
    $samePreview=([string]$unit.cover_preview_path-eq[string]$unit.cover_asset_path)-or([string]$unit.cover_preview_sha256-eq[string]$unit.cover_sha256)
    $previewHtml=if($samePreview){''}else{$preview=Resolve-P0V2SessionReference $SessionRoot ([string]$unit.cover_preview_path) $HtmlBase;'<div><span class="label">平台表面预览</span><img src="'+[string](Encode-P0V2Html $preview.HtmlPath)+'" alt="'+[string](Encode-P0V2Html ([string]$unit.platform_label))+' preview"></div>'}
    $hashtags=[string]::Join(' ',@($unit.hashtags|ForEach-Object{Encode-P0V2Html $_}))
    $items.Add('<article class="card platform-card"><div><h3>'+[string](Encode-P0V2Html ([string]$unit.platform_label))+'</h3><div class="asset-pair"><div><span class="label">封面成品</span><img src="'+[string](Encode-P0V2Html $asset.HtmlPath)+'" alt="'+[string](Encode-P0V2Html ([string]$unit.rendered_cover_text))+'"><a class="download" href="'+[string](Encode-P0V2Html $asset.HtmlPath)+'" download>下载封面</a></div>'+$previewHtml+'</div></div><div><span class="label">封面标题</span><textarea class="copy-field" readonly>'+[string](Encode-P0V2Html ([string]$unit.cover_title))+'</textarea><span class="label">视频标题</span><textarea class="copy-field" readonly>'+[string](Encode-P0V2Html ([string]$unit.video_title))+'</textarea><span class="label">发布描述</span><textarea class="copy-field" readonly>'+[string](Encode-P0V2Html ([string]$unit.publish_description))+'</textarea><span class="label">话题标签</span><p>'+$hashtags+'</p></div></article>')
  }
  return [string]::Join("`n",$items.ToArray())
}

function Invoke-R7H7AssetFinalize {
  param([string]$ProjectRoot,[string]$SessionRoot,[string]$NodeId='visual_asset_finalize')
  try{
    $current=Get-R7CandidateCurrentArtifact $SessionRoot 'image_asset_set'
    if($NodeId-eq'visual_asset_finalize_l3'){$reviewCurrent=Get-R7CandidateCurrentArtifact $SessionRoot 'visual_asset_review_set';$result=New-R7L3ImageAssetDeliverySet $SessionRoot $current.Payload ([string]$current.Sha256) $reviewCurrent.Payload ([string]$reviewCurrent.Sha256)}else{$result=New-R7H7ImageAssetDeliverySet $SessionRoot $current.Payload ([string]$current.Sha256)}
    if($result.ExitCode-ne0){return New-R7RuntimeResult $result.ResultCode $result.ExitCode $null @($result.Errors)}
    foreach($record in @($result.RecordWrites)){
      $path=Resolve-R7RuntimePath $SessionRoot ([string]$record.RelativePath)
      Write-P0EvidenceAtomicText $path ([string]$record.Text)
      if((Get-R7RuntimeHash $path)-ne[string]$record.Sha256){throw "finalize_record_digest_mismatch:$($record.RelativePath)"}
    }
  }catch{return New-R7RuntimeResult 'final_asset_binding_error' 1 $null @($_.Exception.Message)}
  $sources=@([string]$current.Pointer.artifact_id);if($NodeId-eq'visual_asset_finalize_l3'){$sources+=@([string]$reviewCurrent.Pointer.artifact_id)}
  return Commit-R7DeterministicArtifact $ProjectRoot $SessionRoot $NodeId 'image_asset_delivery_set' ([string]$result.Data.delivery_asset_set_id) $result.Data ([string]$result.Data.finalize_status) $sources @('R3-C164','R3-C175','R7-C146','R7-C149')
}
