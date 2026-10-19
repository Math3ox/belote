# ============================================================
#  cards.s — dessin des cartes (design « bistrot classique ») dans le repère canonique 100 x 140 centré sur l'origine
#  Face : ivoire, double filet, indices en serif aux coins, points disposés comme sur un vrai jeu, figures dans un cadre.
#  Dos : bordeaux à losanges dorés, médaillon central.
# ============================================================
RGB C_CRED,    194, 38, 46
RGB C_CBLK,    27, 27, 34
RGB C_TRED,    236, 195, 190
RGB C_TBLK,    194, 192, 187
RGB C_PANELF,  244, 236, 214
RGB C_GOLDF,   217, 178, 106
RGB C_GOLDLN,  140, 106, 36
RGB C_BORD,    122, 31, 43
RGB C_BORDDK,  96, 22, 33
RGB C_CLN2,    140, 134, 111
RGB C_DIMF,    178, 178, 170

.section .rdata,"dr"
.balign 4
# couronnes et bonnet (paires x, y relatives)
pl_roi:     .long -16,10, -16,-6, -8,2, 0,-10, 8,2, 16,-6, 16,10
pl_dame:    .long -13,10, -13,-3, -6,3, 0,-7, 6,3, 13,-3, 13,10
pl_valet:   .long -13,10, -13,0, -6,-6, 6,-6, 13,0, 13,10
# points : n, puis (x, y) du centre de chaque point
t_pip7:     .byte 7,  -17,-44, 17,-44, -17,0, 17,0, -17,44, 17,44, 0,-22
t_pip8:     .byte 8,  -17,-44, 17,-44, -17,0, 17,0, -17,44, 17,44, 0,-22, 0,22
t_pip9:     .byte 9,  -17,-44, 17,-44, -17,-15, 17,-15, -17,15, 17,15, -17,44, 17,44, 0,0
t_pip10:    .byte 10, -17,-44, 17,-44, -17,-15, 17,-15, -17,15, 17,15, -17,44, 17,44, 0,-30, 0,30
.balign 8
t_pipptr:   .quad t_pip7, t_pip8, t_pip9, t_pip10

.bss
.balign 8
g_pts:      .skip 128
g_nullbr:   .skip 8
g_dcbr:     .skip 8
g_penlat:   .skip 8
g_dcpen:    .skip 8

.text
cards_init:                                # poignées de GDI utilisées par le dessin des cartes
    ENTER
    mov ecx, 5                             # NULL_BRUSH
    call GetStockObject
    mov qword ptr [rip+g_nullbr], rax
    mov ecx, 18                            # DC_BRUSH
    call GetStockObject
    mov qword ptr [rip+g_dcbr], rax
    mov ecx, 19                            # DC_PEN
    call GetStockObject
    mov qword ptr [rip+g_dcpen], rax
    xor ecx, ecx                           # PS_SOLID, 1, or
    mov edx, 1
    mov r8d, C_GOLDF
    call CreatePen
    mov qword ptr [rip+g_penlat], rax
    LEAVE

hollow_on:                                 # formes suivantes sans remplissage
    sub rsp, 40
    mov rcx, qword ptr [rip+g_hdcD]
    mov rdx, qword ptr [rip+g_nullbr]
    call SelectObject
    add rsp, 40
    ret

hollow_off:
    sub rsp, 40
    mov rcx, qword ptr [rip+g_hdcD]
    mov rdx, qword ptr [rip+g_dcbr]
    call SelectObject
    add rsp, 40
    ret

# poly_draw : rsi = modèle (paires de dword), ecx = nombre de points, edx = dx, r8d = dy, r9d = 1 pour retourner verticalement
poly_draw:
    ENTER
    mov r11d, ecx
    lea rdi, [rip+g_pts]
    xor r10d, r10d
1:  cmp r10d, r11d
    jge 2f
    mov eax, dword ptr [rsi+r10*8]
    add eax, edx
    mov dword ptr [rdi+r10*8], eax
    mov eax, dword ptr [rsi+r10*8+4]
    test r9d, r9d
    jz 3f
    neg eax
3:  add eax, r8d
    mov dword ptr [rdi+r10*8+4], eax
    inc r10d
    jmp 1b
2:  mov rcx, qword ptr [rip+g_hdcD]
    mov rdx, rdi
    mov r8d, r11d
    call Polygon
    LEAVE

