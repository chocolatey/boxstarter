@echo off
  
powershell -NoProfile -ExecutionPolicy bypass -command ". '%~dp0setup.ps1';Install-Boxstarter '%~dp0' 'Boxstarter.Chocolatey'"