REM compile the program and delete intermediary files
"tniasm/tniasm.exe" "src/cgol-1.1.asm" "bin/cgol-1.1.bin"
DEL tniasm.sym
DEL tniasm.tmp