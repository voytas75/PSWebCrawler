# Manual Windows preproduction package

Run from a Windows checkout in Windows PowerShell 5.1 Desktop. Choose an
existing, user-controlled output parent outside the checkout and all prior
artifact directories. Each invocation creates a new `PSWC-preproduction-<GUID>`
child; it never appends to old evidence or updates the input checkout.

```powershell
# From the repository root; choose your own existing output directory.
powershell.exe -NoProfile -NonInteractive -File .\tests\Run-WindowsPreproduction.ps1 -OutputParent "$env:USERPROFILE\Documents" -StaticOnly
# Explicit manual host execution, without enforced isolation:
powershell.exe -NoProfile -NonInteractive -File .\tests\Run-WindowsPreproduction.ps1 -OutputParent "$env:USERPROFILE\Documents"
```

Without `-StaticOnly`, prerequisites are .NET Framework 4.8 or newer, existing
PSParseHTML 3.0.6 (no other version available), and Pester 3.4.0. Missing or
ambiguous dependencies fail before staging. No installation, trust, execution
policy, CI, host security or SDK changes are performed. Dependency DLLs are not
vendored. Static-only does not import the product or dependencies or run Pester.

The runner copies repository module files and the fixed test harness, binds them
in a relative-path SHA256 manifest before launch, and launches the prepared guard
in a fresh child. The guard verifies every prepared file before running tests.
The full manual command runs the existing S2 (32), S3 (14), S4 (16), baseline (7),
dependency/import (5), and import-runtime (4) gates in fresh processes. These are
78 expected test outcomes; no skip/pending or reduced case count is accepted.
The public export gate requires only `Start-PSWebCrawler` and the two legacy
aliases; fresh imports must not expose `Invoke-PSWebCrawler`. Contract tests
access that retained private implementation in module scope.
Fixtures substitute private policy/transport boundaries with counted page facts;
legacy network routines are not intentionally exercised. This is not a network
blocker, sandbox, production crawler acceptance, dependency binary safety proof,
or guaranteed descendant-process containment. Product/dependency imports are
real in the full command. Existing module initialization modifies TLS settings
inside test processes; nothing here changes that legacy code.

## Outputs and exit status

The printed path contains `source-manifest.json`, `receipt.json`, `stdout.txt`
and `stderr.txt`, plus the prepared module/tests. The receipt records the run ID,
parent/child PID, child start/exit UTC, exit code, timeout, observed exit, reader
completion and launch/guard/manifest hashes. It does not record dependency binary
closure. Exit 0 requires the guard/test child to exit cleanly, empty stderr,
completed readers and unchanged prepared sources. Exit 1 means failure; inspect
the retained receipt/logs. Preflight failures occur before a receipt exists.
The outer deadline is five minutes; existing gate/inner-child deadlines remain.
A failed or partial run is preserved, never reclassified or overwritten.
Receipts/logs may contain local paths; review before sharing them publicly.

## C2 / B2 limitation

C2-01..12 are **not included or qualified** by this repository package. The
retained B2/supplement snapshot has 37 changed module lines (31 additions,
6 deletions) and four additional product files: admission (141 lines), consumer
mapping (62), page hops (50), and robots (94). Its C2 test requires those private
functions, a BytePipe C# source, network-policy helpers and retained receipt data.
Copying it here would promote out-of-scope product code and machine-specific
artifacts. The checked-in module retains unavailable transport/capability stubs;
Domains is unsupported. S7, R1/R2, HTTPS and the broken historical B2 evidence
chain remain unqualified. No historical receipts are repaired by this package.

## Verified manual acceptance

Native Windows PowerShell parser/static-only execution is the preparation gate.
The owner subsequently performed the full command: run
`7e555fedf1ba4b919b6bf6526c2e41c1` passed 78/78 (32/14/16/7/5/4), with zero
failed/pending/skipped, exit 0, no timeout, empty stderr and completed readers.
The parent verified all 19 snapshot-manifest hashes. This accepts the current
contracts/analysis baseline, not C2/B2, HTTPS/TLS or S7; those are [future work](ROADMAP.md),
not current release gates. A static pass alone only proves prepared-source integrity,
syntax, ordered active S2/S3/S4 identities and current unavailable stubs; it does
not prove the 78 behavioral outcomes or any C2 behavior.
