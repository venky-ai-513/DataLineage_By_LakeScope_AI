@echo off
setlocal
title LakeScope - build server Python environment
cd /d "%~dp0"
rem The original .venv was copied from another PC and points to a Python that
rem does not exist on this server. This builds a fresh environment (.venv-server)
rem with the server's own Python and installs the backend requirements.
set "LOG=%~dp0data\setup-server-venv.log"
echo [%date% %time%] setup started > "%LOG%"
if not exist ".venv-server\Scripts\python.exe" (
  echo Creating .venv-server with the server's Python...
  py -3 -m venv .venv-server >> "%LOG%" 2>&1 || python -m venv .venv-server >> "%LOG%" 2>&1
)
if not exist ".venv-server\Scripts\python.exe" (echo [ERROR] Could not create .venv-server - see data\setup-server-venv.log & echo VENV_FAILED>> "%LOG%" & pause & exit /b 1)
echo Installing backend requirements (this can take a few minutes)...
".venv-server\Scripts\python.exe" -m pip install --upgrade pip >> "%LOG%" 2>&1
".venv-server\Scripts\python.exe" -m pip install -r backend\requirements.txt >> "%LOG%" 2>&1
if errorlevel 1 (echo [ERROR] pip install failed - see data\setup-server-venv.log & echo PIP_FAILED>> "%LOG%" & pause & exit /b 1)
".venv-server\Scripts\python.exe" -c "import fastapi, uvicorn, sqlalchemy; print('imports ok')" >> "%LOG%" 2>&1
echo SETUP_OK>> "%LOG%"
echo Done. Now run start-lakescope.bat
timeout /t 5 >nul
