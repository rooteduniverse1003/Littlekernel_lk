/*
 * Copyright (c) 2009 Corey Tabaka
 * Copyright (c) 2015 Intel Corporation
 * Copyright (c) 2016 Travis Geiselbrecht
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT
 */
#include <lk/asm.h>
#include <arch/x86/descriptor.h>

#define NUM_INT 0x31
#define NUM_EXC 0x14

.text

/* interrupt service routine stubs */
_isr:

.set i, 0
.rept NUM_INT

100:  /* unnamed label for start of isr stub */
.if i == 8 || (i >= 10 && i <= 14) || i == 17
    nop                     /* error code pushed by exception */
    nop                     /* 2 nops are the same length as push byte */
    pushl $i                /* interrupt number */
    jmp interrupt_common
.else
    pushl $0                /* fill in error code in iframe */
    pushl $i                /* interrupt number */
    jmp interrupt_common
.endif

.set i, i + 1
.endr

/* figure out the length of a single isr stub (usually 6 or 9 bytes) */
.set isr_stub_len, . - 100b

/* annoying, but force AS to use the same (longer) encoding of jmp for all of the stubs */
.fill 256

FUNCTION(interrupt_common)
    cld
    pushl %gs               /* save segment registers */
    pushl %fs
    pushl %es
    pushl %ds
    pusha                   /* save general purpose registers */
    movl $DATA_SELECTOR, %eax /* put known good value in segment registers */
    movl %eax, %gs
    movl %eax, %fs
    movl %eax, %es
    movl %eax, %ds

    movl %esp, %eax         /* store pointer to iframe */
    pushl %eax

    call x86_exception_handler

    popl %eax               /* drop pointer to iframe */

    popa                    /* restore general purpose registers */
    popl %ds                /* restore segment registers */
    popl %es
    popl %fs
    popl %gs
    addl $8, %esp           /* drop exception number and error code */
    iret

FUNCTION(setup_idt)
    /* setup isr stub descriptors in the idt */
    movl $_isr, %esi
    movl $_idt, %edi
    movl $NUM_INT, %ecx

.Lloop:
    movl %esi, %ebx
    movw %bx, (%edi)        /* low word in IDT(n).low */
    shrl $16, %ebx
    movw %bx, 6(%edi)       /* high word in IDT(n).high */

    addl $isr_stub_len, %esi/* index the next ISR stub */
    addl $8, %edi           /* index the next IDT entry */

    loop .Lloop

    lidt _idtr

    ret

.data

.align 8
.global _idtr
_idtr:
    .short _idt_end - _idt - 1  /* IDT limit */
    .int _idt

/* interrupt descriptor table (IDT) */
.global _idt
_idt:

.set i, 0
.rept NUM_INT-1
    .short 0                /* low 16 bits of ISR offset (_isr#i & 0FFFFh) */
    .short CODE_SELECTOR    /* selector */
    .byte  0
    .byte  0x8e             /* present, ring 0, 32-bit interrupt gate */
    .short 0                /* high 16 bits of ISR offset (_isr#i / 65536) */

.set i, i + 1
.endr

/* syscall int (ring 3) */
_idt30:
    .short 0                /* low 16 bits of ISR offset (_isr#i & 0FFFFh) */
    .short CODE_SELECTOR    /* selector */
    .byte  0
    .byte  0xee             /* present, ring 3, 32-bit interrupt gate */
    .short 0                /* high 16 bits of ISR offset (_isr#i / 65536) */

.global _idt_end
_idt_end:


