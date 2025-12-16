@
@ GBA Startup Code (crt0.s)
@ Sets up the ARM7 processor and calls main()
@

.section .text.start
.global _start
.arm

@ GBA ROM Header
_start:
    b       rom_header_end      @ Branch to actual start
    .fill   156, 1, 0           @ Nintendo logo area
    .ascii  "OOTDEMAKE\0\0\0"   @ Game title (12 characters)
    .ascii  "AOTE"              @ Game code (4 characters)
    .ascii  "01"                @ Maker code (2 characters)
    .byte   0x96                @ Fixed value
    .byte   0x00                @ Main unit code
    .byte   0x00                @ Device type
    .fill   7, 1, 0             @ Reserved
    .byte   0x00                @ Software version
    .byte   0x00                @ Header checksum
    .fill   2, 1, 0             @ Reserved

.align 4
rom_header_end:
    @ Set interrupt jump table
    ldr     pc, =main_start     @ Reset
    ldr     pc, =halt_loop      @ Undefined instruction
    ldr     pc, =halt_loop      @ Software interrupt
    ldr     pc, =halt_loop      @ Prefetch abort
    ldr     pc, =halt_loop      @ Data abort
    ldr     pc, =halt_loop      @ Reserved
    ldr     pc, =irq_handler    @ IRQ
    ldr     pc, =halt_loop      @ FIQ

main_start:
    @ Set up stack pointers for different modes
    
    @ Set IRQ mode stack
    mrs     r0, cpsr
    bic     r1, r0, #0x1F
    orr     r1, r1, #0x12       @ IRQ mode
    msr     cpsr, r1
    ldr     sp, =irq_stack_top
    
    @ Set system mode stack  
    bic     r1, r0, #0x1F
    orr     r1, r1, #0x1F       @ System mode
    msr     cpsr, r1
    ldr     sp, =stack_top
    
    @ Copy data section from ROM to RAM
    ldr     r0, =data_start     @ Source (ROM)
    ldr     r1, =data_ram       @ Destination (RAM)
    ldr     r2, =data_end
    sub     r2, r2, r1          @ Length
    bl      memory_copy
    
    @ Clear BSS section
    ldr     r0, =bss_start
    ldr     r1, =bss_end
    sub     r1, r1, r0          @ Length
    mov     r2, #0
    bl      memory_set
    
    @ Jump to main function
    ldr     r0, =main
    bx      r0

@ Simple memory copy function
@ r0 = source, r1 = dest, r2 = length
memory_copy:
    cmp     r2, #0
    bxeq    lr
    
copy_loop:
    ldrb    r3, [r0], #1
    strb    r3, [r1], #1
    subs    r2, r2, #1
    bne     copy_loop
    bx      lr

@ Simple memory set function  
@ r0 = address, r1 = length, r2 = value
memory_set:
    cmp     r1, #0
    bxeq    lr
    
set_loop:
    strb    r2, [r0], #1
    subs    r1, r1, #1
    bne     set_loop
    bx      lr

@ IRQ handler
irq_handler:
    @ Save registers
    stmfd   sp!, {r0-r3, r12, lr}
    
    @ Read interrupt flags and handle
    ldr     r0, =0x04000202     @ REG_IF
    ldrh    r1, [r0]
    
    @ Check for VBlank interrupt
    tst     r1, #0x0001
    beq     irq_done
    
    @ Clear VBlank flag
    mov     r2, #0x0001
    strh    r2, [r0]
    
    @ Call VBlank handler if needed
    @ (We'll keep this minimal for now)

irq_done:
    @ Restore registers and return
    ldmfd   sp!, {r0-r3, r12, lr}
    subs    pc, lr, #4

@ Infinite loop for unhandled exceptions
halt_loop:
    b       halt_loop

@ Memory layout symbols (defined by linker script)
.extern data_start
.extern data_ram  
.extern data_end
.extern bss_start
.extern bss_end
.extern stack_top
.extern irq_stack_top
