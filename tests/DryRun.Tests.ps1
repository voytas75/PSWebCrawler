$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -Force -ErrorAction Stop
Describe 'DryRun plans only' {
 InModuleScope PSWebCrawler {
  foreach($seam in @('Get-PSWCBanner','Write-Log','Get-PSWCoutPath','New-PSWCoutPath','Set-PSWCSessionFolder','Get-RandomUserAgent','start-watch','Get-PSWCHttpResponse','Get-PSWCGetHostAddresses','Get-PSWCDocumentElements','Start-PSWCCrawl','Open-PSWCExplorerCache','Read-Host','Out-File','Add-Content','New-Item','Set-Content')) { Mock $seam {throw 'Forbidden preview effect'} }
  It 'P01 URL only yields exactly one structured plan' {
   $r=@(Start-PSWebCrawler -Url 'https://fixture.test' -DryRun)
   $r.Count | Should Be 1
   $r[0].PSObject.TypeNames[0] | Should Be 'PSWebCrawler.Plan'
   $r[0].Operation | Should Be 'ShowAllElements'
   $r[0].NetworkRequired | Should Be $true
   $r[0].EffectiveOptions.Type | Should Be 'All'
  }
  It 'P02 Preview is the same switch on both aliases' {
   (PSWC -Url 'https://fixture.test' -Preview).Operation | Should Be 'ShowAllElements'
   (PSWebCrawler -Url 'https://fixture.test' -DryRun).SchemaVersion | Should Be '1.0'
  }
  It 'P03 crawl options explicit output and resolve are interpreted without execution' {
   $r=Start-PSWebCrawler -Url 'https://fixture.test' -Depth 2 -Resolve -outputFolder 'D:\scratch\not-created' -DryRun
   $r.Operation | Should Be 'WebCrawl'
   $r.EffectiveOptions.Depth | Should Be 2
   $r.EffectiveOptions.Resolve | Should Be $true
   $r.PlannedOutputLocation | Should Be 'D:\scratch\not-created'
  }
  It 'P04 all legacy selectors plan rather than request' {
   foreach($selector in @('GetImageUrls','GetHTMLMetadata','GetContactInformation','GetHeadersAndValues','ShowAllElements')) {
    $options=@{Url='https://fixture.test';DryRun=$true};$options[$selector]=$true
    $plan=Start-PSWebCrawler @options
    $plan.Operation | Should Be $selector
    $expected=@{GetImageUrls='Possible files: Images.txt or Header.json (response-dependent)';GetHTMLMetadata='Possible file: Header.json';GetContactInformation='Possible file: Contact.json';GetHeadersAndValues='Possible file: HTMLhead.json';ShowAllElements='Possible category files when anchors exist: UrlsUnique.txt, noHrefUnique.txt, InternalLinksUnique.txt, DomainsUnique.txt'}
    ($plan.Effects -contains $expected[$selector]) | Should Be $true
   }
  }
  It 'P05 no argument preview is a HelpMenu plan' {
   $r=Start-PSWebCrawler -DryRun
   $r.Operation | Should Be 'HelpMenu'
   $r.NetworkRequired | Should Be $false
   $r.Effects.Count | Should Be 0
  }
  It 'P06 cache plan has no network but documents Explorer' {
   $r=Start-PSWebCrawler -ShowCacheFolder -Preview
   $r.NetworkRequired | Should Be $false
   ($r.Effects -contains 'Open Windows File Explorer') | Should Be $true
  }
  It 'P07 invalid explicit legacy URL rejects without prompting' {
   foreach($value in @('relative','ftp://fixture.test','https://','')) {
    {Start-PSWebCrawler -Url $value -GetImageUrls -DryRun} | Should Throw
   }
  }
  It 'P08 Doctor excludes both preview spellings' {
   {Start-PSWebCrawler -Doctor -DryRun} | Should Throw
   {Start-PSWebCrawler -Doctor -Preview} | Should Throw
  }
  It 'P09 local preview validates metadata but never parses HTML' {
   $r=Start-PSWebCrawler -HtmlPath (Join-Path $PSScriptRoot '..\README.md') -DryRun
   $r.InputKind | Should Be 'LocalHtml'
   $r.NetworkRequired | Should Be $false
   $r.Operation | Should Be 'LocalHtmlLinks'
  }
  It 'P11 inactive effective options are null with closed keys and active defaults' {
   foreach($selector in @('GetImageUrls','GetHTMLMetadata','GetContactInformation','GetHeadersAndValues','ShowAllElements')) {
    $options=@{Url='https://fixture.test';DryRun=$true};$options[$selector]=$true
    $r=Start-PSWebCrawler @options
    ($null -eq $r.EffectiveOptions.Depth) | Should Be $true
    ($null -eq $r.EffectiveOptions.Resolve) | Should Be $true
    ($null -eq $r.EffectiveOptions.BaseUrl) | Should Be $true
    if($selector -eq 'ShowAllElements') {$r.EffectiveOptions.Type | Should Be 'All';$r.EffectiveOptions.OnlyDomains | Should Be $false}
    else {($null -eq $r.EffectiveOptions.Type) | Should Be $true;($null -eq $r.EffectiveOptions.OnlyDomains) | Should Be $true}
    $r.EffectiveOptions.Keys.Count | Should Be 5
   }
   foreach($r in @((Start-PSWebCrawler -DryRun),(Start-PSWebCrawler -ShowCacheFolder -DryRun))) {
    foreach($value in $r.EffectiveOptions.Values){($null -eq $value) | Should Be $true}
   }
   $local=Start-PSWebCrawler -HtmlPath (Join-Path $PSScriptRoot '..\README.md') -DryRun
   $local.EffectiveOptions.Type | Should Be 'All'
   foreach($key in @('Depth','Resolve','OnlyDomains','BaseUrl')){($null -eq $local.EffectiveOptions[$key]) | Should Be $true}
   $based=Start-PSWebCrawler -HtmlPath (Join-Path $PSScriptRoot '..\README.md') -BaseUrl 'https://base.test/page' -DryRun
   $based.EffectiveOptions.BaseUrl | Should Be 'https://base.test/page'
  }
  It 'P12 crawl defaults and generic output names remain active and cache creates a session' {
   $r=Start-PSWebCrawler -Url 'https://fixture.test' -Depth 2 -DryRun
   $r.EffectiveOptions.Depth | Should Be 2
   $r.EffectiveOptions.Resolve | Should Be $false
   $r.EffectiveOptions.OnlyDomains | Should Be $false
   ($null -eq $r.EffectiveOptions.Type) | Should Be $true
   ($null -eq $r.EffectiveOptions.BaseUrl) | Should Be $true
   ($r.Effects -contains 'Possible files: UniqueURLs.txt, UniqueDomain.txt and response-dependent page-derived files') | Should Be $true
   ((Start-PSWebCrawler -ShowCacheFolder -DryRun).Effects -contains 'Create timestamped session folder') | Should Be $true
  }
  It 'P10 local invalid path base and mixed inputs terminate' {
   {Start-PSWebCrawler -HtmlPath 'D:\scratch\absent-html-fixture.html' -DryRun} | Should Throw
   {Start-PSWebCrawler -HtmlPath (Join-Path $PSScriptRoot '..\README.md') -BaseUrl 'relative' -DryRun} | Should Throw
   {Start-PSWebCrawler -HtmlPath (Join-Path $PSScriptRoot '..\README.md') -Url 'https://a.test' -DryRun} | Should Throw
  }
 }
}
