[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$WorkRoot = '',
    [string]$MachineReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Read-M2Json {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Copy-M2FixtureFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Add-M2Result {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][string]$FixtureId,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Actual,
        [Parameter(Mandatory = $true)][string]$Fingerprint,
        [Parameter(Mandatory = $true)][string]$Detail
    )
    $Results.Add([pscustomobject][ordered]@{
        fixture_id = $FixtureId
        expected_result = $Expected
        actual_result = $Actual
        expected_fingerprint = $Fingerprint
        fixture_result = $(if ($Expected -eq $Actual) { 'pass' } else { 'fail' })
        detail = $Detail
    })
}

function Invoke-M2Kernel {
    param(
        [Parameter(Mandatory = $true)][string]$PowerShellPath,
        [Parameter(Mandatory = $true)][string]$KernelCliPath,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ShadowRoot,
        [string]$RequestPath = ''
    )
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $KernelCliPath,
        '-Mode', $Mode,
        '-ProjectRoot', $Root,
        '-ShadowRoot', $ShadowRoot
    )
    if (-not [string]::IsNullOrWhiteSpace($RequestPath)) {
        $arguments += @('-RequestPath', $RequestPath)
    }
    return Invoke-TaogeProcessCapture -FilePath $PowerShellPath -Arguments $arguments -WorkingDirectory $Root -AllowNonZeroExit
}

