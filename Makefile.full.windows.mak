DIR := $(subst /,\,${CURDIR})
BUILD_DIR := bin
OBJ_DIR := obj

ASSEMBLY := playground
ENGINE := engine

# Make does not offer a recursive wildcard function, so here's one:
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

SRC_FILES := $(call rwildcard,$(ASSEMBLY)/,*.c3) # Get all .c3 files
ENGINE_FILES := $(call rwildcard,$(ENGINE)/,*.c3) # Get all .c3 files
ENGINE_FILES_I := $(call rwildcard,$(ENGINE)/,*.c3i) # Get all .c3i files
DIRECTORIES := \$(ASSEMBLY)\src $(subst $(DIR),,$(shell dir $(ASSEMBLY)\src /S /AD /B | findstr /i src)) # Get all directories under src.

all: scaffold compile

scaffold: # create build directory
	@echo Scaffolding folder structure...
	-@setlocal enableextensions enabledelayedexpansion && mkdir $(addprefix $(OBJ_DIR), $(DIRECTORIES)) 2>NUL || cd .
	-@setlocal enableextensions enabledelayedexpansion && mkdir $(BUILD_DIR) 2>NUL || cd .
	@echo Done.

compile:
	c3\c3c compile $(SRC_FILES) $(ENGINE_FILES) $(ENGINE_FILES_I) --obj-out $(OBJ_DIR) --build-dir $(BUILD_DIR) --output-dir $(BUILD_DIR) -D KENZINE_IMPORT -D PLATFORM_WINDOWS -o $(ASSEMBLY) --trust=include -z "./engine/src/thirdparty/wgpu-native/libwgpu_native.dll.lib"