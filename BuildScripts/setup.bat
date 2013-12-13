@echo off
  
powershell -NoProfile -ExecutionPolicy bypass -command ". '%~dp0\BuildScripts\bootstrapper.ps1';Get-Boxstarter"