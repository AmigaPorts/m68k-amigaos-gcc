/* Default linker script, for normal executables */
OUTPUT_FORMAT("amiga")
OUTPUT_ARCH(m68k)
SEARCH_DIR("/opt/amiga/m68k-amigaos/lib");
SECTIONS
{
  PROVIDE(___machtype = 0x0);
  . = 0x0;
  .text :
  {
    __stext = .;
    *(.text)
    *(.text.main)
    *(.text*)
    *(_*)
    *(.rodata*)
    *(.data.rel.ro*)
    *(.gnu.linkonce.t.*)
    *(.gnu.linkonce.r.*)
    *(.gcc_except_table*)
    *(SORT_BY_NAME(.list___EH_FRAME*))
    *(SORT_BY_NAME(.list_*))
    *(.end_of_lists)
    ___datadata_relocs = .;
    __etext = .;
  }
  ___text_size = SIZEOF(.text);
  . = ALIGN(0x0);
  .data :
  {
    __sdata = .;
    *(.data)
    *(SORT_BY_NAME(.data.*))
    CONSTRUCTORS
    *(SORT_BY_NAME(.dlist___EH_FRAME_OBJECT*))
    *(SORT_BY_NAME(.dlist_*))
    *(.end_of_dlists)
    *(.data.__EH_FRAME_OBJECT__*)
    *(.gnu.linkonce.d.*)
    ___a4_init = 0x7ffe;
    __edata = .;
  }
  .bss :
  {
    __bss_start = .;
    ___a4_init2 = 0x7ffe;
    *(.bss)
    *(.bss.*)
    *(COMMON)
    __end = .;
  }
  ___data_size = SIZEOF(.data) + SIZEOF(.bss);
  ___bss_size = 0x0;
  ___bss_init_size = SIZEOF(.bss);
  .datachip :
  {
    *(.datachip)
  }
  .bsschip :
  {
    *(.bsschip)
  }
  .debug_frame :
  {
    *(.debug_frame)
  }
  .debug_info :
  {
    *(.debug_info)
  }
  .debug_abbrev :
  {
    *(.debug_abbrev)
  }
  .debugloclists :
  {
    *(.debug_loclists)
  }
  .debug_aranges :
  {
    *(.debug_aranges)
  }
  .debug_rnglists :
  {
    *(.debug_rnglists)
  }
  .debug_line :
  {
    *(.debug_line)
  }
  .debug_str :
  {
    *(.debug_str)
  }
  .debug_line_str :
  {
    *(.debug_line_str)
  }
}
