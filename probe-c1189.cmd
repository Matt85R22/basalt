@echo off
rem probe-c1189.cmd - dimostra che senza /Zc:preprocessor la build CUDA su Windows muore di C1189.
rem Usa il worktree H:\basalt-probe (main senza il nostro commit) e compila UN SOLO object.
rem 20-10 Sibilla. Dopo l'uso: git worktree remove --force H:\basalt-probe
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_PATH_V13_4=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\lib\x64;C:\Program Files\CMake\bin;%PATH%"
set "NINJA=C:\Users\Matt\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe\ninja.exe"
echo == configure (probe, senza flag) ==
cmake -S H:\basalt-probe -B H:\basalt-probe\build -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA%" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
echo == build del solo dec_gdn_rec.cu (attendiamoci C1189) ==
cmake --build H:\basalt-probe\build --target CMakeFiles/kernels.dir/src/kernels/cuda/dec_gdn_rec.cu.obj
echo exitcode=%errorlevel%
