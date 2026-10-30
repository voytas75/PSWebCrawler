# Offline diagnostics: read facts, never install, repair, fetch or set process exit status.
function New-PSWCDoctorCheck($Name,$Status,$Expected,$Actual,$Message,$Hint) {
    # Static offline catalog: commands and links are advice, never executed here.
    $docs='https://learn.microsoft.com/powershell/module/microsoft.powershell.core/get-module'
    $verify='Get-Module PSWebCrawler | Format-List Version,Path,ExportedFunctions,ExportedAliases'
    $impact='Package selection determines which implementation is being inspected.'
    $action='Compare the loaded facts with the intended trusted package in a fresh process; retain the package if they agree.'
    switch($Name){
        ModuleVersion {$action='Compare manifest and loaded version; select the intended trusted manifest in a fresh process if they differ.'}
        ModulePath {$action='Compare the loaded path with the intended trusted package; select that manifest explicitly in a fresh process.'}
        PublicInterface {$impact='Unexpected exports or alias targets indicate a package/interface inconsistency.'; $action='Compare the documented interface with the same trusted package version; report unexplained differences to its maintainer.'}
        LegacyDisplayVersion {$impact='The legacy display string is cosmetic, not the loaded package version.'; $action='Ask the maintainer to review the cosmetic display mismatch; use the loaded ModuleVersion, not the legacy display string.'}
        PowerShell {$impact='Other hosts are not qualified by this Windows PowerShell 5.1 Desktop acceptance.'; $action='Inspect the host edition/version; use an existing Windows PowerShell 5.1 Desktop host for qualification.'; $verify='$PSVersionTable'; $docs='https://learn.microsoft.com/powershell/scripting/windows-powershell/starting-windows-powershell'}
        DotNetQualification {$impact='New internal contracts require .NET 4.8 qualification; this is distinct from the legacy manifest minimum.'; $action='Review the installed Release value against the documented threshold; legacy compatibility is not blocked by this qualification warning alone.'; $verify="Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release"; $docs='https://learn.microsoft.com/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed'}
        PSParseHTML {$impact='Dependency selection affects the assembly actually used; missing prerequisites can prevent import before Doctor runs.'; $action='Inspect available and loaded versions in a fresh process; manually review dependency ownership against tested PSParseHTML 3.0.6 before any separately authorized change.'; $verify='Get-Module -ListAvailable PSParseHTML; Get-Module PSParseHTML'; $docs='https://www.powershellgallery.com/packages/PSParseHTML/3.0.6'}
        HapIdentity {$impact='A dependency can load a different HAP assembly before the bundled DLL.'; $action='Review dependency ownership and actual parser behavior: passing smoke is not evidence of incompatibility. Do not automatically replace or downgrade HAP; the latest version is not necessarily qualified.'; $verify='[HtmlAgilityPack.HtmlDocument].Assembly | Format-List FullName,Location'; $docs='https://www.nuget.org/packages/HtmlAgilityPack'}
        HtmlSmoke {$impact='This fixed in-memory parser check does not qualify fetching, DNS, HTTPS or transport.'; $action='If smoke fails, review loaded HAP identity and dependency/import errors; if it passes, retain that limited behavioral evidence without claiming transport qualification.'; $verify='Start-PSWebCrawler -Doctor | Select-Object -ExpandProperty Checks | Where-Object Name -eq HtmlSmoke'; $docs='https://github.com/zzzprojects/html-agility-pack'}
        PackageIntegrity {$impact='Byte mismatches indicate drift against the shipped inventory, not a determination of authenticity.'; $action='Compare with or manually reinstall the same trusted package version after review; never regenerate the baseline to hide a mismatch.'; $verify='Start-PSWebCrawler -Doctor | Select-Object -ExpandProperty Checks | Where-Object Name -eq PackageIntegrity'; $docs='https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-filehash'}
    }
    [pscustomobject][ordered]@{Name=$Name;Status=$Status;Expected=$Expected;Actual=$Actual;Message=$Message;Hint=$Hint;Impact=$impact;RecommendedAction=$action;VerificationCommand=$verify;DocumentationUrls=@($docs)}
}
function Get-PSWCDoctorStatus($Checks) {
    if(@($Checks | Where-Object Status -eq 'FAIL').Count){return 'FAIL'}
    if(@($Checks | Where-Object Status -eq 'WARN').Count){return 'WARN'}
    return 'PASS'
}
function Test-PSWCPackageIntegrity([string]$Root) {
    $bad=@();$count=0
    try {
        $inventory=Get-Content -LiteralPath (Join-Path $Root 'PackageIntegrity.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if($inventory.SchemaVersion -ne '1.0' -or @($inventory.Files).Count -eq 0){throw 'Invalid inventory schema or empty inventory.'}
        $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($entry in $inventory.Files){
            $path=[string]$entry.Path
            if($path -notmatch '^[A-Za-z0-9_][A-Za-z0-9_./-]*$' -or $path.Split('/') -contains '..' -or $path.Split('/') -contains '.' -or $path.Contains('//') -or $path -eq 'PackageIntegrity.json' -or $entry.Sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or -not $seen.Add($path)){throw 'Invalid or duplicate inventory entry.'}
            $full=Join-Path $Root $path
            $current=$full
            while($current -and $current.Length -ge $Root.Length){
                if(Test-Path -LiteralPath $current){if((Get-Item -LiteralPath $current -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Inventory path is a reparse point.'}}
                $current=Split-Path $current -Parent
            }
            if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$bad+='Missing: '+$path}
            elseif((Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash -ne $entry.Sha256){$bad+='Changed: '+$path}
            $count++
        }
    } catch {$bad+='Unreadable/invalid inventory: '+$_.Exception.Message}
    $status=if($bad.Count){'FAIL'}else{'PASS'}
    New-PSWCDoctorCheck 'PackageIntegrity' $status 'All inventoried SHA256 hashes match' (@{Checked=$count;Problems=@($bad)}) 'Checks packaged bytes against the shipped baseline; not authenticity or provenance.' 'Compare with a trusted clean package; do not regenerate the baseline to hide changes.'
}
function Get-PSWCDoctor {
    $root=Split-Path $PSScriptRoot -Parent
    $checks=@()
    $module=$ExecutionContext.SessionState.Module
    $data=$null
    try {$data=Import-PowerShellDataFile (Join-Path $root 'PSWebCrawler.psd1') -ErrorAction Stop} catch {}
    $expected=if($data){[string]$data.ModuleVersion}else{'Readable manifest'}
    $checks+=New-PSWCDoctorCheck 'ModuleVersion' $(if($data -and [string]$module.Version -eq $expected){'PASS'}else{'FAIL'}) $expected ([string]$module.Version) 'Manifest versus actually loaded module version.' 'Import the exact trusted manifest in a fresh process.'
    $expectedPath=Join-Path $root 'PSWebCrawler.psm1'
    $checks+=New-PSWCDoctorCheck 'ModulePath' $(if($module.Path -eq $expectedPath){'PASS'}else{'FAIL'}) $expectedPath ([string]$module.Path) 'Loaded module path, not merely an installed version.' 'Select the intended checkout/package explicitly.'
    $exports=(@($module.ExportedFunctions.Keys | Sort-Object) -join ',')+'|'+(@($module.ExportedAliases.Keys | Sort-Object) -join ',')
    $aliasesOk=@($module.ExportedAliases.Values | Where-Object Definition -ne 'Start-PSWebCrawler').Count -eq 0
    $checks+=New-PSWCDoctorCheck 'PublicInterface' $(if($exports -ceq 'Start-PSWebCrawler|PSWC,PSWebCrawler' -and $aliasesOk){'PASS'}else{'FAIL'}) 'Start-PSWebCrawler|PSWC,PSWebCrawler' $exports 'Exact public functions and alias targets; Invoke remains private.' 'Use a clean package with the documented interface.'
    $checks+=New-PSWCDoctorCheck 'LegacyDisplayVersion' $(if([string]$ModuleVersion -eq $expected){'PASS'}else{'WARN'}) $expected ([string]$ModuleVersion) 'Legacy display metadata can differ from the manifest; no correction performed.' 'Use ModuleVersion above as the package version.'
    $native=$PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1
    $checks+=New-PSWCDoctorCheck 'PowerShell' $(if($native){'PASS'}else{'FAIL'}) 'Windows PowerShell 5.1 Desktop' ($PSVersionTable.PSEdition+' '+$PSVersionTable.PSVersion) 'Native supported host qualification.' 'Run in Windows PowerShell 5.1 Desktop; Core is not qualified.'
    $release='Unknown'
    try {$release=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction Stop).Release} catch {}
    $checks+=New-PSWCDoctorCheck 'DotNetQualification' $(if($release -is [int] -and $release -ge 528040){'PASS'}else{'WARN'}) 'Release >= 528040 (.NET 4.8); legacy manifest minimum 4.5' $release 'Modern qualification is distinct from legacy manifest compatibility.' 'Unknown/older framework is not qualified for new internal contracts; no installation performed.'
    $available=@(Get-Module -ListAvailable PSParseHTML -ErrorAction SilentlyContinue)
    $loaded=@(Get-Module PSParseHTML)
    $versions=@($available | ForEach-Object {$_.Version.ToString()} | Sort-Object -Unique)
    $depStatus=if(-not $available.Count -or -not $loaded.Count){'FAIL'}elseif($versions.Count -ne 1 -or $versions[0] -ne '3.0.6' -or @($loaded | Where-Object Version -ne ([version]'3.0.6')).Count){'WARN'}else{'PASS'}
    $checks+=New-PSWCDoctorCheck 'PSParseHTML' $depStatus 'Available and loaded 3.0.6; no other versions' ('Available='+($versions -join ',')+'; Loaded='+(@($loaded | ForEach-Object {$_.Version.ToString()+' @ '+$_.Path}) -join ';')) 'Reports actual dependency selection without importing another version.' 'Resolve dependency selection manually in a fresh process; no install or reconfiguration performed.'
    try {
        $assembly=[HtmlAgilityPack.HtmlDocument].Assembly
        $packaged=[Reflection.AssemblyName]::GetAssemblyName((Join-Path $root 'lib/Net45/HtmlAgilityPack.dll'))
        $actual=@{Name=$assembly.GetName().Name;Version=$assembly.GetName().Version.ToString();Location=$assembly.Location;FullName=$assembly.FullName}
        $hapStatus=if($assembly.FullName -eq $packaged.FullName -and $assembly.Location -eq (Join-Path $root 'lib/Net45/HtmlAgilityPack.dll')){'PASS'}else{'WARN'}
        $checks+=New-PSWCDoctorCheck 'HapIdentity' $hapStatus (@{FullName=$packaged.FullName;Location=(Join-Path $root 'lib/Net45/HtmlAgilityPack.dll')}) $actual 'Actual HtmlDocument assembly versus passive packaged assembly identity; dependency may load HAP first.' 'Identity/location differences need review, not automatic replacement; smoke separately tests behavior.'
    } catch {$checks+=New-PSWCDoctorCheck 'HapIdentity' 'FAIL' 'Loaded HAP and readable bundled DLL' 'Unavailable' 'HAP identity could not be inspected.' 'Inspect import errors and trusted package contents.'}
    try {
        $doc=New-Object HtmlAgilityPack.HtmlDocument
        $doc.LoadHtml('<html><head><title>Doctor &amp; ready</title></head><body><a href="/offline?a=1&amp;b=2">link</a></body></html>')
        $smoke=[HtmlAgilityPack.HtmlEntity]::DeEntitize($doc.DocumentNode.SelectSingleNode('//title').InnerText)+'|'+[HtmlAgilityPack.HtmlEntity]::DeEntitize($doc.DocumentNode.SelectSingleNode('//a').GetAttributeValue('href',''))
        $checks+=New-PSWCDoctorCheck 'HtmlSmoke' $(if($smoke -ceq 'Doctor & ready|/offline?a=1&b=2'){'PASS'}else{'FAIL'}) 'Doctor & ready|/offline?a=1&b=2' $smoke 'Actual fixed in-memory title/href/entity parsing; no URL request.' 'Review loaded HAP identity if parsing differs.'
    } catch {$checks+=New-PSWCDoctorCheck 'HtmlSmoke' 'FAIL' 'Doctor & ready|/offline?a=1&b=2' 'Parse unavailable' 'The in-memory HAP smoke failed.' 'Inspect dependency/import errors; no network fallback is attempted.'}
    $checks+=Test-PSWCPackageIntegrity $root
    [pscustomobject][ordered]@{SchemaVersion='1.0';Status=(Get-PSWCDoctorStatus $checks);Healthy= -not(@($checks | Where-Object Status -eq 'FAIL').Count);Qualified=$false;Checks=@($checks)}
}
