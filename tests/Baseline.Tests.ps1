# Baseline characterization, not v1 acceptance. Windows PowerShell 5.1 / Pester 3.4.
$root = Split-Path $PSScriptRoot -Parent
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'), [ref]$tokens, [ref]$parseErrors)
$names = @('Start-PSWCCrawl','Get-PSWCDocumentElements','Get-PSWCAllElements','Get-PSWCSchemeAndDomain')
$ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names}, $false) | ForEach-Object { Invoke-Expression $_.Extent.Text }
Add-Type -AssemblyName System.Net.Http
Add-Type -Path (Join-Path $root 'PSWebCrawler\lib\Net45\HtmlAgilityPack.dll')
. (Join-Path $root 'PSWebCrawler\Private\Get-PSWCImageUrls.ps1')
function Write-Log { param($message) }
function Set-PSWCSessionFolder { param($FolderPath,$FolderName) $FolderPath }
function Get-PSWCHttpResponse {
    param($url,$userAgent,$timeout)
    $script:requests += $url
    $response = New-Object System.Net.Http.HttpResponseMessage
    $response.Content = New-Object System.Net.Http.StringContent -ArgumentList $script:fixtureHtml
    return $null,$response
}
Describe 'Baseline on native Windows PowerShell' {
    It 'uses the declared Desktop runtime' {
        $PSVersionTable.PSEdition | Should Be 'Desktop'
        $PSVersionTable.PSVersion.Major | Should Be 5
    }
    It 'parses the module without syntax errors' { @($parseErrors).Count | Should Be 0 }
    It 'extracts absolute image URLs' {
        $result = @(Get-PSWCImageUrls -HtmlContent '<img src="https://site.test/a.png">' -url 'https://site.test/folder/page')
        $result.Count | Should Be 1
        $result[0] | Should Be 'https://site.test/a.png'
    }
    It 'resolves root and parent relative images' {
        $result = @(Get-PSWCImageUrls -HtmlContent '<img src="/root.png"><img src="../up.png">' -url 'https://site.test/folder/page')
        $result.Count | Should Be 2
        $result[0] | Should Be 'https://site.test/root.png'
        $result[1] | Should Be 'https://site.test/up.png'
    }
    It 'characterizes the unresolved plain relative image gap' {
        $result = @(Get-PSWCImageUrls -HtmlContent '<img src="images/pic.png">' -url 'https://site.test/folder/page')
        $result[0] | Should Be 'images/pic.png'
    }
    It 'characterizes external recursion and missing same-host traversal' {
        $script:requests = @()
        $script:fixtureHtml = '<a href="https://site.test/second">internal</a><a href="https://other.test/page">external</a>'
        $script:ArrayData = @([pscustomobject]@{Url='https://site.test/';Href='';Domain=''})
        $script:visitedUrls = @{}; $script:historyDomains = @()
        $script:SessionFolder = $TestDrive
        Start-PSWCCrawl -url 'https://site.test/' -depth 2 -outputFolder '' -userAgent test 6>$null
        $script:requests.Count | Should Be 2
        $script:requests[0] | Should Be 'https://site.test/'
        $script:requests[1] | Should Be 'https://other.test/page'
    }
    It 'characterizes inclusion of the start host in domain extraction' {
        $script:requests = @()
        $script:fixtureHtml = '<a href="https://site.test/second">internal</a><a href="https://other.test/page">external</a>'
        $script:SessionFolder = $TestDrive
        Get-PSWCAllElements -url 'https://site.test/' -Type onlyDomains 6>$null
        $result = @(Get-Content (Join-Path $TestDrive 'DomainsUnique.txt'))
        $result.Count | Should Be 2
        ($result -contains 'https://site.test') | Should Be $true
        ($result -contains 'https://other.test') | Should Be $true
    }
}