# card_ink : r13d = couleur de la carte -> eax = encre, edx = teinte du filet (conserve ecx)
card_ink:
    mov eax, C_CBLK
    mov edx, C_TBLK
    lea r8, [rip+t_isred]
    cmp byte ptr [r8+r13], 0
    je 1f
    mov eax, C_CRED
    mov edx, C_TRED
1:  ret

# draw_card : ecx = carte (0..31) ; dessine la face
draw_card:
    ENTER
    mov r12d, ecx
    mov r13d, ecx
    shr r13d, 3                            # couleur
    mov r14d, r12d
    and r14d, 7                            # rang
    call card_ink
    mov r15d, eax                          # encre
    mov ebx, edx                           # teinte
    mov ecx, C_SHADOW                      # ombre portée
    mov edx, C_SHADOW
    call set_cols
    mov dword ptr [rip+g_rad], 12
    mov ecx, -46
    mov edx, -66
    mov r8d, 100
    mov r9d, 140
    call rrect
    mov ecx, C_IVORY                       # face
    cmp dword ptr [rip+g_dim], 0
    je 1f
    mov ecx, C_DIMF
1:  mov edx, C_CLN2
    call set_cols
    mov dword ptr [rip+g_rad], 12
    mov ecx, -50
    mov edx, -70
    mov r8d, 100
    mov r9d, 140
    call rrect
    call hollow_on                         # double filet teinté
    mov ecx, C_IVORY
    mov edx, ebx
    call set_cols
    mov dword ptr [rip+g_rad], 8
    mov ecx, -47
    mov edx, -67
    mov r8d, 94
    mov r9d, 134
    call rrect
    call hollow_off
    mov dword ptr [rip+g_tc], r15d
    mov dword ptr [rip+g_ta], 6
    lea rdx, [rip+s_ranks]                 # texte du rang
    xor eax, eax
    xor ecx, ecx
2:  cmp ecx, r14d
    je 3f
    cmp byte ptr [rdx+rax], 0
    jne 4f
    inc ecx
4:  inc eax
    jmp 2b
3:  lea rsi, [rdx+rax]
    mov qword ptr [rsp+96], rsi            # conservé pour les figures
    mov ecx, -36                           # indices : haut gauche et bas droite
    mov edx, -69
    mov r8, rsi
    mov r9d, F_SERIF
    call gtext
    mov ecx, -36
    mov edx, -43
    mov r8d, r13d
    mov r9d, F_PIP
    call gglyph
    mov ecx, 36
    mov edx, 41
    mov r8, qword ptr [rsp+96]
    mov r9d, F_SERIF
    call gtext
    mov ecx, 36
    mov edx, 14
    mov r8d, r13d
    mov r9d, F_PIP
    call gglyph
    cmp r14d, 7
    je .Lc_ace
    cmp r14d, 4
    jae .Lc_face
    lea rax, [rip+t_pipptr]                # cartes à points
    mov rsi, qword ptr [rax+r14*8]
    movzx r12d, byte ptr [rsi]
    inc rsi
    xor r14d, r14d
.Lc_pip:
    cmp r14d, r12d
    jge .Lc_end
    movsx ecx, byte ptr [rsi+r14*2]
    movsx edx, byte ptr [rsi+r14*2+1]
    sub edx, 17
    mov r8d, r13d
    mov r9d, F_PIP
    call gglyph
    inc r14d
    jmp .Lc_pip
.Lc_ace:
    mov ecx, 0
    mov edx, -64
    mov r8d, r13d
    mov r9d, F_BIGSUIT
    call gglyph
    jmp .Lc_end
.Lc_face:
    mov ecx, C_PANELF                      # cadre de la figure
    mov edx, ebx
    call set_cols
    mov dword ptr [rip+g_rad], 6
    mov ecx, -26
    mov edx, -54
    mov r8d, 52
    mov r9d, 108
    call rrect
    mov ecx, C_GOLDF                       # couronnes haut et bas
    mov edx, C_GOLDLN
    call set_cols
    lea rbx, [rip+pl_roi]
    mov r12d, 7
    cmp r14d, 6
    je 5f
    lea rbx, [rip+pl_dame]
    cmp r14d, 5
    je 5f
    lea rbx, [rip+pl_valet]
    mov r12d, 6
5:  mov rsi, rbx
    mov ecx, r12d
    xor edx, edx
    mov r8d, -40
    xor r9d, r9d
    call poly_draw
    mov rsi, rbx
    mov ecx, r12d
    xor edx, edx
    mov r8d, 40
    mov r9d, 1
    call poly_draw
    cmp r14d, 5
    jne 6f
    xor ecx, ecx                           # perles de la dame
    mov edx, -50
    mov r8d, 3
    mov r9d, 3
    call ellipse
    xor ecx, ecx
    mov edx, 50
    mov r8d, 3
    mov r9d, 3
    call ellipse
