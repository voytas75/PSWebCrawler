# Offline real-body regression: all legacy transport/output seams intercepted before calls.
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Bounded URL entry' {
    InModuleScope PSWebCrawler {
        Mock Get-PSWCBanner {}
        Mock Write-Log {}
        Mock Get-PSWCoutPath {'C:\PSWC-fixture'}
        Mock New-PSWCoutPath {'C:\PSWC-fixture'}
        Mock Set-PSWCSessionFolder {'C:\PSWC-fixture\session'}
        Mock Add-Content {}
        Mock Out-File {}
        Mock Open-PSWCExplorerCache {}
        Mock Read-Host {throw 'Forbidden prompt'}
        Mock Get-RandomUserAgent {'offline-fixture'}
        Mock start-watch {New-Object Diagnostics.Stopwatch}
        Mock stop-watch {}
        Mock Start-PSWCCrawl {}
        Mock Get-PSWCGetHostAddresses {'192.0.2.1'}
        Mock Get-PSWCHttpResponse {
            $response=New-Object System.Net.Http.HttpResponseMessage
            $response.Content=New-Object System.Net.Http.StringContent('<html><head><title>Offline fixture</title></head><body><img src="/fixture.png"><a href="https://outside.test/a">Outside</a><a href="/inside">Inside</a></body></html>')
            return @($true,$response)
        }
        It 'U01 no arguments preserve menu without initialization or HTTP' {
            Mock Show-PSWCMenu {}
            Start-PSWebCrawler
            Assert-MockCalled Show-PSWCMenu -Times 1 -Exactly -Scope It
            Assert-MockCalled Set-PSWCSessionFolder -Times 0 -Exactly -Scope It
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'U02 URL only analyzes one page through real All extraction and preserved files' {
            Start-PSWebCrawler -Url 'https://udt.gov.pl'
            Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It -ParameterFilter {$url -eq 'https://udt.gov.pl'}
            Assert-MockCalled Start-PSWCCrawl -Times 0 -Exactly -Scope It
            Assert-MockCalled Set-PSWCSessionFolder -Times 1 -Exactly -Scope It
            Assert-MockCalled Out-File -Times 4 -Exactly -Scope It
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$FilePath -like '*InternalLinksUnique.txt'}
        }
        It 'U03 PSWC alias follows URL-only path' {
            PSWC -Url 'https://udt.gov.pl'
            Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It
            Assert-MockCalled Start-PSWCCrawl -Times 0 -Exactly -Scope It
        }
        It 'U04 PSWebCrawler alias follows URL-only path' {
            PSWebCrawler -Url 'https://udt.gov.pl'
            Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It
        }
        It 'U05 explicit ShowAllElements remains single page' {
            Start-PSWebCrawler -Url 'https://fixture.test' -ShowAllElements -Type All
            Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It
        }
        It 'U06 explicit image extraction remains selected' {
            Start-PSWebCrawler -Url 'https://fixture.test' -GetImageUrls
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$FilePath -like '*Images.txt'}
        }
        It 'U07 explicit metadata remains selected' {
            Start-PSWebCrawler -Url 'https://fixture.test' -GetHTMLMetadata
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$FilePath -like '*Header.json'}
        }
        It 'U08 explicit contact extraction remains selected' {
            Start-PSWebCrawler -Url 'https://fixture.test' -GetContactInformation
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$FilePath -like '*Contact.json'}
        }
        It 'U09 explicit headers remain selected' {
            Start-PSWebCrawler -Url 'https://fixture.test' -GetHeadersAndValues
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$FilePath -like '*HTMLhead.json'}
        }
        It 'U10 Depth Resolve outputFolder preserve crawl dispatch' {
            Start-PSWebCrawler -Url 'https://fixture.test' -Depth 2 -Resolve -outputFolder 'C:\PSWC-fixture'
            Assert-MockCalled Start-PSWCCrawl -Times 1 -Exactly -Scope It -ParameterFilter {$depth -eq 2 -and $resolve -and $outputFolder -eq 'C:\PSWC-fixture'}
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'U11 invalid supplied URLs terminate before prompts initialization or HTTP' {
            foreach($value in @($null,'','relative','ftp://fixture.test','https://')) {
                {Start-PSWebCrawler -Url $value -ErrorAction Stop} | Should Throw
                if (-not [string]::IsNullOrEmpty($value)) {
                    {Start-PSWebCrawler -Url $value -ErrorAction Stop} | Should Throw 'absolute HTTP or HTTPS URL'
                }
            }
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
            Assert-MockCalled Set-PSWCSessionFolder -Times 0 -Exactly -Scope It
            Assert-MockCalled Get-PSWCoutPath -Times 0 -Exactly -Scope It
            Assert-MockCalled Write-Log -Times 0 -Exactly -Scope It
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'U12 Doctor is isolated and Doctor with URL rejects binding' {
            (Start-PSWebCrawler -Doctor).SchemaVersion | Should Be '1.0'
            {Start-PSWebCrawler -Doctor -Url 'https://udt.gov.pl'} | Should Throw
            Assert-MockCalled Set-PSWCSessionFolder -Times 0 -Exactly -Scope It
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'U13 Type alone retains extraction selection' {
            Start-PSWebCrawler -Url 'https://fixture.test' -Type Href
            Assert-MockCalled Out-File -Times 1 -Exactly -Scope It
        }
        It 'U14 Default metadata admits optional URL and excludes Doctor URL' {
            $command=Get-Command Start-PSWebCrawler
            $set=$command.ParameterSets | Where-Object Name -eq Default
            $parameter=$set.Parameters | Where-Object Name -eq Url
            [bool]$parameter | Should Be $true
            $parameter.IsMandatory | Should Be $false
            @(( $command.ParameterSets | Where-Object Name -eq Doctor).Parameters | Where-Object Name -eq Url).Count | Should Be 0
        }
    }
}
Describe 'Menu discoverability' {
    It 'U16 displays literal structured result capture and properties' {
        InModuleScope PSWebCrawler {
            $script:captureLines=@()
            Mock Write-Host {$script:captureLines += [string]$Object}
            Show-PSWCMenu
            ($script:captureLines -contains "    `$result = PSWC -ShowAllElements -Type All -Url 'https://example.org/'") | Should Be $true
            foreach($property in @('Hrefs','Counts','OutputFiles')) {
                ($script:captureLines -contains ('    $result.'+$property)) | Should Be $true
            }
            $numbers=@($script:captureLines | Where-Object {$_ -match '^\[(\d+)\]'} | ForEach-Object {[int]([regex]::Match($_,'^\[(\d+)\]').Groups[1].Value)})
            ($numbers -join ',') | Should Be '1,2,3,4,5,6,7,8,9'
        }
    }
    It 'U15 keeps nine examples and includes English offline Doctor' {
        InModuleScope PSWebCrawler {
            $script:menuLines=@()
            Mock Write-Host {$script:menuLines += [string]$Object}
            Show-PSWCMenu
            $headings=@($script:menuLines | Where-Object {$_ -match '^\[[1-9]\]'})
            ($headings[-1] -match '^\[9\].*offline diagnostics') | Should Be $true
            @($script:menuLines | Where-Object {$_ -match 'PSWC -Doctor'}).Count | Should Be 1
            @($script:menuLines | Where-Object {$_ -match '-Depth 2 -onlyDomains -Resolve'}).Count | Should Be 0
            foreach($selector in @('-ShowAllElements','-GetImageUrls','-GetHTMLMetadata','-GetContactInformation','-GetHeadersAndValues','-ShowCacheFolder')) {
                @($script:menuLines | Where-Object {$_ -match [regex]::Escape($selector)}).Count | Should Be 1
            }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter {$Object -eq '    PSWC -Doctor | ConvertTo-Json -Depth 6'}
            Assert-MockCalled Write-Host -Times 9 -Exactly -Scope It -ParameterFilter {$Object -match '^\[[1-9]\]'}
        }
    }
}
