TARGET = $(notdir $(CURDIR)).gb
BUILDDIR = $(abspath $(CURDIR)/build)

ASM = rgbasm
LINKER = rgblink
FIX = rgbfix

ASMFLAGS = -i inc/ -i data/

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	ECHOFLAGS = -e
endif
ifeq ($(UNAME_S),Darwin)
	# ?
endif

ASM_FILES := $(wildcard src/*.asm)

SOURCES := $(ASM_FILES:.asm=.o) \

OBJS := $(foreach src,$(SOURCES), $(BUILDDIR)/$(src))


all: build

build: $(TARGET)

$(BUILDDIR)/%.o: %.asm
	@echo $(ECHOFLAGS) "[ASM]\t$<"
	@mkdir -p "$(dir $@)"
	@$(ASM) $(ASMFLAGS) -o "$@" "$<"

$(TARGET): $(OBJS)
	@echo $(ECHOFLAGS) "[LD]\t$@"
	@$(LINKER) -o "$@" $(OBJS)
	@$(FIX) -v -p 0 "$@"

clean:
	@echo Cleaning...
	@rm -rf "$(BUILDDIR)/src/"
	@rm -f "$(TARGET)"
