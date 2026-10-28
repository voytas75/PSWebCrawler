# Test base

## Runtime and execution
Windows PowerShell 5.1 Desktop; existing Pester 3.4.0. No Python, Linux pwsh, installs, public HTTP or production module import.
Run in a fresh process: powershell.exe -NoProfile -File .\tests\Run-Baseline.ps1.
If source is accessed over WSL UNC, .NET may reject DLL loading. Copy only PSWebCrawler/ and tests/ into a new local Windows scratch directory and run there. Do not enable loadFromRemoteSources, change persistent execution policy or overwrite D:\repos\PSWebCrawler. Verify copied file hashes against sources before interpreting results.

## Baseline coverage
Seven tests characterize the current implementation: Desktop runtime, parsing, absolute images, root/parent relative images, unresolved plain relative images, external-only recursion, and start-host inclusion in domain extraction.
The last three intentionally document gaps. Green baseline is NOT v1 acceptance. Change them into regression expectations when separately approved implementation addresses the corresponding contract. Tests load selected functions through AST and use a local fake HTTP function; generated files use Pester TestDrive. No PSparseHTML dependency is required because full import and conversion paths are not exercised.

## Future v1 acceptance matrix — not implemented or counted as tests
- Site: same-host links visited; foreign hosts/subdomains and redirects outside scope recorded, not fetched.
- Domains: one page per host; first discovered URL and all host edges preserved.
- Depth 0/1/2, BFS, deduplication/cycles, query preservation, fragment removal, base href.
- Isolated state across runs; machine-readable Run/Pages/Links/Errors and JSON parity.
- Page/host/time/size limits return partial result with cause.
- robots.txt missing/error/disallow; host request spacing; private/local target denial including redirects.
- Invalid inputs fail without prompts; import makes no network calls and does not terminate the process.
- Native full invocation on Windows 5.1 with explicitly approved dependency setup.

## First Site RED gate
Run-SiteContract.ps1 executes Site.Contract.Tests.ps1 in native Windows PowerShell. It checks the AST definition and manifest declaration without importing the production module. This is a static public API gate, NOT proof of runtime export. Four explicitly Pending slots name the next behavioral checks; they contain no implementation and are not qualified tests. Runner exits nonzero on failures, pending or skipped cases.
Observed: 0 passed, 1 failed (missing Invoke-PSWebCrawler), 4 pending, 0 skipped. No fake production API is introduced. Future behavioral tests require an agreed transport seam and exact schema. Actual import/export requires a separate process test after import neutralization.

## Limits and next slice
This base cannot qualify Site or Domains v1, actual HTTP, cancellation, robots, network controls, output schema or full import. Legacy API direction is agreed. Next: settle exact schema and transport seam before activating pending behavioral checks. No production fixes or CI added in this stage.
