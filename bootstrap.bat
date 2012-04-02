@echo off
  
powershell -NonInteractive -NoProfile -ExecutionPolicy bypass -Command "& '%~dp0bootstrap.ps1' %*"