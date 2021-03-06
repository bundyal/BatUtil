@echo off
cd /d "%~dp0"
set uiv=v4.7
:: when changing below options, recommended to set the new values between = and " marks

:: target image or wim file
:: leave it blank to automatically detect wim file next to the script, or current online os
set "target="

:: updates location, remember to set the parent "Updates" directory for WHD repository
set "repo=%~dp0Updates"

:: dism.exe tool path (default is system)
set "dismroot=%windir%\system32\dism.exe"

:: updates to process by default
set LDRbranch=ON
set Hotfix=ON
set WUSatisfy=ON
set WMF=OFF
set Windows10=OFF
set win10u=ON
set RSAT=OFF
set onlinelimit=75

:: update winre.wim if detected inside install.wim, set to 0 to skip it
set winre=1

:: enable .NET 3.5 feature, set to 0 to skip it
set net35=1

:: # Manual options #

:: create new iso file if the target is a distribution folder
:: require ADK installed, or placing oscdimg.exe or cdimage.exe next to the script
set iso=1

:: set this to 1 to delete DVD distribution folder after creating updated ISO
set delete_source=0

:: set this to 1 to start the process directly once you execute the script
:: make sure you set the above options correctly first
set autostart=0

:: optional, set directory for temporary extracted files
set "cab_dir=%~d0\W81UItemp"

:: Optional, set mount directory for updating wim files
set "mountdir=%SystemDrive%\W81UImount"
set "winremount=%SystemDrive%\W81UImountre"

:: ##################################################################
:: # NORMALY THERE IS NO NEED TO CHANGE ANYTHING BELOW THIS COMMENT #
:: ##################################################################

:: Technical options for updates
set ssu1=KB3021910
set ssu2=KB3173424
set baselinelist=(KB2919355,KB3000850,KB2932046,KB2934018,KB2937592,KB2938439,KB2938772,KB3003057,KB3014442)
set gdrlist=(KB3023219,KB3037576,KB3074545,KB3097992,KB3127222)
set hv_integ_kb=hypervintegrationservices
set hv_integ_vr=9600.18692

title Installer for Windows 8.1 Updates
set oscdimgroot=%windir%\system32\oscdimg.exe
set _reg=%windir%\system32\reg.exe
%_reg% query "HKU\S-1-5-19" 1>nul 2>nul || goto :E_Admin

:detect
if exist "%cab_dir%" (
echo.
echo ============================================================
echo Removing temporary extracted files...
echo ============================================================
echo.
rmdir /s /q "%cab_dir%" >nul
)
setlocal enableextensions
setLocal EnableDelayedExpansion
set dvd=0
set wim=0
set offline=0
set online=0
set _wim=0
set copytarget=0
set imgcount=0
if exist "*.wim" (for /f "delims=" %%i in ('dir /b /a:-d *.wim') do (call set /a _wim+=1))
if "%target%"=="" if %_wim%==1 (for %%i in ("*.wim") do set "target=%%~fi"&set "targetname=%%i")
if "%target%"=="" set "target=%SystemDrive%"
if "%target:~-1%"=="\" set "target=%target:~0,-1%"
if /i "%target%"=="%SystemDrive%" goto :check
echo %target%| findstr /E /I "\.wim" >nul
if %errorlevel%==0 (
set wim=1
for /f %%i in ('dir /b "%target%"') do set "targetname=%%i"
) else (
if exist "%target%\sources\boot.wim" set dvd=1 
if exist "%target%\Windows\regedit.exe" set offline=1
)
if %offline%==0 if %wim%==0 if %dvd%==0 (set "target=%SystemDrive%"&goto :check)
if %offline%==1 (
dir /b "%target%\Windows\servicing\Version\6.3.9600.*" 1>nul 2>nul || (set "MESSAGE=Detected target offline image is not Windows 8.1"&goto :E_Target)
set "mountdir=%target%"
if exist "%target%\Windows\SysWOW64\*" (set arch=x64) else (set arch=x86)
)
if %dvd%==1 (
echo.
echo ============================================================
echo Please wait...
echo ============================================================
dir /b /s /adr "%target%" 1>nul 2>nul && set copytarget=1
dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:1 | find /i "Version : 6.3.9600" >nul || (set "MESSAGE=Detected install.wim version is not Windows 10"&goto :E_Target)
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:1 ^| find /i "Architecture"') do set arch=%%i
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" ^| findstr "Index"') do set imgcount=%%i
for /L %%i in (1,1,!imgcount!) do (
  for /f "tokens=1* delims=: " %%a in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:%%i ^| findstr /b /c:"Name"') do set name%%i="%%b"
  )
set "indices=*"
)
if %wim%==1 (
echo.
echo ============================================================
echo Please wait...
echo ============================================================
dism /english /get-wiminfo /wimfile:"%target%" /index:1 | find /i "Version : 6.3.9600" >nul || (set "MESSAGE=Detected wim version is not Windows 8.1"&goto :E_Target)
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%" /index:1 ^| find /i "Architecture"') do set arch=%%i
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%" ^| findstr "Index"') do set imgcount=%%i
for /L %%i in (1,1,!imgcount!) do (
  for /f "tokens=1* delims=: " %%a in ('dism /english /get-wiminfo /wimfile:"%target%" /index:%%i ^| findstr /b /c:"Name"') do set name%%i="%%b"
  )
set "indices=*"
)

:check
if /i "%target%"=="%SystemDrive%" (if exist "%target%\Windows\SysWOW64\*" (set arch=x64) else (set arch=x86))
for /f "tokens=6 delims=[]. " %%G in ('ver') do set winbuild=%%G
rem if %winbuild% geq 9600 goto :mainmenu
if /i "%dismroot%" neq "%windir%\system32\dism.exe" goto :mainmenu
goto :checkadk

:mainboard
if %winbuild% neq 9600 (
if /i "%target%"=="%SystemDrive%" (goto :mainmenu)
)
if "%repo%"=="" (goto :mainmenu)
if "%repo:~-1%"=="\" set "repo=%repo:~0,-1%"
if exist "%repo%\Windows8.1-Update3-%arch%\Security\*" (set "repo=%repo%\Windows8.1-Update3-%arch%") else (set "repo=%repo%\Windows8.1-%arch%")
if /i "%target%"=="%SystemDrive%" (set dismtarget=/online&set "mountdir=%target%"&set online=1) else (set dismtarget=/image:"%mountdir%")
cls
echo ============================================================
echo Running WHD-W81UI %uiv%
echo ============================================================
if %online%==1 (
net stop trustedinstaller >nul 2>&1
net stop wuauserv >nul 2>&1
DEL /F /Q %systemroot%\Logs\CBS\* >nul 2>&1
)
DEL /F /Q %systemroot%\Logs\DISM\* >nul 2>&1
if %dvd%==1 if %copytarget%==1 (
echo.
echo ============================================================
echo Copying DVD contents to work directory
echo ============================================================
robocopy "%target%" "%~dp0DVD" /E /A-:R >nul
set "target=%~dp0DVD"
)
if %online%==1 call :update
if %offline%==1 (
call :update
call :cleanupmanual
)
if %wim%==1 (
if "%indices%"=="*" set "indices="&for /L %%i in (1,1,%imgcount%) do set "indices=!indices! %%i"
call :mount "%target%"
if /i "%targetname%" neq "winre.wim" (if exist "%~dp0winre.wim" del /f /q "%~dp0winre.wim" >nul)
)
if %dvd%==1 (
if "%indices%"=="*" set "indices="&for /L %%i in (1,1,%imgcount%) do set "indices=!indices! %%i"
call :mount "%target%\sources\install.wim"
if exist "%~dp0winre.wim" del /f /q "%~dp0winre.wim" >nul
set "indices="&set imgcount=2&for /L %%i in (1,1,!imgcount!) do set "indices=!indices! %%i"
call :mount "%target%\sources\boot.wim"
xcopy /CRY "%target%\efi\microsoft\boot\fonts" "%target%\boot\fonts" >nul
if %net35%==1 if exist "%target%\sources\sxs" (rmdir /s /q "%target%\sources\sxs" >nul)
)
goto :fin

