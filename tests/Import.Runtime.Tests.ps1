# Execute in a fresh Windows PowerShell 5.1 process from local Windows staging.
$root=Split-Path $PSScriptRoot -Parent
$global:pswcFindCalls=0
function global:Find-Module { $global:pswcFindCalls++; throw 'Unexpected update check' }
$module=Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -PassThru -ErrorAction Stop
Describe 'Real manifest import and legacy initialization' {
    It 'loads the real manifest and preserves commands and aliases' {
        (Get-Command Start-PSWebCrawler -Module PSWebCrawler).Name | Should Be 'Start-PSWebCrawler'
        (Get-Alias PSWC).Definition | Should Be 'Start-PSWebCrawler'
        (Get-Alias PSWebCrawler).Definition | Should Be 'Start-PSWebCrawler'
        $global:pswcFindCalls | Should Be 0
    }
    It 'leaves the output path uninitialized on import' {
        (& $module { [string]$script:loganddatafolderPath }) | Should Be ''
    }
    It 'does not initialize output or log when displaying the menu' {
        $result=& $module {
            $script:creates=0; $script:logs=0
            function script:Get-PSWCoutPath { return $null }
            function script:New-PSWCoutPath { $script:creates++; return 'D:\scratch' }
            function script:Write-Log { param($message) $script:logs++ }
            function script:Open-PSWCExplorerCache {}
            Start-PSWebCrawler 1>$null 6>$null
            [pscustomobject]@{Creates=$script:creates;Logs=$script:logs}
        }
        $result.Creates | Should Be 0
        $result.Logs | Should Be 0
    }
    It 'initializes once before logging for two cache-folder operations' {
        $result=& $module {
            function script:Write-Log { param($message) if(-not $script:loganddatafolderPath){throw 'Log before initialization'}; $script:logs++ }
            Start-PSWebCrawler -ShowCacheFolder 1>$null 6>$null
            Start-PSWebCrawler -ShowCacheFolder 1>$null 6>$null
            [pscustomobject]@{Creates=$script:creates;Logs=$script:logs}
        }
        $result.Creates | Should Be 1
        ($result.Logs -gt 0) | Should Be $true
    }
}
# No real Explorer, HTTP or output-directory creation. Full import is real;
# operation filesystem/logging boundaries are substituted in the module scope.
