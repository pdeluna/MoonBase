# Runs the Firestore rules suite with a Java runtime on PATH.
# Prefers an existing `java`, else Android Studio's bundled JBR (common on Flutter machines).

$ErrorActionPreference = "Stop"

function Test-Java {
  try {
    & java -version 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
  } catch {
    return $false
  }
}

if (-not (Test-Java)) {
  $jbr = "C:\Program Files\Android\Android Studio\jbr"
  if (Test-Path "$jbr\bin\java.exe") {
    $env:JAVA_HOME = $jbr
    $env:Path = "$jbr\bin;$env:Path"
    Write-Host "Using JAVA_HOME=$jbr"
  } else {
    Write-Error "Java not found. Install a JDK 21+ or Android Studio, then re-run."
  }
}

Set-Location $PSScriptRoot
# Prefer npm.cmd so Restricted PowerShell ExecutionPolicy does not block npm.ps1.
npm.cmd test
