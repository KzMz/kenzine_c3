@ECHO OFF

ECHO "Building kenzine c3..."

make -f "Makefile.engine.windows.mak" all
IF %ERRORLEVEL% NEQ 0 (echo "Build failed!")

ECHO "Building kenzine c3... DONE"

ECHO "Building kenzine c3 playground..."

make -f "Makefile.playground.windows.mak" all
IF %ERRORLEVEL% NEQ 0 (echo "Build failed!")

ECHO "Build successful!"