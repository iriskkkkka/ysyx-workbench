/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
"#include <stdio.h>\n"
"int main() { "
"  unsigned result = %s; "
"  printf(\"%%u\", result); "
"  return 0; "
"}";

static int ptr = 0;
static int symbol_counter = 0;

uint32_t choose(uint32_t a){
  uint32_t k = rand()%(a); 
  return  k;
} 

static void add_rnd_spc(){
  if (choose(2)){
    int i = choose(10);
    while (i!=0){
      buf[ptr] = ' ';
      ptr = ptr+1;
      i = i-1;
    }  
  } else{
    return;
  }
}

static void gen_rand_expr(void) {
    if (symbol_counter > 15) {          
      buf[ptr] = choose(10) + 48; 
      ptr = ptr + 1;          
      buf[ptr] = 'u'; 
      ptr = ptr + 1;
      symbol_counter = symbol_counter + 1;
      add_rnd_spc();
      return;
  }
  switch (choose(3)){
    case 0: 
      int numsize = choose(9);
      for (int i = -1; i<numsize;i++){
        buf[ptr] = choose(10)+48; 
        ptr = ptr+1;  
      }    
      if (buf[ptr-numsize-1]=='0'){
        buf[ptr-numsize-1] = choose(9)+49;
      }
      buf[ptr] = 'u'; 
      ptr = ptr + 1;
      symbol_counter = symbol_counter + 1;
      add_rnd_spc();
      break;
    case 1: 
      buf[ptr] = '('; 
      ptr = ptr+1; 
      symbol_counter = symbol_counter + 1;
      gen_rand_expr(); 
      buf[ptr] = ')'; 
      ptr = ptr+1;
      symbol_counter = symbol_counter + 1;
      add_rnd_spc();
      break; 
    default: 
      gen_rand_expr();
      switch(choose(4)){
        case 0: 
          buf[ptr] = '+'; 
          ptr = ptr+1;
          symbol_counter = symbol_counter + 1;
          add_rnd_spc();
          break;
        case 1: 
          buf[ptr] = '-'; 
          ptr = ptr+1;
          symbol_counter = symbol_counter + 1;
          add_rnd_spc();
          break;
        case 2: 
          buf[ptr] = '/'; 
          ptr = ptr+1;
          symbol_counter = symbol_counter + 1;
          add_rnd_spc();
          break;
        default: 
          buf[ptr] = '*'; 
          ptr = ptr+1;
          symbol_counter = symbol_counter + 1;
          add_rnd_spc();
      }
      gen_rand_expr();
      add_rnd_spc();
  }
  buf[ptr] = '\0';
}



int main(int argc, char *argv[]) {
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1) {
    sscanf(argv[1], "%d", &loop);
  }
  int i;
  for (i = 0; i < loop; i ++) {
    gen_rand_expr();
    if (symbol_counter>31){
      ptr = 0;
      symbol_counter = 0;
      i = i-1;
      continue;
    }
    ptr = 0;
    symbol_counter = 0;

    sprintf(code_buf, code_format, buf);

    FILE *fp = fopen("/tmp/.code.c", "w");
    assert(fp != NULL);
    fputs(code_buf, fp);
    fclose(fp);

    int ret = system("gcc -Werror /tmp/.code.c -o /tmp/.expr 2>/dev/null");
    if (ret != 0) continue;

    fp = popen("/tmp/.expr", "r");
    assert(fp != NULL);

    unsigned result;
    ret = fscanf(fp, "%u", &result);
    int pclose_ret = pclose(fp);
    if (ret != 1 || pclose_ret != 0) {
      i = i-1;
      continue;
    }
    printf("%u %s\n", result, buf);
  }
  return 0;
}
