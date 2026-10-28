# First RED gate. Run in a fresh native Windows PowerShell 5.1 process.
$root = Split-Path $PSScriptRoot -Parent
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'), [ref]$tokens, [ref]$errors)
$definitions = @($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-PSWebCrawler'}, $false))
$manifest = Import-PowerShellDataFile (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1')
Describe 'Site v1 public API gate' {
    It 'defines and declares the new public entry point' {
        $definitions.Count | Should Be 1
        ($manifest.FunctionsToExport -contains 'Invoke-PSWebCrawler') | Should Be $true
    }
    It 'requires an explicit Mode without prompting' -Pending {}
    It 'fetches only the start page for Site Depth 0' -Pending {}
    It 'returns one Run Pages Links Errors object on the success stream' -Pending {}
    It 'preserves empty singleton and multiple arrays through JSON round-trip' -Pending {}
}
# Pending cases are NOT acceptance or implemented behavioral tests.
# They await the public API plus an agreed transport seam and exact schema.
# Do not replace the missing production API with a fake to make this gate green.
