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

TOOL_PREFIX-arm32 = armv7-w64-mingw32-
TOOL_PREFIX-arm64 = aarch64-w64-mingw32-
TOOL_PREFIX-intel32 = i686-w64-mingw32-
TOOL_PREFIX-intel64 = x86_64-w64-mingw32-

TARGET_CMAKE_SYSTEM_PROCESSOR-arm32 = arm
TARGET_CMAKE_SYSTEM_PROCESSOR-arm64 = arm64
TARGET_CMAKE_SYSTEM_PROCESSOR-intel32 = i686
TARGET_CMAKE_SYSTEM_PROCESSOR-intel64 = amd64

CC := $(TOOL_PREFIX-$(TARGET_ARCH))gcc
CXX := $(TOOL_PREFIX-$(TARGET_ARCH))g++
AR := $(TOOL_PREFIX-$(TARGET_ARCH))ar
WINDRES := $(TOOL_PREFIX-$(TARGET_ARCH))windres
STRIP := $(TOOL_PREFIX-$(TARGET_ARCH))strip
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

BINARY-arm32 ?= $(PROJECT_BASENAME)_$(TARGET_ARCH)_unstripped.spi
BINARY-arm64 ?= $(PROJECT_BASENAME)_$(TARGET_ARCH)_unstripped.spha
BINARY-intel32 ?= $(PROJECT_BASENAME)_unstripped.spi
BINARY-intel64 ?= $(PROJECT_BASENAME)_unstripped.sph

BINARY = $(BINARY-$(TARGET_ARCH))

BINARY_STRIPPED-arm32 = $(PROJECT_BASENAME)_$(TARGET_ARCH).spi
BINARY_STRIPPED-arm64 = $(PROJECT_BASENAME)_$(TARGET_ARCH).spha
BINARY_STRIPPED-intel32 = $(PROJECT_BASENAME).spi
BINARY_STRIPPED-intel64 = $(PROJECT_BASENAME).sph

BINARY_STRIPPED = $(BINARY_STRIPPED-$(TARGET_ARCH))

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
		-DCMAKE_SYSTEM_PROCESSOR=$(TARGET_CMAKE_SYSTEM_PROCESSOR-$(TARGET_ARCH)) \
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
