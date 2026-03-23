@echo off
REM Host-side initialization (Windows).
REM Delegates to PowerShell script in the same directory.
powershell -ExecutionPolicy Bypass -File "%~dp0init-host.ps1"
