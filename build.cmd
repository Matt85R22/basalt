@echo off
rem build.cmd — configure+build di Basalt su Windows (msu: VS BuildTools + CUDA 13 + CMake + Ninja)
rem Uso: build.cmd            -> configure + build completo (Release)
rem      build.cmd configure  -> solo configure
rem      build.cmd test        -> configure + build + ctest cpu
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1

rem CUDA: forza 13.4 (dopo la rimozione del 12.9 il CUDA_PATH di sistema coincide gia',
rem ma il forcing rende la build indipendente dall'ambiente)
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_PATH_V13_4=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\lib\x64;C:\Program Files\CMake\bin;%PATH%"

set "NINJA=C:\Users\Matt\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe\ninja.exe"

echo == configure ==
rem /Zc:preprocessor: CCCL di CUDA 13 lo pretende con cl.exe (senza, dec_gdn_rec.cu e mid_chain.cu
rem muoiono con C1189 "traditional preprocessor"). Il flag va a nvcc che lo passa a cl con -Xcompiler.
cmake -S "%~dp0." -B "%~dp0build" -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA%" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
if "%1"=="configure" exit /b %errorlevel%
if errorlevel 1 exit /b 1

echo == build ==
cmake --build "%~dp0build" -j
if errorlevel 1 exit /b 1

if "%1"=="test" (
  echo == ctest cpu ==
  rem -LE avx512: expert_multi_test pretende AVX512-VNNI/VBMI, sul 5800X3D non passa (limite CPU, non regressione)
  ctest --test-dir "%~dp0build" -L cpu -LE avx512 -j 8 --output-on-failure
)
echo == FATTO ==
