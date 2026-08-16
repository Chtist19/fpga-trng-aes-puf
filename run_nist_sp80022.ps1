# =============================================================================
# One-click NIST SP 800-22 runner (official sts-2.1.2)
# Usage:
#   powershell -ExecutionPolicy Bypass -File run_nist_sp80022.ps1 -DataFile F:\fpga_project\trng_data.bin -Streams 8
#   powershell -ExecutionPolicy Bypass -File run_nist_sp80022.ps1 -DataFile F:\fpga_project\trng_data_12m.bin -Streams 100
# Params:
#   -DataFile  binary data file to test (8 bits per byte)
#   -Streams   number of bitstreams (NIST recommends 100)
#   -Bits      bits per bitstream (default 1000000)
#   -ResultOut where to save the report (default: project root)
# =============================================================================
param(
    [Parameter(Mandatory = $true)][string]$DataFile,
    [int]$Streams = 8,
    [int]$Bits = 1000000,
    [string]$ResultOut = "F:\fpga_project\NIST_SP800-22_结果.txt"
)

$ErrorActionPreference = "Stop"
$mingw  = "F:\ANACONDA\envs\nist-sts\Library\mingw-w64\bin"
$runDir = "F:\fpga_project\sts-2.1.2\sts-2.1.2\sts-2.1.2"

if (-not (Test-Path $DataFile)) { Write-Host "ERROR: data file not found: $DataFile"; exit 1 }
if (-not (Test-Path "$runDir\assess.exe")) { Write-Host "ERROR: assess.exe not found. Build it first."; exit 1 }

$bytes = (Get-Item $DataFile).Length
$need  = [long]$Streams * $Bits / 8
if ($bytes -lt $need) {
    Write-Host ("ERROR: need at least {0} bytes ({1} streams x {2} bits = {3} MB), but file has {4} bytes" -f `
        $need, $Streams, $Bits, [math]::Round($need/1MB, 2), $bytes)
    exit 1
}
Write-Host ("Data file : {0}" -f $DataFile)
Write-Host ("Streams   : {0}  x  {1} bits  (needs {2} MB)" -f $Streams, $Bits, [math]::Round($need/1MB, 2))

$env:PATH = $mingw + ";" + $env:PATH
Push-Location $runDir
try {
    # interactive answers: 0=file input, filename, 1=all tests, 0=default params, streams, 1=binary mode
    $input_seq = "0`n$DataFile`n1`n0`n$Streams`n1`n"
    $input_seq | .\assess.exe $Bits
    Copy-Item "experiments\AlgorithmTesting\finalAnalysisReport.txt" $ResultOut -Force
    Write-Host ""
    Write-Host ("==== DONE. Report saved to: {0} ====" -f $ResultOut)
} finally {
    Pop-Location
}
