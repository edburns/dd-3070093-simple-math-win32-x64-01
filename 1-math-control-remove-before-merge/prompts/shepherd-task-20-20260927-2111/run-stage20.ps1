[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = 'edburns/dd-3070093-simple-math-win32-x64-01'
$parentIssue = 1
$logDirectory = 'C:\Users\edburns\workareas\dd-3070093-simple-math-win32-x64-01-shepherd-control\1-math-control-remove-before-merge\prompts\shepherd-task-20-20260927-2111'
$ledgerPath = Join-Path $logDirectory 'creation-ledger.json'
$resultPath = Join-Path $logDirectory 'stage-20-result.json'
$preChildrenPath = Join-Path $logDirectory 'pre-creation-children.json'
$finalChildrenPath = Join-Path $logDirectory 'final-children.json'
$issueBodyVerifier = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\verify-github-issue-body.ps1'
$childLinkVerifier = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\verify-stage20-child-links.ps1'

$tasks = @(
    [pscustomobject]@{
        implementationSubsection = '1. Implement Fibonacci with unit and isolated CLI coverage'
        title = '1. Implement Fibonacci with unit and isolated CLI coverage'
        bodyFile = 'issue-bodies\01-1-implement-fibonacci-body.md'
    },
    [pscustomobject]@{
        implementationSubsection = '2. Add factorial and operation dispatch'
        title = '2. Add factorial and operation dispatch'
        bodyFile = 'issue-bodies\02-2-add-factorial-dispatch-body.md'
    }
)

function Write-AtomicText {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $temporaryPath = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $temporaryPath,
            $Content,
            [Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object]$Value
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 10
    Write-AtomicText -Path $Path -Content $json
}

function Read-CreationLedger {
    $parsed = [IO.File]::ReadAllText($ledgerPath) |
        ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [System.Array]) {
        throw 'Creation ledger JSON root must be an array.'
    }

    $ledger = [object[]]$parsed
    if (@($ledger | Where-Object { $_ -is [System.Array] }).Count -ne 0) {
        throw 'Creation ledger must not contain nested array entries.'
    }
    return $ledger
}

function Save-CreationLedger {
    param([AllowEmptyCollection()][object[]]$Ledger)
    Write-AtomicJson -Path $ledgerPath -Value ([object[]]$Ledger)
}

function Update-LedgerFlag {
    param(
        [int]$Number,
        [ValidateSet('body_verified', 'linked')]
        [string]$Field,
        [bool]$Value
    )

    $ledger = @(Read-CreationLedger)
    $entry = @($ledger | Where-Object { $_.number -eq $Number })
    if ($entry.Count -ne 1) {
        throw "Expected exactly one ledger entry for issue #$Number."
    }
    $entry[0].$Field = $Value
    Save-CreationLedger -Ledger $ledger
}

function Get-NormalizedChildrenJson {
    $childrenOutput = & gh api "repos/$repo/issues/$parentIssue/sub_issues" --paginate --slurp 2>&1
    $childrenExitCode = $LASTEXITCODE
    if ($childrenExitCode -ne 0) {
        throw "Unable to query parent children: $($childrenOutput | Out-String)"
    }

    $completeJson = $childrenOutput | Out-String
    $normalized = $completeJson |
        & jq 'if length == 0 then [] elif all(.[]; type == "array") then add else . end' 2>&1
    $jqExitCode = $LASTEXITCODE
    if ($jqExitCode -ne 0) {
        throw "Unable to normalize parent children: $($normalized | Out-String)"
    }
    return ($normalized | Out-String).Trim()
}

function Reconcile-Ledger {
    $normalizedJson = Get-NormalizedChildrenJson
    $serverChildren = @($normalizedJson | ConvertFrom-Json)
    $linkedIds = @($serverChildren | ForEach-Object { [Int64]$_.id })
    $ledger = @(Read-CreationLedger)
    foreach ($entry in $ledger) {
        $entry.linked = $linkedIds -contains [Int64]$entry.id
    }
    Save-CreationLedger -Ledger $ledger
}

function Set-StageResult {
    param(
        [ValidateSet('in_progress', 'failed', 'complete')]
        [string]$Status,
        [AllowNull()]
        [string]$OperationError
    )

    Write-AtomicJson -Path $resultPath -Value ([ordered]@{
        schemaVersion = 1
        status = $Status
        ledgerFile = 'creation-ledger.json'
        operationError = $OperationError
    })
}

Save-CreationLedger -Ledger @()
Set-StageResult -Status in_progress -OperationError $null

