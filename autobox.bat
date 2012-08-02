@echo off
  
powershell -NoProfile -ExecutionPolicy bypass -Command "start-process powershell -verb runas -argumentlist '-noexit -ExecutionPolicy bypass -command ""Import-Module %~dp0AutoBox.psm1;Invoke-AutoBox %*""'"