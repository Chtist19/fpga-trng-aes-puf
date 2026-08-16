@echo off
rem ============================================================
rem  NIST SP 800-22 one-click runner
rem  Double-click: runs default data trng_data.bin, 8 streams
rem  With args  : run_nist.bat <data file> <streams>
rem    example  : run_nist.bat F:\fpga_project\trng_data_12m.bin 100
rem ============================================================
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_nist_sp80022.ps1" -DataFile "F:\fpga_project\trng_data.bin" -Streams 8
) else if "%~2"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_nist_sp80022.ps1" -DataFile "%~1" -Streams 8
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_nist_sp80022.ps1" -DataFile "%~1" -Streams %2
)
pause
