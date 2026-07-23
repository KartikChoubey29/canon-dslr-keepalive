@echo off
title Canon Keep-Alive Automation
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CanonKeepAlive.ps1"
pause
