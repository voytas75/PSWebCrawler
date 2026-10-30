# Explicit packaging operation, not a Doctor repair. Offline; does not import the module.
# Generate a deterministic required-file inventory only; no byte hashes or integrity claims.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path (Split-Path $PSScriptRoot -Parent) 'PSWebCrawler'
$files=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object Name -ne 'PackageIntegrity.json' | Sort-Object FullName)
$entries=@(foreach($file in $files){
    if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Package links are not accepted.'}
    [pscustomobject][ordered]@{Path=$file.FullName.Substring($root.Length+1).Replace('\','/')}
})
$inventory=[pscustomobject][ordered]@{SchemaVersion='2.0';Files=$entries}
$inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'PackageIntegrity.json') -Encoding UTF8
Write-Output ('Inventoried files: '+$entries.Count)
