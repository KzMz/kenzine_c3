DIR := $(subst /,\,${CURDIR})
BUILD_DIR := bin
OBJ_DIR := obj
OUTPUT_DIR := playground\web

ASSEMBLY := playground
ENGINE := engine
EMBEDS := assets\embeds

# Make does not offer a recursive wildcard function, so here's one:
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

SRC_FILES := $(call rwildcard,$(ASSEMBLY)/,*.c3) # Get all .c3 files
ENGINE_FILES := $(call rwildcard,$(ENGINE)/,*.c3) # Get all .c3 files
ENGINE_FILES_I := $(call rwildcard,$(ENGINE)/,*.c3i) # Get all .c3i files
EMBEDS_FILES := $(call rwildcard,$(EMBEDS)/,*.*) # Get all .c3 embed files
DIRECTORIES := \$(ASSEMBLY)\src $(subst $(DIR),,$(shell dir $(ASSEMBLY)\src /S /AD /B | findstr /i src)) # Get all directories under src.

WEB_FLAGS := --reloc=none --target wasm32 -g0 -O3 --link-libc=no --no-entry -z --export-table -z --allow-undefined
FLAGS := --obj-out $(OBJ_DIR) --build-dir $(BUILD_DIR) --output-dir $(OUTPUT_DIR) -D KENZINE_IMPORT -D PLATFORM_WEB

all: scaffold clear-embeds generate-embeds compile

scaffold: # create build directory
	@echo Scaffolding folder structure...
	-@setlocal enableextensions enabledelayedexpansion && mkdir $(addprefix $(OBJ_DIR), $(DIRECTORIES)) 2>NUL || cd .
	-@setlocal enableextensions enabledelayedexpansion && mkdir $(BUILD_DIR) 2>NUL || cd .
	@echo Done.

clear-embeds:
	@echo Clearing embeds...
	@if exist "$(EMBEDS)\" rmdir /S /Q $(EMBEDS)
	@echo Done.

generate-embeds:
	@echo Generating embeds...
	@mkdir $(EMBEDS)
	c3\c3c compile-run tools/embedder.c3
	@echo Done.

compile:
	c3\c3c compile $(SRC_FILES) $(ENGINE_FILES) $(ENGINE_FILES_I) $(EMBEDS_FILES) $(FLAGS) $(WEB_FLAGS) -o $(ASSEMBLY)