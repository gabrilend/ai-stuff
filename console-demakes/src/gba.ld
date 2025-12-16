/*
 * GBA Linker Script
 * Defines memory layout for Game Boy Advance ROMs
 */

ENTRY(_start)

MEMORY
{
    rom (rx) : ORIGIN = 0x08000000, LENGTH = 32M
    ewram (rw) : ORIGIN = 0x02000000, LENGTH = 256K
    iwram (rw) : ORIGIN = 0x03000000, LENGTH = 32K
}

SECTIONS
{
    /* ROM sections */
    .text :
    {
        *(.text.start)      /* Startup code must come first */
        *(.text*)           /* All other code */
        *(.rodata*)         /* Read-only data */
        . = ALIGN(4);
    } > rom

    /* Data section (copied to RAM at startup) */
    .data :
    {
        data_ram = .;       /* Start of data in RAM */
        *(.data*)
        . = ALIGN(4);
        data_end = .;       /* End of data in RAM */
    } > iwram AT > rom
    
    data_start = LOADADDR(.data);   /* Location of data in ROM */

    /* BSS section (uninitialized data) */
    .bss :
    {
        bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        bss_end = .;
    } > iwram

    /* Stack setup */
    .stack :
    {
        . = ALIGN(4);
        . += 0x1000;        /* 4KB stack */
        stack_top = .;
        . += 0x400;         /* 1KB IRQ stack */
        irq_stack_top = .;
    } > iwram

    /* EWRAM sections (if needed) */
    .ewram :
    {
        ewram_start = .;
        /* Large data structures can go here */
        . = ALIGN(4);
        ewram_end = .;
    } > ewram

    /* Discard unnecessary sections */
    /DISCARD/ :
    {
        *(.ARM.exidx*)
        *(.ARM.extab*)
        *(.comment)
        *(.debug*)
    }
}

/* Provide some useful symbols */
_ewram_start = ORIGIN(ewram);
_ewram_end = ORIGIN(ewram) + LENGTH(ewram);
_iwram_start = ORIGIN(iwram);
_iwram_end = ORIGIN(iwram) + LENGTH(iwram);