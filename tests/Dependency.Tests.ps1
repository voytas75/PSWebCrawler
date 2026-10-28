# Real installed dependency, not the production crawler. Offline native Windows test.
Import-Module PSParseHTML -RequiredVersion 3.0.6 -ErrorAction Stop
Describe 'PSParseHTML compatibility with crawler calls' {
    It 'converts HTML to a text file using the crawler parameter names' {
        $path = Join-Path $TestDrive 'content.txt'
        Convert-HTMLToText -Content '<html><body><p>Hello analyst</p></body></html>' -OutputFile $path -ErrorAction Stop
        (Test-Path $path) | Should Be $true
        (Get-Content $path -Raw) | Should Match 'Hello analyst'
    }
    It 'formats HTML with the switches used by the crawler' {
        $html = '<html><body><!--comment--><p>Hello analyst</p></body></html>'
        $result = Format-HTML -Content $html -RemoveHTMLComments -RemoveOptionalTags -RemoveEmptyBlocks -RemoveEmptyAttributes -AlphabeticallyOrderAttributes -ErrorAction Stop
        $result | Should Match 'Hello analyst'
        $result | Should Not Match '<!--comment-->'
    }
}
