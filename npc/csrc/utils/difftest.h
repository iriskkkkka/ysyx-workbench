#ifndef __DIFFTEST_H__
#define __DIFFTEST_H__

#include "generated/autoconf.h"
#include <cstdint>
#include <cstddef>

#ifdef CONFIG_DIFFTEST

#define DIFFTEST_TO_DUT false
#define DIFFTEST_TO_REF true
void init_difftest(const char *ref_so_file, long img_size);
void difftest_step(uint32_t pc);
void difftest_skip_ref();         
uint32_t dut_gpr(int i);
uint32_t dut_pc(void);
uint8_t *guest_to_host_ptr(uint32_t guest_addr);
void     difftest_fail(void);

#endif
#endif