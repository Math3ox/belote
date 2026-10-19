# ============================================================
#  gui.s — fenêtre Win32, tampons de dessin, mise à l'échelle, plein écran, réglages mémorisés
# ============================================================
.section .rdata,"dr"
c_cfg:      .asciz "belote.cfg"
c_shot:     .asciz "belote_shot.bmp"
c_dbg1:     .asciz "ph "
.balign 8
g_bmiSmall: .long 40, WW, -WH
            .short 1, 32
            .long 0, WW*WH*4, 0, 0, 0, 0
g_bmiBig:   .long 40, WW*2, -WH*2
            .short 1, 32
            .long 0, WW*WH*16, 0, 0, 0, 0
g_bmphdr:   .ascii "BM"
            .long 54 + WW*WH*4, 0, 54
            .long 40, WW, -WH
            .short 1, 32
            .long 0, WW*WH*4, 0, 0, 0, 0

.data
.balign 8
g_scale:    .double 1.0
g_iscale:   .double 1.0
g_wscale:   .double 1.0

.bss
.balign 8
g_hwnd:     .skip 8
g_hinst:    .skip 8
g_wc:       .skip 80
g_msgrec:   .skip 48
g_ps:       .skip 72
g_rect:     .skip 16
g_rect2:    .skip 16
g_wrect:    .skip 16
g_sc_on:    .skip 4
g_wson:     .skip 4
g_ox:       .skip 4
g_oy:       .skip 4
g_fsmode:   .skip 4
g_erase:    .skip 4
g_cwx:      .skip 4
g_cwy:      .skip 4
g_cww:      .skip 4
g_cwh:      .skip 4
g_tmr:      .skip 4
g_optfs:    .skip 4
g_cfg:      .skip 64
g_dbgbuf:   .skip 128
g_bytes:    .skip 8
g_qpf:      .skip 8
g_rms:      .skip 4

.text
# ---------- réglages ----------
opt_load:
    ENTER
    lea rcx, [rip+c_cfg]
    mov edx, 0x80000000
    mov r8d, 1
    xor r9d, r9d
    mov dword ptr [rsp+32], 3               # OPEN_EXISTING
    mov dword ptr [rsp+40], 0x80
    mov qword ptr [rsp+48], 0
    call CreateFileA
    cmp rax, -1
    je 9f
    mov r12, rax
    mov rcx, r12
    lea rdx, [rip+g_cfg]
    mov r8d, 40
    lea r9, [rip+g_bytes]
    mov qword ptr [rsp+32], 0
    call ReadFile
    mov rcx, r12
    call CloseHandle
    lea rsi, [rip+g_cfg]
    cmp dword ptr [rsi], 0xB3107E01
    jne 9f
    mov eax, dword ptr [rsi+4]
    cmp eax, 2
    je 1f
    cmp eax, 4
    jne 9f
1:  mov dword ptr [rip+g_np], eax
    mov eax, dword ptr [rsi+8]
    cmp eax, 100
    jl 9f
    mov dword ptr [rip+g_target], eax
    mov eax, dword ptr [rsi+12]
    and eax, 1
    mov dword ptr [rip+g_optann], eax
    mov eax, dword ptr [rsi+16]
    cmp eax, 2
    ja 9f
    mov dword ptr [rip+g_botlvl], eax
    mov eax, dword ptr [rsi+20]
    mov ecx, 2
    cmp eax, 1
    jne 2f
    mov ecx, 1
2:  mov dword ptr [rip+g_S], ecx
    mov eax, dword ptr [rsi+24]
    mov dword ptr [rip+g_optfs], eax
    mov eax, dword ptr [rsi+28]
    and eax, 1
    mov dword ptr [rip+g_help], eax
    mov eax, dword ptr [rsi+32]
    mov dword ptr [rip+g_wins], eax
    mov eax, dword ptr [rsi+36]
    mov dword ptr [rip+g_wins+4], eax
