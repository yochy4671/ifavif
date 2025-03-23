#############################################
##                                         ##
##    Copyright (C) 2019-2022 Julian Uy    ##
##  https://sites.google.com/site/awertyb  ##
##                                         ##
##   See details of license at "LICENSE"   ##
##                                         ##
#############################################

TARGET_ARCH ?= intel32
USE_STABS_DEBUG ?= 0
USE_POSITION_INDEPENDENT_CODE ?= 0
USE_ARCHIVE_HAS_GIT_TAG ?= 0
ifeq (x$(TARGET_ARCH),xarm32)
TOOL_TRIPLET_PREFIX ?= armv7-w64-mingw32-
endif
ifeq (x$(TARGET_ARCH),xarm64)
TOOL_TRIPLET_PREFIX ?= aarch64-w64-mingw32-
endif
ifeq (x$(TARGET_ARCH),xintel64)
TOOL_TRIPLET_PREFIX ?= x86_64-w64-mingw32-
endif
TOOL_TRIPLET_PREFIX ?= i686-w64-mingw32-
ifeq (x$(TARGET_ARCH),xarm32)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= arm
endif
ifeq (x$(TARGET_ARCH),xarm64)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= arm64
endif
ifeq (x$(TARGET_ARCH),xintel64)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= amd64
endif
TARGET_CMAKE_SYSTEM_PROCESSOR ?= i686
CC := $(TOOL_TRIPLET_PREFIX)gcc
CXX := $(TOOL_TRIPLET_PREFIX)g++
AR := $(TOOL_TRIPLET_PREFIX)ar
WINDRES := $(TOOL_TRIPLET_PREFIX)windres
STRIP := $(TOOL_TRIPLET_PREFIX)strip
7Z := 7z
ifeq (x$(TARGET_ARCH),xintel32)
OBJECT_EXTENSION ?= .o
endif
OBJECT_EXTENSION ?= .$(TARGET_ARCH).o
DEP_EXTENSION ?= .dep.make
OPTFLAGS := -O3
ifeq (x$(TARGET_ARCH),xintel32)
OPTFLAGS += -march=core-avx2
endif
ifeq (x$(TARGET_ARCH),xintel32)
ifneq (x$(USE_STABS_DEBUG),x0)
CFLAGS += -gstabs
else
CFLAGS += -gdwarf-2
endif
else
CFLAGS += -gdwarf-2
endif

ifneq (x$(USE_POSITION_INDEPENDENT_CODE),x0)
CFLAGS += -fPIC
endif
CFLAGS += -flto
CFLAGS += -I$(DEPENDENCY_OUTPUT_DIRECTORY)/include -Wall -Wno-unused-value -Wno-format -DNDEBUG -DWIN32 -D_WIN32 -D_WINDOWS 
CFLAGS += -D_USRDLL -DMINGW_HAS_SECURE_API -DUNICODE -D_UNICODE -DNO_STRICT
CFLAGS += -MMD -MF $(patsubst %$(OBJECT_EXTENSION),%$(DEP_EXTENSION),$@)
CXXFLAGS += $(CFLAGS) -fpermissive
WINDRESFLAGS += --codepage=65001
LDFLAGS += $(OPTFLAGS) -static -static-libgcc -Wl,--kill-at -fPIC
LDFLAGS_LIB += -shared
LDLIBS +=

DEPENDENCY_SOURCE_DIRECTORY := $(abspath build-source)
DEPENDENCY_BUILD_DIRECTORY := $(abspath build-$(TARGET_ARCH))
DEPENDENCY_OUTPUT_DIRECTORY := $(abspath build-libraries)-$(TARGET_ARCH)

%$(OBJECT_EXTENSION): %.c
	@printf '\t%s %s\n' CC $<
	$(CC) -c $(CFLAGS) $(OPTFLAGS) -o $@ $<

%$(OBJECT_EXTENSION): %.cpp
	@printf '\t%s %s\n' CXX $<
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) -o $@ $<

%$(OBJECT_EXTENSION): %.rc
	@printf '\t%s %s\n' WINDRES $<
	$(WINDRES) $(WINDRESFLAGS) $< $@

