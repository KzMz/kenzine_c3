@ECHO OFF

ECHO "Building kenzine c3..."

make -f "Makefile.full.web.mak" all
IF %ERRORLEVEL% NEQ 0 (echo "Build failed!")

ECHO "Building kenzine c3... DONE"

ECHO "Build successful!"