CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")

ifeq ($(CONFIG_ITRACE),y)
  LLVM_CONFIG ?= llvm-config
  CXXFLAGS += $(shell $(LLVM_CONFIG) --cxxflags) -fPIE
  LDFLAGS  += $(shell $(LLVM_CONFIG) --libs)
else
  CSRCS := $(filter-out %/disasm.cc, $(CSRCS))
endif