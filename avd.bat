@echo off
setlocal EnableExtensions EnableDelayedExpansion

if "%ANDROID_HOME%"=="" (
	echo ANDROID_HOME is not defined.
	exit /b 1
)

set adb="%ANDROID_HOME%\platform-tools\adb.exe"
set emulator="%ANDROID_HOME%\emulator\emulator.exe"

if not exist %emulator% (
	echo Android emulator is missing.
	exit /b 2
)

if "%1"=="" goto usage
SET DEVICE=%1

echo.
echo Starting %DEVICE%...
start "Android Emulator" /B %emulator% -avd %DEVICE% -writable-system
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo Please note that the AVD will be modified and then rebooted,
echo so be patient until it is rebooted so you can continue...
echo.
echo.

call :wait
call :root

echo Working with the hosts file...
md %temp% 2>nul
%adb% pull /system/etc/hosts "%temp%\hosts"
if %errorlevel% neq 0 (
	echo Could not pull hosts file.
	call :kill
	exit /b 1000
)
sleep 1
echo 10.0.2.2	[MY_LOCAL_DOMAIN] >> "%temp%\hosts"
%adb% push "%temp%\hosts" /system/etc/hosts
if %errorlevel% neq 0 (
	echo Could not push hosts file.
	call :kill
	exit /b 1000
)
sleep 1
call :reboot

REM open ports
echo mapping ports 44300-44399
%adb% reverse --remove-all
for /L %%i in (44300,1,44399) do adb reverse tcp:%%i tcp:%%i

REM inject certificate
%adb% shell mkdir /data/local/tmp/cacerts/
%adb% shell cp /system/etc/security/cacerts/* /data/local/tmp/cacerts/
%adb% push cert/ef9573ed.0 /data/local/tmp/cacerts/
%adb% root
%adb% shell mount -t tmpfs tmpfs /system/etc/security/cacerts
%adb% shell mv /data/local/tmp/cacerts/* /system/etc/security/cacerts/
%adb% shell chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*

echo All done
echo You can proceed...
goto :eof

:root
%adb% root
sleep 1
call :adb
%adb% shell avbctl disable-verification
call :reboot
%adb% root
echo remount...
%adb% remount
goto :eof

:reboot
%adb% reboot
sleep 10
call :wait
echo Waiting for adb to connect...
call :adb
goto :eof

:wait
echo Waiting for the emulator...
%adb% wait-for-device shell "while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done; sleep 3; input keyevent 82" 
goto :eof

:adb
adb devices | findstr /i "\<device\>">nul
if %errorlevel%==1 (
	sleep 5
	goto adb
)
goto :eof

:kill
taskkill /F /IM emulator.exe
goto :eof

:usage
echo.
echo This will modify AVD device's HOSTS file and run it.
echo An AVD ID is required to proceed.
echo 	%~n0 [AVD ID]
echo.
echo where AVD ID is the ID of your AVD device.
echo It is expected to be something like Pixel_5_API_29 for example.
echo It can be obtained from Android Studio Deveice Manager ^> Virtual Device Configuration
echo.