9:  LEAVE

opt_save:
    ENTER
    lea rsi, [rip+g_cfg]
    mov dword ptr [rsi], 0xB3107E01
    mov eax, dword ptr [rip+g_np]
    mov dword ptr [rsi+4], eax
    mov eax, dword ptr [rip+g_target]
    mov dword ptr [rsi+8], eax
    mov eax, dword ptr [rip+g_optann]
    mov dword ptr [rsi+12], eax
    mov eax, dword ptr [rip+g_botlvl]
    mov dword ptr [rsi+16], eax
    mov eax, dword ptr [rip+g_S]
    mov dword ptr [rsi+20], eax
    mov eax, dword ptr [rip+g_fsmode]
    mov dword ptr [rsi+24], eax
    mov eax, dword ptr [rip+g_help]
    mov dword ptr [rsi+28], eax
    mov eax, dword ptr [rip+g_wins]
    mov dword ptr [rsi+32], eax
    mov eax, dword ptr [rip+g_wins+4]
    mov dword ptr [rsi+36], eax
    lea rcx, [rip+c_cfg]
    mov edx, 0x40000000
    xor r8d, r8d
    xor r9d, r9d
    mov dword ptr [rsp+32], 2
    mov dword ptr [rsp+40], 0x80
    mov qword ptr [rsp+48], 0
    call CreateFileA
    cmp rax, -1
    je 9f
    mov r12, rax
    mov rcx, r12
    lea rdx, [rip+g_cfg]
    mov r8d, 40
    lea r9, [rip+g_bytes]
    mov qword ptr [rsp+32], 0
    call WriteFile
    mov rcx, r12
    call CloseHandle
9:  LEAVE

save_bmp:
    ENTER
    lea rcx, [rip+c_shot]
    mov edx, 0x40000000
    xor r8d, r8d
    xor r9d, r9d
    mov dword ptr [rsp+32], 2
    mov dword ptr [rsp+40], 0x80
    mov qword ptr [rsp+48], 0
    call CreateFileA
    cmp rax, -1
    je 9f
    mov r12, rax
    mov rcx, r12
    lea rdx, [rip+g_bmphdr]
    mov r8d, 54
    lea r9, [rip+g_bytes]
    mov qword ptr [rsp+32], 0
    call WriteFile
    mov rcx, r12
    mov rdx, qword ptr [rip+g_smallbits]
    mov r8d, WW*WH*4
    lea r9, [rip+g_bytes]
    mov qword ptr [rsp+32], 0
    call WriteFile
    mov rcx, r12
    call CloseHandle
9:  LEAVE

# ---------- tampons ----------
make_dc:                                    # r12 = DC fenêtre, rdx = bmi, r8 = &bits -> rax = DC mémoire
    ENTER
    mov r13, rdx
    mov r14, r8
    mov rcx, r12
    call CreateCompatibleDC
    mov r15, rax
    mov rcx, r12
    mov rdx, r13
    xor r8d, r8d
    mov r9, r14
    mov qword ptr [rsp+32], 0
    mov dword ptr [rsp+40], 0
    call CreateDIBSection
    mov rcx, r15
    mov rdx, rax
    call SelectObject
    mov rcx, r15
    mov edx, 2                              # GM_ADVANCED
    call SetGraphicsMode
    mov rcx, r15
    mov edx, 1                              # TRANSPARENT
    call SetBkMode
    mov ecx, 18                             # DC_BRUSH
    call GetStockObject
    mov rcx, r15
    mov rdx, rax
    call SelectObject
    mov ecx, 19                             # DC_PEN
    call GetStockObject
    mov rcx, r15
    mov rdx, rax
    call SelectObject
    mov rax, r15
    LEAVE