:update
set verb=1
if not "%1"=="" (
set "mountdir_b=%mountdir%"
set "mountdir=%winremount%"
set dismtarget=/image:"%winremount%"
set verb=0
)
if %online%==1 (
for /f "skip=2 tokens=3 delims= " %%i in ('%_reg% query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID') do set CEdition=%%i
) else if not exist "%mountdir%\sources\recovery\RecEnv.exe" (
%_reg% load HKLM\OFFSOFT "%mountdir%\Windows\System32\config\SOFTWARE" >nul
for /f "skip=2 tokens=3 delims= " %%i in ('%_reg% query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID') do set CEdition=%%i
%_reg% unload HKLM\OFFSOFT >nul
)
set allcount=0
set GDR=0
set winpe=0
if exist "%mountdir%\sources\recovery\RecEnv.exe" (
call :ssu
call :baseline
call :security
call :winpe
goto :eof
)
call :ssu
call :baseline
call :general
call :online
if %net35%==1 call :enablenet35
call :net35
if /i %WMF% equ ON call :wmf
if /i %Hotfix% equ ON call :hotfix
if /i %WUSatisfy% equ ON call :wusatisfy
if /i %RSAT% equ ON call :rsat
if /i %Windows10% equ ON call :windows10
rem if /i %Windows10% equ ON if /i %win10u% equ ON call :win10u
call :security
goto :eof

:ssu
if %online%==1 if exist "%windir%\winsxs\pending.xml" (goto :stacklimit)
call :cleaner
cd Baseline\
set package=%ssu2%&call :ssu2
set package=%ssu1%&call :ssu2
goto :eof