PROJECT_BASENAME ?= ifavif
ifeq (x$(TARGET_ARCH),xintel32)
BINARY ?= $(PROJECT_BASENAME)_unstripped.spi
endif
ifeq (x$(TARGET_ARCH),xintel64)
BINARY ?= $(PROJECT_BASENAME)_unstripped.sph
endif
BINARY ?= $(PROJECT_BASENAME)_$(TARGET_ARCH)_unstripped.spi
ifeq (x$(TARGET_ARCH),xintel32)
BINARY_STRIPPED ?= $(PROJECT_BASENAME).spi
endif
ifeq (x$(TARGET_ARCH),xintel64)
BINARY_STRIPPED ?= $(PROJECT_BASENAME).sph
endif
BINARY_STRIPPED ?= $(PROJECT_BASENAME)_$(TARGET_ARCH).spi
ifneq (x$(USE_ARCHIVE_HAS_GIT_TAG),x0)
ARCHIVE ?= $(PROJECT_BASENAME).$(TARGET_ARCH).$(GIT_TAG).7z
endif
ARCHIVE ?= $(PROJECT_BASENAME).$(TARGET_ARCH).7z

DEPENDENCY_BUILD_DIRECTORY_LIBAVIF := $(DEPENDENCY_BUILD_DIRECTORY)/libavif

LIBAVIF_LIBS += $(DEPENDENCY_OUTPUT_DIRECTORY)/lib/libavif.a
SOURCES := extractor.c spi00in.c ifavif.rc
OBJECTS := $(SOURCES:.c=$(OBJECT_EXTENSION))
OBJECTS := $(OBJECTS:.cpp=$(OBJECT_EXTENSION))
OBJECTS := $(OBJECTS:.rc=$(OBJECT_EXTENSION))
DEPENDENCIES := $(OBJECTS:%$(OBJECT_EXTENSION)=%$(DEP_EXTENSION))
EXTERNAL_LIBS := $(LIBAVIF_LIBS)

.PHONY:: all archive clean

all: $(BINARY_STRIPPED)

archive: $(ARCHIVE)

clean::
	rm -f $(OBJECTS) $(OBJECTS_BIN) $(BINARY) $(BINARY_STRIPPED) $(ARCHIVE) $(DEPENDENCIES)
	rm -rf $(DEPENDENCY_BUILD_DIRECTORY) $(DEPENDENCY_OUTPUT_DIRECTORY)

$(DEPENDENCY_OUTPUT_DIRECTORY):
	mkdir -p $@

$(ARCHIVE): $(BINARY_STRIPPED) $(EXTRA_DIST)
	@printf '\t%s %s\n' 7Z $@
	rm -f $(ARCHIVE)
	$(7Z) a $@ $^

$(BINARY_STRIPPED): $(BINARY)
	@printf '\t%s %s\n' STRIP $@
	$(STRIP) -o $@ $^

$(BINARY): $(OBJECTS) $(EXTERNAL_LIBS)
	@printf '\t%s %s\n' LNK $@
	$(CC) $(CFLAGS) $(LDFLAGS) $(LDFLAGS_LIB) -o $@ $^ $(LDLIBS)

-include $(DEPENDENCIES)

extractor$(OBJECT_EXTENSION): $(DEPENDENCY_OUTPUT_DIRECTORY)/lib/libavif.a

DEPENDENCY_SOURCE_DIRECTORY_LIBAVIF := $(DEPENDENCY_SOURCE_DIRECTORY)/libavif

$(DEPENDENCY_OUTPUT_DIRECTORY)/lib/libavif.a: $(DEPENDENCY_SOURCE_DIRECTORY_LIBAVIF) $(DEPENDENCY_OUTPUT_DIRECTORY)
	cmake -G Ninja \
		-B $(DEPENDENCY_BUILD_DIRECTORY_LIBAVIF) \
		-S $(DEPENDENCY_SOURCE_DIRECTORY_LIBAVIF) \
		-DCMAKE_SYSTEM_NAME=Windows \
		-DCMAKE_SYSTEM_PROCESSOR=$(TARGET_CMAKE_SYSTEM_PROCESSOR) \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_RC_COMPILER=$(WINDRES) \
		-DCMAKE_INSTALL_PREFIX="$(DEPENDENCY_OUTPUT_DIRECTORY)" \
		-DCMAKE_BUILD_TYPE=Release \
		-DAVIF_CODEC_DAV1D=LOCAL \
		-DAVIF_LIBYUV=LOCAL \
		-DCROSS_FILE=$(abspath external/meson_toolchains/mingw32_$(TARGET_ARCH)_meson.ini) \
		-DBUILD_SHARED_LIBS=OFF \
		&& \
	cmake --build $(DEPENDENCY_BUILD_DIRECTORY_LIBAVIF) && \
	cmake --build $(DEPENDENCY_BUILD_DIRECTORY_LIBAVIF) --target install
