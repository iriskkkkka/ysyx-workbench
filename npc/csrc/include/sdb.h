#ifndef SDB_H
#define SDB_H

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

void sdb_mainloop();
void init_sdb();
bool single_cycle();
void reset(int n);
int  pmem_read(int addr);
void mrom_read(int32_t addr, int32_t *data);
uint32_t isa_reg_str2val(const char *s, bool *success);
void     isa_reg_display(void);
extern bool npc_trap;

#define ARRLEN(arr) (int)(sizeof(arr) / sizeof(arr[0]))
#define Assert(cond, ...) \
  do { \
    if (!(cond)) { \
      fprintf(stderr, "" __VA_ARGS__); fprintf(stderr, "\n"); \
      assert(cond); \
    } \
  } while (0)

#ifdef __cplusplus
}
#endif

#endif