set_quality:                                # g_S = 1 ou 2
    mov eax, dword ptr [rip+g_S]
    cvtsi2sd xmm0, eax
    movsd qword ptr [rip+g_Sd], xmm0
    mov rax, qword ptr [rip+g_hdcS]
    cmp dword ptr [rip+g_S], 2
    jne 1f
    mov rax, qword ptr [rip+g_hdcBig]
1:  mov qword ptr [rip+g_hdcD], rax
    ret

init_gfx:
    ENTER
    mov rcx, qword ptr [rip+g_hwnd]
    call GetDC
    mov r12, rax
    lea rdx, [rip+g_bmiSmall]
    lea r8, [rip+g_smallbits]
    call make_dc
    mov qword ptr [rip+g_hdcS], rax
    lea rdx, [rip+g_bmiBig]
    lea r8, [rip+g_bigbits]
    call make_dc
    mov qword ptr [rip+g_hdcBig], rax
    mov rcx, qword ptr [rip+g_hwnd]
    mov rdx, r12
    call ReleaseDC
    call set_quality
    call init_fonts
    rdtsc
    shl rdx, 32
    or rax, rdx
    or rax, 1
    mov qword ptr [rip+g_rng], rax
    LEAVE

render_frame:
    ENTER
    lea rcx, [rsp+96]
    call QueryPerformanceCounter
    call build_optline
    call render_scene
    cmp dword ptr [rip+g_S], 2
    jne 1f
    call downsample
1:  mov dword ptr [rip+g_dirty], 0
    lea rcx, [rsp+104]
    call QueryPerformanceCounter
    mov rax, qword ptr [rsp+104]
    sub rax, qword ptr [rsp+96]
    imul rax, rax, 1000000
    xor edx, edx
    mov rcx, qword ptr [rip+g_qpf]
    test rcx, rcx
    jnz 2f
    lea rcx, [rip+g_qpf]
    call QueryPerformanceFrequency
    mov rcx, qword ptr [rip+g_qpf]
    mov rax, qword ptr [rsp+104]
    sub rax, qword ptr [rsp+96]
    imul rax, rax, 1000000
    xor edx, edx
2:  div rcx
    mov dword ptr [rip+g_rms], eax
    LEAVE

# ---------- affichage à l'échelle ----------
calc_window_size:                           # r10d, r11d = taille totale de la fenêtre (client WWxWH)
    ENTER
    mov r12d, r10d
    sub r12d, WW
    mov r13d, r11d
    sub r13d, WH
    mov ecx, 0x30                           # SPI_GETWORKAREA
    xor edx, edx
    lea r8, [rip+g_rect2]
    xor r9d, r9d
    call SystemParametersInfoA
    mov r14d, dword ptr [rip+g_rect2+8]
    sub r14d, dword ptr [rip+g_rect2]
    mov r15d, dword ptr [rip+g_rect2+12]
    sub r15d, dword ptr [rip+g_rect2+4]
    mov eax, r14d
    sub eax, r12d
    imul eax, eax, 100
    cdq
    mov ecx, WW
    idiv ecx
    mov ebx, eax
    mov eax, r15d
    sub eax, r13d
    imul eax, eax, 100
    cdq
    mov ecx, WH
    idiv ecx
    cmp eax, ebx
    jge 1f
    mov ebx, eax
1:  cmp ebx, 100
    jle 2f
    mov ebx, 100
2:  cmp ebx, 25
    jge 3f
    mov ebx, 25
3:  cvtsi2sd xmm0, ebx
    divsd xmm0, qword ptr [rip+k_w100]
    movsd qword ptr [rip+g_scale], xmm0
    movsd xmm1, qword ptr [rip+k_one]
    divsd xmm1, xmm0
    movsd qword ptr [rip+g_iscale], xmm1
    movsd qword ptr [rip+g_wscale], xmm0
    xor eax, eax
    cmp ebx, 100
    setne al
    mov dword ptr [rip+g_sc_on], eax
    mov dword ptr [rip+g_wson], eax
    imul eax, ebx, 11
    add eax, r12d
    mov dword ptr [rip+g_cww], eax
    imul ecx, ebx, 8
    add ecx, r13d
    mov dword ptr [rip+g_cwh], ecx
    mov edx, r14d
    sub edx, eax
    sar edx, 1
    jns 4f
    xor edx, edx
