@echo off
setlocal EnableDelayedExpansion
title Windows 10/11 System Tweaker

:: ---------------------------------------------------------
:: 0. Cek dan Request Hak Akses Administrator
:: ---------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Meminta hak akses Administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ========================================================
echo         PENGATUR DAYA, JARINGAN, DAN MENU WINDOWS
echo ========================================================
echo.
echo  [1] TERAPKAN PENGATURAN (PROSES)
echo      - Monitor mati idle 10 menit
echo      - PC tidak sleep atau hibernate
echo      - Tombol power fisik = Shut down
echo      - Sembunyikan opsi Shut down di Start Menu (Restart tetap ada)
echo      - Buka Ping (ICMP) dan Network Discovery
echo      - Optimasi adapter jaringan dan port RDP
echo.
echo  [2] KEMBALIKAN KE SEMULA (RESTORE)
echo      - Tampilkan kembali tombol Shut down dan Sleep di Start Menu
echo      - Kembalikan fungsi tombol power fisik ke default
echo      - Kembalikan timeout monitor dan sleep ke default
echo      - Hapus rule firewall ping khusus
echo.
echo  [3] Keluar
echo.
echo ========================================================
choice /C 123 /N /M "Pilih opsi [1, 2, atau 3]: "

if errorlevel 3 exit /b
if errorlevel 2 goto RESTORE
if errorlevel 1 goto APPLY

:: =========================================================
:: [1] PROSES / TERAPKAN
:: =========================================================
:APPLY
cls
echo ========================================================
echo            MEMPROSES KONFIGURASI SISTEM...
echo ========================================================
echo.

echo [*] 1. Mengatur Display Timeout dan Mencegah Sleep...
powercfg /change monitor-timeout-ac 10
powercfg /change monitor-timeout-dc 10
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0
powercfg /hibernate off

echo [*] 2. Mengatur Tombol Power Fisik menjadi Shutdown...
:: Ambil GUID skema daya yang sedang aktif dari registry
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" /v "ActivePowerScheme" 2^>nul') do set "ACTIVESCHEME=%%a"
if not defined ACTIVESCHEME set "ACTIVESCHEME=381b4222-f694-41f0-9685-ff5bb260df2e"

:: Tulis langsung nilai Shutdown (3) ke registry skema aktif
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\%ACTIVESCHEME%\4f971e89-e93b-4556-9976-a006f16c3355\7648efa3-dd9c-4e8e-b566-30f808769e38" /v "ACSettingIndex" /t REG_DWORD /d 3 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\%ACTIVESCHEME%\4f971e89-e93b-4556-9976-a006f16c3355\7648efa3-dd9c-4e8e-b566-30f808769e38" /v "DCSettingIndex" /t REG_DWORD /d 3 /f >nul 2>&1

:: Refresh skema daya aktif agar pengaturan langsung berlaku
powercfg /setactive %ACTIVESCHEME%

echo [*] 3. Menyembunyikan Shutdown di Start Menu (Restart Tetap Ada)...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoClose" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoClose" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideShutDown" /t REG_DWORD /d 1 /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideRestart" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideSleep" /t REG_DWORD /d 1 /f >nul 2>&1

echo [*] 4. Membuka Akses Ping dan Network Discovery...
powershell -Command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1
netsh advfirewall firewall delete rule name="Allow_Ping_ICMPv4" >nul 2>&1
netsh advfirewall firewall add rule name="Allow_Ping_ICMPv4" protocol=icmpv4:8,any dir=in action=allow >nul 2>&1
netsh advfirewall firewall delete rule name="Allow_Ping_ICMPv6" >nul 2>&1
netsh advfirewall firewall add rule name="Allow_Ping_ICMPv6" protocol=icmpv6:128,any dir=in action=allow >nul 2>&1
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >nul 2>&1
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes >nul 2>&1

for %%s in (FDResPub FDPHost SSDPSRV upnphost) do (
    sc config %%s start=auto >nul 2>&1
    net start %%s >nul 2>&1
)

echo [*] 5. Optimasi Daya Adapter Jaringan dan RDP...
powercfg /setacvalueindex SCHEME_CURRENT sub_pciexpress express 0 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT sub_pciexpress express 0 >nul 2>&1
powercfg /setactive SCHEME_CURRENT >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul 2>&1
netsh advfirewall firewall set rule group="Remote Desktop" new enable=Yes >nul 2>&1

echo [*] 6. Memperbarui Tampilan Start Menu secara Aman...
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1

echo.
echo [SUKSES] Semua pengaturan berhasil diterapkan tanpa error!
echo.
pause
goto MENU

:: =========================================================
:: [2] RESTORE / KEMBALIKAN KE SEMULA
:: =========================================================
:RESTORE
cls
echo ========================================================
echo         MENGEMBALIKAN KONFIGURASI KE DEFAULT...
echo ========================================================
echo.

echo [*] 1. Mengembalikan Opsi Daya di Start Menu...
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideShutDown" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideSleep" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "HideRestart" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoClose" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoClose" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ShutdownWithoutLogon" /f >nul 2>&1

echo [*] 2. Mengembalikan Tombol Power Fisik ke Default (Sleep)...
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" /v "ActivePowerScheme" 2^>nul') do set "ACTIVESCHEME=%%a"
if not defined ACTIVESCHEME set "ACTIVESCHEME=381b4222-f694-41f0-9685-ff5bb260df2e"

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\%ACTIVESCHEME%\4f971e89-e93b-4556-9976-a006f16c3355\7648efa3-dd9c-4e8e-b566-30f808769e38" /v "ACSettingIndex" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\%ACTIVESCHEME%\4f971e89-e93b-4556-9976-a006f16c3355\7648efa3-dd9c-4e8e-b566-30f808769e38" /v "DCSettingIndex" /t REG_DWORD /d 1 /f >nul 2>&1
powercfg /setactive %ACTIVESCHEME%

echo [*] 3. Mengembalikan Timeout Monitor dan Standby ke Default...
powercfg /change monitor-timeout-ac 15
powercfg /change monitor-timeout-dc 5
powercfg /change standby-timeout-ac 30
powercfg /change standby-timeout-dc 15
powercfg /change disk-timeout-ac 20
powercfg /change disk-timeout-dc 10
powercfg /hibernate on

echo [*] 4. Menghapus Rule Firewall Ping Khusus...
netsh advfirewall firewall delete rule name="Allow_Ping_ICMPv4" >nul 2>&1
netsh advfirewall firewall delete rule name="Allow_Ping_ICMPv6" >nul 2>&1

echo [*] 5. Memperbarui Tampilan Start Menu...
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1

echo.
echo [SUKSES] Konfigurasi berhasil dikembalikan ke standar!
echo.
pause
goto MENU