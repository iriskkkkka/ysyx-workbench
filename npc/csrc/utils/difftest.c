#include "generated/autoconf.h"
#include "difftest.h"

#ifdef CONFIG_DIFFTEST
#include <dlfcn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <assert.h>

#define PMEM_BASE  0x80000000u
#define DIFFTEST_TO_DUT false
#define DIFFTEST_TO_REF true

typedef struct {
    uint32_t gpr[32];
    uint32_t pc;
} CPU_state;

static void (*ref_difftest_memcpy)(uint32_t addr, void *buf, size_t n, bool direction) = nullptr;
static void (*ref_difftest_regcpy)(void *dut, bool direction) = nullptr;
static void (*ref_difftest_exec)(uint64_t n) = nullptr;
static void (*ref_difftest_init)(int port) = nullptr;

static bool difftest_on = false;
static bool skip_next   = false;

void init_difftest(const char *ref_so_file, long img_size) {
    void *handle = dlopen(ref_so_file, RTLD_LAZY);
    ref_difftest_memcpy = (decltype(ref_difftest_memcpy))dlsym(handle, "difftest_memcpy");
    ref_difftest_regcpy = (decltype(ref_difftest_regcpy))dlsym(handle, "difftest_regcpy");
    ref_difftest_exec   = (decltype(ref_difftest_exec))  dlsym(handle, "difftest_exec");
    ref_difftest_init   = (decltype(ref_difftest_init))  dlsym(handle, "difftest_init");
    ref_difftest_init(0);
    ref_difftest_memcpy(PMEM_BASE, guest_to_host_ptr(PMEM_BASE), img_size, DIFFTEST_TO_REF);
    CPU_state ref;
    for (int i = 0; i < 32; i++) ref.gpr[i] = dut_gpr(i);
    ref.pc = dut_pc();
    ref_difftest_regcpy(&ref, DIFFTEST_TO_REF);
    skip_next = false; 
    difftest_on = true;
}
void difftest_skip_ref() { skip_next = true; }

void difftest_step(uint32_t pc) {
    if (!difftest_on) return;
    if (skip_next) {
        skip_next = false;  
        CPU_state ref;
        for (int i = 0; i < 32; i++) ref.gpr[i] = dut_gpr(i);
        ref.pc = dut_pc();
        ref_difftest_regcpy(&ref, DIFFTEST_TO_REF);
        return;
    }
    ref_difftest_exec(1);                     
    CPU_state ref;
    ref_difftest_regcpy(&ref, DIFFTEST_TO_DUT);
    for (int i = 0; i < 32; i++) {
        if (ref.gpr[i] != dut_gpr(i)) {
            printf("Register %d mismatch, pc=0x%08x: nemu=0x%08x npc=0x%08x\n",
                   i, pc, ref.gpr[i], dut_gpr(i));
            assert(0);
        }
    }
}
#endif