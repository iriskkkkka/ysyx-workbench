sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!

TOPNAME = top
INC_PATH ?= $(abspath ./csrc/sdb ./csrc/utils ./csrc/include)
VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build --trace -cc  \
				-O3 --x-assign fast --x-initial fast --noassert

BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

Q         := @
KCONFIG   := Kconfig
CONF_FILE := .config
AUTOCONF  := $(abspath csrc/include/generated/autoconf.h)

-include $(CONF_FILE)

default: $(BIN)

$(shell mkdir -p $(BUILD_DIR))

# project source
VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
CSRCS += $(SRC_AUTO_BIND)

ifneq ($(CONFIG_ITRACE),)
  LLVM_CONFIG ?= llvm-config
  LLVM_CXXFLAGS := $(filter-out -D__STDC_FORMAT_MACROS,$(shell $(LLVM_CONFIG) --cxxflags))
  CXXFLAGS += $(LLVM_CXXFLAGS) -fPIC
  LDFLAGS  += $(shell $(LLVM_CONFIG) --ldflags --libs --system-libs)
else
  CSRCS := $(filter-out %/disasm.cc, $(CSRCS))
endif
ifneq ($(CONFIG_DIFFTEST),)
  LDFLAGS += -ldl
else
  CSRCS := $(filter-out %/difftest.cc, $(CSRCS))
endif

# rules for verilator
INCFLAGS  = $(addprefix -I, $(INC_PATH))
LDFLAGS += -lreadline
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

$(BIN): $(VSRCS) $(CSRCS) $(AUTOCONF)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $(VSRCS) $(CSRCS) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

$(CONF_FILE):
	$(Q)alldefconfig $(KCONFIG)

$(AUTOCONF): $(CONF_FILE) $(KCONFIG)
	$(Q)mkdir -p $(dir $@)
	$(Q)genconfig --header-path $@ $(KCONFIG)

menuconfig:
	$(Q)menuconfig $(KCONFIG)
	$(Q)$(MAKE) $(AUTOCONF)

defconfig:
	$(Q)alldefconfig $(KCONFIG)
	$(Q)$(MAKE) $(AUTOCONF)

all: default

run: $(BIN)
	@$(BIN) $(ARGS) $(IMG)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all sim run clean menuconfig defconfig

include ../Makefile