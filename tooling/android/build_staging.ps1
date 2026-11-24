param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [string]$ClerkPublishableKey,
    [string]$InterviewOrigin,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
# Keep staging policy here; ApiClient retains its existing Web/local defaults.
$api = $null
if ($ApiBaseUrl -cne $ApiBaseUrl.Trim() -or
    -not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$api) -or
    $api.Scheme -ne 'https' -or -not $api.Host -or
    $api.UserInfo -or $api.Query -or $api.Fragment -or
    $api.AbsolutePath.TrimEnd('/') -cne '/api') {
    throw 'Use an HTTPS API_BASE_URL ending in /api, without credentials, query, or fragment.'
}
if ($ClerkPublishableKey -and $ClerkPublishableKey -notmatch '^pk_test_[A-Za-z0-9_-]+$') {
    throw 'Use a dedicated Clerk test instance publishable key for staging.'
}
if ($InterviewOrigin) {
    $origin = $null
    if (-not [Uri]::TryCreate($InterviewOrigin, [UriKind]::Absolute, [ref]$origin) -or
        ($origin.Scheme -ne 'https' -and -not ($origin.Scheme -eq 'http' -and $origin.Host -in @('localhost', '127.0.0.1'))) -or
        $origin.UserInfo -or $origin.Query -or $origin.Fragment -or $origin.AbsolutePath -ne '/') {
        throw 'Use an exact HTTPS interview origin, or a loopback HTTP origin for this debug build.'
    }
}
if ($ValidateOnly) { return }

$frontendRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $frontendRoot
try {
    $arguments = @('build', 'apk', '--debug', "--dart-define=API_BASE_URL=$($api.AbsoluteUri.TrimEnd('/'))")
    if ($ClerkPublishableKey) {
        $arguments += "--dart-define=CLERK_PUBLISHABLE_KEY=$ClerkPublishableKey"
    }
    if ($InterviewOrigin) {
        $arguments += "--dart-define=ANDROID_INTERVIEW_ORIGIN=$($origin.GetLeftPart([UriPartial]::Authority))"
    }
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw "Android staging build failed (exit $LASTEXITCODE)." }
    Write-Output (Join-Path $frontendRoot 'build/app/outputs/flutter-apk/app-debug.apk')
} finally {
    Pop-Location
}
