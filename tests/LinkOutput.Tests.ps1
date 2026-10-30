$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Single page output contract' {
 InModuleScope PSWebCrawler {
  Mock Write-Log {}
  Mock Get-PSWCoutPath {$TestDrive}
  Mock Set-PSWCSessionFolder {
   $p=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
   [void][IO.Directory]::CreateDirectory($p);$p
  }
  Mock Get-RandomUserAgent {'offline-fixture'}
  Mock start-watch {New-Object Diagnostics.Stopwatch}
  Mock stop-watch {}
  Mock Read-Host {throw 'Forbidden prompt'}
  Mock Get-PSWCGetHostAddresses {throw 'Forbidden DNS'}
  Mock Start-PSWCCrawl {throw 'Forbidden crawl'}
  $script:outputHtml='<base href="https://ignored.test/"><a href="https://outside.test/z">Z</a><a href="https://outside.test/a">A</a><a href="https://outside.test/a">Duplicate</a><a href="/inside">I</a><a href="mailto:person@test.invalid">Mail</a>'
  Mock Get-PSWCHttpResponse {
   $r=New-Object Net.Http.HttpResponseMessage
   $r.Content=New-Object Net.Http.StringContent($script:outputHtml)
   @($true,$r)
  }
  function Assert-LinkResult($r) {
   @($r).Count | Should Be 1
   $r.PSObject.TypeNames[0] | Should Be 'PSWebCrawler.LinkAnalysis'
   $r.SchemaVersion | Should Be '1.0'
   $r.Hrefs.GetType().FullName | Should Be 'System.String[]'
   $r.NonHrefs.GetType().FullName | Should Be 'System.String[]'
   $r.InternalLinks.GetType().FullName | Should Be 'System.String[]'
   $r.Domains.GetType().FullName | Should Be 'System.String[]'
   $r.Counts.Hrefs | Should Be $r.Hrefs.Count
   $r.Counts.NonHrefs | Should Be $r.NonHrefs.Count
   $r.Counts.InternalLinks | Should Be $r.InternalLinks.Count
   $r.Counts.Domains | Should Be $r.Domains.Count
   foreach($p in $r.OutputFiles.PSObject.Properties){Test-Path -LiteralPath $p.Value -PathType Leaf | Should Be $true}
  }
  It 'O01 public command captures one data object with known unique sorted categories' {
   $r=Start-PSWebCrawler -ShowAllElements -Type All -Url 'https://fixture.test/page'
   Assert-LinkResult $r
   $r.Operation | Should Be 'ShowAllElements'
   $r.InputKind | Should Be 'Url'
   $r.SourceUrl | Should Be 'https://fixture.test/page'
   ($r.Hrefs -join ',') | Should Be 'https://outside.test/a,https://outside.test/z'
   ($r.NonHrefs -join ',') | Should Be '/inside,person@test.invalid'
   ($r.InternalLinks -join ',') | Should Be 'https://fixture.test/inside'
   ($r.Domains -join ',') | Should Be 'https://outside.test'
   @($r.OutputFiles.PSObject.Properties).Count | Should Be 5
   @((Get-Content -LiteralPath $r.OutputFiles.Hrefs)).Count | Should Be 2
  }
  It 'O02 PSWC assignment and JSON pipeline contain no logo strings or booleans' {
   $hostFile=Join-Path $TestDrive 'host.txt'
   $r=PSWC -ShowAllElements -Type All -Url 'https://fixture.test/page' 6> $hostFile
   Assert-LinkResult $r
   (Get-Content $hostFile -Raw).Length -gt 0 | Should Be $true
   $json=$r | ConvertTo-Json -Depth 6 | ConvertFrom-Json
   $json.SchemaVersion | Should Be '1.0'
   $json.Counts.Hrefs | Should Be 2
  }
  It 'O03 PSWebCrawler URL only returns the same single page contract' {
   $r=PSWebCrawler -Url 'https://fixture.test/page'
   Assert-LinkResult $r
   Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It
   Assert-MockCalled Start-PSWCCrawl -Times 0 -Exactly -Scope It
  }
  It 'O04 Href keeps all arrays but writes only Hrefs and settings' {
   $r=PSWC -ShowAllElements -Type Href -Url 'https://fixture.test/page'
   Assert-LinkResult $r
   $r.NonHrefs.Count | Should Be 2
   ($r.OutputFiles.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be 'Hrefs,SettingsLog'
  }
  It 'O05 noHref writes two category files and settings' {
   $r=PSWC -ShowAllElements -Type noHref -Url 'https://fixture.test/page'
   Assert-LinkResult $r
   ($r.OutputFiles.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be 'InternalLinks,NonHrefs,SettingsLog'
  }
  It 'O06 onlyDomains type writes Domains and settings without DNS' {
   $r=PSWC -ShowAllElements -Type onlyDomains -Url 'https://fixture.test/page'
   Assert-LinkResult $r
   ($r.OutputFiles.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be 'Domains,SettingsLog'
   Assert-MockCalled Get-PSWCGetHostAddresses -Times 0 -Exactly -Scope It
  }
  It 'O07 empty remote anchors return typed empty arrays without invented category paths' {
   $old=$script:outputHtml
   try {$script:outputHtml='<html>none</html>'; $r=PSWC -Url 'https://fixture.test/page';Assert-LinkResult $r
    $r.Counts.Hrefs | Should Be 0
    $r.Counts.NonHrefs | Should Be 0
    $r.Counts.InternalLinks | Should Be 0
    $r.Counts.Domains | Should Be 0
    ($r.OutputFiles.PSObject.Properties.Name -join ',') | Should Be 'SettingsLog'
   } finally {$script:outputHtml=$old}
  }
  It 'O08 local Unicode provenance and explicit base preserve extraction and real files' {
   $p=Join-Path $TestDrive ('space '+[char]0x0142+'.html')
   [IO.File]::WriteAllText($p,$script:outputHtml)
   $r=PSWC -HtmlPath $p -BaseUrl 'https://base.test/dir/page'
   Assert-LinkResult $r
   $r.Operation | Should Be 'LocalHtmlLinks'
   $r.InputKind | Should Be 'LocalHtml'
   $r.HtmlPath | Should Be $p
   $r.SourcePath | Should Be $p
   $r.SourceUrl | Should Be $null
   ($r.InternalLinks -join ',') | Should Be 'https://base.test/dir/person@test.invalid,https://base.test/inside'
   Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It
  }
  It 'O09 local without base keeps relative links unresolved and emits empty file correctly' {
   $p=Join-Path $TestDrive 'no-base.html';[IO.File]::WriteAllText($p,$script:outputHtml)
   $r=PSWC -HtmlPath $p;Assert-LinkResult $r
   $r.InternalLinks.Count | Should Be 0
   @(Get-Content -LiteralPath $r.OutputFiles.InternalLinks).Count | Should Be 0
  }
  It 'O10 empty local input returns one object and settings only' {
   $p=Join-Path $TestDrive 'empty.html';[IO.File]::WriteAllText($p,'')
   $r=PSWC -HtmlPath $p;Assert-LinkResult $r
   $r.Counts.Hrefs | Should Be 0
   ($r.OutputFiles.PSObject.Properties.Name -join ',') | Should Be 'SettingsLog'
  }
  It 'O11 failed HTTP preserves no-result behavior' {
   Mock Get-PSWCHttpResponse {$r=New-Object Net.Http.HttpResponseMessage([Net.HttpStatusCode]::NotFound);@($true,$r)}
   $r=@(PSWC -Url 'https://fixture.test/page')
   $r.Count | Should Be 0
  }
  It 'O12 direct private banner remains visible on information stream only' {
   $p=Join-Path $TestDrive 'banner.txt'
   $r=@(Get-PSWCBanner 6> $p)
   $r.Count | Should Be 0
   ((Get-Content -LiteralPath $p -Raw).Trim() -replace "`r`n","`n") | Should Be (((Get-Content -LiteralPath (Join-Path (Get-Module PSWebCrawler).ModuleBase 'images\PSWCbanner.txt') -Raw).Trim()) -replace "`r`n","`n")
  }
 }
}
