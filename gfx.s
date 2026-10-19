# ============================================================
#  gfx.s — primitives de dessin (GDI + transformation affine), polices, cartes, tampon 2x
#  Tout se dessine en coordonnées logiques 1100x800 ; la transformation du DC applique l'échelle du tampon
#  (x2 pour l'anticrénelage) et, pour les objets posés sur la table, la projection isométrique.
# ============================================================
.macro RGB name, r, g, b
.equ \name, ((\b) << 16) | ((\g) << 8) | (\r)
.endm

RGB C_BG,      18, 22, 29
RGB C_WOOD,    128, 84, 44
RGB C_WOODDK,  78, 48, 24
RGB C_WOODHI,  160, 108, 60
RGB C_FELT0,   14, 92, 62
RGB C_FELT1,   22, 112, 76
RGB C_FELT2,   30, 132, 90
RGB C_IVORY,   250, 247, 238
RGB C_CARDLN,  120, 115, 100
RGB C_BLACK,   26, 26, 32
RGB C_RED,     200, 32, 36
RGB C_GOLD,    255, 205, 70
RGB C_WHITE,   240, 240, 235
RGB C_SHADOW,  8, 52, 36
RGB C_SHFLY,   20, 92, 64
RGB C_BACK0,   34, 56, 130
RGB C_BACK1,   70, 96, 180
RGB C_BTN,     60, 150, 100
RGB C_BTNDK,   30, 90, 60
RGB C_BTNOFF,  70, 74, 84
RGB C_PANEL,   30, 36, 46
RGB C_PANELLN, 80, 90, 106
RGB C_TXT,     220, 226, 232
RGB C_TXTDIM,  140, 150, 162
RGB C_GREEN,   110, 220, 140
RGB C_FELTEDGE, 16, 60, 40
RGB C_OVER,    38, 46, 60
RGB C_TURNFILL, 60, 64, 30
RGB C_GOLDDK,  144, 96, 16
RGB C_PLAYER,  96, 200, 255
RGB C_ENEMY,   255, 120, 140

.equ F_TITLE, 0
.equ F_LABEL, 1
.equ F_RANK,  2
.equ F_SUIT,  3
.equ F_SMALL, 4
.equ F_BIGSUIT, 5
.equ F_BTN,   6
.equ F_MED,   7
.equ F_HUGE,  8
.equ F_SYM2,  9
.equ F_SERIF, 10
.equ F_SERIFBIG, 11
.equ F_PIP,   12

.section .rdata,"dr"
.balign 16
k_signneg:  .quad 0x8000000000000000, 0x8000000000000000
k_absmask:  .quad 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
.balign 8
k_one:      .double 1.0
k_half:     .double 0.5
k_neg1:     .double -1.0
k_ground:   .double 0.62               # écrasement vertical du plan de la table (vue isométrique)
k_deg:      .double 0.017453292519943295
k_w100:     .double 100.0
k_w1100:    .double 1100.0
k_w800:     .double 800.0
k_eps6:     .double 0.000001
c_face:     .asciz "Segoe UI"
c_facesym:  .asciz "Segoe UI Symbol"
c_geo:      .asciz "Georgia"
# glyphes des couleurs : pique coeur carreau trèfle (UTF-16)
w_suits:    .word 0x2660, 0x2665, 0x2666, 0x2663
s_ranks:    .asciz "7", "8", "9", "10", "V", "D", "R", "A"

.data
.balign 8
g_S:        .long 2                    # facteur du tampon (1 ou 2)
g_Sd:       .double 2.0
g_sq:       .double 1.0                # écrasement courant
g_fc:       .long 0
g_lc:       .long 0
g_tc:       .long 0
g_ta:       .long 6                    # TA_CENTER (|TA_TOP = 0)
g_rad:      .long 0

.bss
.balign 8
g_hdcD:     .skip 8                    # DC de dessin (grand tampon ou petit)
g_hdcS:     .skip 8                    # DC du petit tampon (1100x800)
g_hdcBig:   .skip 8
g_bigbits:  .skip 8
g_smallbits:.skip 8
g_fonts:    .skip 8*16
g_tmp_d:    .skip 8
g_tmp_d2:   .skip 8

.text
sincos_d:                              # xmm0 = angle -> xmm0 = sin, xmm1 = cos
    movsd qword ptr [rip+g_tmp_d], xmm0
    fld qword ptr [rip+g_tmp_d]
    fsincos
    fstp qword ptr [rip+g_tmp_d2]
    fstp qword ptr [rip+g_tmp_d]
    movsd xmm1, qword ptr [rip+g_tmp_d2]
    movsd xmm0, qword ptr [rip+g_tmp_d]
    ret

