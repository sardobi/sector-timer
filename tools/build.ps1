[CmdletBinding()]
param(
    [ValidateSet('Build', 'Test', 'Run')]
    [string]$Mode = 'Build',
    [string]$DeveloperKey = $env:CIQ_DEVELOPER_KEY,
    [string]$JavaHome = $env:JAVA_HOME
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sdkConfig = Join-Path $env:APPDATA 'Garmin\ConnectIQ\current-sdk.cfg'
if (-not (Test-Path -LiteralPath $sdkConfig)) {
    throw 'Select an active Connect IQ SDK in SDK Manager first.'
}
$sdk = (Get-Content -LiteralPath $sdkConfig -Raw).Trim()
if (-not $JavaHome) {
    $JavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
}
$java = if ($JavaHome) { Join-Path $JavaHome 'bin\java.exe' } else { (Get-Command java -ErrorAction Stop).Source }
if (-not (Test-Path -LiteralPath $java)) {
    throw "Java executable not found: $java. Pass -JavaHome with the JDK root."
}
if (-not $DeveloperKey -or -not (Test-Path -LiteralPath $DeveloperKey -PathType Leaf)) {
    throw 'Pass -DeveloperKey with your private Garmin signing-key path, or set CIQ_DEVELOPER_KEY. Do not place the key in this repository.'
}
$DeveloperKey = (Resolve-Path -LiteralPath $DeveloperKey).Path
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$filename = switch ($Mode) {
    'Build' { 'SectorTimer.prg' }
    'Test' { 'SectorTimer-tests.prg' }
    'Run' { 'SectorTimer-debug.prg' }
}
$output = Join-Path $bin $filename
$jungle = if ($Mode -eq 'Test') { 'tests.jungle' } else { 'monkey.jungle' }
$compilerArguments = @(
    '-Xms1g', '-Dfile.encoding=UTF-8', '-cp', (Join-Path $sdk 'bin\monkeybrains.jar'),
    'com.garmin.monkeybrains.Monkeybrains',
    '-f', $jungle, '-d', 'vivoactive5', '-o', $output, '-y', $DeveloperKey,
    '-w', '-l', '3'
)
if ($Mode -eq 'Build') { $compilerArguments += '-r' }
if ($Mode -eq 'Test') { $compilerArguments += '--unit-test' }

Push-Location $root
try {
    & $java @compilerArguments
    if ($LASTEXITCODE -ne 0) { throw "Connect IQ compiler failed ($LASTEXITCODE)." }
    Write-Host "Built $output"
    if ($Mode -ne 'Build') {
        $simulator = Join-Path $sdk 'bin\simulator.exe'
        $existing = Get-Process -Name simulator -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -eq $simulator }
        if (-not $existing) {
            $process = Start-Process -FilePath $simulator -PassThru
            Start-Sleep -Seconds 3
            if ($process.HasExited) { throw 'The Connect IQ simulator exited during startup.' }
        }
        $runArguments = @(
            '-cp', (Join-Path $sdk 'bin\monkeybrains.jar'),
            'com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux',
            '-f', $output, '-d', 'vivoactive5', '-s', (Join-Path $sdk 'bin\shell.exe')
        )
        if ($Mode -eq 'Test') { $runArguments += '-t' }
        $log = Join-Path $bin "$Mode.log"
        & $java @runArguments 2>&1 | Tee-Object -FilePath $log
        $runnerExit = $LASTEXITCODE
        if ($Mode -eq 'Test') {
            $passed = Select-String -LiteralPath $log -Pattern '^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)$' -Quiet
            if (-not $passed) {
                throw "The simulator did not report a passing test suite. See $log."
            }
            if ($runnerExit -eq 1 -and (Get-Content -LiteralPath (Join-Path $sdk 'bin\version.txt') -Raw).Trim() -eq '9.2.0') {
                # SDK 9.2.0's runner misparses its own passing summary and returns 1.
                # Accept only this version and an explicit non-empty, zero-failure summary.
                Write-Warning 'SDK 9.2.0 runner returned 1 despite a passing test summary; using the explicit simulator results.'
            } elseif ($runnerExit -ne 0) {
                throw "Simulator execution failed ($runnerExit). See $log."
            }
        } elseif ($runnerExit -ne 0) {
            throw "Simulator execution failed ($runnerExit). See $log."
        }
    }
} finally {
    Pop-Location
}