:ssu2
if not exist "%repo%\Baseline\*%package%*%arch%.msu" goto :eof
if exist "%mountdir%\Windows\servicing\packages\package_for_%package%_rtm*6.3*.mum" goto :eof
if /i %package%==%ssu2% if not exist "%mountdir%\Windows\servicing\packages\package_for_KB2919355_rtm*6.3*.mum" goto :eof
if /i %package%==%ssu2% if not exist "%mountdir%\Windows\servicing\packages\package_for_KB2975061_rtm*6.3*.mum" if not exist "%mountdir%\Windows\servicing\packages\package_for_%ssu1%_rtm*6.3*.mum" goto :eof
if /i %package%==%ssu1% if exist "%mountdir%\Windows\servicing\packages\package_for_%ssu2%_rtm*6.3*.mum" goto :eof
if %verb%==1 (
echo.
echo ============================================================
echo *** Servicing Stack Update ***
echo ============================================================
)
set "dest=%cab_dir%\%package%"
if not exist "%dest%\*.manifest" (
expand.exe -f:*Windows*.cab "*%package%*%arch%.msu" "%cab_dir%" >nul
mkdir "%dest%"
expand.exe -f:* "%cab_dir%\*%package%*.cab" "%dest%" 1>nul 2>nul || ("%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:"%cab_dir%"&del /f /q "%cab_dir%\*%package%*.cab"&goto :eof)
)
"%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:"%dest%\update.mum"
goto :eof

:baseline
if not exist "%repo%\Baseline\*%arch%*.msu" goto :eof
call :cleaner
if %verb%==1 (
echo.
echo ============================================================
echo *** Baseline Updates ***
echo ============================================================
)
cd Baseline\
if %verb%==1 (
echo.
echo ============================================================
echo Checking and Extracting Applicable Updates
echo *** This will require some disk space, please be patient ***
echo ============================================================
echo.
)
set ldr=
for %%G in %baselinelist% do (set package=%%G&call :baseline2)
if defined ldr (
if %verb%==1 (
echo.
echo ============================================================
echo Installing %count% Baseline Updates
echo ============================================================
)
"%dismroot%" %dismtarget% /NoRestart /Add-Package %ldr%
)
goto :eof

:baseline2
if exist "%mountdir%\Windows\servicing\packages\package_for_%package%_rtm*6.3*.mum" goto :eof
if /i %package%==KB3003057 if exist "%mountdir%\sources\recovery\RecEnv.exe" goto :eof
if /i %package%==KB3014442 if exist "%mountdir%\sources\recovery\RecEnv.exe" goto :eof
if not exist "*%package%*%arch%*" if not exist "RTM\*%package%*%arch%*" goto :eof
set /a count+=1
set "dest=%cab_dir%\%package%"
if not exist "%dest%\*.manifest" (
echo %count%: %package%
if /i %package%==KB2938772 (
  copy /y RTM\*%package%*%arch%.cab "%cab_dir%" >nul
  ) else (
  for /f "delims=" %%i in ('dir /b /s /a:-d "*%package%*%arch%.msu"') do expand.exe -f:*Windows*.cab "%%i" "%cab_dir%" >nul
  )
mkdir "%dest%"
expand.exe -f:* "%cab_dir%\*%package%*.cab" "%dest%" 1>nul 2>nul || (
  for /f "delims=" %%i in ('dir /b "%cab_dir%\*%package%*.cab"') do set "ldr=!ldr! /packagepath:%cab_dir%\%%i"
  goto :eof
  )
)
set "ldr=!ldr! /packagepath:%dest%\update.mum"
if %online%==1 if /i %package%==KB2919355 (
"%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:%dest%\update.mum
goto :cumulativelimit
)
if %online%==1 if /i %package%==KB3000850 (
"%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:%dest%\update.mum
goto :cumulativelimit
)
goto :eof

:general
if not exist "%repo%\General\*.msu" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** General Updates ***
echo ============================================================
cd General\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=General Updates
goto :listdone

:security
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Security\*.msu" goto :eof
call :cleaner
if %verb%==1 (
echo.
echo ============================================================
echo *** Security Updates ***
echo ============================================================
)
cd Security\
if /i "%CEdition%" equ "ProfessionalWMC" if exist "ProWMC\*%arch%*.msu" (expand.exe -f:*Windows*.cab ProWMC\*%arch%*.msu .\ >nul)
call :counter
call :cab
if exist "%repo%\Security\*.cab" (del "%repo%\Security\*.cab" >nul)
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=Security Updates
goto :listdone

:net35
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Additional\NET35\*.msu" goto :eof
if not exist "%mountdir%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** .NET 3.5 Updates ***
echo ============================================================
cd Additional\NET35\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=.NET 3.5 Updates
goto :listdone

:hotfix
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Hotfix\*.msu" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** Hotfixes ***
echo ============================================================
cd Hotfix\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=Hotfixes
goto :listdone

:wusatisfy
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Additional\WU.Satisfy\*.msu" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** WU Satisfy Updates ***
echo ============================================================
set GDR=1
if /i %LDRbranch% equ ON if exist "%mountdir%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" (for %%G in %gdrlist% do expand.exe -f:*Windows*.cab Additional\NET35\*%%G*%arch%.msu Additional\WU.Satisfy\ 1>nul 2>nul)
cd Additional\WU.Satisfy\
if /i "%CEdition%" equ "ProfessionalWMC" if exist "ProfessionalWMC\*%arch%*.msu" (expand.exe -f:*Windows*.cab ProfessionalWMC\*%arch%*.msu .\ >nul)
call :counter
call :cab
if exist "%repo%\Additional\WU.Satisfy\*.cab" (del "%repo%\Additional\WU.Satisfy\*.cab" >nul)
if %_sum% equ 0 set GDR=0&goto :eof
call :mum
set GDR=0
if %_sum% equ 0 goto :eof
set cat=WU Satisfy Updates
goto :listdone

:windows10
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Additional\Windows10\*.msu" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** Windows10/Telemetry Updates ***
echo ============================================================
cd Additional\Windows10\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=Win10/Tel Updates
goto :listdone

:wmf
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
if not exist "%repo%\Additional\WMF\*.msu" goto :eof
if not exist "%mountdir%\Windows\Microsoft.NET\Framework\v4.0.30319\ngen.exe" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** WMF Updates ***
echo ============================================================
cd Additional\WMF\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=WMF Updates
goto :listdone

:winpe
if not exist "%repo%\Additional\WinPE\*Windows*%arch%*" goto :eof
call :cleaner
if %verb%==1 (
echo.
echo ============================================================
echo *** WinPE Updates ***
echo ============================================================
)
set winpe=1
mkdir "%cab_dir%\WinPE" 1>nul 2>nul
if exist "%mountdir%\sources\setup.exe" if exist "Additional\WinPE\*%arch%*.cab" copy /y Additional\WinPE\*%arch%*.cab "%cab_dir%\WinPE\" >nul
if exist "Additional\WinPE\*%arch%*.msu" copy /y Additional\WinPE\*%arch%*.msu "%cab_dir%\WinPE\" >nul
if exist "General\*KB3084905*%arch%*.msu" copy /y General\*KB3084905*%arch%*.msu "%cab_dir%\WinPE\" >nul
if exist "General\*KB3115224*%arch%*.msu" copy /y General\*KB3115224*%arch%*.msu "%cab_dir%\WinPE\" >nul
cd /d "%cab_dir%\WinPE"
call :counter
call :cab
if %_sum% equ 0 set winpe=0&goto :eof
call :mum
set winpe=0
rd /s /q "%cab_dir%\WinPE" 1>nul 2>nul
if %_sum% equ 0 goto :eof
set cat=WinPE Updates
goto :listdone

:rsat
if %online%==1 if %allcount% geq %onlinelimit% (goto :countlimit)
call :cleaner
if exist "%mountdir%\Windows\servicing\packages\*RemoteServerAdministrationTools*.mum" (
call :rsatu
goto :eof
)
if not exist "%repo%\Extra\RSAT\*.msu" goto :eof
echo.
echo ============================================================
echo *** RSAT KB2693643 ***
echo ============================================================
cd Extra\RSAT\
expand.exe -f:*Windows*.cab *%arch%*.msu "%cab_dir%" >nul
"%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:"%cab_dir%"
del /f /q "%cab_dir%\*KB2693643*.cab"
call :rsatu
goto :eof

:rsatu
if not exist "%repo%\Extra\RSAT\Updates\*.msu" goto :eof
echo.
echo ============================================================
echo *** RSAT Updates ***
echo ============================================================
cd /d "%repo%"
cd Extra\RSAT\Updates\
call :counter
call :cab
if %_sum% equ 0 goto :eof
call :mum
if %_sum% equ 0 goto :eof
set cat=RSAT Updates
goto :listdone

:online
if not exist "%repo%\Additional\Do.Not.Integrate\*.msu" goto :eof
call :cleaner
echo.
echo ============================================================
echo *** Online Updates ***
echo ============================================================
cd Additional\Do.Not.Integrate\
for /f %%G in ('dir /b *%arch%*.msu') do (set package=%%G&call :online2)
goto :eof

:online2
for /f "tokens=2 delims=-" %%V in ('dir /b %package%') do set kb=%%V
if exist "%mountdir%\Windows\servicing\packages\package_for_%kb%_rtm*6.3*.mum" goto :eof
if %online%==1 (
%package% /quiet /norestart
)
if /i %kb%==KB2990967 if %online%==0 (
%_reg% load HKLM\OFFUSR "%mountdir%\Users\Default\ntuser.dat" >nul
%_reg% add HKLM\OFFUSR\Software\Microsoft\Skydrive /v EnableTeamTier /t REG_DWORD /d 1 /f >nul
%_reg% unload HKLM\OFFUSR >nul
)
expand.exe -f:*Windows*.cab %package% "%cab_dir%" >nul
"%dismroot%" %dismtarget% /NoRestart /Add-Package /packagepath:"%cab_dir%"
del /f /q "%cab_dir%\*%kb%*.cab"
goto :eof

:enablenet35
if exist "%mountdir%\sources\recovery\RecEnv.exe" goto :eof
if exist "%mountdir%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" goto :eof
call :cleaner
if not defined net35source (
for %%b in (D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do if exist "%%b:\sources\sxs\msil_microsoft.build.engine*3.5.9600.16384*" set "net35source=%%b:\sources\sxs"
if %dvd%==1 if exist "%target%\sources\sxs\msil_microsoft.build.engine*3.5.9600.16384*" (set "net35source=%target%\sources\sxs")
if %wim%==1 for %%i in ("%target%") do if exist "%%~dpisxs\msil_microsoft.build.engine*3.5.9600.16384*" set "net35source=%%~dpisxs"
)
if not defined net35source goto :eof
if not exist "%net35source%" goto :eof
echo.
echo ============================================================
echo *** .NET 3.5 Feature ***
echo ============================================================
"%dismroot%" %dismtarget% /NoRestart /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"%net35source%"
goto :eof

rem ##################################################################

:cab
if %verb%==1 (
echo.
echo ============================================================
echo Checking Applicable Updates
echo ============================================================
echo.
)
set count=0
if %_cab% neq 0 (set msu=0&for /f %%G in ('dir /b *%arch%*.cab') do (set package=%%G&call :cab2))
if %_msu% neq 0 (set msu=1&for /f %%G in ('dir /b *%arch%*.msu') do (set package=%%G&call :cab2))
goto :eof

:cab2
if %online%==1 if %count% equ %onlinelimit% goto :eof
for /f "tokens=2 delims=-" %%V in ('dir /b %package%') do set kb=%%V
if /i %kb%==KB917607 (if exist "%mountdir%\Windows\WinSxS\Manifests\*microsoft-windows-winhstb*6.3.9600.20470*.manifest" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB2899189 (if exist "%mountdir%\Windows\servicing\packages\*CameraCodec*6.3.9600.16453.mum" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB3191564 (if exist "%mountdir%\Windows\servicing\packages\*WinMan-WinIP*7.2.9600.16384.mum" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB3049443 (if exist "%mountdir%\Windows\servicing\packages\*WinMan-WinIP*7.2.9600.16384.mum" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB3140185 (if not exist "%mountdir%\Windows\servicing\packages\Microsoft-Windows-Anytime-Upgrade-Package*.mum" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB2894852 (if not exist "%mountdir%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB2973201 (if /i "%CEdition%" NEQ "ProfessionalWMC" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB2978742 (if /i "%CEdition%" NEQ "ProfessionalWMC" set /a _sum-=1&set /a _msu-=1&goto :eof)
if /i %kb%==KB3172729 (if %winbuild% lss 9600 set /a _sum-=1&set /a _msu-=1&goto :eof)
if exist "%mountdir%\sources\recovery\RecEnv.exe" if %winpe% equ 0 (
md "%cab_dir%\check"
if %msu% equ 1 (expand.exe -f:*Windows*.cab %package% "%cab_dir%\check" >nul) else (copy %package% "%cab_dir%\check" >nul)
expand.exe -f:update.mum "%cab_dir%\check\*.cab" "%cab_dir%\check" >nul
findstr /i /m "Package_for_RollupFix" "%cab_dir%\check\update.mum" 1>nul 2>nul || (rd /s /q "%cab_dir%\check"&set /a _sum-=1&if %msu% equ 1 (set /a _msu-=1&goto :eof) else (set /a _cab-=1&goto :eof))
rd /s /q "%cab_dir%\check"
)
set inver=0
if /i %kb%==%hv_integ_kb% if exist "%mountdir%\Windows\servicing\packages\*Hyper-V-Integration-Services*.mum" (
for /f "tokens=6,7 delims=~." %%i in ('dir /b /od "%mountdir%\Windows\servicing\packages\*Hyper-V-Integration-Services*.mum"') do set inver=%%i%%j
if !inver! GEQ !hv_integ_vr! (set /a _sum-=1&set /a _cab-=1&goto :eof)
)
set "mumcheck=package_for_%kb%_rtm*6.3*.mum"
if %GDR% equ 1 set "mumcheck=package_for_%kb%_rtm~*6.3*.mum"
set inver=0
if /i %kb%==KB2976978 if exist "%mountdir%\Windows\servicing\packages\%mumcheck%" (
for /f "tokens=6,7 delims=~." %%i in ('dir /b /od "%mountdir%\Windows\servicing\packages\%mumcheck%"') do set inver=%%i%%j
md "%cab_dir%\check"
if %msu% equ 1 (expand.exe -f:*Windows*.cab %package% "%cab_dir%\check" >nul) else (copy %package% "%cab_dir%\check" >nul)
expand.exe -f:package_for_%kb%_rtm~*.mum "%cab_dir%\check\*.cab" "%cab_dir%\check" >nul
for /f "tokens=6,7 delims=~." %%i in ('dir /b "%cab_dir%\check\package_for_%kb%_rtm*6.3*.mum"') do call set kbver=%%i%%j
rd /s /q "%cab_dir%\check"
if !inver! GEQ !kbver! (set /a _sum-=1&if %msu% equ 1 (set /a _msu-=1&goto :eof) else (set /a _cab-=1&goto :eof))
)
if /i not %kb%==KB2976978 if exist "%mountdir%\Windows\servicing\packages\%mumcheck%" (set /a _sum-=1&if %msu% equ 1 (set /a _msu-=1&goto :eof) else (set /a _cab-=1&goto :eof))
set /a count+=1
if %verb%==1 (
echo %count%: %package%
)
if %msu% equ 1 (expand.exe -f:*Windows*.cab %package% "%cab_dir%" >nul) else (copy %package% "%cab_dir%" >nul)
goto :eof

:mum
if %verb%==1 (
echo.
echo ============================================================
echo Extracting files from update cabinets ^(.cab^)
echo *** This will require some disk space, please be patient ***
echo ============================================================
echo.
)
set ldr=&set listc=0&set list=1&set AC=100&set count=0
cd /d "%cab_dir%"
for /f %%G in ('dir /b *.cab') do (call :mum2 %%G)
goto :eof

:mum2
if %listc% geq %ac% (set /a AC+=100&set /a list+=1&set ldr%list%=%ldr%&set ldr=)
set package=%1
set dest=%~n1
if not exist "%dest%" mkdir "%dest%"
set /a count+=1
set /a allcount+=1
set /a listc+=1
if not exist "%dest%\*.manifest" (
if %verb%==1 echo %count%/%_sum%: %package%
expand.exe -f:* "%package%" "%dest%" 1>nul 2>nul || (set "ldr=!ldr! /packagepath:%package%"&goto :eof)
)
if /i %LDRbranch% neq ON (set "ldr=!ldr! /packagepath:%dest%\update.mum"&goto :eof)
if %GDR% equ 1 (set "ldr=!ldr! /packagepath:%dest%\update.mum"&goto :eof)
if exist "%dest%\update-bf.mum" (set "ldr=!ldr! /packagepath:%dest%\update-bf.mum") else (set "ldr=!ldr! /packagepath:%dest%\update.mum")
if not exist "%dest%\*cablist.ini" goto :eof
expand.exe -f:* "%dest%\*.cab" "%dest%" 1>nul 2>nul || (set "ldr=!ldr! /packagepath:%package%")
del /f /q "%dest%\*cablist.ini" 1>nul 2>nul
del /f /q "%dest%\*.cab" 1>nul 2>nul
goto :eof

:listdone
if %listc% leq %ac% (set ldr%list%=%ldr%)
set lc=1

:PP
if %lc% gtr %list% goto :eof
call set ldr=%%ldr%lc%%%
set ldr%lc%=
if %verb%==1 (
echo.
echo ============================================================
echo Installing %listc% %cat%, session %lc%/%list%
echo ============================================================
)
"%dismroot%" %dismtarget% /NoRestart /Add-Package %ldr%
set /a lc+=1
if /i "%cat%" equ "Security Updates" call :diagtrack
goto :PP

:counter
set _msu=0
set _cab=0
set _sum=0
if exist "*%arch%*.msu" (for /f %%a in ('dir /b *%arch%*.msu') do (call set /a _msu+=1))
if exist "*%arch%*.cab" (for /f %%a in ('dir /b *%arch%*.cab') do (call set /a _cab+=1))
set /a _sum=%_msu%+%_cab%
goto :eof

:cleaner
cd /d "%repo%"
if %wim%==1 (
if exist "%cab_dir%\*.cab" del /f /q "%cab_dir%\*.cab" >nul
) else if %dvd%==1 (
if exist "%cab_dir%\*.cab" del /f /q "%cab_dir%\*.cab" >nul
) else (
  if exist "%cab_dir%" (
  echo.
  echo ============================================================
  echo Removing temporary extracted files...
  echo ============================================================
  rmdir /s /q "%cab_dir%" >nul
  )
)
if not exist "%cab_dir%" mkdir "%cab_dir%"
goto :eof
)
if exist "%cab_dir%" (
echo.
echo ============================================================
echo Removing temporary extracted files...
echo ============================================================
rmdir /s /q "%cab_dir%" >nul
)
if not exist "%cab_dir%" mkdir "%cab_dir%"
goto :eof

rem ##################################################################

:diagtrack
if %online%==1 (
set ksub1=SOFTWARE&set ksub2=SYSTEM
) else (
set ksub1=OFFSOFT&set ksub2=OFFSYST
%_reg% load HKLM\!ksub1! "%mountdir%\Windows\System32\config\SOFTWARE" >nul
%_reg% load HKLM\!ksub2! "%mountdir%\Windows\System32\config\SYSTEM" >nul
)
%_reg% add HKLM\%ksub1%\Policies\Microsoft\Windows\Gwx /v DisableGwx /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Policies\Microsoft\Windows\WindowsUpdate /v DisableOSUpgrade /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% delete HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade /v AllowOSUpgrade /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% delete HKLM\%ksub1%\Policies\Microsoft\Windows\DataCollection /f 1>nul 2>nul
%_reg% delete HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack /v DiagTrackAuthorization /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\IE /v CEIPEnable /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\IE /v SqmLoggerRunning /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\Reliability /v CEIPEnable /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\Reliability /v SqmLoggerRunning /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\Windows /v CEIPEnable /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\Windows /v SqmLoggerRunning /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\SQMClient\Windows /v DisableOptinExperience /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% add HKLM\%ksub2%\ControlSet001\Services\DiagTrack /v Start /t REG_DWORD /d 4 /f 1>nul 2>nul
%_reg% delete HKLM\%ksub2%\ControlSet001\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener /f 1>nul 2>nul
%_reg% delete HKLM\%ksub2%\ControlSet001\Control\WMI\AutoLogger\Diagtrack-Listener /f 1>nul 2>nul
%_reg% delete HKLM\%ksub2%\ControlSet001\Control\WMI\AutoLogger\SQMLogger /f 1>nul 2>nul
icacls "%mountdir%\ProgramData\Microsoft\Diagnosis" /grant:r *S-1-5-32-544:(OI)(CI)(IO)(F) /T /C 1>nul 2>nul
del /f /q "%mountdir%\ProgramData\Microsoft\Diagnosis\*.rbs" 1>nul 2>nul
del /f /q /s "%mountdir%\ProgramData\Microsoft\Diagnosis\ETLLogs\*" 1>nul 2>nul
if %online%==0 (
%_reg% unload HKLM\%ksub1% >nul
%_reg% unload HKLM\%ksub2% >nul
)
call :win10u
goto :eof

:win10u
if exist "%mountdir%\sources\recovery\RecEnv.exe" goto :eof
if exist "%mountdir%\Users\Public\Desktop\RunOnce_W10_Telemetry_Tasks.cmd" goto :eof
if %online%==1 (
schtasks /query /tn "\Microsoft\Windows\Application Experience\ProgramDataUpdater" 1>nul 2>nul || goto :eof
)
echo.
echo ============================================================
echo Processing Windows10/Telemetry block tweaks
echo ============================================================
if %online%==1 (
set ksub1=SOFTWARE&set ksub2=SYSTEM
) else (
set ksub1=OFFSOFT&set ksub2=OFFSYST
%_reg% load HKLM\!ksub1! "%mountdir%\Windows\System32\config\SOFTWARE" >nul
)
%_reg% delete "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser" /f 1>nul 2>nul
%_reg% add "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser" /v HaveUploadedForTarget /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% add "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\AIT" /v AITEnable /t REG_DWORD /d 0 /f 1>nul 2>nul
%_reg% delete "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /f 1>nul 2>nul
%_reg% add "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v DontRetryOnError /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% add "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v IsCensusDisabled /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% add "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v TaskEnableRun /t REG_DWORD /d 1 /f 1>nul 2>nul
%_reg% delete "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags" /v UpgradeEligible /f 1>nul 2>nul
%_reg% delete "HKLM\%ksub1%\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TelemetryController" /f 1>nul 2>nul
%_reg% delete HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack /f 1>nul 2>nul
%_reg% add HKLM\%ksub1%\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack /v DiagTrackAuthorization /t REG_DWORD /d 0 /f 1>nul 2>nul

set "T_Win=Microsoft\Windows"
set "T_App=Microsoft\Windows\Application Experience"
set "T_CEIP=Microsoft\Windows\Customer Experience Improvement Program"
(echo @echo off
echo reg.exe query "HKU\S-1-5-19" 1^>nul 2^>nul ^|^| ^(echo Run the script as administrator^&pause^&exit^)
echo reg.exe delete HKLM\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener /f
echo reg.exe delete HKLM\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\Diagtrack-Listener /f
echo reg.exe delete HKLM\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\SQMLogger /f
echo icacls "%%ProgramData%%\Microsoft\Diagnosis" /grant:r *S-1-5-32-544:^(OI^)^(CI^)^(IO^)^(F^) /T /C
echo del /f /q "%%ProgramData%%\Microsoft\Diagnosis\*.rbs"
echo del /f /q /s "%%ProgramData%%\Microsoft\Diagnosis\ETLLogs\*"
echo sc.exe config DiagTrack start= disabled
echo sc.exe stop DiagTrack
echo schtasks.exe /Change /DISABLE /TN "%T_Win%\PerfTrack\BackgroundConfigSurveyor"
echo schtasks.exe /Change /DISABLE /TN "%T_Win%\SetupSQMTask"
echo schtasks.exe /Change /DISABLE /TN "%T_CEIP%\BthSQM"
echo schtasks.exe /Change /DISABLE /TN "%T_CEIP%\Consolidator"
echo schtasks.exe /Change /DISABLE /TN "%T_CEIP%\KernelCeipTask"
echo schtasks.exe /Change /DISABLE /TN "%T_CEIP%\TelTask"
echo schtasks.exe /Change /DISABLE /TN "%T_CEIP%\UsbCeip"
echo schtasks.exe /Change /DISABLE /TN "%T_App%\AitAgent"
echo schtasks.exe /Change /DISABLE /TN "%T_App%\Microsoft Compatibility Appraiser"
echo schtasks.exe /Change /DISABLE /TN "%T_App%\ProgramDataUpdater"
echo schtasks.exe /Delete /TN "%T_Win%\PerfTrack\BackgroundConfigSurveyor" /F
echo schtasks.exe /Delete /TN "%T_Win%\SetupSQMTask" /F
echo schtasks.exe /Delete /TN "%T_CEIP%\BthSQM" /F
echo schtasks.exe /Delete /TN "%T_CEIP%\Consolidator" /F
echo schtasks.exe /Delete /TN "%T_CEIP%\KernelCeipTask" /F
echo schtasks.exe /Delete /TN "%T_CEIP%\TelTask" /F
echo schtasks.exe /Delete /TN "%T_CEIP%\UsbCeip" /F
echo schtasks.exe /Delete /TN "%T_App%\AitAgent" /F
echo schtasks.exe /Delete /TN "%T_App%\Microsoft Compatibility Appraiser" /F
echo schtasks.exe /Delete /TN "%T_App%\ProgramDataUpdater" /F
echo start /b "" cmd /c del "%%~f0"^&exit /b
)>"%cd%\W10Tel.cmd"

if %online%==1 (
1>nul 2>nul call "%cd%\W10Tel.cmd"
) else (
move /y "%cd%\W10Tel.cmd" "%mountdir%\Users\Public\Desktop\RunOnce_W10_Telemetry_Tasks.cmd" >nul
%_reg% unload HKLM\%ksub1% >nul
)
goto :eof

:stacklimit
echo ============================================================
echo *** ATTENTION ***
echo ============================================================
echo.
echo Installing servicing stack update
echo require no pending update operation.
echo.
echo please restart the system, then run the script again.
echo.
echo Press any key to Exit
pause >nul
exit

:cumulativelimit
call :cleaner
echo ============================================================
echo *** ATTENTION ***
echo ============================================================
echo.
echo Installing cumulative update %package%
echo require a system restart to complete.
echo.
echo please restart the system, then run the script again.
echo.
echo Press any key to Exit
pause >nul
exit

:countlimit
call :cleaner
echo ============================================================
echo *** ATTENTION ***
echo ============================================================
echo.
echo %onlinelimit% or more updates had been installed
echo installing further more will make the process extremely slow.
echo.
echo please restart the system, then run the script again.
echo.
echo Press any key to Exit
pause >nul
exit

rem ##################################################################

:mount
if exist "%mountdir%" rmdir /s /q "%mountdir%" >nul
if exist "%winremount%" rmdir /s /q "%winremount%" >nul
if not exist "%mountdir%" mkdir "%mountdir%"
for %%b in (%indices%) do (
echo.
echo ============================================================
echo Mounting %~nx1 - index %%b/%imgcount%
echo ============================================================
"%dismroot%" /Mount-Wim /Wimfile:%1 /Index:%%b /MountDir:"%mountdir%"
if %errorlevel% neq 0 goto :E_MOUNT
call :update
if exist "%mountdir%\sources\recovery\RecEnv.exe" (
echo.
echo ============================================================
echo Resetting WinPE image base
echo ============================================================
"%dismroot%" /Image:"%mountdir%" /Cleanup-Image /StartComponentCleanup /ResetBase
) else if not exist "%mountdir%\Windows\WinSxS\pending.xml" (
echo.
echo ============================================================
echo Resetting OS image base
echo ============================================================
"%dismroot%" /Image:"%mountdir%" /Cleanup-Image /StartComponentCleanup /ResetBase
)
call :cleanupmanual
if %dvd%==1 if exist "%mountdir%\sources\setup.exe" (
  xcopy /CDRY "%mountdir%\sources" "%target%\sources\" 1>nul 2>nul
  del /f /q "%target%\sources\background.bmp" 1>nul 2>nul
  del /f /q "%target%\sources\xmllite.dll" 1>nul 2>nul
  del /f /q "%target%\efi\microsoft\boot\*noprompt.*" >nul 2>&1
  if /i %arch%==x64 (set efifile=bootx64.efi) else (set efifile=bootia32.efi)
  rem copy /y "%mountdir%\Windows\Boot\DVD\EFI\en-US\efisys.bin" "%target%\efi\microsoft\boot\" >nul
  copy /y "%mountdir%\Windows\Boot\EFI\memtest.efi" "%target%\efi\microsoft\boot\" >nul
  copy /y "%mountdir%\Windows\Boot\EFI\bootmgfw.efi" "%target%\efi\boot\!efifile!" >nul
  copy /y "%mountdir%\Windows\Boot\EFI\bootmgr.efi" "%target%\" >nul
  copy /y "%mountdir%\Windows\Boot\PCAT\bootmgr" "%target%\" >nul
  copy /y "%mountdir%\Windows\Boot\PCAT\memtest.exe" "%target%\boot\" >nul
  copy /y "%mountdir%\setup.exe" "%target%\" >nul
)
if %dvd%==1 if not defined isover (
  if exist "%mountdir%\Windows\WinSxS\Manifests\*_microsoft-windows-rollup-version*.manifest" for /f "tokens=6,7 delims=_." %%i in ('dir /b /a:-d /od "%mountdir%\Windows\WinSxS\Manifests\*_microsoft-windows-rollup-version*.manifest"') do set isover=%%i.%%j
)
if %wim%==1 if exist "%mountdir%\sources\setup.exe" if exist "%~dp1setup.exe" (
  xcopy /CDRY "%mountdir%\sources\setup.exe" "%~dp1" 1>nul 2>nul
)
attrib -S -H -I "%mountdir%\Windows\System32\Recovery\winre.wim" 1>nul 2>nul
if %winre%==1 if exist "%mountdir%\Windows\System32\Recovery\winre.wim" if not exist "%~dp0winre.wim" (
  echo.
  echo ============================================================
  echo Updating winre.wim
  echo ============================================================
  mkdir "!winremount!"
  copy "!mountdir!\Windows\System32\Recovery\winre.wim" "%~dp0winre.wim" >nul
  "!dismroot!" /Mount-Wim /Wimfile:"%~dp0winre.wim" /Index:1 /MountDir:"!winremount!"
  if %errorlevel% neq 0 goto :E_MOUNT
  call :update winre
  "!dismroot!" /Image:"!winremount!" /Cleanup-Image /StartComponentCleanup /ResetBase
  call :cleanupmanual
  set "mountdir=!mountdir_b!"
  set dismtarget=/image:"!mountdir!"
  "!dismroot!" /Unmount-Wim /MountDir:"!winremount!" /Commit
  if !errorlevel! neq 0 goto :E_MOUNT
  "!dismroot!" /Export-Image /SourceImageFile:"%~dp0winre.wim" /SourceIndex:1 /DestinationImageFile:"%~dp0temp.wim"
  move /y "%~dp0temp.wim" "%~dp0winre.wim" >nul
)
if exist "%mountdir%\Windows\System32\Recovery\winre.wim" if exist "%~dp0winre.wim" (
echo.
echo ============================================================
echo Adding updated winre.wim
echo ============================================================
echo.
copy /y "%~dp0winre.wim" "%mountdir%\Windows\System32\Recovery"
)
echo.
echo ============================================================
echo Unmounting %~nx1 - index %%b/%imgcount%
echo ============================================================
"%dismroot%" /Unmount-Wim /MountDir:"%mountdir%" /Commit
if %errorlevel% neq 0 goto :E_MOUNT
)
cd /d "%~dp0"
echo.
echo ============================================================
echo Rebuilding %~nx1
echo ============================================================
"%dismroot%" /Export-Image /SourceImageFile:%1 /All /DestinationImageFile:"%~dp0temp.wim"
move /y "%~dp0temp.wim" %1 >nul
goto :eof

:cleanupmanual
if exist "%mountdir%\Windows\WinSxS\ManifestCache\*.bin" (
takeown /f "%mountdir%\Windows\WinSxS\ManifestCache\*.bin" /A >nul 2>&1
icacls "%mountdir%\Windows\WinSxS\ManifestCache\*.bin" /grant *S-1-5-32-544:F >nul 2>&1
del /f /q "%mountdir%\Windows\WinSxS\ManifestCache\*.bin" >nul 2>&1
)
if exist "%mountdir%\Windows\WinSxS\Temp\PendingDeletes\*" (
takeown /f "%mountdir%\Windows\WinSxS\Temp\PendingDeletes\*" /A >nul 2>&1
icacls "%mountdir%\Windows\WinSxS\Temp\PendingDeletes\*" /grant *S-1-5-32-544:F >nul 2>&1
del /f /q "%mountdir%\Windows\WinSxS\Temp\PendingDeletes\*" >nul 2>&1
)
if exist "%mountdir%\Windows\WinSxS\Temp\TransformerRollbackData\*" (
takeown /f "%mountdir%\Windows\WinSxS\Temp\TransformerRollbackData\*" /R /A >nul 2>&1
icacls "%mountdir%\Windows\WinSxS\Temp\TransformerRollbackData\*" /grant *S-1-5-32-544:F /T >nul 2>&1
del /s /f /q "%mountdir%\Windows\WinSxS\Temp\TransformerRollbackData\*" >nul 2>&1
)
if exist "%mountdir%\Windows\inf\*.log" (
del /f /q "%mountdir%\Windows\inf\*.log" >nul 2>&1
)
if exist "%mountdir%\Windows\CbsTemp\*" (
for /f %%i in ('"dir /s /b /ad %mountdir%\Windows\CbsTemp\*" 2^>nul') do (RD /S /Q %%i >nul 2>&1)
del /s /f /q "%mountdir%\Windows\CbsTemp\*" >nul 2>&1
)
goto :eof

:E_Target
echo.
echo ============================================================
echo ERROR: %MESSAGE%
echo ============================================================
echo.
echo Press any key to continue.
pause >nul
set "target=%SystemDrive%"
goto :mainmenu

:E_Repo
echo.
echo ============================================================
echo ERROR: Specified repository location is not valid
echo ============================================================
echo.
echo Press any key to continue.
pause >nul
set "repo=%~dp0Updates"
goto :mainmenu

:E_MOUNT
echo.
echo ============================================================
echo ERROR: Could not mount or unmount WIM image
echo ============================================================
echo.
echo Press any key to exit.
pause >nul
exit

:E_Admin
echo.
echo ============================================================
echo ERROR: right click on the script and 'Run as administrator'
echo ============================================================
echo.
echo Press any key to exit.
pause >nul
goto :eof

:checkadk
SET regKeyPathFound=1
SET wowRegKeyPathFound=1
REG QUERY "HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots" /v KitsRoot81 1>NUL 2>NUL || SET wowRegKeyPathFound=0
REG QUERY "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /v KitsRoot81 1>NUL 2>NUL || SET regKeyPathFound=0
if %wowRegKeyPathFound% EQU 0 (
  if %regKeyPathFound% EQU 0 (
    goto :mainmenu
  ) else (
    SET regKeyPath=HKLM\Software\Microsoft\Windows Kits\Installed Roots
  )
) else (
    SET regKeyPath=HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots
)
FOR /F "skip=2 tokens=2*" %%i IN ('REG QUERY "%regKeyPath%" /v KitsRoot81') DO (SET "KitsRoot=%%j")
SET "DandIRoot=%KitsRoot%Assessment and Deployment Kit\Deployment Tools"
SET "oscdimgroot=%DandIRoot%\%PROCESSOR_ARCHITECTURE%\Oscdimg\oscdimg.exe"
SET "dismroot=%DandIRoot%\%PROCESSOR_ARCHITECTURE%\DISM\dism.exe"
if not exist "%dismroot%" set "dismroot=%windir%\system32\dism.exe"
goto :mainmenu

:targetmenu
cls
echo ============================================================
echo Enter the path for one of supported targets:
echo - Distribution folder ^(extracted iso, copied dvd/usb^)
echo - WIM file
echo - Mounted directory, offline image drive letter
echo - Current OS / Enter %SystemDrive%
echo.
echo or just press 'Enter' to return to options menu
echo ============================================================
echo.
set /p "_pp="
if "%_pp%"=="" goto :mainmenu
if "%_pp:~-1%"=="\" set "_pp=%_pp:~0,-1%"
set dvd=0
set wim=0
set offline=0
set online=0
set copytarget=0
set "target=%_pp%"
if /i "%target%"=="%SystemDrive%" set online=1&goto :mainmenu
echo %target%| findstr /E /I "\.wim" >nul
if %errorlevel%==0 (
set wim=1
for /f %%i in ('dir /b "%target%"') do set "targetname=%%i"
) else (
if exist "%target%\sources\boot.wim" set dvd=1 
if exist "%target%\Windows\regedit.exe" set offline=1
)
if %offline%==0 if %wim%==0 if %dvd%==0 (set "MESSAGE=Specified location is not valid"&goto :E_Target)
if %offline%==1 (
dir /b "%target%\Windows\servicing\Version\6.3.9600.*" 1>nul 2>nul || (set "MESSAGE=Detected target offline image is not Windows 8.1"&goto :E_Target)
set "mountdir=%target%"
if exist "%target%\Windows\SysWOW64\*" (set arch=x64) else (set arch=x86)
)
if %dvd%==1 (
echo.
echo ============================================================
echo Please wait...
echo ============================================================
dir /b /s /adr "%target%" 1>nul 2>nul && set copytarget=1
dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:1 | find /i "Version : 6.3.9600" >nul || (set "MESSAGE=Detected install.wim version is not Windows 10"&goto :E_Target)
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:1 ^| find /i "Architecture"') do set arch=%%i
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" ^| findstr "Index"') do set imgcount=%%i
for /L %%i in (1,1,!imgcount!) do (
  for /f "tokens=1* delims=: " %%a in ('dism /english /get-wiminfo /wimfile:"%target%\sources\install.wim" /index:%%i ^| findstr /b /c:"Name"') do set name%%i="%%b"
  )
set "indices=*"
)
if %wim%==1 (
echo.
echo ============================================================
echo Please wait...
echo ============================================================
dism /english /get-wiminfo /wimfile:"%target%" /index:1 | find /i "Version : 6.3.9600" >nul || (set "MESSAGE=Detected wim file version is not Windows 8.1"&goto :E_Target)
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%" /index:1 ^| find /i "Architecture"') do set arch=%%i
for /f "tokens=2 delims=: " %%i in ('dism /english /get-wiminfo /wimfile:"%target%" ^| findstr "Index"') do set imgcount=%%i
for /L %%i in (1,1,!imgcount!) do (
  for /f "tokens=1* delims=: " %%a in ('dism /english /get-wiminfo /wimfile:"%target%" /index:%%i ^| findstr /b /c:"Name"') do set name%%i="%%b"
  )
set "indices=*"
)
goto :mainmenu

:repomenu
cls
echo ============================================================
echo Enter the location of WHD parent "Updates" folder
echo.
echo or just press 'Enter' to return to options menu
echo ============================================================
echo.
set /p "_pp="
if "%_pp%"=="" goto :mainmenu
if "%_pp:~-1%"=="\" set "_pp=%_pp:~0,-1%"
set "repo=%_pp%"
if not exist "%repo%\*" (goto :E_Repo)
goto :mainmenu

:countmenu
cls
echo ============================================================
echo Enter the updates count limit for online installation
echo.
echo or just press 'Enter' to return to options menu
echo ============================================================
echo.
set /p "_pp="
if "%_pp%"=="" goto :mainmenu
set onlinelimit=%_pp%
goto :mainmenu

:dismmenu
cls
echo ============================================================
echo Enter the full path for custom dism.exe
echo.
echo or just press 'Enter' to return to options menu
echo ============================================================
echo.
set /p "_pp="
if "%_pp%"=="" goto :mainmenu
set "dismroot=%_pp%"
if not exist "%dismroot%" (
echo not found: "%dismroot%"
pause
set "dismroot=%windir%\system32\dism.exe"
)
goto :mainmenu

:indexmenu
cls
echo ============================================================
for /L %%i in (1,1,%imgcount%) do (
echo. %%i. !name%%i!
)
echo.
echo ============================================================
echo Enter indexes numbers to update separated with space^(s^)
echo Enter * to select all indexes
echo examples: 1 3 4 or 5 1 or *
echo.
echo or just press 'Enter' to return to options menu
echo ============================================================
echo.
set /p "_pp="
if "%_pp%"=="" goto :mainmenu
if "%_pp%"=="*" set "indices=%_pp%"&goto :mainmenu
for %%i in (%_pp%) do (
if %%i gtr %imgcount% echo.&echo %%i is higher than available indexes&pause&set _pp=&goto :indexmenu
if %%i equ 0 echo.&echo 0 is not valid index&pause&set _pp=&goto :indexmenu
)
set "indices=%_pp%"
goto :mainmenu

:mainmenu
if %autostart%==1 goto :mainboard
set _pp=
cls
echo ==================================================================
echo.
if /i "%target%"=="%SystemDrive%" (
if %winbuild% neq 9600 (set "target="&echo 1. Select offline target) else (echo 1. Target   ^(%arch%^) : Current Online OS)
) else (
if /i "%target%"=="" (echo 1. Select offline target) else (echo 1. Target   ^(%arch%^) : "%target%")
)
echo.
echo 2. WHD Repository : "%repo%"
echo.
echo 3. LDR branch     : %LDRbranch%
echo 4. Hotfixes       : %Hotfix%
echo 5. WU Satisfy     : %WUSatisfy%
if /i %Windows10% equ OFF (echo 6. Windows10      : %Windows10%) else (echo 6. Windows10      : %Windows10%        / B. Block Windows10/Telemetry: %win10u%)
echo 7. WMF            : %WMF%
echo 8. RSAT           : %RSAT%
if /i "%target%" neq "%SystemDrive%" (echo.&echo D. DISM : "%dismroot%")
if /i "%target%" equ "%SystemDrive%" (echo.&echo 9. Online installation limit: %onlinelimit% updates)
if %dvd%==1 (
if %winre%==1 (echo E. Update WinRE.wim: ON) else (echo E. Update WinRE.wim: OFF)
if %imgcount% gtr 1 (if "%indices%"=="*" (echo I. Install.wim selected indexes: All ^(%imgcount%^)) else (echo I. Install.wim selected indexes: %indices%))
)
if %wim%==1 (
if %winre%==1 (echo E. Update WinRE.wim: ON) else (echo E. Update WinRE.wim: OFF)
if %imgcount% gtr 1 (if "%indices%"=="*" (echo I. Install.wim selected indexes: All ^(%imgcount%^)) else (echo I. Install.wim selected indexes: %indices%))
)
echo.
echo ==================================================================
echo 0. Start the process
echo ==================================================================
echo.
choice /c 1234567890DBEIX /n /m "Change a menu option, press 0 to start, or X to exit: "
if errorlevel 15 goto :eof
if errorlevel 14 goto :indexmenu
if errorlevel 13 (if /i %winre% equ 1 (set winre=0) else (set winre=1))&goto :mainmenu
if errorlevel 12 (if /i %win10u% equ ON (set win10u=OFF) else (set win10u=ON))&goto :mainmenu
if errorlevel 11 goto :dismmenu
if errorlevel 10 goto :mainboard
if errorlevel 9 goto :countmenu
if errorlevel 8 (if /i %RSAT% equ ON (set RSAT=OFF) else (set RSAT=ON))&goto :mainmenu
if errorlevel 7 (if /i %WMF% equ ON (set WMF=OFF) else (set WMF=ON))&goto :mainmenu
if errorlevel 6 (if /i %Windows10% equ ON (set Windows10=OFF) else (set Windows10=ON))&goto :mainmenu
if errorlevel 5 (if /i %WUSatisfy% equ ON (set WUSatisfy=OFF) else (set WUSatisfy=ON))&goto :mainmenu
if errorlevel 4 (if /i %Hotfix% equ ON (set Hotfix=OFF) else (set Hotfix=ON))&goto :mainmenu
if errorlevel 3 (if /i %LDRbranch% equ ON (set LDRbranch=OFF) else (set LDRbranch=ON))&goto :mainmenu
if errorlevel 2 goto :repomenu
if errorlevel 1 goto :targetmenu
goto :mainmenu

:ISO
if not exist "%oscdimgroot%" if not exist "%~dp0cdimage.exe" if not exist "%~dp0oscdimg.exe" goto :eof
for /f "skip=1" %%x in ('wmic os get localdatetime') do if not defined MyDate set MyDate=%%x
set isodate=%MyDate:~0,4%-%MyDate:~4,2%-%MyDate:~6,2%
if defined isover (set isofile=Win8.1_%isover%_%arch%_%isodate%.iso) else (set isofile=Win8.1_%arch%_%isodate%.iso)
if exist "%isofile%" (echo %isofile% already exist in current directory&goto :eof)
echo.
echo ============================================================
echo Creating updated ISO file...
echo ============================================================
if exist "%oscdimgroot%" (set _ff="%oscdimgroot%") else if exist "%~dp0cdimage.exe" (set _ff=cdimage.exe) else (set _ff=oscdimg.exe)
%_ff% -m -o -u2 -udfver102 -bootdata:2#p0,e,b"%target%\boot\etfsboot.com"#pEF,e,b"%target%\efi\microsoft\boot\efisys.bin" -l"%isover%u" "%target%" %isofile%
if %errorlevel% equ 0 if %delete_source% equ 1 rmdir /s /q "%target%" >nul
goto :eof

:fin
cd /d "%~dp0"
if exist "%cab_dir%" (
echo.
echo ============================================================
echo Removing temporary extracted files...
echo ============================================================
rmdir /s /q "%cab_dir%" >nul
)
if %dvd%==1 (if exist "%mountdir%" rmdir /s /q "%mountdir%" >nul)
if %wim%==1 (if exist "%mountdir%" rmdir /s /q "%mountdir%" >nul)
if exist "%winremount%" rmdir /s /q "%winremount%" >nul
if %dvd%==1 if %iso%==1 call :ISO
echo.
echo ============================================================
echo    Finished
echo ============================================================
echo.
if %online%==1 if exist "%windir%\winsxs\pending.xml" (
echo.
echo ============================================================
echo System restart is required to complete installation
echo ============================================================
echo.
)
echo.
echo Press any key to exit.
pause >nul
goto :eof
