#pragma once
#include "generated/autoconf.h"

#ifdef CONFIG_ITRACE
void iringbuf_write(const char *logbuf);
void iringbuf_display(void);

extern "C" void init_disasm(const char *triple);
extern "C" void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
#endif