@echo off
rem ============================================================
rem  ab-13.0.2-build.cmd - A/B per jesdga (PR #14)
rem  Stesso sorgente (c5f9fa24, senza il nostro commit), stesso
rem  toolkit CUDA 13.0.2, cambia SOLO /Zc:preprocessor:
rem    ab-off = CI-di-jesdga style (traditional preprocessor)
rem    ab-on  = CI + la nostra flag
rem  Confronto greedy: greedy-ab.cmd (dopo, a GPU libera).
rem  20-10 sera, Sibilla.
rem ============================================================
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0"
set "CUDA_PATH_V13_0=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\lib\x64;C:\Program Files\CMake\bin;%PATH%"
set "NINJA=C:\Users\Matt\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe\ninja.exe"
set "TEMP=H:\basalt-probe\tmp"
set "TMP=H:\basalt-probe\tmp"
mkdir "%TEMP%" 2>nul

echo == [ab-off] configure (senza flag) ==
cmake -S H:\basalt-probe -B H:\basalt-probe\build-ab-off -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA%" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler" || exit /b 1
echo == [ab-off] build ==
cmake --build H:\basalt-probe\build-ab-off || exit /b 1

echo == [ab-on] configure (con /Zc:preprocessor) ==
cmake -S H:\basalt-probe -B H:\basalt-probe\build-ab-on -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA%" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler -Xcompiler=/Zc:preprocessor" || exit /b 1
echo == [ab-on] build ==
cmake --build H:\basalt-probe\build-ab-on || exit /b 1

echo == A/B BUILD COMPLETO: build-ab-off e build-ab-on verdi ==
dir /b H:\basalt-probe\build-ab-off\bin 2>nul
dir /b H:\basalt-probe\build-ab-on\bin 2>nul
