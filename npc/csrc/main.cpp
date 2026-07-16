#include <Vtop.h>
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

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char str[32];
  unsigned value;
} WP;
WP* gethead(void);
unsigned expr(char *e, bool *success);
const char *regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

char logbuf[128];

#define PMEM_BASE  0x80000000u
#define PMEM_SIZE  128 * 1024 * 1024   
#define UART_ADDR  0xa00003f8
#define RTC_ADDR   0xa0000048

static uint8_t* pmem = nullptr;
static uint64_t boot = 0;
static uint64_t rtc_latch = 0;
static Vtop dut;
static VerilatedVcdC tfp;
static vluint64_t sim_time = 0;
bool npc_trap = false;
static int trap_code = 0;

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


static uint64_t uptime() {
    struct timeval tv; 
    gettimeofday(&tv, nullptr);
    uint64_t now = tv.tv_sec * 1000000ULL + tv.tv_usec;
    if (boot == 0) boot = now;
    return now - boot;
}

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

extern "C" int pmem_read(int addr) {
    #ifdef CONFIG_MTRACE
        printf("Read address - 0x%x\n", addr);
    #endif
    if ((uint32_t)addr == RTC_ADDR) {
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        rtc_latch = uptime(); 
        return (uint32_t)rtc_latch&0xffffffff;
    }
    if ((uint32_t)addr == RTC_ADDR+4){
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        return (uint32_t)(rtc_latch>>32);
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

extern "C" void pmem_write(int waddr, int wdata, char wmask) {
    #ifdef CONFIG_MTRACE
        printf("Write address - 0x%x\n", waddr);
    #endif
    if ((uint32_t)waddr == UART_ADDR) { 
        #ifdef CONFIG_DIFFTEST
            difftest_skip_ref();
        #endif
        putchar(wdata & 0xff); fflush(stdout); 
        return; }
    uint32_t base = (uint32_t)guest_to_host(waddr) & ~0x3u;      
    for (int i = 0; i < 4; i++) {
        if (wmask & (1 << i)) {                   
            pmem[base + i] = (wdata >> (i * 8)) & 0xFF;          
        }
    }
}

extern "C" void ebreak(int a0) {
    if (npc_trap) return;
    trap_code = a0;
    npc_trap = true;
}

void isa_reg_display(){
    int i = 0;
    while(i<32){
        printf("Reg %d = 0x%x\n", i, dut.gpr_out[i]);
        i++;
    }
    return;
}

uint32_t isa_reg_str2val(const char *s, bool *success) {
  int i = 0;
  while (i<32){
    if(strcmp(regs[i], s) == 0){
      *success = true;
      return dut.gpr_out[i];
    }
    i++;
  }
  if(strcmp(s, "pc")==0){
    *success = true;
    return dut.pc_out;
  }
  *success = false;
  return 0;
}

uint32_t dut_gpr(int i) { return dut.gpr_out[i]; }
uint32_t dut_pc(void)   { return dut.pc_out; }
uint8_t *guest_to_host_ptr(uint32_t a) { return pmem + (a - PMEM_BASE); }
void difftest_fail(void) { npc_trap = true; trap_code = 1; }

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
    dut.instr = pmem_read(dut.addr);
    #if defined(CONFIG_FTRACE) || defined(CONFIG_ITRACE) || defined(CONFIG_DIFFTEST)
        uint32_t cur_pc   = dut.pc_out;
        uint32_t cur_inst = dut.instr;
        bool trace = !dut.rst;
    #endif
    #ifdef CONFIG_ITRACE
        if (trace) trace_inst(cur_pc, cur_inst);
    #endif
    dut.clk = 0; dut.eval();
    tfp.dump(sim_time++);
    dut.clk = 1; dut.eval();
    tfp.dump(sim_time++);

    #ifdef CONFIG_DIFFTEST
        if (trace) difftest_step(cur_pc);
    #endif
    #ifdef CONFIG_FTRACE
        if (trace) ftrace_check(cur_pc, cur_inst, dut.pc_out);
    #endif
    #ifdef CONFIG_WATCHPOINT
        WP *wp = gethead();
        while (wp != NULL) {
            bool success = false;
            unsigned new_value = expr(wp->str, &success);
            if (success && wp->value != new_value) {
                printf("watchpoint %d activated\nprevious value - %u\nnew value - %u\npc - 0x%x\n",
                    wp->NO, wp->value, new_value, dut.pc_out);
                wp->value = new_value;
                return true;
            }
            wp = wp->next;
        }
    #endif
    return false;
}

void reset(int n) {
    dut.rst = 1;
    while (n-- > 0) single_cycle();
    dut.rst = 0;
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

    long img_size = init_pmem(img_file);

    #ifdef CONFIG_FTRACE
        if (elf_file) init_elf(elf_file);
        else printf("No ELF file is provided\n");
    #endif
    init_sdb();
    
    #ifdef CONFIG_ITRACE
        init_disasm("riscv32-pc-linux-gnu");
    #endif 
    
    reset(10);

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