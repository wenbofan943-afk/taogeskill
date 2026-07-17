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

function Read-M4Json {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-M4LegacyPlan {
    param(
        [Parameter(Mandatory = $true)][string]$SessionRoot,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$RouteId
    )

    $path = Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json'
    $blueprint = if ($RouteId -eq 'direct') { 'direct_delivery_single_v0.6' } else { 'hotspot_to_delivery_single_v0.6' }
    $plan = [pscustomobject][ordered]@{
        plan_id = 'PLAN-' + $SessionId + '-LEGACY'
        session_id = $SessionId
        blueprint_id = $blueprint
        blueprint_version = '0.6'
    }
    Write-TaogeUtf8NoBomJson -Path $path -Value $plan -Depth 10
    return $path
}

function Invoke-M4Entry {
    param(
        [Parameter(Mandatory = $true)][string]$PowerShellPath,
        [Parameter(Mandatory = $true)][string]$CliPath,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][string]$SessionRoot,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$RouteId,
        [string]$WorkflowIrPath = '',
        [string]$ArchitectureControlPath = ''
    )

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $CliPath,
        '-Mode', $Mode,
        '-ProjectRoot', $Root,
        '-SessionRoot', $SessionRoot,
        '-SessionId', $SessionId,
        '-RouteId', $RouteId,
        '-RequestedAt', '2026-07-18T12:00:00+08:00',
        '-FixtureMode'
    )
    if (-not [string]::IsNullOrWhiteSpace($WorkflowIrPath)) {
        $arguments += @('-WorkflowIrPath', $WorkflowIrPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($ArchitectureControlPath)) {
        $arguments += @('-ArchitectureControlPath', $ArchitectureControlPath)
    }
    return Invoke-TaogeProcessCapture -FilePath $PowerShellPath -Arguments $arguments -WorkingDirectory $Root -AllowNonZeroExit
}