4:  add edx, dword ptr [rip+g_rect2]
    mov dword ptr [rip+g_cwx], edx
    mov edx, r15d
    sub edx, ecx
    sar edx, 1
    jns 5f
    xor edx, edx
5:  add edx, dword ptr [rip+g_rect2+4]
    mov dword ptr [rip+g_cwy], edx
    LEAVE

fs_view:                                    # ecx = largeur écran, edx = hauteur
    movsd xmm0, qword ptr [rip+g_scale]
    movsd qword ptr [rip+g_wscale], xmm0
    mov eax, dword ptr [rip+g_sc_on]
    mov dword ptr [rip+g_wson], eax
    cvtsi2sd xmm0, ecx
    divsd xmm0, qword ptr [rip+k_w1100]
    cvtsi2sd xmm1, edx
    divsd xmm1, qword ptr [rip+k_w800]
    minsd xmm0, xmm1
    movsd qword ptr [rip+g_scale], xmm0
    movsd xmm1, qword ptr [rip+k_one]
    divsd xmm1, xmm0
    movsd qword ptr [rip+g_iscale], xmm1
    movsd xmm1, qword ptr [rip+k_one]
    subsd xmm1, xmm0
    andpd xmm1, xmmword ptr [rip+k_absmask]
    xor eax, eax
    comisd xmm1, qword ptr [rip+k_eps6]
    seta al
    mov dword ptr [rip+g_sc_on], eax
    movsd xmm1, qword ptr [rip+k_w1100]
    mulsd xmm1, xmm0
    cvttsd2si eax, xmm1
    mov r8d, ecx
    sub r8d, eax
    sar r8d, 1
    jns 1f
    xor r8d, r8d
1:  mov dword ptr [rip+g_ox], r8d
    movsd xmm1, qword ptr [rip+k_w800]
    mulsd xmm1, xmm0
    cvttsd2si eax, xmm1
    mov r8d, edx
    sub r8d, eax
    sar r8d, 1
    jns 2f
    xor r8d, r8d
2:  mov dword ptr [rip+g_oy], r8d
    ret

fs_restore:
    movsd xmm0, qword ptr [rip+g_wscale]
    movsd qword ptr [rip+g_scale], xmm0
    movsd xmm1, qword ptr [rip+k_one]
    divsd xmm1, xmm0
    movsd qword ptr [rip+g_iscale], xmm1
    mov eax, dword ptr [rip+g_wson]
    mov dword ptr [rip+g_sc_on], eax
    ret

toggle_fullscreen:
    ENTER
    cmp dword ptr [rip+g_fsmode], 0
    jne .Ltf_off
    mov rcx, qword ptr [rip+g_hwnd]
    lea rdx, [rip+g_wrect]
    call GetWindowRect
    mov rcx, qword ptr [rip+g_hwnd]
    mov edx, -16
    mov r8d, 0x90000000
    call SetWindowLongA
    xor ecx, ecx
    call GetSystemMetrics
    mov r12d, eax
    mov ecx, 1
    call GetSystemMetrics
    mov r13d, eax
    mov rcx, qword ptr [rip+g_hwnd]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword ptr [rsp+32], r12d
    mov dword ptr [rsp+40], r13d
    mov dword ptr [rsp+48], 0x60
    call SetWindowPos
    mov ecx, r12d
    mov edx, r13d
    call fs_view
    mov dword ptr [rip+g_fsmode], 1
    mov dword ptr [rip+g_erase], 1
    mov rcx, qword ptr [rip+g_hwnd]
    xor edx, edx
    mov r8d, 1
    call InvalidateRect
    jmp .Ltf_end
