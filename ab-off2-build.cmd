@echo off
rem ab-off2-build.cmd - rebuild del braccio ab-off nel worktree DEDICATO H:\basalt-probe-off
rem (il CMakeLists scrive gli exe in ${CMAKE_SOURCE_DIR}/bin: con un solo worktree i due
rem bracci si sovrascrivevano lo stesso basalt.exe, acchiappato il 21-10 mattina).
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0"
set "CUDA_PATH_V13_0=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\lib\x64;C:\Program Files\CMake\bin;%PATH%"
set "NINJA=C:\Users\Matt\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe\ninja.exe"
set "TEMP=H:\basalt-probe-off\tmp"
set "TMP=%TEMP%"
mkdir "%TEMP%" 2>nul
echo == [ab-off2] configure (CUDA 13.0.2, SENZA flag) ==
cmake -S H:\basalt-probe-off -B H:\basalt-probe-off\build-off -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA%" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler" || exit /b 1
echo == [ab-off2] build ==
cmake --build H:\basalt-probe-off\build-off || exit /b 1
echo == ABBINATO OK: H:\basalt-probe-off\bin\basalt.exe e il vettore ab-off ==
