ENTRY(_start)
PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
  mrom (rx)  : ORIGIN = 0x20000000, LENGTH = 4K
  sram (rwx) : ORIGIN = 0x0f000000, LENGTH = 8K
}
SECTIONS {
  .text : {
    *(entry)
    *(.text*)
  } > mrom : text
  etext = .;
  _etext = .;

  .rodata : {
    *(.rodata*)
  } > mrom

  _data_load_start = LOADADDR(.data);
  .data : {
    _data_start = .;
    *(.data*)
    _data_end = .;
  } > sram AT> mrom : data
  edata = .;
  _data = .;

  .bss : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sram

  _heap_start = ALIGN(8);
  _stack_pointer = ORIGIN(sram) + LENGTH(sram);
  _stack_top = _stack_pointer - 0x400;
  _heap_end = _stack_top;
  end = .;
  _end = .;
}