[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$root=Split-Path $PSScriptRoot -Parent
$manifest=Get-Content -LiteralPath (Join-Path $root 'source-manifest.json') -Raw | ConvertFrom-Json
foreach($entry in $manifest){
    $path=Join-Path $root $entry.Path
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.Sha256){throw ('Prepared source changed: '+$entry.Path)}
}
$parsed=0
foreach($entry in $manifest | Where-Object {$_.Path -match '\.(ps1|psm1|psd1)$'}){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $entry.Path),[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw ('Parser rejected: '+$entry.Path)}
    $parsed++
    if($entry.Path -in @('tests\Site.Contract.Tests.ps1','tests\Site.Traversal.Tests.ps1')){
        $cases=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It'},$true))
        $expected=if($entry.Path -eq 'tests\Site.Contract.Tests.ps1'){@(1..32 | ForEach-Object {$_.ToString('00')})+@(1..14 | ForEach-Object {'S3-'+$_.ToString('00')})}else{@(1..16 | ForEach-Object {'S4-'+$_.ToString('00')})}
        $ids=@($cases | ForEach-Object {($_.CommandElements[1].Value -split ' ')[0]})
        if(($ids -join ',') -cne ($expected -join ',')){throw 'Active ordered matrix identity mismatch.'}
        foreach($case in $cases){foreach($element in $case.CommandElements){if($element -is [Management.Automation.Language.CommandParameterAst] -and $element.ParameterName -in @('Skip','Pending','TestCases')){throw 'Inactive or expanded matrix case.'}}}
    }
}
$data=Import-PowerShellDataFile (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1')
if(($data.FunctionsToExport -join ',') -cne 'Start-PSWebCrawler' -or ($data.AliasesToExport -join ',') -cne 'PSWC,PSWebCrawler'){throw 'Public export contract changed.'}
$tokens=$null;$errors=$null
$module=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'),[ref]$tokens,[ref]$errors)
$functions=@($module.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
foreach($rule in @(@{Name='Test-PSWCCapability';Text='return $false'},@{Name='Invoke-PSWCFetchPage';Text='The page transport is unavailable.'},@{Name='Get-PSWCStartPolicy';Text='Allowed=$false'})){
    $f=@($functions | Where-Object Name -eq $rule.Name)
    if($f.Count -ne 1 -or -not $f[0].Body.Extent.Text.Contains($rule.Text)){throw ('Offline stub contract changed: '+$rule.Name)}
}
[pscustomobject]@{Stage='PreparedStatic';Parsed=$parsed;S2=32;S3=14;S4=16;C2='UnavailableInRepository';NetworkIsolation='NotEnforced'} | ConvertTo-Json -Compress
if($StaticOnly){exit 0}
& (Join-Path $PSScriptRoot 'Run-SiteContract.ps1')
exit $LASTEXITCODE
