@ECHO OFF

REM  ----------------------------------------------------
REM  Batch file to create bootable ISO in Windows
REM  usage: make_iso.bat c:\new-slax.iso
REM  author: Tomas M. <http://www.linux-live.org>
REM  ----------------------------------------------------

if "%1"=="" goto error1
cd ..
set CDLABEL=Pentoo

tools\win\mkisofs.exe @tools\win\config -o "%1" -A "%CDLABEL%" -V "%CDLABEL%" .
echo.
echo New ISO should be created now.
goto theend

:error1
echo A parameter is required - target ISO file.
echo Example: %0 c:\target.iso
goto theend

:error2
echo Error creating the ISO file
goto theend

:theend
pause