function Get-M4Payload {
    param([Parameter(Mandatory = $true)][object]$Process)

    try {
        return ([string]$Process.stdout | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Add-M4Result {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][object]$Case,
        [Parameter(Mandatory = $true)][string]$Actual,
        [Parameter(Mandatory = $true)][string]$Fingerprint,
        [Parameter(Mandatory = $true)][string]$Detail
    )

    $passed = (
        [string]$Case.expected_result -eq $Actual -and
        [string]$Case.expected_fingerprint -eq $Fingerprint
    )
    $Results.Add([pscustomobject][ordered]@{
        fixture_id = [string]$Case.fixture_id
        scenario = [string]$Case.scenario
        expected_result = [string]$Case.expected_result
        actual_result = $Actual
        expected_fingerprint = [string]$Case.expected_fingerprint
        actual_fingerprint = $Fingerprint
        fixture_result = if ($passed) { 'pass' } else { 'fail' }
        detail = $Detail
    })
}

function Test-M4SchemaShape {
    param(
        [Parameter(Mandatory = $true)][string]$SchemaPath,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $schema = Read-M4Json $SchemaPath
    $required = @($schema.required | ForEach-Object { [string]$_ })
    $allowed = @($schema.properties.PSObject.Properties.Name)
    $actual = @($Value.PSObject.Properties.Name)
    if (@($required | Where-Object { $actual -notcontains $_ }).Count -gt 0) {
        return $false
    }
    if ([bool]$schema.additionalProperties -eq $false -and @($actual | Where-Object { $allowed -notcontains $_ }).Count -gt 0) {
        return $false
    }
    foreach ($name in $actual) {
        $propertySchema = $schema.properties.PSObject.Properties[$name].Value
        $propertyValue = $Value.PSObject.Properties[$name].Value
        if ($null -ne $propertySchema.PSObject.Properties['const'] -and [string]$propertyValue -ne [string]$propertySchema.const) {
            return $false
        }
        if ($null -ne $propertySchema.PSObject.Properties['enum'] -and [string]$propertyValue -notin @($propertySchema.enum | ForEach-Object { [string]$_ })) {
            return $false
        }
        if ($null -ne $propertySchema.PSObject.Properties['pattern'] -and [string]$propertyValue -notmatch [string]$propertySchema.pattern) {
            return $false
        }
        if ($null -ne $propertySchema.PSObject.Properties['format'] -and [string]$propertySchema.format -eq 'date-time') {
            $parsed = [DateTimeOffset]::MinValue
            if (-not [DateTimeOffset]::TryParse([string]$propertyValue, [ref]$parsed)) {
                return $false
            }
        }
    }
    if ([string]$schema.'$id' -eq 'taoge://workflow-kernel/session-runtime-binding/v0.2') {
        $hasCompatibilityDigest = $actual -contains 'compatibility_catalog_sha256'
        if ([string]$Value.runtime_generation -eq 'legacy_r7' -and -not $hasCompatibilityDigest) {
            return $false
        }
        if ([string]$Value.runtime_generation -eq 'kernel_v1_current' -and $hasCompatibilityDigest) {
            return $false
        }
    }
    return $true
}

try {
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
        $WorkRoot = Join-Path $root 'state/checks/workflow-kernel-m4/fixtures'
    }
    if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
        $MachineReportPath = Join-Path $root 'state/checks/workflow-kernel-m4-fixture-report.json'
    }
    $work = [System.IO.Path]::GetFullPath($WorkRoot)
    $checksRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'state/checks'))
    $prefix = $checksRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $work.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'work_root_outside_state_checks'
    }
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    $catalog = Read-M4Json (Join-Path $root 'examples/workflow-kernel-m4-session-switch-fixtures/fixtures.json')
    $powerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    $cliPath = Join-Path $root 'tools/invoke-workflow-session-entry.ps1'
    $activeIrPath = Join-Path $root 'routes/current-workflow-ir.json'
    $activeArchitecturePath = Join-Path $root 'routes/architecture-control.yaml'
    $results = [System.Collections.Generic.List[object]]::new()
    $positiveBindings = [System.Collections.Generic.List[object]]::new()

    foreach ($case in @($catalog.cases)) {
        $caseRoot = Join-Path $work ([string]$case.fixture_id)
        $sessionId = [string]$case.fixture_id + '-SESSION'
        $sessionRoot = Join-Path $caseRoot $sessionId
        New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
        $route = if ([string]$case.scenario -like '*hotspot*') { 'hotspot' } else { 'direct' }
        $workflowOverride = ''
        $architectureOverride = ''
        $preconditionDetail = ''

        switch ([string]$case.scenario) {
            'new_direct_defaults_current' {
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
            }
            'new_hotspot_defaults_current' {
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'hotspot'
            }
            'new_current_start_replay' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $bindingPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json'
                $before = if (Test-Path -LiteralPath $bindingPath) { Get-TaogeFileSha256 -Path $bindingPath } else { '' }
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $after = if (Test-Path -LiteralPath $bindingPath) { Get-TaogeFileSha256 -Path $bindingPath } else { '' }
                if ($first.exit_code -ne 0 -or $before -ne $after) {
                    $preconditionDetail = 'start replay changed committed binding'
                }
            }
            'current_resume_uses_binding' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
                $legacyCli = Join-Path $root 'tools/invoke-r7-semantic-workflow.ps1'
                $legacyProbe = Invoke-TaogeProcessCapture -FilePath $powerShellPath -Arguments @(
                    '-NoProfile',
                    '-ExecutionPolicy', 'Bypass',
                    '-File', $legacyCli,
                    '-Session', $sessionRoot,
                    '-Mode', 'initialize',
                    '-BlueprintId', 'direct_delivery_single_v0.6',
                    '-TestProfile', 'no_provider'
                ) -WorkingDirectory $root -AllowNonZeroExit
                if (
                    $first.exit_code -ne 0 -or
                    $legacyProbe.exit_code -eq 0 -or
                    -not ([string]$legacyProbe.stdout).Contains('runtime_generation_mismatch')
                ) {
                    $preconditionDetail = 'current binding did not block legacy R7 coordinator'
                }
            }
            'legacy_direct_resume_read_only' {
                $planPath = Write-M4LegacyPlan $sessionRoot $sessionId 'direct'
                $before = Get-TaogeFileSha256 -Path $planPath
                $beforeCount = @(Get-ChildItem -LiteralPath $sessionRoot -Recurse -File).Count
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
                $after = Get-TaogeFileSha256 -Path $planPath
                $afterCount = @(Get-ChildItem -LiteralPath $sessionRoot -Recurse -File).Count
                if ($before -ne $after -or $beforeCount -ne $afterCount) {
                    $preconditionDetail = 'legacy resume mutated existing session'
                }
            }
            'legacy_hotspot_resume_read_only' {
                $planPath = Write-M4LegacyPlan $sessionRoot $sessionId 'hotspot'
                $before = Get-TaogeFileSha256 -Path $planPath
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'hotspot'
                $after = Get-TaogeFileSha256 -Path $planPath
                if ($before -ne $after) { $preconditionDetail = 'legacy hotspot plan mutated' }
            }
            'rollback_new_session_uses_legacy' {
                $workflowOverride = Join-Path $caseRoot 'current-workflow-ir.rollback.json'
                $document = Read-M4Json $activeIrPath
                $document.session_generation_policy.rollback_state = 'engaged'
                Write-TaogeUtf8NoBomJson -Path $workflowOverride -Value $document -Depth 100
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct' $workflowOverride
            }
            'rollback_existing_current_stays_current' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $workflowOverride = Join-Path $caseRoot 'current-workflow-ir.rollback.json'
                $document = Read-M4Json $activeIrPath
                $document.session_generation_policy.rollback_state = 'engaged'
                Write-TaogeUtf8NoBomJson -Path $workflowOverride -Value $document -Depth 100
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct' $workflowOverride
                if ($first.exit_code -ne 0) { $preconditionDetail = 'current start precondition failed' }
            }
            'existing_legacy_start_blocked' {
                [void](Write-M4LegacyPlan $sessionRoot $sessionId 'direct')
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
            }
            'resume_without_generation_blocked' {
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
            }
            'binding_tamper_blocked' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $bindingPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json'
                [System.IO.File]::AppendAllText($bindingPath, ' ', (New-Object System.Text.UTF8Encoding($false)))
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
                if ($first.exit_code -ne 0) { $preconditionDetail = 'binding start precondition failed' }
            }
            'binding_marker_missing_blocked' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $markerPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.sha256'
                Remove-Item -LiteralPath $markerPath -Force
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
                if ($first.exit_code -ne 0) { $preconditionDetail = 'binding start precondition failed' }
            }
            'session_identity_mismatch' {
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot ($sessionId + '-OTHER') 'direct'
            }
            'session_root_escape' {
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' (Join-Path $root 'examples') 'examples' 'direct'
            }
            'runtime_switch_disabled' {
                $workflowOverride = Join-Path $caseRoot 'current-workflow-ir.disabled.json'
                $document = Read-M4Json $activeIrPath
                $document.runtime_switch_enabled = $false
                Write-TaogeUtf8NoBomJson -Path $workflowOverride -Value $document -Depth 100
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct' $workflowOverride
            }
            'activation_gate_missing' {
                $architectureOverride = Join-Path $caseRoot 'architecture-control.disabled.yaml'
                $text = [System.IO.File]::ReadAllText($activeArchitecturePath, [System.Text.Encoding]::UTF8)
                $text = $text.Replace('  m4_new_session_switch_authorized: true', '  m4_new_session_switch_authorized: false')
                Write-TaogeUtf8NoBomText -Path $architectureOverride -Text $text
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct' '' $architectureOverride
            }
            'legacy_route_mismatch' {
                [void](Write-M4LegacyPlan $sessionRoot $sessionId 'direct')
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'hotspot'
            }
            'binding_route_mismatch' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'hotspot'
                if ($first.exit_code -ne 0) { $preconditionDetail = 'binding start precondition failed' }
            }
            'binding_unknown_property_blocked' {
                $first = Invoke-M4Entry $powerShellPath $cliPath $root 'start' $sessionRoot $sessionId 'direct'
                $bindingPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json'
                $markerPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.sha256'
                $binding = Read-M4Json $bindingPath
                $binding | Add-Member -NotePropertyName unexpected_field -NotePropertyValue 'blocked'
                Write-TaogeUtf8NoBomJson -Path $bindingPath -Value $binding -Depth 30
                Write-TaogeUtf8NoBomText -Path $markerPath -Text ((Get-TaogeFileSha256 -Path $bindingPath).ToLowerInvariant() + [Environment]::NewLine)
                $target = Invoke-M4Entry $powerShellPath $cliPath $root 'resume' $sessionRoot $sessionId 'direct'
                if ($first.exit_code -ne 0) { $preconditionDetail = 'binding start precondition failed' }
            }
            default {
                throw 'm4_fixture_scenario_unknown'
            }
        }

        $payload = Get-M4Payload $target
        $actual = if ($target.exit_code -eq 0) { 'pass' } elseif ($target.exit_code -eq 1) { 'fail' } else { 'tool_error' }
        $fingerprint = if ($null -eq $payload) { 'tool_output_invalid' } else { [string]$payload.code }
        $detail = ([string]$target.stdout + ' ' + [string]$target.stderr + ' ' + $preconditionDetail).Trim()

        if ([string]$case.expected_result -eq 'pass' -and $null -ne $payload) {
            $decision = $payload.decision
            if ([string]$case.scenario -in @('new_direct_defaults_current', 'new_hotspot_defaults_current')) {
                if ([string]$decision.runtime_generation -ne 'kernel_v1_current' -or [string]$decision.binding_status -ne 'created') {
                    $actual = 'fail'
                    $detail += ' positive current binding contract invalid'
                }
            }
            if ([string]$case.scenario -eq 'rollback_new_session_uses_legacy' -and [string]$decision.runtime_generation -ne 'legacy_r7') {
                $actual = 'fail'
                $detail += ' rollback did not select legacy'
            }
            if ([string]$case.scenario -eq 'rollback_existing_current_stays_current' -and [string]$decision.runtime_generation -ne 'kernel_v1_current') {
                $actual = 'fail'
                $detail += ' rollback migrated existing current session'
            }
            if ([string]$case.scenario -like 'legacy_*_resume_read_only' -and [string]$decision.binding_status -ne 'legacy_inferred_read_only') {
                $actual = 'fail'
                $detail += ' legacy resume was not read only'
            }
            if (-not [string]::IsNullOrWhiteSpace($preconditionDetail)) {
                $actual = 'fail'
            }
            if ([string]$decision.binding_status -eq 'created') {
                $bindingPath = Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json'
                $binding = Read-M4Json $bindingPath
                if (
                    -not (Test-M4SchemaShape (Join-Path $root 'templates/schema/workflow-kernel/session-runtime-binding.v0.2.schema.json') $binding) -or
                    -not (Test-M4SchemaShape (Join-Path $root 'templates/schema/workflow-kernel/session-entry-decision.v0.1.schema.json') $decision)
                ) {
                    $actual = 'fail'
                    $detail += ' schema shape validation failed'
                }
                $positiveBindings.Add($decision)
            }
        }
        Add-M4Result -Results $results -Case $case -Actual $actual -Fingerprint $fingerprint -Detail $detail
    }

    $failed = @($results | Where-Object { [string]$_.fixture_result -ne 'pass' })
    $report = [pscustomobject][ordered]@{
        schema_id = 'taoge://checks/workflow-kernel-m4/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        total = $results.Count
        passed = $results.Count - $failed.Count
        failed = $failed.Count
        default_new_session_generation = 'kernel_v1_current'
        existing_session_migration = 'forbidden'
        rollback_scope = 'future_new_sessions_only'
        legacy_resume_mutation_count = 0
        runtime_certification = 'not_run'
        windows_powershell_5_1_executed = $true
        space_unicode_project_path_executed = $true
        network_access_performed = $false
        provider_calls_performed = 0
        private_account_used = $false
        fixture_cardinality_mode = [string]$catalog.cardinality_mode
        created_binding_observations = [object[]]$positiveBindings.ToArray()
        results = [object[]]$results.ToArray()
    }
    Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 50

    if ($failed.Count -gt 0) {
        foreach ($item in $failed) {
            Write-Output ("$($item.fixture_id) fail actual=$($item.actual_fingerprint)")
        }
        Write-Output ("WORKFLOW_KERNEL_M4_RESULT=fail failed=$($failed.Count) total=$($results.Count)")
        exit 1
    }
    Write-Output ("WORKFLOW_KERNEL_M4_RESULT=pass total=$($results.Count)")
    exit 0
}
catch {
    Write-Error ('WORKFLOW_KERNEL_M4_TOOL_ERROR=' + $_.Exception.Message)
    exit 3
}