strlen_z:                              # rsi -> eax
    xor eax, eax
1:  cmp byte ptr [rsi+rax], 0
    je 2f
    inc eax
    jmp 1b
2:  ret

mkfont:                                # ecx = hauteur (négative), edx = graisse, r8 = nom -> rax
    ENTER
    mov dword ptr [rsp+32], edx
    mov dword ptr [rsp+40], 0
    mov dword ptr [rsp+48], 0
    mov dword ptr [rsp+56], 0
    mov dword ptr [rsp+64], 1          # DEFAULT_CHARSET
    mov dword ptr [rsp+72], 0
    mov dword ptr [rsp+80], 0
    mov dword ptr [rsp+88], 4          # ANTIALIASED_QUALITY
    mov dword ptr [rsp+96], 0
    mov qword ptr [rsp+104], r8
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call CreateFontA
    LEAVE

init_fonts:
    ENTER
    lea r13, [rip+g_fonts]
    lea r8, [rip+c_face]
    mov ecx, -46
    mov edx, 800
    call mkfont
    mov qword ptr [r13], rax
    lea r8, [rip+c_face]
    mov ecx, -20
    mov edx, 700
    call mkfont
    mov qword ptr [r13+8], rax
    lea r8, [rip+c_face]
    mov ecx, -34
    mov edx, 800
    call mkfont
    mov qword ptr [r13+16], rax
    lea r8, [rip+c_facesym]
    mov ecx, -34
    mov edx, 400
    call mkfont
    mov qword ptr [r13+24], rax
    lea r8, [rip+c_face]
    mov ecx, -15
    mov edx, 600
    call mkfont
    mov qword ptr [r13+32], rax
    lea r8, [rip+c_facesym]
    mov ecx, -84
    mov edx, 400
    call mkfont
    mov qword ptr [r13+40], rax
    lea r8, [rip+c_face]
    mov ecx, -22
    mov edx, 700
    call mkfont
    mov qword ptr [r13+48], rax
    lea r8, [rip+c_face]
    mov ecx, -28
    mov edx, 700
    call mkfont
    mov qword ptr [r13+56], rax
    lea r8, [rip+c_face]
    mov ecx, -64
    mov edx, 800
    call mkfont
    mov qword ptr [r13+64], rax
    lea r8, [rip+c_facesym]
    mov ecx, -50
    mov edx, 400
    call mkfont
    mov qword ptr [r13+72], rax
    lea r8, [rip+c_geo]
    mov ecx, -25
    mov edx, 700
    call mkfont
    mov qword ptr [r13+80], rax
    lea r8, [rip+c_geo]
    mov ecx, -50
    mov edx, 700
    call mkfont
    mov qword ptr [r13+88], rax
    lea r8, [rip+c_facesym]
    mov ecx, -22
    mov edx, 400
    call mkfont
    mov qword ptr [r13+96], rax
    call cards_init
    LEAVE

# ---------- couleurs et formes (coordonnées logiques) ----------
set_cols:                              # ecx = remplissage, edx = contour
    ENTER
    mov dword ptr [rip+g_fc], ecx
    mov dword ptr [rip+g_lc], edx
    mov r12d, edx
    mov edx, ecx
    mov rcx, qword ptr [rip+g_hdcD]
    call SetDCBrushColor
    mov edx, r12d
    mov rcx, qword ptr [rip+g_hdcD]
    call SetDCPenColor
    LEAVE

# rrect : ecx = x, edx = y, r8d = largeur, r9d = hauteur, g_rad = rayon (couleurs : set_cols)
rrect:
    ENTER
    mov eax, dword ptr [rip+g_rad]
    add eax, eax
    mov dword ptr [rsp+40], eax
    mov dword ptr [rsp+48], eax
    mov eax, edx
    add eax, r9d
    mov dword ptr [rsp+32], eax
    mov eax, ecx
    add eax, r8d
    mov r9d, eax
    mov r8d, edx
    mov edx, ecx
    mov rcx, qword ptr [rip+g_hdcD]
    call RoundRect
    LEAVE

# ellipse : ecx = x centre, edx = y centre, r8d = rx, r9d = ry
ellipse:
    ENTER
    mov eax, edx
    add eax, r9d
    mov dword ptr [rsp+32], eax
    mov eax, ecx
    add eax, r8d
    sub ecx, r8d
    sub edx, r9d
    mov r9d, eax
    mov r8d, edx
    mov edx, ecx
    mov rcx, qword ptr [rip+g_hdcD]
    call Ellipse
    LEAVE

