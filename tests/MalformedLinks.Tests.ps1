$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'Malformed anchor isolation' {
 InModuleScope PSWebCrawler {
  Mock Write-Log {}
  Mock Get-PSWCoutPath {$TestDrive}
  Mock Set-PSWCSessionFolder {$p=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($p);$p}
  Mock Get-RandomUserAgent {'offline-fixture'}
  Mock start-watch {New-Object Diagnostics.Stopwatch}
  Mock stop-watch {}
  Mock Read-Host {throw 'Forbidden prompt'}
  Mock Start-PSWCCrawl {throw 'Forbidden crawl'}
  $script:malformedHtml='<a href="https://z.test/z">Z</a><a href="https://[invalid">Bad</a><a href="https://a.test/a">A</a><a href="https://a.test/a">Duplicate</a>'
  Mock Get-PSWCHttpResponse {$r=New-Object Net.Http.HttpResponseMessage;$r.Content=New-Object Net.Http.StringContent($script:malformedHtml);@($true,$r)}
  function Assert-MalformedResult($r,$warnings) {
   @($r).Count | Should Be 1
   $r.PSObject.TypeNames[0] | Should Be 'PSWebCrawler.LinkAnalysis'
   $r.SchemaVersion | Should Be '1.0'
   ($r.Hrefs -join ',') | Should Be 'https://a.test/a,https://z.test/z'
   ($r.Domains -join ',') | Should Be 'https://a.test,https://z.test'
   $r.Counts.Hrefs | Should Be 2
   $r.Counts.Domains | Should Be 2
   $r.Counts.NonHrefs | Should Be 0
   $r.Counts.InternalLinks | Should Be 0
   @($warnings).Count | Should Be 1
   $warnings[0].Message | Should Be 'Skipped malformed HTTP link.'
   foreach($name in @('Hrefs','Domains','NonHrefs','InternalLinks')) {
    ((Get-Content -LiteralPath $r.OutputFiles.$name) -join ',') | Should Be ($r.$name -join ',')
   }
  }
  It 'M01 public URL keeps valid anchors before and after malformed input' {$w=@();$r=Start-PSWebCrawler -Url 'https://fixture.test/page' -WarningVariable w;Assert-MalformedResult $r $w;Assert-MockCalled Get-PSWCHttpResponse -Times 1 -Exactly -Scope It}
  It 'M02 PSWC local input isolates malformed absolute href without HTTP' {$p=Join-Path $TestDrive 'm02.html';[IO.File]::WriteAllText($p,$script:malformedHtml);$w=@();$r=PSWC -HtmlPath $p -WarningVariable w;Assert-MalformedResult $r $w;Assert-MockCalled Get-PSWCHttpResponse -Times 0 -Exactly -Scope It}
  It 'M03 PSWebCrawler alias preserves local result and warning stream' {$p=Join-Path $TestDrive 'm03.html';[IO.File]::WriteAllText($p,$script:malformedHtml);$w=@();$r=PSWebCrawler -HtmlPath $p -BaseUrl 'https://base.test/' -WarningVariable w;Assert-MalformedResult $r $w}
  It 'M04 relative URI construction failure is isolated per anchor' {$old=$script:malformedHtml;try {$script:malformedHtml='<a href="/ok">OK</a><a href="//[invalid">Bad</a><a href="../later">Later</a>';$w=@();$r=PSWC -Url 'https://fixture.test/page' -WarningVariable w;($r.InternalLinks -join ',') | Should Be 'https://fixture.test/later,https://fixture.test/ok';$r.NonHrefs.Count | Should Be 2;@($w).Count | Should Be 1} finally {$script:malformedHtml=$old}}
  It 'M05 unrelated parser failure remains terminating' {Mock Get-PSWCDocumentElements {throw 'OFFLINE parser failure'};{PSWC -Url 'https://fixture.test/page'} | Should Throw 'OFFLINE parser failure'}
 }
}
