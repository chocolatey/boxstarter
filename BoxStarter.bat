@echo off
  
powershell -NoProfile -ExecutionPolicy bypass -file %~dp0Bootstrapper\AdminProxy.ps1 %*