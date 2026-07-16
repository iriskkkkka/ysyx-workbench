#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

size_t strlen(const char *s) {
  const char *k = s;
  size_t cnt = 0;
  while (*k!='\0'){
    k = k+1;
    cnt = cnt+1;
  }
  return cnt;
}

char *strcpy(char *dst, const char *src) {
  char *dstk = dst;
  while (*src != '\0') {
    *dstk++ = *src++;
  }
  *dstk = '\0';
  return dst;
}

char *strncpy(char *dst, const char *src, size_t n) {
  const char *k = src;
  char *dstk = dst;
  for (size_t i = 0; i<n; i++){
    if (*k == '\0'){
      *dstk = '\0';
      dstk = dstk + 1;
    } else{
      *dstk = *k;
      dstk = dstk + 1;
      k = k+1;
    }
  }
  return dst;
}

char *strcat(char *dst, const char *src) {
  char *dstk = dst;
  while (*dstk != '\0') dstk++;      
  while (*src != '\0') *dstk++ = *src++;  
  *dstk = '\0';
  return dst;
}
int strcmp(const char *s1, const char *s2) {
  const char *k = s1;
  const char *k2 = s2;
  while (*k != '\0' && *k == *k2 ){
    k = k + 1;
    k2 = k2 + 1;
  }
  return (unsigned char)*k - (unsigned char)*k2;
}

int strncmp(const char *s1, const char *s2, size_t n) {
  const char *k = s1;
  const char *k2 = s2;
  for (size_t i = 0; i < n; i++){
    if (*k != '\0' && *k == *k2){
      k = k + 1;
      k2 = k2 + 1;
      continue;
    } else {
      return (unsigned char)*k - (unsigned char)*k2;
    }
  }
  return 0; 
}

void *memset(void *s, int c, size_t n) {
  unsigned char *k = s;
  unsigned char v = (unsigned char) c;
  for (size_t i = 0; i<n; i++){
    *k = v;
    k = k+1;
  }
  return s;
}

void *memmove(void *dst, const void *src, size_t n) {
    unsigned char *k = dst;
    const unsigned char *ksrc = src;
    if (k < ksrc) {
        for (size_t i = 0; i < n; i++) {
            k[i] = ksrc[i];
        }
    } else if (k > ksrc) {
        for (size_t i = n; i > 0; i--) {
            k[i - 1] = ksrc[i - 1];
        }
    }
    return dst;
}

void *memcpy(void *out, const void *in, size_t n) {
  unsigned char *k = out;
  const unsigned char *kin = in;
  for (size_t i = 0; i < n; i++) {
    *k = *kin;
    k = k+1;
    kin = kin+1;
  }
  return out;
}

int memcmp(const void *s1, const void *s2, size_t n) {
  const unsigned char *k = s1;
  const unsigned char *k2 = s2;
  for (size_t i = 0; i < n; i++) {
    if (k[i] != k2[i]) {
      return (unsigned char)k[i] - (unsigned char)k2[i];
    }
  }
  return 0;
}

#endif
