#include <VysyxSoCFull.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/time.h>
#include "generated/autoconf.h" 
#include "sdb.h"
#include "trace.h"
#include "ftrace.h"
#include <getopt.h>
#include "difftest.h"

#define PMEM_BASE  0x80000000u
#define PMEM_SIZE  128 * 1024 * 1024 
#define MROM_BASE  0x20000000
#define MROM_SIZE  0x00001000 
#define UART_ADDR  0xa00003f8
#define RTC_ADDR   0xa0000048

static uint32_t gpr_cache[16], pc_cache, inst_cache;
static bool     commit_flag;
static int      trap_code = 0;
bool            npc_trap = false;
static uint8_t* mrom = nullptr; 

extern "C" void flash_read(uint32_t addr, uint32_t *data)    { assert(0); }
extern "C" void mrom_read(int32_t addr, int32_t *data) {    
    uint32_t idx = ((uint32_t)addr - MROM_BASE) & ~0x3u;
    if (idx >= MROM_SIZE) { assert(0);}
    *data = *(uint32_t*)(mrom + idx);
}
uint32_t        dut_gpr   (int i)                            { return gpr_cache[i]; }
uint32_t        dut_pc    (void)                             { return pc_cache; }
void            difftest_fail(void)                          { npc_trap = true; trap_code = 1; }

static uint8_t* pmem = nullptr; 

unsigned expr(char *e, bool *success);

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char str[32];
  unsigned value;
} WP;

WP* gethead(void);

const char *regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

char logbuf[128];

static VysyxSoCFull dut;
static VerilatedVcdC tfp;
static vluint64_t sim_time = 0;
static int counter =0;

static char *img_file  = nullptr;
static char *elf_file  = nullptr;
static char *diff_so_file = nullptr;

