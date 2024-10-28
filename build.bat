@ECHO OFF

ECHO "Building kenzine c3..."

make -f "Makefile.full.windows.mak" all
IF %ERRORLEVEL% NEQ 0 (echo "Build failed!")

ECHO "Building kenzine c3... DONE"

ECHO "Build successful!"