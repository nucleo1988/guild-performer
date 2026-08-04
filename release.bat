@echo off
cd /d "%~dp0tools\release"
python release.py %*
