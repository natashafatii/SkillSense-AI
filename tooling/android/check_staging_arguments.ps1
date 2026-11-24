$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'build_staging.ps1'
foreach ($valid in @('https://staging.example.test/api', 'https://staging.example.test:8443/api/')) {
    & $builder -ApiBaseUrl $valid -ClerkPublishableKey 'pk_test_fixture' -ValidateOnly
}
foreach ($invalid in @(
    'http://staging.example.test/api', 'not-a-url',
    'https://user:password@staging.example.test/api',
    'https://staging.example.test/api?ticket=fixture',
    'https://staging.example.test/api#fixture',
    'https://staging.example.test', ' https://staging.example.test/api'
)) {
    $rejected = $false
    try { & $builder -ApiBaseUrl $invalid -ValidateOnly } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unsafe staging API argument was accepted.' }
}
$rejected = $false
try {
    & $builder -ApiBaseUrl 'https://staging.example.test/api' -ClerkPublishableKey 'sk_test_fixture' -ValidateOnly
} catch { $rejected = $true }
if (-not $rejected) { throw 'A server key was accepted as a publishable key.' }
Write-Output 'PASS: HTTPS staging URL and test publishable-key argument checks.'
