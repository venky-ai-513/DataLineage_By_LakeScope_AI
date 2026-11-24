@echo off
setlocal
title LakeScope - https port 3003
cd /d "%~dp0"
set "PATH=C:\Program Files\RedHat\Podman;%PATH%"

rem ---------------------------------------------------------------------------
rem  LakeScope launcher for crgiwtool01  ->  https://%COMPUTERNAME%:3003/
rem  * If the Podman machine "lakescope-machine" exists: full mode
rem    (PostgreSQL + Neo4j via scripts\run-local.cmd, settings from .env)
rem  * Otherwise: SQLite mode using data\lakescope.db (graph view disabled).
rem    Environment variables below override .env for this window only.
rem ---------------------------------------------------------------------------

rem Prefer the environment built on this server (.venv-server); fall back to .venv
set "PY=%~dp0.venv-server\Scripts\python.exe"
if not exist "%PY%" set "PY=%~dp0.venv\Scripts\python.exe"
"%PY%" -c "import uvicorn, fastapi" >nul 2>&1
if errorlevel 1 (echo [ERROR] No working Python environment. Run setup-server-venv.bat first. & pause & exit /b 1)

podman machine inspect lakescope-machine >nul 2>&1
if not errorlevel 1 (
  echo Podman machine found - starting LakeScope with PostgreSQL and Neo4j...
  call "%~dp0scripts\run-local.cmd"
  goto end
)

echo Podman machine "lakescope-machine" is not available on this server.
echo Starting LakeScope in SQLite mode using data\lakescope.db (lineage graph database disabled).
set "LAKESCOPE_DATABASE_URL=sqlite:///./data/lakescope.db"
set "LAKESCOPE_GRAPH_ENABLED=false"

call "%~dp0scripts\start-ai.cmd"
if errorlevel 1 echo WARNING: LAKE AI ^(Ollama^) did not start. LakeScope will run without AI features.

netsh advfirewall firewall show rule name="LakeScope 3003" >nul 2>nul || netsh advfirewall firewall add rule name="LakeScope 3003" dir=in action=allow protocol=TCP localport=3003 >nul 2>nul

echo LakeScope is starting at https://%COMPUTERNAME%:3003/
echo Press Ctrl+C to stop.
"%PY%" -m uvicorn backend.app.main:app --host 0.0.0.0 --port 3003 --ssl-certfile "%~dp0certs\onestop-cert.pem" --ssl-keyfile "%~dp0certs\onestop-key.pem"

:end
echo.
echo LakeScope stopped (exit code %errorlevel%).
pause
