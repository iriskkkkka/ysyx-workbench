#include <Vtop.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#define MEM_SIZE 4096
static uint8_t pmem[MEM_SIZE];

void init_pmem() {
    memset(pmem, 0, MEM_SIZE);

    uint32_t program[] = {
        /* 0x00 */ 0x00500093,  // addi x1, x0, 5     -> x1 = 5
        /* 0x04 */ 0x00300113,  // addi x2, x0, 3     -> x2 = 3
        /* 0x08 */ 0x002081B3,  // add  x3, x1, x2    -> x3 = 8
        /* 0x0C */ 0x00002203,  // lw   x4, 0(x0)     -> x4 = mem[0]
        /* 0x10 */ 0x01C00313,  // addi x6, x0, 28    -> x6 = 28 (= 0x1C, the landing addr)
        /* 0x14 */ 0x00030267,  // jalr x4, x6, 0     -> x5 = 0x18; PC <- 0x1C
        /* 0x18 */ 0x06300393,  // addi x7, x0, 99    -> POISON, must be SKIPPED
        /* 0x1C */ 0x02A00393,  // addi x7, x0, 42    -> x7 = 42 (landed here)
        /* 0x20 */ 0x00100073,  // ebreak     
    };

    memcpy(pmem, program, sizeof(program));
}

extern "C" int pmem_read(int addr) {
    return *(uint32_t*)(pmem + (addr & ~0x3u));  
}

extern "C" void pmem_write(int waddr, int wdata, char wmask) {
    uint32_t base = (uint32_t)waddr & ~0x3u;      
    for (int i = 0; i < 4; i++) {
        if (wmask & (1 << i)) {                   
            pmem[base + i] = (wdata >> (i * 8)) & 0xFF;          
        }
    }
}

static Vtop dut;
static VerilatedVcdC tfp;
static vluint64_t sim_time = 0;
bool npc_trap = false;  

extern "C" void ebreak() {
    if (npc_trap) return;      
    printf("ebreak\n");
    npc_trap = true;
}

static void single_cycle() {
    dut.clk = 0; dut.eval();
    tfp.dump(sim_time++);

    dut.clk = 1; dut.eval();
    tfp.dump(sim_time++);
}

static void reset(int n) {
    dut.rst = 1;
    while (n-- > 0) single_cycle();
    dut.rst = 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    dut.trace(&tfp, 99);
    tfp.open("wave.vcd");

    init_pmem();
    reset(10);

    while (!npc_trap){
        dut.instr = pmem_read(dut.addr);
        single_cycle();
    }
    dut.final();
    tfp.close();
    _exit(0);   
}