# gtext : ecx = x, edx = y, r8 = texte (ANSI), r9d = police ; couleur g_tc, alignement g_ta
gtext:
    ENTER
    mov r12d, ecx
    mov r13d, edx
    mov r14, r8
    lea rax, [rip+g_fonts]
    mov rdx, qword ptr [rax+r9*8]
    mov rcx, qword ptr [rip+g_hdcD]
    call SelectObject
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, dword ptr [rip+g_tc]
    call SetTextColor
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, dword ptr [rip+g_ta]
    call SetTextAlign
    mov rsi, r14
    call strlen_z
    mov dword ptr [rsp+32], eax
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, r12d
    mov r8d, r13d
    mov r9, r14
    call TextOutA
    LEAVE

# gglyph : ecx = x, edx = y, r8d = couleur 0..3, r9d = police ; symbole de couleur
gglyph:
    ENTER
    mov r12d, ecx
    mov r13d, edx
    mov r14d, r8d
    lea rax, [rip+g_fonts]
    mov rdx, qword ptr [rax+r9*8]
    mov rcx, qword ptr [rip+g_hdcD]
    call SelectObject
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, dword ptr [rip+g_tc]
    call SetTextColor
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, dword ptr [rip+g_ta]
    call SetTextAlign
    lea rax, [rip+w_suits]
    lea r9, [rax+r14*2]
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, r12d
    mov r8d, r13d
    mov dword ptr [rsp+32], 1
    call TextOutW
    LEAVE

# ---------- transformation affine du DC ----------
# set_xf : xmm0 = cx, xmm1 = cy (logique), xmm2 = échelle, xmm3 = angle (radians) ; écrasement vertical : g_sq
set_xf:
    ENTER
    movsd qword ptr [rsp+96], xmm0
    movsd qword ptr [rsp+104], xmm1
    movsd qword ptr [rsp+112], xmm2
    movapd xmm0, xmm3
    call sincos_d                      # xmm0 = sin, xmm1 = cos
    movsd xmm4, qword ptr [rip+g_Sd]
    mulsd xmm4, qword ptr [rsp+112]    # S * échelle
    movsd xmm5, qword ptr [rip+g_sq]
    movapd xmm6, xmm4
    mulsd xmm6, xmm1
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+64], xmm7     # eM11 = S sc cos
    movapd xmm6, xmm4
    mulsd xmm6, xmm0
    mulsd xmm6, xmm5
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+68], xmm7     # eM12 = S sc sin sq
    movapd xmm6, xmm4
    mulsd xmm6, xmm0
    mulsd xmm6, qword ptr [rip+k_neg1]
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+72], xmm7     # eM21 = -S sc sin
    movapd xmm6, xmm4
    mulsd xmm6, xmm1
    mulsd xmm6, xmm5
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+76], xmm7     # eM22 = S sc cos sq
    movsd xmm6, qword ptr [rsp+96]
    mulsd xmm6, qword ptr [rip+g_Sd]
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+80], xmm7     # eDx
    movsd xmm6, qword ptr [rsp+104]
    mulsd xmm6, qword ptr [rip+g_Sd]
    cvtsd2ss xmm7, xmm6
    movss dword ptr [rsp+84], xmm7     # eDy
    mov rcx, qword ptr [rip+g_hdcD]
    lea rdx, [rsp+64]
    call SetWorldTransform
    LEAVE

xf_reset:                              # retour à l'échelle seule
    ENTER
    mov rax, qword ptr [rip+k_one]
    mov qword ptr [rip+g_sq], rax
    xorpd xmm0, xmm0
    xorpd xmm1, xmm1
    movsd xmm2, qword ptr [rip+k_one]
    xorpd xmm3, xmm3
    call set_xf
    LEAVE

# ---------- réduction 2x2 : grand tampon -> petit tampon ----------
downsample:
    mov rsi, qword ptr [rip+g_bigbits]
    mov rdi, qword ptr [rip+g_smallbits]
    mov edx, WH
1:  lea rax, [rsi+8800]
    xor ecx, ecx
2:  movdqu xmm0, xmmword ptr [rsi+rcx]
    movdqu xmm1, xmmword ptr [rax+rcx]
    pavgb xmm0, xmm1
    movdqu xmm2, xmmword ptr [rsi+rcx+16]
    movdqu xmm3, xmmword ptr [rax+rcx+16]
    pavgb xmm2, xmm3
    movaps xmm4, xmm0
    shufps xmm4, xmm2, 0x88
    shufps xmm0, xmm2, 0xDD
    pavgb xmm0, xmm4
    movdqu xmmword ptr [rdi], xmm0
    add rdi, 16
    add ecx, 32
    cmp ecx, 8800
    jb 2b
    add rsi, 17600
    dec edx
    jnz 1b
    ret

.section .rdata,"dr"
t_isred:    .byte 0, 1, 1, 0
