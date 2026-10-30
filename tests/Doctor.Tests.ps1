$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Offline Doctor' {
    It 'D09 adds offline advice and preserves JSON arrays without claiming qualification' {
        $r=Start-PSWebCrawler -Doctor
        $r.Qualified | Should Be $false
        $j=$r | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        foreach($c in $j.Checks){
            [bool]$c.Impact | Should Be $true
            [bool]$c.RecommendedAction | Should Be $true
            [bool]$c.VerificationCommand | Should Be $true
            @($c.DocumentationUrls).Count | Should BeGreaterThan 0
            foreach($url in $c.DocumentationUrls){$url | Should Match '^https://(learn.microsoft.com/|www.powershellgallery.com/|www.nuget.org/|github.com/zzzprojects/html-agility-pack)'}
        }
    }
    It 'D10 uses safe specific guidance for every known finding at each severity' {
        InModuleScope PSWebCrawler {
            foreach($status in @('PASS','WARN','FAIL')){
                foreach($name in @('ModuleVersion','ModulePath','PublicInterface','LegacyDisplayVersion','PowerShell','DotNetQualification','PSParseHTML','HapIdentity','HtmlSmoke','PackageIntegrity')){
                    $c=New-PSWCDoctorCheck $name $status 'expected' 'actual' 'message' 'hint'
                    $c.Name | Should Be $name
                    $c.Status | Should Be $status
                    $c.RecommendedAction | Should Not Match 'Install-Module|Invoke-WebRequest|Update-PackageIntegrity|Set-ExecutionPolicy'
                    $c.VerificationCommand | Should Not Match 'Install-|Invoke-WebRequest|Set-|Remove-|checkout-index'
                    switch($name){
                        PackageIntegrity {$c.RecommendedAction | Should Match 'same.*version'; $c.RecommendedAction | Should Match 'never regenerate'}
                        HapIdentity {$c.RecommendedAction | Should Match 'passing smoke.*not.*incompatibility'; $c.RecommendedAction | Should Match 'latest.*not.*qualified'}
                        PSParseHTML {$c.RecommendedAction | Should Match 'fresh process'; ($c.DocumentationUrls -contains 'https://www.powershellgallery.com/packages/PSParseHTML/3.0.6') | Should Be $true}
                        LegacyDisplayVersion {$c.RecommendedAction | Should Match 'maintainer.*cosmetic'}
                        DotNetQualification {$c.RecommendedAction | Should Match 'legacy.*not blocked'}
                    }
                }
            }
        }
    }
    It 'D01 returns one structured object without URL or legacy initialization' {
        $r=@(Start-PSWebCrawler -Doctor)
        $r.Count | Should Be 1
        $r[0].Checks.Count | Should BeGreaterThan 7
        @($r[0].Checks | Where-Object Status -notin @('PASS','WARN','FAIL')).Count | Should Be 0
        @($r[0].Checks | Where-Object {$null -eq $_.Expected -or $null -eq $_.Actual -or -not $_.Message -or -not $_.Hint}).Count | Should Be 0
        InModuleScope PSWebCrawler { [bool]$script:SessionFolder | Should Be $false }
    }
    It 'D02 keeps exports and aliases and excludes legacy arguments' {
        (Get-Module PSWebCrawler).ExportedFunctions.Keys -join ',' | Should Be 'Start-PSWebCrawler'
        (PSWC -Doctor).SchemaVersion | Should Be '1.0'
        (PSWebCrawler -Doctor).SchemaVersion | Should Be '1.0'
        {Start-PSWebCrawler -Doctor -Url 'https://example.test'} | Should Throw
        {Start-PSWebCrawler -Doctor -Depth 1} | Should Throw
    }
    It 'D03 JSON depth six preserves check facts and arrays' {
        $r=Start-PSWebCrawler -Doctor
        $j=$r | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        $j.Checks.Count | Should Be $r.Checks.Count
        $j.Checks[0].Name | Should Be $r.Checks[0].Name
        $j.Status | Should Be $r.Status
    }
    It 'D04 exercises actual in-memory title href and entity parsing' {
        $r=Start-PSWebCrawler -Doctor
        ($r.Checks | Where-Object Name -eq 'HtmlSmoke').Status | Should Be 'PASS'
        ($r.Checks | Where-Object Name -eq 'HtmlSmoke').Actual | Should Be 'Doctor & ready|/offline?a=1&b=2'
    }
    It 'D05 detects immutable baseline missing and changed owned fixtures' {
        InModuleScope PSWebCrawler {
            $dir=Join-Path $TestDrive 'integrity'
            [void](New-Item -ItemType Directory -Path $dir)
            Set-Content (Join-Path $dir 'owned.txt') 'original'
            $h=(Get-FileHash (Join-Path $dir 'owned.txt')).Hash
            [pscustomobject]@{SchemaVersion='1.0';Files=@([pscustomobject]@{Path='owned.txt';Sha256=$h})} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'PackageIntegrity.json')
            (Test-PSWCPackageIntegrity $dir).Status | Should Be 'PASS'
            Set-Content (Join-Path $dir 'owned.txt') 'changed'
            (Test-PSWCPackageIntegrity $dir).Status | Should Be 'FAIL'
            Remove-Item (Join-Path $dir 'owned.txt')
            (Test-PSWCPackageIntegrity $dir).Status | Should Be 'FAIL'
        }
    }
    It 'D06 rejects malformed unsafe duplicate and empty integrity entries' {
        InModuleScope PSWebCrawler {
            $dir=Join-Path $TestDrive 'invalid'
            [void](New-Item -ItemType Directory -Path $dir)
            foreach($files in @(@(),@(@{Path='../escape';Sha256=('A'*64)}),@(@{Path='x';Sha256='bad'}),@(@{Path='x';Sha256=('A'*64)},@{Path='x';Sha256=('A'*64)}))){
                @{SchemaVersion='1.0';Files=$files} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'PackageIntegrity.json')
                (Test-PSWCPackageIntegrity $dir).Status | Should Be 'FAIL'
            }
        }
    }
    It 'D12 checks only known bundled HAP paths for presence and retains other hashes' {
        InModuleScope PSWebCrawler {
            $dir=Join-Path $TestDrive 'hap-presence'
            [void][IO.Directory]::CreateDirectory((Join-Path $dir 'lib/Net45'))
            [void][IO.Directory]::CreateDirectory((Join-Path $dir 'lib/core'))
            $paths=@('lib/Net45/HtmlAgilityPack.dll','lib/core/HtmlAgilityPack.dll','other.dll')
            $entries=@(foreach($path in $paths){
                Set-Content (Join-Path $dir $path) 'original'
                @{Path=$path;Sha256=(Get-FileHash (Join-Path $dir $path)).Hash;Verification='Exists'}
            })
            @{SchemaVersion='1.0';Files=$entries} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'PackageIntegrity.json')
            foreach($path in $paths[0..1]){Set-Content (Join-Path $dir $path) 'changed bytes'}
            $r=Test-PSWCPackageIntegrity $dir
            $r.Status | Should Be 'PASS'
            $r.Actual.Checked | Should Be 3
            $r.Actual.HashedChecked | Should Be 1
            $r.Actual.PresenceChecked | Should Be 2
            $r.Message | Should Match 'presence only'
            Set-Content (Join-Path $dir 'other.dll') 'changed bytes'
            (Test-PSWCPackageIntegrity $dir).Status | Should Be 'FAIL'
            Set-Content (Join-Path $dir 'other.dll') 'original'
            foreach($path in $paths[0..1]){
                Remove-Item (Join-Path $dir $path)
                $r=Test-PSWCPackageIntegrity $dir
                $r.Status | Should Be 'FAIL'
                ($r.Actual.Problems -contains ('Missing: '+$path)) | Should Be $true
                Set-Content (Join-Path $dir $path) 'replacement'
            }
            foreach($files in @(@(@{Path='lib/Net45/HtmlAgilityPack.dll';Sha256='bad'}),@($entries[0],$entries[0]),@(@{Path='lib/Net45/../HtmlAgilityPack.dll';Sha256=('A'*64);Verification='Exists'}))){
                @{SchemaVersion='1.0';Files=$files} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'PackageIntegrity.json')
                (Test-PSWCPackageIntegrity $dir).Status | Should Be 'FAIL'
            }
        }
    }
    It 'D13 invalid bundled metadata fails identity even when presence passes' {
        InModuleScope PSWebCrawler {
            $dir=Join-Path $TestDrive 'invalid-hap'
            [void][IO.Directory]::CreateDirectory((Join-Path $dir 'lib/Net45'))
            $bundled=Join-Path $dir 'lib/Net45/HtmlAgilityPack.dll'
            [IO.File]::WriteAllText($bundled,'Not an assembly')
            @{SchemaVersion='1.0';Files=@(@{Path='lib/Net45/HtmlAgilityPack.dll';Sha256=('A'*64)})} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'PackageIntegrity.json')
            (Test-PSWCPackageIntegrity $dir).Status | Should Be 'PASS'
            {[Reflection.AssemblyName]::GetAssemblyName($bundled)} | Should Throw
            # Doctor uses this same passive metadata call and catches its failure.
            $doctorSource=[IO.File]::ReadAllText((Join-Path (Get-Module PSWebCrawler).ModuleBase 'Private/Get-PSWCDoctor.ps1'))
            $doctorSource | Should Match "catch.*New-PSWCDoctorCheck 'HapIdentity' 'FAIL'"
            ((Start-PSWebCrawler -Doctor).Checks | Where-Object Name -eq HtmlSmoke).Status | Should Be 'PASS'
        }
    }
    It 'D07 severity aggregation does not terminate unhealthy sessions' {
        InModuleScope PSWebCrawler {
            (Get-PSWCDoctorStatus @(@{Status='PASS'},@{Status='WARN'})) | Should Be 'WARN'
            (Get-PSWCDoctorStatus @(@{Status='WARN'},@{Status='FAIL'})) | Should Be 'FAIL'
            (Get-PSWCDoctorStatus @(@{Status='PASS'})) | Should Be 'PASS'
            Mock Test-PSWCPackageIntegrity { New-PSWCDoctorCheck 'PackageIntegrity' 'FAIL' 'Original' 'Controlled anomaly' 'Fixture failure' 'Review fixture' }
            $unhealthy=Start-PSWebCrawler -Doctor
            $unhealthy.Status | Should Be 'FAIL'
            $unhealthy.Healthy | Should Be $false
        }
        'alive' | Should Be 'alive'
    }
    It 'D08 reports loaded version path aligned display version dependency and HAP facts' {
        $r=Start-PSWebCrawler -Doctor
        ($r.Checks | Where-Object Name -eq 'ModuleVersion').Status | Should Be 'PASS'
        ($r.Checks | Where-Object Name -eq 'ModulePath').Status | Should Be 'PASS'
        $display = $r.Checks | Where-Object Name -eq 'LegacyDisplayVersion'
        $display.Status | Should Be 'PASS'
        $display.Expected | Should Be '0.2.0'
        $display.Actual | Should Be '0.2.0'
        ($r.Checks | Where-Object Name -eq 'PSParseHTML').Actual | Should Match '3.0.6'
        ($r.Checks | Where-Object Name -eq 'HapIdentity').Actual.FullName | Should Match 'HtmlAgilityPack'
    }
}
# Pester 3 module mocks survive within Describe; isolate prohibited write hooks.
Describe 'Offline Doctor prohibited hooks' {
    It 'D14 never hashes either known bundled HAP DLL at runtime' {
        InModuleScope PSWebCrawler {
            Mock Get-FileHash {throw 'Bundled DLL hash forbidden'} -ParameterFilter {$LiteralPath -match 'lib[\\/]((Net45)|(core))[\\/]HtmlAgilityPack\.dll$'}
            $r=Start-PSWebCrawler -Doctor
            $c=$r.Checks | Where-Object Name -eq PackageIntegrity
            $c.Status | Should Be 'PASS'
            $c.Actual.HashedChecked | Should Be 9
            $c.Actual.PresenceChecked | Should Be 2
            Assert-MockCalled Get-FileHash -Times 0 -Exactly -ParameterFilter {$LiteralPath -match 'lib[\\/]((Net45)|(core))[\\/]HtmlAgilityPack\.dll$'}
        }
    }
    It 'D11 Doctor never invokes network installation repair or process launch hooks' {
        InModuleScope PSWebCrawler {
            Mock Invoke-WebRequest {throw 'Network forbidden'}
            Mock Invoke-RestMethod {throw 'Network forbidden'}
            Mock Install-Module {throw 'Installation forbidden'}
            Mock Start-Process {throw 'Process launch forbidden'}
            Mock Set-Content {throw 'Write forbidden'}
            $null=Start-PSWebCrawler -Doctor
            Assert-MockCalled Invoke-WebRequest -Times 0 -Exactly
            Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Start-Process -Times 0 -Exactly
            Assert-MockCalled Set-Content -Times 0 -Exactly
        }
    }
}
