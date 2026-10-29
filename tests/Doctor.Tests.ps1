$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Offline Doctor' {
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
    It 'D08 reports loaded version path legacy mismatch dependency and HAP facts' {
        $r=Start-PSWebCrawler -Doctor
        ($r.Checks | Where-Object Name -eq 'ModuleVersion').Status | Should Be 'PASS'
        ($r.Checks | Where-Object Name -eq 'ModulePath').Status | Should Be 'PASS'
        ($r.Checks | Where-Object Name -eq 'LegacyDisplayVersion').Status | Should Be 'WARN'
        ($r.Checks | Where-Object Name -eq 'PSParseHTML').Actual | Should Match '3.0.6'
        ($r.Checks | Where-Object Name -eq 'HapIdentity').Actual.FullName | Should Match 'HtmlAgilityPack'
    }
}
