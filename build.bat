@echo off
rem Compile belote.s (+ gfx.s, game.s, ai.s, sim.s, ui.s, ui2.s, net.s, gui.s) en belote.exe avec le gcc/as/ld de MSYS2 (ucrt64)
set PATH=C:\msys64\ucrt64\bin;%PATH%
gcc -nostartfiles -nostdlib -mwindows -o belote.exe belote.s -lkernel32 -luser32 -lgdi32 -lws2_32 -Wl,-e,start
if errorlevel 1 (echo ECHEC) else (echo OK)