$currentOperation = 'initialization'
try {
    foreach ($task in $tasks) {
        $bodyFile = Join-Path $logDirectory $task.bodyFile
        $currentOperation = "create issue for $($task.implementationSubsection)"
        $createOutput = & gh api "repos/$repo/issues" `
            -X POST `
            -f "title=$($task.title)" `
            -F "body=@$bodyFile" 2>&1
        $createExitCode = $LASTEXITCODE
        if ($createExitCode -ne 0) {
            throw "GitHub issue creation failed: $($createOutput | Out-String)"
        }
        try {
            $created = ($createOutput | Out-String) | ConvertFrom-Json
        }
        catch {
            throw "GitHub issue creation returned invalid JSON: $($_.Exception.Message)"
        }

        $ledger = @(Read-CreationLedger)
        $ledger += [pscustomobject][ordered]@{
            implementationSubsection = $task.implementationSubsection
            bodyFile = $task.bodyFile
            id = [Int64]$created.id
            number = [int]$created.number
            title = [string]$created.title
            url = [string]$created.html_url
            body_verified = $false
            linked = $false
        }
        Save-CreationLedger -Ledger $ledger

        $currentOperation = "verify body for issue #$($created.number)"
        try {
            $observedIssue = & $issueBodyVerifier `
                -Repository $repo `
                -IssueNumber $created.number `
                -ExpectedBodyPath $bodyFile `
                -MaxAttempts 6 `
                -DelaySeconds 5 `
                -DiagnosticPath (
                    Join-Path $logDirectory `
                        "issue-$($created.number)-body-verification-failure.json"
                )
        }
        catch {
            throw "Issue body verification failed for issue #$($created.number): $($_.Exception.Message)"
        }
        if ($null -eq $observedIssue) {
            throw "Issue body verifier returned no issue for #$($created.number)."
        }
        Update-LedgerFlag -Number $created.number -Field body_verified -Value $true

        $currentOperation = "link issue #$($created.number) to parent #$parentIssue"
        $linked = $false
        $lastLinkError = ''
        for ($attempt = 1; $attempt -le 3 -and -not $linked; $attempt++) {
            $linkJson = ConvertTo-Json -Compress -InputObject @{
                sub_issue_id = [Int64]$created.id
            }
            $linkOutput = $linkJson |
                & gh api "repos/$repo/issues/$parentIssue/sub_issues" -X POST --input - 2>&1
            $linkExitCode = $LASTEXITCODE
            if ($linkExitCode -eq 0) {
                $linked = $true
            }
            else {
                $lastLinkError = ($linkOutput | Out-String).Trim()
                if ($attempt -lt 3) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        if (-not $linked) {
            throw "Unable to link issue after 3 attempts: $lastLinkError"
        }
        Update-LedgerFlag -Number $created.number -Field linked -Value $true
    }

    $currentOperation = 'capture final child snapshot'
    $finalChildrenJson = Get-NormalizedChildrenJson
    Write-AtomicText -Path $finalChildrenPath -Content $finalChildrenJson

    $currentOperation = 'verify child count, identity, and order'
    & $childLinkVerifier `
        -PreCreationChildrenPath $preChildrenPath `
        -FinalChildrenPath $finalChildrenPath `
        -CreationLedgerPath $ledgerPath | Out-Null

    $currentOperation = 'verify final issue postconditions'
    $ledger = @(Read-CreationLedger)
    foreach ($entry in $ledger) {
        $bodyFile = Join-Path $logDirectory $entry.bodyFile
        try {
            $observedIssue = & $issueBodyVerifier `
                -Repository $repo `
                -IssueNumber $entry.number `
                -ExpectedBodyPath $bodyFile `
                -MaxAttempts 6 `
                -DelaySeconds 5 `
                -DiagnosticPath (
                    Join-Path $logDirectory `
                        "issue-$($entry.number)-final-body-verification-failure.json"
                )
        }
        catch {
            throw "Final issue verification failed for issue #$($entry.number): $($_.Exception.Message)"
        }
        if ($observedIssue.state -ne 'open') {
            throw "Issue #$($entry.number) is not open."
        }
        if (@($observedIssue.assignees).Count -ne 0) {
            throw "Issue #$($entry.number) unexpectedly has assignees."
        }
    }

    Set-StageResult -Status complete -OperationError $null
    [pscustomobject]@{
        status = 'complete'
        issues = @(Read-CreationLedger)
    } | ConvertTo-Json -Depth 10
}
catch {
    $operationError = "${currentOperation}: $($_.Exception.Message)"
    try {
        Reconcile-Ledger
    }
    catch {
        $operationError += " Reconciliation also failed: $($_.Exception.Message)"
    }
    Set-StageResult -Status failed -OperationError $operationError

    $ledger = @(Read-CreationLedger)
    [pscustomobject]@{
        status = 'failed'
        operationError = $operationError
        issues = $ledger
        cleanupCommands = @(
            $ledger | ForEach-Object {
                "gh issue delete $($_.number) --repo `"$repo`" --yes"
            }
        )
    } | ConvertTo-Json -Depth 10
    exit 1
}
