# Run in an isolated powershell.exe -NoProfile process. No imports of production module.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Run using native Windows PowerShell 5.1.'
}
Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
$result = Invoke-Pester -Script (Join-Path $PSScriptRoot 'Baseline.Tests.ps1') -PassThru
$result | Select-Object TotalCount,PassedCount,FailedCount,SkippedCount | Format-List
if ($result.FailedCount -gt 0 -or $result.TotalCount -ne 7) { exit 1 }
exit 0
