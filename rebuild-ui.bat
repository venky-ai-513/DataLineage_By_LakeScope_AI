@echo off
title LakeScope - rebuild UI (CRG theme)
cd /d "%~dp0"
set "LOG=%~dp0data\theme-build.log"
echo [%date% %time%] build start > "%LOG%"
if not exist "dist.bak-before-crg" xcopy /e /i /q dist dist.bak-before-crg >> "%LOG%" 2>&1
"C:\Program Files\nodejs\node.exe" node_modules\vite\bin\vite.js build >> "%LOG%" 2>&1
if errorlevel 1 (echo BUILD_FAILED>> "%LOG%") else (echo BUILD_OK>> "%LOG%")
