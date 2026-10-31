$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Local HTML entry' {
 InModuleScope PSWebCrawler {
  $script:localParser=(Get-Command Get-PSWCDocumentElements).ScriptBlock
  Mock Get-PSWCDocumentElements { & $script:localParser -htmlContent $htmlContent -Node $Node }
  Mock Get-PSWCBanner {}
  Mock Write-Log {}
  Mock Get-PSWCoutPath {'D:\scratch\local-output'}
  Mock Set-PSWCSessionFolder {'D:\scratch\local-output\session'}
  Mock Out-File {}
  Mock Add-Content {}
  Mock Get-PSWCHttpResponse {throw 'Forbidden HTTP'}
  Mock Get-PSWCGetHostAddresses {throw 'Forbidden DNS'}
  Mock Start-PSWCCrawl {throw 'Forbidden crawl'}
  Mock Read-Host {throw 'Forbidden prompt'}
  $script:localFixture=Join-Path $TestDrive 'quoted space.html'
  [IO.File]::WriteAllText($script:localFixture,'<base href="https://ignored.test/"><a href="https://outside.test/a">A</a><a href="/inside">B</a><a href="?q=1">Q</a><a href="#part">F</a><a href="plain">P</a>')
  It 'L01 retains categories and file provenance without implicit base' {
   $r=Start-PSWebCrawler -HtmlPath $script:localFixture
   $r.SourcePath | Should Be $script:localFixture
   $r.Hrefs.Count | Should Be 1
   $r.NonHrefs.Count | Should Be 4
   $r.InternalLinks.Count | Should Be 0
   Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$LiteralPath -like '*\UrlsUnique.txt'}
   Assert-MockCalled Out-File -Times 1 -Scope It -ParameterFilter {$LiteralPath -like '*\noHrefUnique.txt'}
   # Pester 3's pipeline mock records no process call for an empty collection.
   # Actual empty category-file creation is verified by the native output probe.
   Assert-MockCalled Out-File -Times 0 -Exactly -Scope It -ParameterFilter {$LiteralPath -eq 'D:\scratch\local-output\session\InternalLinksUnique.txt'}
   Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$LiteralPath -like '*\DomainsUnique.txt'}
   Assert-MockCalled Get-PSWCDocumentElements -Times 1 -Exactly -Scope It
   Assert-MockCalled Get-PSWCGetHostAddresses -Times 0 -Exactly -Scope It
   Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
   Assert-MockCalled Start-PSWCCrawl -Times 0 -Exactly -Scope It
  }
  It 'L02 explicit base resolves fragment query and relative paths' {
   $r=PSWC -HtmlPath $script:localFixture -BaseUrl 'https://base.test/dir/page'
   ($r.InternalLinks -contains 'https://base.test/dir/page#part') | Should Be $true
   ($r.InternalLinks -contains 'https://base.test/dir/page?q=1') | Should Be $true
   ($r.InternalLinks -contains 'https://base.test/dir/plain') | Should Be $true
   $r.InternalLinks.Count | Should Be 4
  }
  It 'L03 Href writes only legacy Href file' {
   Start-PSWebCrawler -HtmlPath $script:localFixture -Type Href | Out-Null
   Assert-MockCalled Out-File -Times 1 -Exactly -Scope It -ParameterFilter {$LiteralPath -like '*UrlsUnique.txt'}
  }
  It 'L04 noHref writes two categories' {
   Start-PSWebCrawler -HtmlPath $script:localFixture -BaseUrl 'https://base.test/dir/page' -Type noHref | Out-Null
   Assert-MockCalled Out-File -Times 1 -Scope It -ParameterFilter {$LiteralPath -eq 'D:\scratch\local-output\session\noHrefUnique.txt'}
   Assert-MockCalled Out-File -Times 1 -Scope It -ParameterFilter {$LiteralPath -eq 'D:\scratch\local-output\session\InternalLinksUnique.txt'}
   Assert-MockCalled Out-File -Times 0 -Exactly -Scope It -ParameterFilter {$LiteralPath -eq 'D:\scratch\local-output\session\UrlsUnique.txt'}
   Assert-MockCalled Out-File -Times 0 -Exactly -Scope It -ParameterFilter {$LiteralPath -eq 'D:\scratch\local-output\session\DomainsUnique.txt'}
  }
  It 'L05 onlyDomains type is extraction not DNS' {
   $r=PSWebCrawler -HtmlPath $script:localFixture -Type onlyDomains
   $r.Domains[0] | Should Be 'https://outside.test'
   Assert-MockCalled Get-PSWCGetHostAddresses -Times 0 -Exactly -Scope It
  }
  It 'L06 explicit outputFolder is honored' {
   Start-PSWebCrawler -HtmlPath $script:localFixture -outputFolder 'D:\scratch\explicit' | Out-Null
   Assert-MockCalled Set-PSWCSessionFolder -Times 1 -Exactly -Scope It -ParameterFilter {$FolderPath -eq 'D:\scratch\explicit'}
  }
  It 'L07 zero and one malformed anchors use actual HAP' {
   foreach($html in @('<html>none','<a href="/one">unclosed')) {
    [IO.File]::WriteAllText($script:localFixture,$html)
    $r=Start-PSWebCrawler -HtmlPath $script:localFixture
    $r.NonHrefs.Count | Should Be ([int]($html -like '*href*'))
   }
  }
  It 'L08 missing file and invalid base terminate before output' {
   {Start-PSWebCrawler -HtmlPath 'D:\scratch\absent-html-fixture.html'} | Should Throw 'readable local HTML file'
   {Start-PSWebCrawler -HtmlPath $script:localFixture -BaseUrl 'ftp://base.test'} | Should Throw 'absolute HTTP or HTTPS'
   Assert-MockCalled Set-PSWCSessionFolder -Times 0 -Exactly -Scope It
  }
  It 'L10 Unicode literal filename and empty file are supported' {
   $unicodePath=Join-Path $TestDrive ('space '+[char]0x0142+'.html')
   [IO.File]::WriteAllText($unicodePath,'')
   $r=Start-PSWebCrawler -HtmlPath $unicodePath
   $r.SourcePath | Should Be $unicodePath
   $r.Hrefs.Count | Should Be 0
   $r.NonHrefs.Count | Should Be 0
  }
  It 'L09 incompatible URL operations Doctor and shared onlyDomains reject' {
   {Start-PSWebCrawler -HtmlPath $script:localFixture -Url 'https://a.test'} | Should Throw
   {Start-PSWebCrawler -HtmlPath $script:localFixture -Doctor} | Should Throw
   {Start-PSWebCrawler -HtmlPath $script:localFixture -GetImageUrls} | Should Throw
   {Start-PSWebCrawler -HtmlPath $script:localFixture -onlyDomains} | Should Throw
   {Start-PSWebCrawler -Url 'https://a.test' -BaseUrl 'https://b.test'} | Should Throw
  }
 }
}