try {
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
        $WorkRoot = Join-Path $root 'state\checks\workflow-kernel-m2\fixtures'
    }
    if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
        $MachineReportPath = Join-Path $root 'state\checks\workflow-kernel-m2-fixture-report.json'
    }
    $work = [System.IO.Path]::GetFullPath($WorkRoot)
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'state\checks')).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $work.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'work_root_outside_state_checks'
    }
    if (Test-Path -LiteralPath $work) {
        $verifiedWork = [System.IO.Path]::GetFullPath($work)
        if (-not $verifiedWork.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'work_root_delete_preflight_failed'
        }
        Remove-Item -LiteralPath $verifiedWork -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    $fixtureRoot = Join-Path $root 'examples\workflow-kernel-m2-direct-shadow-fixtures'
    $fixtureCatalog = Read-M2Json (Join-Path $fixtureRoot 'fixtures.json')
    $kernelCliPath = Join-Path $root 'tools\invoke-workflow-kernel-shadow.ps1'
    $powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    $results = [System.Collections.Generic.List[object]]::new()
    $positiveEvidence = $null

    foreach ($case in @($fixtureCatalog.cases)) {
        $caseName = [string]$case.fixture_id
        if ($case.PSObject.Properties['path_variant'] -and [string]$case.path_variant -eq 'space_unicode') {
            $caseName += ' space ' + [char]0x4E2D + [char]0x6587
        }
        $caseRoot = Join-Path $work $caseName
        $sourceRoot = Join-Path $caseRoot 'source'
        $shadowRoot = Join-Path $caseRoot 'shadow'
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

        foreach ($fileName in @('baseline-request.json', 'source-content.md', 'expected-final-delivery.html')) {
            Copy-M2FixtureFile -Source (Join-Path $fixtureRoot $fileName) -Destination (Join-Path $sourceRoot $fileName)
        }
        $requestPath = Join-Path $sourceRoot 'baseline-request.json'
        $request = Read-M2Json $requestPath

        switch ([string]$case.mutation) {
            'none' {}
            'remove_component_result' {
                $request.component_results = [object[]]@($request.component_results | Select-Object -Skip 1)
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'illegal_result_status' {
                $request.component_results[0].result_status = 'fixture_status_not_allowed'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'wrong_contract_ref' {
                $request.component_results[0].output_contract_ref = 'taoge://schemas/fixture/wrong'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'failed_validation_receipt' {
                $request.component_results[0].validation_receipt.validation_status = 'fail'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'input_digest_mismatch' {
                $request.input.sha256 = ('0' * 64)
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'legacy_artifact_projection_mismatch' {
                $request.legacy_observation.artifact_projection_sha256 = ('0' * 64)
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'legacy_event_projection_mismatch' {
                $request.legacy_observation.event_projection_sha256 = ('0' * 64)
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'legacy_final_html_mismatch' {
                $request.legacy_observation.final_html_sha256 = ('0' * 64)
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'timestamp_without_timezone' {
                $request.initialized_at = '2026-07-18T09:00:00'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'hotspot_route' {
                $request.route_id = 'hotspot'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'final_decision_result_present' {
                $request.final_decision_results = [object[]]@(
                    [pscustomobject][ordered]@{
                        component_id = 'final_human_decision_gate'
                        result_status = 'approved'
                    }
                )
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'shadow_output_escape' {
                $shadowRoot = Join-Path $root 'M2-shadow-output-must-not-exist'
            }
            'artifact_tamper_before_rebuild' {}
            'unknown_result_property' {
                $request.component_results[0] | Add-Member -NotePropertyName 'fixture_unknown_field' -NotePropertyValue 'must_fail'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            'allowed_but_non_progress_status' {
                $request.component_results[0].result_status = 'waiting_human'
                Write-TaogeUtf8NoBomJson -Path $requestPath -Value $request -Depth 100
            }
            default {
                throw ('fixture_mutation_unknown:' + [string]$case.mutation)
            }
        }

        $process = Invoke-M2Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_direct' -ShadowRoot $shadowRoot -RequestPath $requestPath
        $combined = ($process.stdout + "`n" + $process.stderr).Trim()
        $actual = if ($process.exit_code -eq 0) { 'pass' } elseif ($process.exit_code -eq 1) { 'fail' } else { 'tool_error' }

        if ([string]$case.mutation -eq 'artifact_tamper_before_rebuild') {
            if ($process.exit_code -ne 0) {
                $actual = 'tool_error'
                $combined += "`ninitial_positive_run_failed"
            }
            else {
                $artifactPath = Join-Path $shadowRoot 'artifacts\final_delivery\r1\M2-DIRECT-FINAL-HTML-001.html'
                Add-TaogeUtf8NoBomLine -Path $artifactPath -Line '<!-- tampered -->'
                $rebuild = Invoke-M2Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'rebuild_projection' -ShadowRoot $shadowRoot
                $combined += "`n" + $rebuild.stdout + "`n" + $rebuild.stderr
                $actual = if ($rebuild.exit_code -eq 1) { 'fail' } else { 'tool_error' }
                if (-not $combined.Contains([string]$case.expected_fingerprint)) {
                    $actual = 'unexpected_failure_fingerprint'
                    $combined += "`nexpected_fingerprint_missing=" + [string]$case.expected_fingerprint
                }
            }
        }
        elseif ([string]$case.expected_result -eq 'pass') {
            $requiredFiles = @(
                'kernel-session.json',
                'events.jsonl',
                'artifact-projection.json',
                'event-projection.json',
                'run-state.json',
                'resume-summary.json',
                'shadow-observation.json',
                'parity-report.json'
            )
            $missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $shadowRoot $_) -PathType Leaf) })
            if ($missingFiles.Count -gt 0) {
                $actual = 'fail'
                $combined += "`nmissing_evidence=" + [string]::Join(',', $missingFiles)
            }
            else {
                $state = Read-M2Json (Join-Path $shadowRoot 'run-state.json')
                $observation = Read-M2Json (Join-Path $shadowRoot 'shadow-observation.json')
                $parity = Read-M2Json (Join-Path $shadowRoot 'parity-report.json')
                if (
                    [string]$state.stop_reason -ne 'waiting_human' -or
                    [string]$state.current_stage_id -ne 'final_decision' -or
                    [int]$state.artifact_count -ne 23 -or
                    [int]$state.event_count -ne 31 -or
                    [string]$parity.status -ne 'pass' -or
                    [string]$parity.comparison_baseline_kind -ne 'frozen_legacy_contract_fixture' -or
                    [bool]$parity.real_legacy_runtime_executed -or
                    [bool]$observation.runtime_switch_enabled -or
                    [bool]$observation.current_write_performed
                ) {
                    $actual = 'fail'
                    $combined += "`npositive_shadow_contract_invalid"
                }

                $derivedFiles = @('artifact-projection.json', 'event-projection.json', 'run-state.json', 'resume-summary.json', 'shadow-observation.json', 'parity-report.json')
                $beforeHashes = @{}
                foreach ($file in $derivedFiles) {
                    $beforeHashes[$file] = Get-TaogeFileSha256 -Path (Join-Path $shadowRoot $file)
                }
                $eventHashBefore = Get-TaogeFileSha256 -Path (Join-Path $shadowRoot 'events.jsonl')

                $rebuild = Invoke-M2Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'rebuild_projection' -ShadowRoot $shadowRoot
                $combined += "`n" + $rebuild.stdout + "`n" + $rebuild.stderr
                if ($rebuild.exit_code -ne 0) {
                    $actual = 'fail'
                    $combined += "`nprojection_rebuild_failed"
                }
                foreach ($file in $derivedFiles) {
                    $afterHash = Get-TaogeFileSha256 -Path (Join-Path $shadowRoot $file)
                    if ($afterHash -ne [string]$beforeHashes[$file]) {
                        $actual = 'fail'
                        $combined += "`nderived_file_not_byte_stable=$file"
                    }
                }

                $replay = Invoke-M2Kernel -PowerShellPath $powershellPath -KernelCliPath $kernelCliPath -Root $root -Mode 'run_direct' -ShadowRoot $shadowRoot -RequestPath $requestPath
                $combined += "`n" + $replay.stdout + "`n" + $replay.stderr
                if ($replay.exit_code -ne 0 -or -not $replay.stdout.Contains('shadow_run_reused')) {
                    $actual = 'fail'
                    $combined += "`nidempotent_replay_failed"
                }
                if ((Get-TaogeFileSha256 -Path (Join-Path $shadowRoot 'events.jsonl')) -ne $eventHashBefore) {
                    $actual = 'fail'
                    $combined += "`nevent_log_changed_on_replay"
                }
                $temporaryResidue = @(Get-ChildItem -LiteralPath $shadowRoot -Recurse -Force -File | Where-Object {
                    $_.Name.EndsWith('.tmp', [System.StringComparison]::OrdinalIgnoreCase) -or
                    $_.Name.EndsWith('.bak', [System.StringComparison]::OrdinalIgnoreCase)
                })
                if ($temporaryResidue.Count -gt 0) {
                    $actual = 'fail'
                    $combined += "`natomic_write_residue=" + [string]::Join(',', @($temporaryResidue.FullName))
                }

                $positiveEvidence = [pscustomobject][ordered]@{
                    artifact_count = [int]$observation.artifact_count
                    event_count = [int]$observation.event_count
                    stop_reason = [string]$observation.stop_reason
                    final_html_sha256 = [string]$observation.final_html_sha256
                    artifact_projection_sha256 = [string]$observation.artifact_projection_sha256
                    event_projection_sha256 = [string]$observation.event_projection_sha256
                    comparison_baseline_kind = [string]$parity.comparison_baseline_kind
                    real_legacy_runtime_executed = [bool]$parity.real_legacy_runtime_executed
                    projection_rebuild_byte_stable = $true
                    replay_reused = $true
                    atomic_write_residue_count = $temporaryResidue.Count
                }
            }
        }
        else {
            if (-not $combined.Contains([string]$case.expected_fingerprint)) {
                $actual = 'unexpected_failure_fingerprint'
                $combined += "`nexpected_fingerprint_missing=" + [string]$case.expected_fingerprint
            }
            $isParityFailure = @(
                'legacy_artifact_projection_mismatch',
                'legacy_event_projection_mismatch',
                'legacy_final_html_mismatch'
            ) -contains [string]$case.mutation
            if ($isParityFailure) {
                if (
                    -not (Test-Path -LiteralPath (Join-Path $shadowRoot 'events.jsonl') -PathType Leaf) -or
                    -not (Test-Path -LiteralPath (Join-Path $shadowRoot 'parity-report.json') -PathType Leaf)
                ) {
                    $actual = 'unexpected_evidence_loss'
                    $combined += "`nparity_failure_evidence_not_preserved"
                }
            }
            elseif ([string]$case.mutation -ne 'artifact_tamper_before_rebuild') {
                if (Test-Path -LiteralPath (Join-Path $shadowRoot 'events.jsonl') -PathType Leaf) {
                    $actual = 'unexpected_preflight_side_effect'
                    $combined += "`npreflight_failure_wrote_event_log"
                }
            }
        }

        Add-M2Result -Results $results -FixtureId ([string]$case.fixture_id) -Expected ([string]$case.expected_result) -Actual $actual -Fingerprint ([string]$case.expected_fingerprint) -Detail $combined
    }

    $failed = @($results | Where-Object { [string]$_.fixture_result -ne 'pass' })
    $report = [pscustomobject][ordered]@{
        schema_id = 'taoge://reports/workflow-kernel-m2-direct-shadow/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        fixture_set_id = [string]$fixtureCatalog.fixture_set_id
        result = $(if ($failed.Count -eq 0) { 'pass' } else { 'fail' })
        case_count = $results.Count
        passed_count = $results.Count - $failed.Count
        failed_count = $failed.Count
        route_id = 'direct'
        runtime_generation = 'kernel_v1_shadow'
        current_runtime_generation = 'legacy_r7'
        execution_scope = 'direct_positive_path_to_final_human_wait'
        intermediate_non_progress_behavior = 'block_before_shadow_write'
        runtime_switch_enabled = $false
        current_write_performed = $false
        runtime_certification = $false
        windows_powershell_5_1_executed = $true
        space_unicode_path_executed = $true
        network_called = $false
        provider_called = $false
        positive_evidence = $positiveEvidence
        cases = $results.ToArray()
    }
    Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 50

    foreach ($result in $results) {
        Write-Output ("$($result.fixture_id) $($result.fixture_result) expected=$($result.expected_result) actual=$($result.actual_result)")
    }
    if ($failed.Count -gt 0) {
        Write-Output ("WORKFLOW_KERNEL_M2_RESULT=fail failed=$($failed.Count) total=$($results.Count)")
        exit 1
    }
    Write-Output ("WORKFLOW_KERNEL_M2_RESULT=pass total=$($results.Count)")
    exit 0
}
catch {
    Write-Error ('WORKFLOW_KERNEL_M2_TOOL_ERROR=' + $_.Exception.Message + ' stack=' + [string]$_.ScriptStackTrace)
    exit 3
}
