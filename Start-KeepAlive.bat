@echo off
title Canon Keep-Alive Automation (100% Background Process)
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CanonKeepAlive.ps1"
