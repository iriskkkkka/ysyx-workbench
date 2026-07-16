#ifndef __FTRACE_H__
#define __FTRACE_H__
#include <common.h>
void init_elf(const char *elf_file);
void ftrace_jal(vaddr_t pc, vaddr_t target, int rd);
void ftrace_jalr(vaddr_t pc, vaddr_t target, int rd, int rs1);
#endif