# Native offline public-body output-root qualification; real parsers and filesystem.
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Complete outputFolder ownership' {
    InModuleScope PSWebCrawler {
        Mock Get-PSWCoutPath { throw 'Default output resolver forbidden for explicit root' }
        Mock New-PSWCoutPath { throw 'Default output creation forbidden for explicit root' }
        Mock Get-PSWCGetHostAddresses { '192.0.2.1' }
        Mock Get-RandomUserAgent { 'offline-fixture' }
        Mock Start-Process {}
        Mock Get-PSWCHttpResponse {
            $response = New-Object System.Net.Http.HttpResponseMessage
            $response.Content = New-Object System.Net.Http.StringContent('<html><head><title>Fixture</title><meta name="description" content="fixture"></head><body><img src="https://fixture.test/image.png"><a href="https://outside.test/a">Outside</a><a href="/inside">Inside</a><a href="mailto:fixture@example.test">Email</a><a href="tel:123456789">Phone</a></body></html>')
            return @($true, $response)
        }
        foreach ($selector in @('UrlOnly','ShowAllElements','GetImageUrls','GetHTMLMetadata','GetContactInformation','GetHeadersAndValues','WebCrawl','LocalHtml')) {
            It "O root owns real files for $selector without private state patch" {
                $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
                $arguments = @{outputFolder=$folder;Url='https://fixture.test/'}
                switch ($selector) {
                    'UrlOnly' {}
                    'WebCrawl' { $arguments.Depth=0 }
                    'LocalHtml' {
                        $arguments.Remove('Url');$input = Join-Path $TestDrive 'input.html'
                        [IO.File]::WriteAllText($input,'<html><a href="https://outside.test/a">Outside</a><a href="/inside">Inside</a></html>')
                        $arguments.HtmlPath=$input
                    }
                    default { $arguments[$selector]=$true }
                }
                $result = @(Start-PSWebCrawler @arguments)
                (Test-Path -LiteralPath (Join-Path $folder 'PSWebCrawler.log')) | Should Be $true
                $sessions = @(Get-ChildItem -LiteralPath $folder -Directory)
                $sessions.Count | Should Be 1
                (Test-Path -LiteralPath (Join-Path $sessions[0].FullName 'Settings.log')) | Should Be $true
                $expected = switch ($selector) {
                    'GetImageUrls' {'Images.txt'}
                    'GetHTMLMetadata' {'Header.json'}
                    'GetContactInformation' {'Contact.json'}
                    'GetHeadersAndValues' {'HTMLhead.json'}
                    'WebCrawl' {'fixture.test\UniqueURLs.txt'}
                    default {'UrlsUnique.txt'}
                }
                (Test-Path -LiteralPath (Join-Path $sessions[0].FullName $expected)) | Should Be $true
                $script:loganddatafolderPath | Should Be $folder
                Assert-MockCalled Get-PSWCoutPath -Times 0 -Exactly -Scope It
                Assert-MockCalled New-PSWCoutPath -Times 0 -Exactly -Scope It
            }
        }
        It 'O cache opens the selected existing root without HTTP or fallback' {
            $folder=Join-Path $TestDrive 'cache'
            [void][IO.Directory]::CreateDirectory($folder)
            $sentinel=Join-Path $folder 'existing.txt';[IO.File]::WriteAllText($sentinel,'preserved')
            PSWC -ShowCacheFolder -outputFolder $folder
            Assert-MockCalled Start-Process -Times 1 -Exactly -Scope It -ParameterFilter {$ArgumentList -eq $folder}
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
            Assert-MockCalled Get-PSWCoutPath -Times 0 -Exactly -Scope It
            Assert-MockCalled New-PSWCoutPath -Times 0 -Exactly -Scope It
            [IO.File]::ReadAllText($sentinel) | Should Be 'preserved'
            $script:loganddatafolderPath | Should Be $folder
        }
        It 'O Depth2 recursively writes real child page artifacts beneath a literal root' {
            $folder=Join-Path $TestDrive ('recursive [literal] '+[guid]::NewGuid().ToString('N'))
            Mock Get-PSWCHttpResponse {
                $body=if($url -eq 'https://tree.test/'){'<html><body><a href="https://child.test/page">child</a><a href="https://child.test/other">other</a></body></html>'}else{'<html><body><a href="https://leaf.test/end">leaf</a><a href="https://leaf.test/other">other</a></body></html>'}
                $response=New-Object System.Net.Http.HttpResponseMessage
                $response.Content=New-Object System.Net.Http.StringContent($body)
                return @($true,$response)
            }
            PSWC -Url 'https://tree.test/' -Depth 2 -outputFolder $folder | Out-Null
            Assert-MockCalled Get-PSWCHttpResponse -Times 3 -Exactly -Scope It
            Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It -ParameterFilter {$url -eq 'https://child.test/page'}
            Assert-MockCalled Get-PSWCoutPath -Times 0 -Exactly -Scope It
            Assert-MockCalled New-PSWCoutPath -Times 0 -Exactly -Scope It
            $files=@(Get-ChildItem -LiteralPath $folder -Recurse -File)
            @($files|Where-Object Name -like '*.headers.json').Count | Should Be 3
            @($files|Where-Object Name -like '*.FormatedHTMLContent.txt').Count | Should Be 3
            @($files|Where-Object Name -like '*.ConvertedtoTextContent.txt').Count | Should Be 3
            @($files|Where-Object {$_.FullName -match 'child.test'}).Count | Should BeGreaterThan 0
            foreach($file in $files){$file.FullName.StartsWith($folder,[StringComparison]::OrdinalIgnoreCase) | Should Be $true}
            (Test-Path -LiteralPath (Join-Path $folder 'PSWebCrawler.log')) | Should Be $true
        }
        It 'O real empty category files and no-anchor contracts preserve existing files' {
            $input=Join-Path $TestDrive 'empty-categories.html'
            foreach($type in @('All','Href','noHref','onlyDomains')) {
                $folder=Join-Path $TestDrive ('empty-'+$type)
                [void][IO.Directory]::CreateDirectory($folder)
                $sentinel=Join-Path $folder 'existing.txt';[IO.File]::WriteAllText($sentinel,'keep')
                [IO.File]::WriteAllText($input,'<html><body>No anchors</body></html>')
                $r=PSWC -HtmlPath $input -Type $type -outputFolder $folder
                foreach($key in @('Hrefs','NonHrefs','InternalLinks','Domains')){$r.$key.Count | Should Be 0}
                @($r.OutputFiles.PSObject.Properties|Where-Object Name -ne 'SettingsLog').Count | Should Be 0
                [IO.File]::ReadAllText($sentinel) | Should Be 'keep'
            }
            [IO.File]::WriteAllText($input,'<html><a href="/relative">relative</a></html>')
            $folder=Join-Path $TestDrive 'empty-selected-href'
            $r=PSWC -HtmlPath $input -Type Href -outputFolder $folder
            $r.Hrefs.Count | Should Be 0
            (Test-Path -LiteralPath $r.OutputFiles.Hrefs) | Should Be $true
            @([IO.File]::ReadAllLines($r.OutputFiles.Hrefs)).Count | Should Be 0
            @($r.OutputFiles.PSObject.Properties|Where-Object Name -ne 'SettingsLog').Count | Should Be 1
            $folder=Join-Path $TestDrive 'all-empty-absolute'
            $r=PSWC -HtmlPath $input -Type All -outputFolder $folder
            foreach($key in @('Hrefs','Domains','InternalLinks')) {
                (Test-Path -LiteralPath $r.OutputFiles.$key) | Should Be $true
                @([IO.File]::ReadAllLines($r.OutputFiles.$key)).Count | Should Be 0
            }
            [IO.File]::ReadAllLines($r.OutputFiles.NonHrefs)[0] | Should Be '/relative'
            [IO.File]::WriteAllText($input,'<html><a href="https://absolute.test/">absolute</a></html>')
            $r=PSWC -HtmlPath $input -Type All -outputFolder (Join-Path $TestDrive 'empty-nonhref')
            (Test-Path -LiteralPath $r.OutputFiles.NonHrefs) | Should Be $true
            @([IO.File]::ReadAllLines($r.OutputFiles.NonHrefs)).Count | Should Be 0
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'O changing explicit root redirects subsequent log writes' {
            $a=Join-Path $TestDrive 'first';$b=Join-Path $TestDrive 'second'
            PSWC -Url 'https://fixture.test/' -outputFolder $a | Out-Null
            $before=[IO.File]::ReadAllText((Join-Path $a 'PSWebCrawler.log'))
            PSWC -Url 'https://fixture.test/' -outputFolder $b | Out-Null
            [IO.File]::ReadAllText((Join-Path $a 'PSWebCrawler.log')) | Should Be $before
            (Test-Path -LiteralPath (Join-Path $b 'PSWebCrawler.log')) | Should Be $true
        }
        It 'O preview resolves a relative root without creating it' {
            $folder=Join-Path $TestDrive 'preview'
            $p=PSWC -GetImageUrls -Url 'https://fixture.test/' -outputFolder $folder -DryRun
            $p.PlannedOutputLocation | Should Be $folder
            (Test-Path -LiteralPath $folder) | Should Be $false
        }
        It 'O file root terminates before HTTP and writes' {
            $file=Join-Path $TestDrive 'not-a-folder';[IO.File]::WriteAllText($file,'keep')
            {PSWC -Url 'https://fixture.test/' -outputFolder $file} | Should Throw 'outputFolder'
            [IO.File]::ReadAllText($file) | Should Be 'keep'
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'O empty explicit root terminates before effects' {
            {PSWC -Url 'https://fixture.test/' -outputFolder ''} | Should Throw 'outputFolder'
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'O all producer previews plan the selected root without effects' {
            foreach($selector in @('ShowAllElements','GetImageUrls','GetHTMLMetadata','GetContactInformation','GetHeadersAndValues','WebCrawl','LocalHtml','ShowCacheFolder')) {
                $folder=Join-Path $TestDrive ('preview-'+$selector)
                $arguments=@{outputFolder=$folder;DryRun=$true;Url='https://fixture.test/'}
                if($selector -eq 'WebCrawl'){$arguments.Depth=1}
                elseif($selector -eq 'LocalHtml'){$arguments.Remove('Url');$input=Join-Path $TestDrive 'preview.html';[IO.File]::WriteAllText($input,'<html/>');$arguments.HtmlPath=$input}
                elseif($selector -eq 'ShowCacheFolder'){$arguments.Remove('Url');$arguments.ShowCacheFolder=$true}
                else{$arguments[$selector]=$true}
                $p=PSWC @arguments
                $p.PlannedOutputLocation | Should Be $folder
                (Test-Path -LiteralPath $folder) | Should Be $false
            }
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
            Assert-MockCalled Start-Process -Times 0 -Exactly -Scope It
        }
        It 'O literal relative root with spaces is resolved and written' {
            Push-Location $TestDrive
            try {
                $result=PSWC -Url 'https://fixture.test/' -outputFolder '.\relative space [literal]'
                $expected=Join-Path $TestDrive 'relative space [literal]'
                $result.SessionFolder.StartsWith($expected,[StringComparison]::OrdinalIgnoreCase) | Should Be $true
                (Test-Path -LiteralPath (Join-Path $expected 'PSWebCrawler.log')) | Should Be $true
                $p=PSWC -Url 'https://fixture.test/' -outputFolder '.\no create' -DryRun
                $p.PlannedOutputLocation | Should Be (Join-Path $TestDrive 'no create')
                (Test-Path -LiteralPath (Join-Path $TestDrive 'no create')) | Should Be $false
            } finally {Pop-Location}
        }
        It 'O omitted root returns to default after explicit root' {
            $folder=Join-Path $TestDrive 'explicit-before-default'
            PSWC -Url 'https://fixture.test/' -outputFolder $folder | Out-Null
            $default=Join-Path $TestDrive 'default-owned';[void][IO.Directory]::CreateDirectory($default)
            Mock Get-PSWCoutPath {$default}
            PSWC -Url 'https://fixture.test/' | Out-Null
            $script:loganddatafolderPath | Should Be $default
            (Test-Path -LiteralPath (Join-Path $default 'PSWebCrawler.log')) | Should Be $true
            $plan=PSWC -Url 'https://fixture.test/' -DryRun
            $plan.PlannedOutputLocation | Should Match 'Unresolved'
        }
        It 'O null root and non-filesystem root reject before effects' {
            {PSWC -Url 'https://fixture.test/' -outputFolder $null} | Should Throw 'outputFolder'
            {PSWC -Url 'https://fixture.test/' -outputFolder 'HKCU:\Software\PSWC'} | Should Throw 'outputFolder'
            Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
        }
        It 'O Doctor excludes outputFolder at binding' {
            {PSWC -Doctor -outputFolder (Join-Path $TestDrive 'doctor')} | Should Throw
        }
    }
}
