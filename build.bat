@echo off
powershell -NoProfile -ExecutionPolicy bypass -Command "%~dp0build.ps1 %*"