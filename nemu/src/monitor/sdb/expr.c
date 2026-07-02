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

#include <isa.h>

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

enum {
  TK_NOTYPE = 256, TK_HEXADECIMAL, TK_REGISTER, TK_DECIMAL, TK_EQ, TK_UEQ, TK_AND, TK_PNT
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {
  {" +", TK_NOTYPE},  
  {"0x[0-9a-f]+", TK_HEXADECIMAL},   
  {"[0-9]+u", TK_DECIMAL},
  {"\\$[a-z0-9]+", TK_REGISTER}, 
  {"\\)", ')'},
  {"\\(", '('},        
  {"\\*", '*'},         
  {"\\/", '/'},         
  {"\\+", '+'},         
  {"\\-", '-'},         
  {"==", TK_EQ},       
  {"!=", TK_UEQ},       
  {"&&", TK_AND},       
  {"\\*", TK_PNT},      
};

#define NR_REGEX ARRLEN(rules)
static regex_t re[NR_REGEX] = {};
word_t isa_reg_str2val(const char *s, bool *success);
word_t vaddr_ifetch(vaddr_t addr, int len) ;

void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[32] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;
  nr_token = 0;
  memset(tokens, 0, sizeof(tokens));
  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

       //Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
         //   i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;
        switch (rules[i].token_type) {
          case TK_NOTYPE: break;
          case TK_HEXADECIMAL:
          case TK_DECIMAL: 
          case TK_REGISTER: 
            tokens[nr_token].type = rules[i].token_type;
            int k = 0;
            while (k < substr_len){
              tokens[nr_token].str[k] = *substr_start;
              substr_start += 1;
              k += 1;
            }
            nr_token += 1;
            break;
            case '*': {
                bool ok =
                  (nr_token == 0) ||
                  tokens[nr_token-1].type == '+' || tokens[nr_token-1].type == '-' ||
                  tokens[nr_token-1].type == '*' || tokens[nr_token-1].type == '/' ||
                  tokens[nr_token-1].type == TK_PNT || tokens[nr_token-1].type == TK_NOTYPE ||
                  tokens[nr_token-1].type == TK_EQ || tokens[nr_token-1].type == TK_UEQ ||
                  tokens[nr_token-1].type == TK_AND || tokens[nr_token-1].type == '(';
                if(ok) {
                  tokens[nr_token].type = TK_PNT;

                } else{
                  tokens[nr_token].type = '*';
                }

                nr_token += 1;
                break;
            }
          default: 
            tokens[nr_token].type = rules[i].token_type;
            nr_token += 1;
        }
        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }
  return true;
}




bool check_parentheses(int a, int b){
  int is_open = 0;
  for (int i = a; i<b; i++){
    is_open += (tokens[i].type == '(') ? 1 : (tokens[i].type == ')' ? -1 : 0);
    if (is_open == 0 && i < b - 1) return false;
  }
  if (tokens[a].type=='(' && tokens[b-1].type==')' && !(is_open)){
    return true;
  } else {
    return false;
  }
}

static unsigned eval(int a, int b){
  Assert(a < b, "Expression Evalution Error");
  if (a == b-1){
    unsigned num;
    if (tokens[a].type == TK_DECIMAL){
      sscanf(&(tokens[a].str[0]), "%u", &num);
      return num;
    }else if (tokens[a].type == TK_HEXADECIMAL){
      sscanf(&(tokens[a].str[0]), "%x", &num);
      return num;
    }else if(tokens[a].type == TK_REGISTER) {
      bool success = false;
      num = isa_reg_str2val(&tokens[a].str[0+1], &success);
      Assert(success, "Provide correct register name");
      return num;
    } 
    else{
      Assert(0, "Wrong!");
    }
  }  
  else if (check_parentheses(a,b) == true){
      return eval(a+1, b-1);
  } 
  else {
      int op = 0;
      int is_open = 0;
      for (int i=a; i<b;i++){
        if (tokens[i].type == '('){
          is_open += 1;
          continue;
        } else if (tokens[i].type == ')'){
          is_open -= 1;
          continue;
        }
        if ((tokens[i].type == TK_AND)&&!(is_open)){
          op = i;
        } 
      }
      is_open = 0;
      if (op==0){
        for (int i=a; i<b;i++){
          if (tokens[i].type == '('){
            is_open += 1;
            continue;
          } else if (tokens[i].type == ')'){
            is_open -= 1;
            continue;
          }
          if ((tokens[i].type == TK_UEQ || tokens[i].type == TK_EQ)&&!(is_open)){
            op = i;
          } 
        }
      }
      is_open = 0;
      if (op==0){
        for (int i=a; i<b;i++){
          if (tokens[i].type == '('){
            is_open += 1;
            continue;
          } else if (tokens[i].type == ')'){
            is_open -= 1;
            continue;
          }
          if ((tokens[i].type == '+' || tokens[i].type == '-')&&!(is_open)){
            op = i;
          } 
        }
      }
      is_open = 0;
      if (op==0){
        for (int i=a; i<b;i++){
          if (tokens[i].type == '('){
            is_open += 1;
            continue;
          } else if (tokens[i].type == ')'){
            is_open -= 1;
            continue;
          }
          if ((tokens[i].type == '*' || tokens[i].type == '/')&&!(is_open)){
            op = i;
          } 
        }
      }
      if (op == 0){
          Assert(tokens[a].type == TK_PNT, "No meaningful operator");
          return vaddr_ifetch(eval(a+1, b), 4);
      }
      unsigned val1 = eval(a, op);
      unsigned val2 = eval(op+1, b);
      switch(tokens[op].type){
        case '+': return val1+val2;
        case '-': return val1-val2;
        case '*': return val1*val2;
        case '/': return val1/val2;
        case TK_EQ: return val1==val2;
        case TK_UEQ: return val1!=val2;
        case TK_AND: return val1&&val2;
        default: Assert(!(op==0), "No meaningful operator");  return 0;    
      }
  }
}


unsigned expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }
  /* TODO: Insert codes to evaluate the expression. */
  unsigned r = eval(0, nr_token); 
  *success = true;
  return r;
}
