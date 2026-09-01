# Runs the Storage rules suite with a Java runtime on PATH.
# Prefers JDK 23+, then Android Studio JBR, then whatever is on PATH.

$ErrorActionPreference = "Stop"

function Test-JavaExe([string]$javaExe) {
  if (-not (Test-Path $javaExe)) { return $false }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $null = & $javaExe -version 2>&1
    return $LASTEXITCODE -eq 0
  } catch {
    return $false
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Set-JavaHome([string]$javaHome) {
  $env:JAVA_HOME = $javaHome
  $env:Path = "$javaHome\bin;$env:Path"
  Write-Host "Using JAVA_HOME=$javaHome"
}

$candidates = @(
  "C:\Program Files\Java\jdk-23",
  "C:\Program Files\Android\Android Studio\jbr"
)

$resolved = $false
foreach ($jdkHome in $candidates) {
  $exe = Join-Path $jdkHome "bin\java.exe"
  if (Test-JavaExe $exe) {
    Set-JavaHome $jdkHome
    $resolved = $true
    break
  }
}

if (-not $resolved) {
  # Fall back to whatever `java` resolves to on PATH.
  $javaCmd = Get-Command java -ErrorAction SilentlyContinue
  if ($javaCmd -and (Test-JavaExe $javaCmd.Source)) {
    Write-Host "Using java on PATH: $($javaCmd.Source)"
    $resolved = $true
  }
}

if (-not $resolved) {
  Write-Error "Java not found. Install a JDK 21+ or Android Studio, then re-run."
}

Set-Location $PSScriptRoot
# Prefer npm.cmd so Restricted PowerShell ExecutionPolicy does not block npm.ps1.
npm.cmd test