.Ltf_off:
    mov rcx, qword ptr [rip+g_hwnd]
    mov edx, -16
    mov r8d, 0x10CA0000
    call SetWindowLongA
    mov rcx, qword ptr [rip+g_hwnd]
    xor edx, edx
    mov r8d, dword ptr [rip+g_wrect]
    mov r9d, dword ptr [rip+g_wrect+4]
    mov eax, dword ptr [rip+g_wrect+8]
    sub eax, r8d
    mov dword ptr [rsp+32], eax
    mov eax, dword ptr [rip+g_wrect+12]
    sub eax, r9d
    mov dword ptr [rsp+40], eax
    mov dword ptr [rsp+48], 0x60
    call SetWindowPos
    mov dword ptr [rip+g_ox], 0
    mov dword ptr [rip+g_oy], 0
    call fs_restore
    mov dword ptr [rip+g_fsmode], 0
    mov rcx, qword ptr [rip+g_hwnd]
    xor edx, edx
    xor r8d, r8d
    call InvalidateRect
.Ltf_end:
    mov dword ptr [rip+g_dirty], 1
    LEAVE

view_mouse:                                 # ecx = x, edx = y (fenêtre) -> g_mx, g_my (jeu)
    cmp dword ptr [rip+g_sc_on], 0
    jne 1f
    sub ecx, dword ptr [rip+g_ox]
    sub edx, dword ptr [rip+g_oy]
    jmp 2f
1:  cvtsi2sd xmm0, ecx
    cvtsi2sd xmm2, dword ptr [rip+g_ox]
    subsd xmm0, xmm2
    mulsd xmm0, qword ptr [rip+g_iscale]
    cvttsd2si ecx, xmm0
    cvtsi2sd xmm1, edx
    cvtsi2sd xmm2, dword ptr [rip+g_oy]
    subsd xmm1, xmm2
    mulsd xmm1, qword ptr [rip+g_iscale]
    cvttsd2si edx, xmm1
2:  mov dword ptr [rip+g_mx], ecx
    mov dword ptr [rip+g_my], edx
    ret

present:                                    # rcx = DC de la fenêtre
    ENTER
    mov r12, rcx
    cmp dword ptr [rip+g_sc_on], 0
    jne .Lp_sc
    mov rcx, r12
    mov edx, dword ptr [rip+g_ox]
    mov r8d, dword ptr [rip+g_oy]
    mov r9d, WW
    mov dword ptr [rsp+32], WH
    mov rax, qword ptr [rip+g_hdcS]
    mov qword ptr [rsp+40], rax
    mov dword ptr [rsp+48], 0
    mov dword ptr [rsp+56], 0
    mov dword ptr [rsp+64], 0x00CC0020
    call BitBlt
    jmp .Lp_end
.Lp_sc:
    mov rcx, r12
    mov edx, 4                              # HALFTONE
    call SetStretchBltMode
    mov rcx, r12
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov qword ptr [rsp+32], 0
    call SetBrushOrgEx
    movsd xmm0, qword ptr [rip+k_w1100]
    mulsd xmm0, qword ptr [rip+g_scale]
    cvtsd2si r13d, xmm0
    movsd xmm0, qword ptr [rip+k_w800]
    mulsd xmm0, qword ptr [rip+g_scale]
    cvtsd2si r14d, xmm0
    mov rcx, r12
    mov edx, dword ptr [rip+g_ox]
    mov r8d, dword ptr [rip+g_oy]
    mov r9d, r13d
    mov dword ptr [rsp+32], r14d
    mov rax, qword ptr [rip+g_hdcS]
    mov qword ptr [rsp+40], rax
    mov dword ptr [rsp+48], 0
    mov dword ptr [rsp+56], 0
    mov dword ptr [rsp+64], WW
    mov dword ptr [rsp+72], WH
    mov dword ptr [rsp+80], 0x00CC0020
    call StretchBlt