static int parse_args(int argc, char *argv[]) {
  const struct option table[] = {
    {"elf"      , required_argument, NULL, 'e'},
    {"diff"     , required_argument, NULL, 'd'},
    {0          , 0                , NULL,  0 },
  };
  int o;
  while ( (o = getopt_long(argc, argv, "-bhl:d:p:e:", table, NULL)) != -1) {
    switch (o) {
      case 'e': elf_file = optarg; break;
      case 'd': diff_so_file = optarg; break;
      case 1: img_file = optarg; return 0;
      default:
        printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
        printf("\t-b,--batch              run with batch mode\n");
        printf("\t-l,--log=FILE           output log to FILE\n");
        printf("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
        printf("\t-p,--port=PORT          run DiffTest with port PORT\n");
        printf("\n");
        exit(0);
    }
  }
  return 0;
}


extern "C" void ebreak(int a0) {
    if (npc_trap) return;
    trap_code = a0;
    npc_trap = true;
}
extern "C" void gpr_update(int idx, int val) { gpr_cache[idx] = val; }
extern "C" void commit(int pc, int inst) { pc_cache = pc; inst_cache = inst; commit_flag = true;}

static uint32_t guest_to_host(uint32_t guest_addr) {
    return guest_addr - PMEM_BASE;   
}

long init_pmem(const char* img) {
    pmem = (uint8_t*)malloc(PMEM_SIZE);
    memset(pmem, 0, PMEM_SIZE);
    FILE* fp = fopen(img, "rb");
    if (!fp) exit(1);
    size_t n = fread(pmem, 1, PMEM_SIZE, fp);
    fclose(fp);
    return (long)n;
}

static long init_mrom(const char *img) {
    mrom = (uint8_t*)malloc(MROM_SIZE);
    memset(mrom, 0, MROM_SIZE);
    FILE *fp = fopen(img, "rb");
    if (!fp) {exit(1); }
    size_t n = fread(mrom, 1, MROM_SIZE, fp);
    fclose(fp);
    return (long)n;
}

uint8_t* guest_to_host_ptr(uint32_t addr) {
    if (addr >= MROM_BASE && addr < MROM_BASE + MROM_SIZE)
        return mrom + (addr - MROM_BASE);
    return pmem + (addr - PMEM_BASE);
}

int pmem_read(int addr) {
    #ifdef CONFIG_MTRACE
        printf("Read address - 0x%x\n", addr);
    #endif
    if ((uint32_t)addr == RTC_ADDR) {
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        return 0;
    }
    if ((uint32_t)addr == RTC_ADDR+4){
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        return 0;
    } 
    if ((uint32_t)addr == UART_ADDR){ 
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        return 0;
    }
    uint32_t idx = guest_to_host((uint32_t)addr) & ~0x3u;
    if (idx >= PMEM_SIZE) {        
        return 0;
    }
    return *(uint32_t*)(pmem + idx);
}


void isa_reg_display(){
    int i = 0;
    while(i<16){
        printf("Reg %d = 0x%x\n", i, dut_gpr(i));
        i++;
    }
    return;
}

uint32_t isa_reg_str2val(const char *s, bool *success) {
  int i = 0;
  while (i<16){
    if(strcmp(regs[i], s) == 0){
      *success = true;
      return dut_gpr(i);
    }
    i++;
  }
  if(strcmp(s, "pc")==0){
    *success = true;
    return dut_pc();
  }
  *success = false;
  return 0;
}


#ifdef CONFIG_ITRACE
    static void trace_inst(uint32_t pc, uint32_t inst) {
        char *p   = logbuf;
        char *end = logbuf + sizeof(logbuf);
        uint8_t *bytes = (uint8_t *)&inst;      

        p += snprintf(p, end - p, "0x%08x:", pc);
        for (int i = 0; i < 4; i++) p += snprintf(p, end - p, " %02x", bytes[i]);
        p += snprintf(p, end - p, "   ");

        disassemble(p, end - p, pc, bytes, 4);
        iringbuf_write(logbuf);
    }
#endif

#ifdef CONFIG_FTRACE
    static void ftrace_check(uint32_t pc, uint32_t inst, uint32_t next_pc) {
        uint32_t opcode = inst & 0x7f;
        int rd  = (inst >> 7)  & 0x1f;
        int rs1 = (inst >> 15) & 0x1f;
        if      (opcode == 0x6f) ftrace_jal(pc, next_pc, rd);
        else if (opcode == 0x67) ftrace_jalr(pc, next_pc, rd, rs1);
    }
#endif

bool single_cycle() {
    
    #if defined(CONFIG_FTRACE) || defined(CONFIG_ITRACE) || defined(CONFIG_DIFFTEST)
        uint32_t cur_pc   = dut_pc();
        bool trace = !dut.reset;
        bool do_step = trace && commit_flag; 
    #endif

    #ifdef CONFIG_ITRACE
        if (trace) trace_inst(cur_pc, cur_inst);
    #endif
    
    dut.clock = 0; dut.eval();
    
    #ifdef CONFIG_WAVE
        tfp.dump(sim_time);
    #endif
    
    sim_time++;
    dut.clock = 1; dut.eval();
    
    #ifdef CONFIG_WAVE
        tfp.dump(sim_time);
    #endif
    
    sim_time++;
    counter = counter + 1;
    
    #ifdef CONFIG_DIFFTEST
        if (do_step) difftest_step(cur_pc);
        commit_flag = false;
    #endif
    #ifdef CONFIG_FTRACE
        if (trace) ftrace_check(cur_pc, cur_inst, dut_pc());
    #endif
    #ifdef CONFIG_WATCHPOINT
        WP *wp = gethead();
        while (wp != NULL) {
            bool success = false;
            unsigned new_value = expr(wp->str, &success);
            if (success && wp->value != new_value) {
                printf("watchpoint %d activated\nprevious value - %u\nnew value - %u\npc - 0x%x\n",
                    wp->NO, wp->value, new_value, dut_pc());
                wp->value = new_value;
                return true;
            }
            wp = wp->next;
        }
    #endif
    
    return false;
}

void reset(int n) {
    dut.reset = 1;
    while (n-- > 0) single_cycle();
    dut.reset = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    parse_args(argc, argv);  
    if (!img_file) {
        printf("No image is given\n");
        exit(1);
    }
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    dut.trace(&tfp, 99);
    tfp.open("wave.vcd");

    long img_size = init_mrom(img_file);
    
    #ifdef CONFIG_FTRACE
        if (elf_file) init_elf(elf_file);
        else printf("No ELF file is provided\n");
    #endif
    init_sdb();
    
    #ifdef CONFIG_ITRACE
        init_disasm("riscv32-pc-linux-gnu");
    #endif 
    
    reset(100);

    #ifdef CONFIG_DIFFTEST
        if (diff_so_file) init_difftest(diff_so_file, img_size);
    #endif
    sdb_mainloop();
   
    if (trap_code == 0){
        printf("HIT GOOD TRAP\n");
    }else{
        printf("HIT BAD TRAP\n", trap_code);
        #ifdef CONFIG_ITRACE
            iringbuf_display();
        #endif
    }
    

    dut.final();
    tfp.close();
    _exit(trap_code == 0 ? 0 : 1);   
}