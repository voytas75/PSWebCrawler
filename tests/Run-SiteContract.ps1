# Invoke once with powershell.exe -NoProfile -NonInteractive -File in fresh D: staging.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Use native Windows PowerShell 5.1 Desktop.'}
Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
$root=Split-Path $PSScriptRoot -Parent;$testPath=Join-Path $PSScriptRoot 'Site.Contract.Tests.ps1'
foreach($path in @((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'),(Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1'),$testPath,$PSCommandPath)){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if(@($errors).Count -ne 0){throw "Parser rejected $path"}
    if($path -eq $testPath){
        $cases=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It'},$true))
        $ids=@($cases | ForEach-Object {($_.CommandElements[1].Value -split ' ')[0]})
        $expected=@(1..32 | ForEach-Object {$_.ToString('00')})+@(1..14 | ForEach-Object {'S3-'+$_.ToString('00')})
        if($cases.Count -ne 46 -or ($ids -join ',') -ne ($expected -join ',')){throw 'Expected ordered S2 01..32 and S3-01..14.'}
        $describes=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Describe'},$true))
        if($describes.Count -ne 2){throw 'Expected separate S2/S3 Describes.'}
        foreach($matrix in @(@{Index=0;Name='S2 exact 32-case Site contract';Ids=$expected[0..31]},@{Index=1;Name='S3 exact 14-case URI extraction contract';Ids=$expected[32..45]})){
            $describe=$describes[$matrix.Index]
            $owned=@($describe.CommandElements[-1].ScriptBlock.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It'},$true))
            if($describe.CommandElements[1].Value -ne $matrix.Name -or (($owned | ForEach-Object {($_.CommandElements[1].Value -split ' ')[0]}) -join ',') -ne ($matrix.Ids -join ',')){throw 'Matrix ownership mismatch.'}
        }
        foreach($case in $cases){if($case.CommandElements.Extent.Text -match '^-(Pending|Skip|TestCases)$'){throw 'Every matrix case must be active and unexpanded.'}}
    }
}
# Validate S4 as exactly sixteen active, unexpanded cases in its own Describe.
$traversal=Join-Path $PSScriptRoot 'Site.Traversal.Tests.ps1'
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($traversal,[ref]$t,[ref]$e)
if(@($e).Count){throw 'Traversal parser failed.'}
$d=@($a.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Describe'},$true))
$c=@($a.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It'},$true))
$expected=@(1..16 | ForEach-Object {'S4-'+$_.ToString('00')})
if($d.Count -ne 1 -or $d[0].CommandElements[1].Value -ne 'S4 exact 16-case Site traversal contract' -or $c.Count -ne 16 -or (($c | ForEach-Object {($_.CommandElements[1].Value -split ' ')[0]}) -join ',') -ne ($expected -join ',')){throw 'S4 matrix mismatch.'}
foreach($case in $c){if($case.CommandElements.Extent.Text -match '^-(Pending|Skip|TestCases)$'){throw 'S4 must be active and unexpanded.'}}
# Every matrix/regression gate gets a fresh process; no HAP or mocks carried between gates.
foreach($gate in @(
    @{Name='S2';Count=32;Files=@('Site.Contract.Tests.ps1');TestName='S2 exact 32-case Site contract'},
    @{Name='S3';Count=14;Files=@('Site.Contract.Tests.ps1');TestName='S3 exact 14-case URI extraction contract'},
    @{Name='S4';Count=16;Files=@('Site.Traversal.Tests.ps1');TestName='S4 exact 16-case Site traversal contract'},
    @{Name='Baseline';Count=7;Files=@('Baseline.Tests.ps1')},
    @{Name='DependencyImport';Count=5;Files=@('Dependency.Tests.ps1','Import.Tests.ps1')},
    @{Name='ImportRuntime';Count=4;Files=@('Import.Runtime.Tests.ps1')}
)){
    $paths=@($gate.Files | ForEach-Object {"'"+(Join-Path $PSScriptRoot $_).Replace("'","''")+"'"}) -join ','
    $selection=if($gate.TestName){" -TestName '"+$gate.TestName.Replace("'","''")+"'"}else{''}
    $code=@'
$ProgressPreference='SilentlyContinue'
$ErrorActionPreference='Stop'
Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
$r=Invoke-Pester -Script @(PATHS)SELECTION -PassThru 4>$null 6>$null
$r | Select-Object TotalCount,PassedCount,FailedCount,PendingCount,SkippedCount | ConvertTo-Json -Compress
if($r.TotalCount -ne EXPECTED -or $r.PassedCount -ne EXPECTED -or $r.FailedCount -ne 0 -or $r.PendingCount -ne 0 -or $r.SkippedCount -ne 0){exit 1}
exit 0
'@
    $code=$code.Replace('PATHS',$paths).Replace('SELECTION',$selection).Replace('EXPECTED',[string]$gate.Count)
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -NonInteractive -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info;$started=$false
    try {
        $started=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(40000)){$process.Kill();[void]$process.WaitForExit(5000);throw "Deadline: $($gate.Name)"}
        if(-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)){throw "Reader deadline: $($gate.Name)"}
        $receipt=$stdout.Result | ConvertFrom-Json
        Write-Output "$($gate.Name): exit=$($process.ExitCode) $($stdout.Result.Trim())"
        if($process.ExitCode -ne 0 -or $stderr.Result -ne '' -or $receipt.TotalCount -ne $gate.Count -or $receipt.PassedCount -ne $gate.Count -or $receipt.FailedCount -ne 0 -or $receipt.PendingCount -ne 0 -or $receipt.SkippedCount -ne 0){throw "Gate failed: $($gate.Name)"}
    }
    finally {if($started -and -not $process.HasExited){$process.Kill();[void]$process.WaitForExit(5000)};$process.Dispose()}
}
exit 0