.Lp_end:
    LEAVE

# ---------- fenêtre ----------
set_title_dbg:                              # D : valeurs de contrôle dans le titre
    ENTER
    call tb_reset
    mov ecx, dword ptr [rip+g_phase]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_turn]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_trump]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_taker]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_score]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_score+4]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_trickno]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_np]
    call tb_int
    lea rsi, [rip+c_sp1]
    call tb_str
    mov ecx, dword ptr [rip+g_rms]
    call tb_int
    mov rcx, qword ptr [rip+g_hwnd]
    lea rdx, [rip+g_tbuf]
    call SetWindowTextA
    LEAVE

WndProc:
    ENTER
    mov rbx, rcx
    mov r12d, edx
    mov r13, r8
    mov r14, r9
    cmp r12d, 0x113
    je .Lw_timer
    cmp r12d, 0x0F
    je .Lw_paint
    cmp r12d, 0x14
    je .Lw_erase
    cmp r12d, 0x100
    je .Lw_key
    cmp r12d, 0x201
    je .Lw_click
    cmp r12d, 0x200
    je .Lw_move
    cmp r12d, 0x102
    je .Lw_char
    cmp r12d, 0x401
    je .Lw_net
    cmp r12d, 1
    je .Lw_create
    cmp r12d, 2
    je .Lw_destroy
.Lw_def:
    mov rcx, rbx
    mov edx, r12d
    mov r8, r13
    mov r9, r14
    call DefWindowProcA
    LEAVE
.Lw_create:
    mov qword ptr [rip+g_hwnd], rbx
    call GetTickCount64
    mov dword ptr [rip+g_now], eax
    call init_gfx
    mov rcx, rbx
    mov edx, 1
    mov r8d, 16
    xor r9d, r9d
    call SetTimer
    call ui_newmatch
    xor eax, eax
    LEAVE
.Lw_destroy:
    xor ecx, ecx
    call PostQuitMessage
    xor eax, eax
    LEAVE
.Lw_erase:
    cmp dword ptr [rip+g_erase], 0
    je 1f
    mov dword ptr [rip+g_erase], 0
    mov rcx, rbx
    lea rdx, [rip+g_rect]
    call GetClientRect
    mov ecx, 4
    call GetStockObject
    mov rcx, r13
    lea rdx, [rip+g_rect]
    mov r8, rax
    call FillRect
1:  mov eax, 1
    LEAVE
.Lw_timer:
    call ui_tick
    cmp dword ptr [rip+g_dirty], 0
    je .Lw_zero
    call render_frame
    mov rcx, rbx
    xor edx, edx
    xor r8d, r8d
    call InvalidateRect
.Lw_zero:
    xor eax, eax
    LEAVE
.Lw_paint:
    mov rcx, rbx
    lea rdx, [rip+g_ps]
    call BeginPaint
    mov r15, rax
    cmp dword ptr [rip+g_frames], 0
    je 1f
    mov rcx, r15
    call present
1:  mov rcx, rbx
    lea rdx, [rip+g_ps]
    call EndPaint
    xor eax, eax
    LEAVE
.Lw_move:
    mov ecx, r14d
    and ecx, 0xFFFF
    mov edx, r14d
    shr edx, 16
    and edx, 0xFFFF
    call view_mouse
    call ui_move
    jmp .Lw_zero
.Lw_click:
    mov ecx, r14d
    and ecx, 0xFFFF
    mov edx, r14d
    shr edx, 16
    and edx, 0xFFFF
    call view_mouse
    call ui_click
    jmp .Lw_zero
.Lw_char:
    mov ecx, r13d
    call net_char
    jmp .Lw_zero
.Lw_net:
    mov rcx, r13
    mov edx, r14d
    call net_event
    jmp .Lw_zero
