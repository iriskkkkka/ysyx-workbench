#ifndef __FTRACE_H__
#define __FTRACE_H__

#include <cstdint>
#include "generated/autoconf.h"   

#ifdef CONFIG_FTRACE
void init_elf(const char *elf_file);
void ftrace_jal(uint32_t pc, uint32_t target, int rd);
void ftrace_jalr(uint32_t pc, uint32_t target, int rd, int rs1);
#endif

#endif