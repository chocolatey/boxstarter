@echo off
  
powershell -NoProfile -ExecutionPolicy bypass -Command "start-process powershell -verb runas -argumentlist '-ExecutionPolicy bypass -command ""&  %~dp0bootstrap.ps1 %*""'"