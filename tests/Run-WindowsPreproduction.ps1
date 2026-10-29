# Manual owner-run host qualification; no enforced filesystem/network isolation.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputParent,[switch]$StaticOnly)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$repo=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
function Test-Inside([string]$Child,[string]$Parent){
    $Child.Equals($Parent,[StringComparison]::OrdinalIgnoreCase) -or $Child.StartsWith($Parent+'\',[StringComparison]::OrdinalIgnoreCase)
}
function Assert-OrdinaryPath([string]$Path){
    $current=$Path
    while($current){
        if(Test-Path -LiteralPath $current){if((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse paths are not accepted.'}}
        $next=Split-Path $current -Parent;if($next -eq $current){break};$current=$next
    }
}
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Use Windows PowerShell 5.1 Desktop.'}
if(-not [IO.Path]::IsPathRooted($OutputParent)){throw 'OutputParent must be absolute.'}
$parent=[IO.Path]::GetFullPath($OutputParent).TrimEnd('\')
if(Test-Inside $parent $repo){throw 'Output must be outside the input repository.'}
Assert-OrdinaryPath $repo;Assert-OrdinaryPath $parent
# Require an existing owner-selected directory; never reuse an artifact root.
if(-not (Test-Path -LiteralPath $parent -PathType Container)){throw 'Create an owner-controlled OutputParent first.'}
$current=$parent
while($current){
    if((Test-Path -LiteralPath (Join-Path $current 'source-manifest.json')) -or (Test-Path -LiteralPath (Join-Path $current 'receipt.json'))){throw 'OutputParent is inside an existing artifact.'}
    $next=Split-Path $current -Parent;if($next -eq $current){break};$current=$next
}
if(-not $StaticOnly){
    $release=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if($release -lt 528040){throw '.NET Framework 4.8 or newer is required.'}
    if(-not (Get-Module -ListAvailable PSParseHTML | Where-Object Version -eq ([version]'3.0.6'))){throw 'PSParseHTML 3.0.6 must already be installed; nothing is installed by this runner.'}
    if(-not (Get-Module -ListAvailable Pester | Where-Object Version -eq ([version]'3.4.0'))){throw 'Pester 3.4.0 must already be installed; nothing is installed by this runner.'}
    $available=@(Get-Module -ListAvailable PSParseHTML)
    if(@($available | Where-Object Version -ne ([version]'3.0.6')).Count){throw 'Multiple PSParseHTML versions: use a host with only 3.0.6 available for this manual gate.'}
}
$runId=[guid]::NewGuid().ToString('N')
$output=Join-Path $parent ('PSWC-preproduction-'+$runId)
[void](New-Item -ItemType Directory -Path $output -ErrorAction Stop)
$receipt=[ordered]@{RunId=$runId;StaticOnly=[bool]$StaticOnly;Status='Preparing';ParentPid=$PID;ChildPid=$null;ChildStartUtc=$null;ChildExitUtc=$null;ExitCode=$null;TimedOut=$false;ParentObservedExit=$false;ReadersDone=$false;NetworkIsolation='NotEnforced';C2='UnavailableInRepository';DependencyVersion=if($StaticOnly){$null}else{'3.0.6'}}
$p=$null;$started=$false
try {
    $moduleFiles=@(Get-ChildItem -LiteralPath (Join-Path $repo 'PSWebCrawler') -File -Recurse -Force)
    $testNames=@('Run-WindowsPreproduction.ps1','Preproduction.Guard.ps1','Run-SiteContract.ps1','Site.Contract.Tests.ps1','Site.Traversal.Tests.ps1','Baseline.Tests.ps1','Dependency.Tests.ps1','Import.Tests.ps1','Import.Runtime.Tests.ps1')
    $files=$moduleFiles+@($testNames | ForEach-Object {Get-Item -LiteralPath (Join-Path $PSScriptRoot $_)})
    $manifest=@(foreach($file in $files){
        if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Source links are not accepted.'}
        $relative=$file.FullName.Substring($repo.Length+1)
        $destination=Join-Path $output $relative
        [void][IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
        $before=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Copy-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop
        if((Get-FileHash -LiteralPath $destination).Hash -ne $before -or (Get-FileHash -LiteralPath $file.FullName).Hash -ne $before){throw 'Copy/source hash changed.'}
        [pscustomobject]@{Path=$relative;Sha256=$before}
    })
    # This manifest binds every staged source, including the fixed guard, before launch.
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'source-manifest.json') -Encoding UTF8
    $guard=Join-Path $output 'tests\Preproduction.Guard.ps1'
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $receipt.LaunchExecutableSha256=(Get-FileHash -LiteralPath $info.FileName).Hash
    $receipt.GuardSha256=(Get-FileHash -LiteralPath $guard).Hash
    $receipt.ManifestSha256=(Get-FileHash -LiteralPath (Join-Path $output 'source-manifest.json')).Hash
    $info.Arguments='-NoProfile -NonInteractive -File "'+$guard+'"';if($StaticOnly){$info.Arguments+=' -StaticOnly'}
    $info.WorkingDirectory=$output;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$info
    $receipt.Status='Running';$started=$p.Start();$receipt.ChildPid=$p.Id;$receipt.ChildStartUtc=$p.StartTime.ToUniversalTime().ToString('o')
    $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
    if(-not $p.WaitForExit(300000)){$receipt.TimedOut=$true;$p.Kill();[void]$p.WaitForExit(5000)}
    $receipt.ParentObservedExit=$p.HasExited
    if($p.HasExited){$receipt.ExitCode=$p.ExitCode;$receipt.ChildExitUtc=$p.ExitTime.ToUniversalTime().ToString('o')}
    $receipt.ReadersDone=$stdout.Wait(5000) -and $stderr.Wait(5000)
    if($stdout.IsCompleted){[IO.File]::WriteAllText((Join-Path $output 'stdout.txt'),$stdout.Result)}
    if($stderr.IsCompleted){[IO.File]::WriteAllText((Join-Path $output 'stderr.txt'),$stderr.Result)}
    if($receipt.TimedOut -or -not $receipt.ParentObservedExit -or -not $receipt.ReadersDone -or $receipt.ExitCode -ne 0 -or $stderr.Result -ne ''){throw 'Child qualification failed; inspect the new receipt and logs.'}
    foreach($entry in $manifest){if((Get-FileHash -LiteralPath (Join-Path $output $entry.Path)).Hash -ne $entry.Sha256){throw 'Prepared sources changed during run.'}}
    $receipt.Status='Passed'
}
catch {$receipt.Status='Failed';$receipt.Failure=$_.Exception.Message}
finally {
    if($started -and -not $p.HasExited){$p.Kill();[void]$p.WaitForExit(5000)}
    if($p){$p.Dispose()}
    $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding UTF8
}
Write-Output $output
if($receipt.Status -ne 'Passed'){exit 1}
exit 0
