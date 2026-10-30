# Explicit packaging operation, not a Doctor repair. Offline; does not import the module.
# Retain SHA256 byte bindings for every asset as maintainer metadata. Doctor validates
# this schema but checks the two code-owned bundled HAP DLL paths for presence only.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path (Split-Path $PSScriptRoot -Parent) 'PSWebCrawler'
$files=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object Name -ne 'PackageIntegrity.json' | Sort-Object FullName)
$entries=@(foreach($file in $files){
    if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Package links are not accepted.'}
    [pscustomobject][ordered]@{Path=$file.FullName.Substring($root.Length+1).Replace('\','/');Sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
})
$inventory=[pscustomobject][ordered]@{SchemaVersion='1.0';Files=$entries}
$inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'PackageIntegrity.json') -Encoding UTF8
Write-Output ('Inventoried files: '+$entries.Count)
