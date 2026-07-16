#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int count = 0;
  while (*fmt) {
    if (*fmt == '%') {
      fmt++;
      int zero_pad = 0, width = 0;
      if (*fmt == '0') { zero_pad = 1; fmt++; }     
      while (*fmt >= '0' && *fmt <= '9') {        
        width = width * 10 + (*fmt - '0');
        fmt++;
      }
      switch (*fmt) {
        case '%': putch('%'); count++; break;
        case 'c': putch((char)va_arg(ap, int)); count++; break;
        case 's': {
          char *s = va_arg(ap, char *);
          while (*s) { putch(*s++); count++; }
          break;
        }
        case 'd': {
          int d = va_arg(ap, int);
          char buf[12]; int i = 0, neg = 0;
          if (d < 0) { neg = 1; d = -d; }
          if (d == 0) buf[i++] = '0';
          while (d > 0) { buf[i++] = '0' + d % 10; d /= 10; }
          int len = i + (neg ? 1 : 0);
          if (neg) { putch('-'); count++; }
          while (len < width) { putch(zero_pad ? '0' : ' '); count++; len++; }  // pad
          while (i > 0) { putch(buf[--i]); count++; }
          break;
        }
        case 'x': {
          unsigned u = va_arg(ap, unsigned);
          char digits[9]; int n = 0;
          if (u == 0) digits[n++] = '0';
          while (u > 0) { int g = u & 0xf; digits[n++] = g < 10 ? '0'+g : 'a'+g-10; u >>= 4; }
          while (n > 0) { putch(digits[--n]); count++; }
          break;
        }
        default:
          putch('%'); count++;
          if (*fmt) { putch(*fmt); count++; }
          break;
      }
      if (*fmt) fmt++;   
    } else {
      putch(*fmt++); count++;
    }
  }
  va_end(ap);
  return count;
}

int vsprintf(char *out, const char *fmt, va_list ap) {
  panic("Not implemented");
}

int sprintf(char *out, const char *fmt, ...) {
  va_list ap;
  char *k = out;
  int d;
  char *s;

  va_start(ap, fmt);
  while (*fmt) {
    if (*fmt == '%') {
      fmt++;
      switch (*fmt) {
        case 's':
          s = va_arg(ap, char *);
          while (*s != '\0') {
            *k++ = *s++;
          }
          break;
        case 'd': {
          d = va_arg(ap, int);
          if (d < 0) {
            *k++ = '-';
            d = -d;
          }
          char digits[12];
          int i = 0;
          if (d == 0) digits[i++] = '0';
          while (d > 0) {
            digits[i++] = (d % 10) + '0';
            d = d / 10;
          }
          while (i > 0) {
            *k++ = digits[--i];
          }
          break;
        }
      }
      fmt++;
    } else {
      *k++ = *fmt++;
    }
  }
  *k = '\0';
  va_end(ap);
  return k - out;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  panic("Not implemented");
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  panic("Not implemented");
}

#endif
