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

#include "sdb.h"

#define NR_WP 32

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char str[32];
  unsigned value;
} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

WP* gethead(void){
  if (head==NULL){
    printf("nothing in use\n");
    return NULL;
  }
  return head;
}

WP* new_wp(char *input, unsigned initial){
  Assert(!(free_ == NULL), "No free watchpoints left!");
  if (head == NULL){
    head = free_;
    free_ = free_->next;
    snprintf(head->str, sizeof(head->str), "%s", input);
    head->value = initial;
    head->next = NULL;
    return free_;
  } else{
    WP *tmp = head;
    while (tmp->next != NULL){
      tmp = tmp->next;
    }
    tmp->next = free_;
    snprintf((tmp->next)->str, sizeof((tmp->next)->str), "%s", input);
    (tmp->next)->value = initial;
    free_ = free_->next;
    (tmp->next)->next = NULL;
    return free_;
  }
}



void free_wp(int NO){
  WP *tmp = head;
  WP *tmp_free = free_;
  if (head == NULL){
    printf("No watchpoints in use\n");
    return;
  }

  if (head->NO == NO){
    if (tmp_free == NULL){
      free_ = head;
      head = head->next;
      (free_)->next = NULL;
      return;
    }
    while(tmp_free->next != NULL){
      tmp_free=tmp_free->next;
    }
    tmp_free->next = head;
    head = head->next;
    (tmp_free->next)->next = NULL;
    return;
  }
  while (tmp->next != NULL && tmp->next->NO != NO){
    tmp = tmp->next;
  }
  Assert(!(tmp->next == NULL), "No such watchpoint!");
  if (tmp_free == NULL){
    free_ = tmp->next;
    tmp->next = (tmp->next)->next;
    (free_)->next = NULL;
    return;
  }
  while(tmp_free->next != NULL){
    tmp_free=tmp_free->next;
  }
  tmp_free->next = tmp->next;
  tmp->next = (tmp->next)->next;
  (tmp_free->next)->next = NULL;
  return;
}