.Lw_key:
    cmp dword ptr [rip+g_menu], 3           # message d'information : une touche le ferme
    jne .Lk0a
    mov dword ptr [rip+g_menu], 0
    mov dword ptr [rip+g_dirty], 1
    jmp .Lw_zero
.Lk0a:
    cmp dword ptr [rip+g_menu], 0
    je .Lk0b
    mov ecx, r13d
    call net_menu_key
    jmp .Lw_zero
.Lk0b:
    cmp r13d, 0x1B
    jne .Lk1x
    mov eax, dword ptr [rip+g_net]          # Échap pendant une attente en ligne : annule
    cmp eax, 1
    je .Lk0c
    cmp eax, 2
    je .Lk0c
    cmp eax, 3
    jne .Lk1b
.Lk0c:
    call net_cancel
    jmp .Lw_zero
.Lk1x:
.Lk1b:
    cmp r13d, 0x1B
    jne .Lk1
    cmp dword ptr [rip+g_fsmode], 0
    je .Lw_destroy
    call toggle_fullscreen
    call opt_save
    jmp .Lw_zero
.Lk1:
    cmp r13d, 0x7A                          # F11
    jne .Lk2
    call toggle_fullscreen
    call opt_save
    jmp .Lw_zero
.Lk2:
    cmp r13d, 0x7B                          # F12
    jne .Lk3
    call save_bmp
    jmp .Lw_zero
.Lk3:
    cmp r13d, 0x20                          # Espace / Entrée
    je .Lk3b
    cmp r13d, 0x0D
    jne .Lk4
.Lk3b:
    cmp dword ptr [rip+g_net], 1            # hôte en attente : Entrée lance la partie
    jne .Lk3c
    call net_host_start
    jmp .Lw_zero
.Lk3c:
    mov ecx, 6
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_ROUNDEND
    je 1f
    cmp eax, PH_MATCHEND
    jne .Lw_zero
1:  call btn_action
    jmp .Lw_zero
.Lk4:
    cmp r13d, 0x4A                          # J : 4 joueurs / à deux
    jne .Lk5
    cmp dword ptr [rip+g_net], 0
    jne .Lw_zero
    mov eax, 6
    sub eax, dword ptr [rip+g_np]
    mov dword ptr [rip+g_np], eax
    call ui_newmatch
    call opt_save
    jmp .Lw_zero
.Lk5:
    cmp r13d, 0x4C                          # L : niveau des bots
    jne .Lk6
    cmp dword ptr [rip+g_net], 0
    jne .Lw_zero
    mov eax, dword ptr [rip+g_botlvl]
    inc eax
    cmp eax, 3
    jb 1f
    xor eax, eax
1:  mov dword ptr [rip+g_botlvl], eax
    call ui_set_levels
    mov dword ptr [rip+g_dirty], 1
    call opt_save
    jmp .Lw_zero
.Lk6:
    cmp r13d, 0x41                          # A : annonces
    jne .Lk7
    cmp dword ptr [rip+g_net], 0
    jne .Lw_zero
    xor dword ptr [rip+g_optann], 1
    mov dword ptr [rip+g_dirty], 1
    call opt_save
    jmp .Lw_zero
.Lk7:
    cmp r13d, 0x48                          # H : aide
    jne .Lk8
    xor dword ptr [rip+g_help], 1
    call ui_help
    call opt_save
    jmp .Lw_zero
.Lk8:
    cmp r13d, 0x50                          # P : objectif
    jne .Lk9
    cmp dword ptr [rip+g_net], 0
    jne .Lw_zero
    mov eax, dword ptr [rip+g_target]
    mov ecx, 1000
    cmp eax, 501
    je 1f
    mov ecx, 1500
    cmp eax, 1000
    je 1f
    mov ecx, 501
1:  mov dword ptr [rip+g_target], ecx
    mov dword ptr [rip+g_dirty], 1
    call opt_save
    jmp .Lw_zero
