#include "generated/autoconf.h"    
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ftrace.h>
#include <elf.h>

#ifdef CONFIG_FTRACE
typedef struct {
  char name[64];
  uint32_t addr;
  Elf32_Word size;
} Symbol;
static Symbol *symbols = NULL;
static int symbol_count = 0;

void init_elf(const char *elf_file) {
  FILE *fp = fopen(elf_file, "rb");
  Elf32_Ehdr ehdr;
  fread(&ehdr, sizeof(Elf32_Ehdr), 1, fp);
  Elf32_Shdr *shdr = (Elf32_Shdr *)malloc(ehdr.e_shnum * sizeof(Elf32_Shdr));
  fseek(fp, ehdr.e_shoff, SEEK_SET);
  fread(shdr, sizeof(Elf32_Shdr), ehdr.e_shnum, fp);
  Elf32_Shdr *symtab = NULL, *strtab = NULL;
  for (int i = 0; i < ehdr.e_shnum; i++) {
    if (shdr[i].sh_type == SHT_SYMTAB) {
      symtab = &shdr[i];
      strtab = &shdr[symtab->sh_link];
    }
  }
  char *str = (char *)malloc(strtab->sh_size);
  fseek(fp, strtab->sh_offset, SEEK_SET);
  fread(str, strtab->sh_size, 1, fp);
  int n = symtab->sh_size / sizeof(Elf32_Sym);
  Elf32_Sym *syms = (Elf32_Sym *)malloc(symtab->sh_size);
  fseek(fp, symtab->sh_offset, SEEK_SET);
  fread(syms, sizeof(Elf32_Sym), n, fp);
  symbols = (Symbol *)malloc(n * sizeof(Symbol));
  for (int i = 0; i < n; i++) {
    if (ELF32_ST_TYPE(syms[i].st_info) == STT_FUNC) {
      strncpy(symbols[symbol_count].name, str + syms[i].st_name, sizeof(symbols[0].name) - 1);
      symbols[symbol_count].name[sizeof(symbols[0].name) - 1] = '\0';
      symbols[symbol_count].addr = syms[i].st_value;
      symbols[symbol_count].size = syms[i].st_size;
      symbol_count++;
    }
  }

  free(shdr); free(syms); free(str);
  fclose(fp);
}

static const char* find_func(uint32_t addr) {
  for (int i = 0; i < symbol_count; i++){
    if (symbols[i].addr == addr) return symbols[i].name;            
    if (symbols[i].size && addr >= symbols[i].addr
        && addr < symbols[i].addr + symbols[i].size)                 
      return symbols[i].name;
  }
  return "???";
}
static int depth = 0;

void ftrace_jal(uint32_t pc, uint32_t target, int rd) {
  if (rd != 1 && rd != 5) return;          
  printf("0x%08x:", pc);
  for (int i = 0; i < depth; i++) printf("  ");
  printf("call [%s@0x%08x]\n", find_func(target), target);
  depth++;
}

void ftrace_jalr(uint32_t pc, uint32_t target, int rd, int rs1) {
  if (rd == 0 && (rs1 == 1 || rs1 == 5)) {  
    if (depth > 0) depth--;
    printf("0x%08x:", pc);
    for (int i = 0; i < depth; i++) printf("  ");
    printf("ret  [%s]\n", find_func(pc));
  } else if (rd == 1 || rd == 5) {          
    printf("0x%08x:", pc);
    for (int i = 0; i < depth; i++) printf("  ");
    printf("call [%s@0x%08x]\n", find_func(target), target);
    depth++;
  }
}
#endif