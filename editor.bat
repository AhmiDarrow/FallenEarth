@echo off
set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
"%~dp0Godot_v4.7.1-stable_win64.exe" --editor --path "%PROJECT%"
