@ECHO OFF

set prg=%1

SHIFT

set cmd= 
:Loop
IF "%~1"=="" GOTO Continue

set cmd=%cmd% '%1'

SHIFT
GOTO Loop
:Continue

rem echo %cmd%
powershell.exe -command "&'.\csscript.ps1' '%prg%' %cmd%"

