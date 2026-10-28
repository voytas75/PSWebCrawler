$root = Split-Path $PSScriptRoot -Parent
$t=$null; $e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'),[ref]$t,[ref]$e)
# Exclude function bodies: inspect only module initialization statements.
$top=($ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object {$_.Extent.Text}) -join "`n"
Describe 'Import initialization contract' {
    It 'does not check PSGallery during import' { $top | Should Not Match 'Find-Module' }
    It 'does not create the output directory during import' { $top | Should Not Match 'New-PSWCoutPath' }
    It 'does not exit or clear the host during import' { $top | Should Not Match '(?m)^\s*(exit|Clear-Host)\s*$' }
}