.Lk9:
    cmp r13d, 0x51                          # Q : qualité du rendu
    jne .Lk10
    mov eax, 3
    sub eax, dword ptr [rip+g_S]
    mov dword ptr [rip+g_S], eax
    call set_quality
    mov dword ptr [rip+g_dirty], 1
    call opt_save
    jmp .Lw_zero
.Lk10:
    cmp r13d, 0x55                          # U : le jeu joue à ta place (test / démonstration)
    jne .Lk11
    xor dword ptr [rip+g_auto], 1
    mov dword ptr [rip+g_dirty], 1
    jmp .Lw_zero
.Lk11:
    cmp r13d, 0x44                          # D : valeurs de contrôle
    jne .Lk12
    call set_title_dbg
    jmp .Lw_zero
.Lk12:
    cmp r13d, 0x4E                          # N : multijoueur en ligne
    jne .Lw_zero
    call net_open
    jmp .Lw_zero

gui_main:
    ENTER
    xor ecx, ecx
    call GetModuleHandleA
    mov qword ptr [rip+g_hinst], rax
    call SetProcessDPIAware
    call opt_load
    lea rdi, [rip+g_wc]
    mov dword ptr [rdi], 80
    mov dword ptr [rdi+4], 3
    lea rax, [rip+WndProc]
    mov qword ptr [rdi+8], rax
    mov rax, qword ptr [rip+g_hinst]
    mov qword ptr [rdi+24], rax
    xor ecx, ecx
    mov edx, 32512
    call LoadCursorA
    mov qword ptr [rdi+40], rax
    lea rax, [rip+s_cls]
    mov qword ptr [rdi+64], rax
    lea rcx, [rip+g_wc]
    call RegisterClassExA
    lea rdi, [rip+g_rect]
    mov dword ptr [rdi], 0
    mov dword ptr [rdi+4], 0
    mov dword ptr [rdi+8], WW
    mov dword ptr [rdi+12], WH
    lea rcx, [rip+g_rect]
    mov edx, 0x00CA0000
    xor r8d, r8d
    call AdjustWindowRect
    mov eax, dword ptr [rip+g_rect+8]
    sub eax, dword ptr [rip+g_rect]
    mov r10d, eax
    mov eax, dword ptr [rip+g_rect+12]
    sub eax, dword ptr [rip+g_rect+4]
    mov r11d, eax
    call calc_window_size
    xor ecx, ecx
    lea rdx, [rip+s_cls]
    lea r8, [rip+s_title]
    mov r9d, 0x10CA0000
    mov eax, dword ptr [rip+g_cwx]
    mov dword ptr [rsp+32], eax
    mov eax, dword ptr [rip+g_cwy]
    mov dword ptr [rsp+40], eax
    mov eax, dword ptr [rip+g_cww]
    mov dword ptr [rsp+48], eax
    mov eax, dword ptr [rip+g_cwh]
    mov dword ptr [rsp+56], eax
    mov qword ptr [rsp+64], 0
    mov qword ptr [rsp+72], 0
    mov rax, qword ptr [rip+g_hinst]
    mov qword ptr [rsp+80], rax
    mov qword ptr [rsp+88], 0
    call CreateWindowExA
    test rax, rax
    jz .Lgm_quit
    cmp dword ptr [rip+g_optfs], 0
    je .Lgm_loop
    call toggle_fullscreen
.Lgm_loop:
    lea rcx, [rip+g_msgrec]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call GetMessageA
    test eax, eax
    jle .Lgm_quit
    lea rcx, [rip+g_msgrec]
    call TranslateMessage
    lea rcx, [rip+g_msgrec]
    call DispatchMessageA
    jmp .Lgm_loop
.Lgm_quit:
    LEAVE

.section .rdata,"dr"
c_sp1:      .asciz " "
.data
g_frames:   .long 1
