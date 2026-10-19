# ============================================================
#  Belote — assembleur x86-64, Windows (GNU as, syntaxe Intel, API Win32, sans CRT)
#  Build : build.bat
# ============================================================
.intel_syntax noprefix

.equ WW, 1100
.equ WH, 800
.equ NT_HELLO, 1
.equ NT_START, 2
.equ NT_BID, 3
.equ NT_PLAY, 4
.equ NT_NEXT, 5

.macro ENTER
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 168
.endm

.macro LEAVE
    add rsp, 168
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    pop rbp
    ret
.endm

.section .rdata,"dr"
c_simfile:  .asciz "sim.log"
c_sim:      .asciz "-sim"

.bss
.balign 8
g_args:     .skip 64

.text
.globl start

start:
    sub rsp, 40
    call GetCommandLineA
    mov rsi, rax
    call find_sim
    test rax, rax
    jz .Lgui
    mov rsi, rax
    call sim_main
    xor ecx, ecx
    call ExitProcess
.Lgui:
    call gui_main
    xor ecx, ecx
    call ExitProcess

# find_sim : rsi = ligne de commande -> rax = pointeur après "-sim" ou 0
find_sim:
    mov rax, rsi
1:  cmp byte ptr [rax], 0
    je 3f
    cmp byte ptr [rax], 45
    jne 2f
    cmp byte ptr [rax+1], 115
    jne 2f
    cmp byte ptr [rax+2], 105
    jne 2f
    cmp byte ptr [rax+3], 109
    jne 2f
    add rax, 4
    ret
2:  inc rax
    jmp 1b
3:  xor eax, eax
    ret

.include "gfx.s"
.include "game.s"
.include "ai.s"
.include "mc.s"
.include "sim.s"
.include "ui.s"
.include "ui2.s"
.include "net.s"
.include "gui.s"