6:  mov dword ptr [rip+g_tc], r15d
    xor ecx, ecx                           # grande lettre et petite couleur sous elle
    mov edx, -38
    mov r8, qword ptr [rsp+96]
    mov r9d, F_SERIFBIG
    call gtext
    xor ecx, ecx
    mov edx, 2
    mov r8d, r13d
    mov r9d, F_PIP
    call gglyph
.Lc_end:
    LEAVE

# draw_back : dos de carte
draw_back:
    ENTER
    mov ecx, C_SHADOW
    mov edx, C_SHADOW
    call set_cols
    mov dword ptr [rip+g_rad], 12
    mov ecx, -46
    mov edx, -66
    mov r8d, 100
    mov r9d, 140
    call rrect
    mov ecx, C_IVORY
    mov edx, C_CLN2
    call set_cols
    mov dword ptr [rip+g_rad], 12
    mov ecx, -50
    mov edx, -70
    mov r8d, 100
    mov r9d, 140
    call rrect
    mov ecx, C_BORD                        # champ bordeaux
    mov edx, C_BORD
    call set_cols
    mov dword ptr [rip+g_rad], 7
    mov ecx, -44
    mov edx, -64
    mov r8d, 88
    mov r9d, 128
    call rrect
    mov rcx, qword ptr [rip+g_hdcD]        # losanges dorés : droites à 45 degrés recoupées au cadre
    mov rdx, qword ptr [rip+g_penlat]
    call SelectObject
    mov r12d, -190                         # c : y = x - c, puis y = -x - c
.Ldb_l:
    cmp r12d, 190
    jg .Ldb_done
    mov eax, r12d                          # x de départ = max(-39, c - 59), x d'arrivée = min(39, c + 59)
    sub eax, 59
    mov r13d, -39
    cmp eax, r13d
    cmovg r13d, eax
    mov eax, r12d
    add eax, 59
    mov r14d, 39
    cmp eax, r14d
    cmovl r14d, eax
    cmp r13d, r14d
    jge .Ldb_nx
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, r13d
    mov r8d, r13d
    sub r8d, r12d
    xor r9d, r9d
    call MoveToEx
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, r14d
    mov r8d, r14d
    sub r8d, r12d
    call LineTo
    mov rcx, qword ptr [rip+g_hdcD]        # symétrique en x
    mov edx, r13d
    neg edx
    mov r8d, r13d
    sub r8d, r12d
    xor r9d, r9d
    call MoveToEx
    mov rcx, qword ptr [rip+g_hdcD]
    mov edx, r14d
    neg edx
    mov r8d, r14d
    sub r8d, r12d
    call LineTo
.Ldb_nx:
    add r12d, 16
    jmp .Ldb_l
.Ldb_done:
    mov rcx, qword ptr [rip+g_hdcD]
    mov rdx, qword ptr [rip+g_dcpen]
    call SelectObject
    call hollow_on                         # filet ivoire et filet doré
    mov ecx, C_IVORY
    mov edx, C_IVORY
    call set_cols
    mov dword ptr [rip+g_rad], 7
    mov ecx, -44
    mov edx, -64
    mov r8d, 88
    mov r9d, 128
    call rrect
    mov ecx, C_GOLDF
    mov edx, C_GOLDF
    call set_cols
    mov dword ptr [rip+g_rad], 4
    mov ecx, -39
    mov edx, -59
    mov r8d, 78
    mov r9d, 118
    call rrect
    call hollow_off
    mov ecx, C_BORD                        # médaillon
    mov edx, C_GOLDF
    call set_cols
    mov ecx, 0
    mov edx, 0
    mov r8d, 22
    mov r9d, 31
    call ellipse
    call hollow_on
    mov ecx, C_BORD
    mov edx, C_GOLDF
    call set_cols
    mov ecx, 0
    mov edx, 0
    mov r8d, 15
    mov r9d, 23
    call ellipse
    call hollow_off
    mov dword ptr [rip+g_tc], C_GOLDF
    mov dword ptr [rip+g_ta], 6
    mov ecx, 0
    mov edx, -17
    mov r8d, 1
    mov r9d, F_SUIT
    call gglyph
    LEAVE
