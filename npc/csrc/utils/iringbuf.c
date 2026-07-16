#include "generated/autoconf.h"

#ifdef CONFIG_ITRACE
#include <cstdio>
#include <cstring>

#define IRINGBUF_SIZE 16

static char iringbuf[IRINGBUF_SIZE][128];
static int  pos  = 0;
static bool full = false;

void iringbuf_write(const char *logbuf) {
  strncpy(iringbuf[pos], logbuf, sizeof(iringbuf[0]) - 1);
  iringbuf[pos][sizeof(iringbuf[0]) - 1] = '\0';
  pos = (pos + 1) % IRINGBUF_SIZE;
  if (pos == 0) full = true;
}

void iringbuf_display() {
  if (pos == 0 && !full) return;

  int count = full ? IRINGBUF_SIZE : pos;
  int start = full ? pos : 0;
  int last  = (pos - 1 + IRINGBUF_SIZE) % IRINGBUF_SIZE;

  printf("------ iringbuf ------\n");
  int i = start;
  for (int k = 0; k < count; k++) {
    printf("%s %s\n", (i == last) ? " --> " : "     ", iringbuf[i]);
    i = (i + 1) % IRINGBUF_SIZE;
  }
}
#endif