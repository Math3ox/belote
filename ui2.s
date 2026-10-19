# ============================================================
#  ui2.s — dessin des éléments de la scène, souris et clavier
# ============================================================
.text
# plane_xf : place une carte posée sur la table (projection isométrique)
draw_talon:
    ENTER
    cmp dword ptr [rip+g_np], 2
    jne 3f
    mov eax, 32
    sub eax, dword ptr [rip+g_dpos]
    jle 3f
    mov r12d, eax
    mov rax, qword ptr [rip+k_ground]
    mov qword ptr [rip+g_sq], rax
    xor r13d, r13d                          # pile : 3 dos décalés
1:  cmp r13d, 3
    jge 2f
    cvtsi2sd xmm0, r13d
    mulsd xmm0, qword ptr [rip+k_neg1]
    addsd xmm0, qword ptr [rip+k_d300]
    cvtsi2sd xmm1, r13d
    mulsd xmm1, qword ptr [rip+k_neg1]
    mulsd xmm1, qword ptr [rip+k_c05]
    movsd xmm2, qword ptr [rip+k_c352]
    addsd xmm1, xmm2
    movsd xmm2, qword ptr [rip+k_c095]
    xorpd xmm3, xmm3
    call set_xf
    call draw_back
    inc r13d
    jmp 1b
2:  call xf_reset
    call tb_reset
    lea rsi, [rip+s_talon]
    call tb_str
    mov ecx, 32
    mov eax, 32
    sub eax, dword ptr [rip+g_dpos]
    mov ecx, eax
    lea rsi, [rip+c_sp]
    call tb_str
    call tb_int
    mov dword ptr [rip+g_tc], C_WHITE
    mov dword ptr [rip+g_ta], 6
    mov ecx, 300
    mov edx, 398
    lea r8, [rip+g_tbuf]
    mov r9d, F_SMALL
    call gtext
3:  mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_BID1
    je 4f
    cmp eax, PH_BID2
    jne 5f
4:  mov rax, qword ptr [rip+k_ground]       # la retourne, face visible, au centre
    mov qword ptr [rip+g_sq], rax
    movsd xmm0, qword ptr [rip+k_c550]
    movsd xmm1, qword ptr [rip+k_c352]
    movsd xmm2, qword ptr [rip+k_c10]
    movsd xmm3, qword ptr [rip+k_c05b]
    call set_xf
    mov ecx, dword ptr [rip+g_turned]
    call draw_card
    call xf_reset
5:  LEAVE

draw_labels:
    ENTER
    xor r12d, r12d
.Ldl_p:
    cmp r12d, dword ptr [rip+g_np]
    jge .Ldl_end
    mov ecx, r12d
    call disp_pos
    mov r13d, eax                           # position
    mov ecx, r12d
    call player_name
mov r14, rsi
    lea rax, [rip+t_lx]
    mov r15d, dword ptr [rax+r13*4]
    lea rax, [rip+t_ly]
    mov ebx, dword ptr [rax+r13*4]
    mov eax, r12d                           # équipe : la nôtre en bleu
    xor eax, dword ptr [rip+g_me]
    and eax, 1
    mov ecx, C_PANEL
    mov edx, C_PLAYER
    test eax, eax
    jz 3f
    mov edx, C_ENEMY
3:  mov eax, dword ptr [rip+g_phase]        # joueur dont c'est le tour : contour doré
    cmp eax, PH_BID1
    je 4f
    cmp eax, PH_BID2
    je 4f
    cmp eax, PH_PLAY
    jne 5f
4:  cmp r12d, dword ptr [rip+g_turn]
    jne 5f
    mov edx, C_GOLD
    mov ecx, C_TURNFILL
5:  call set_cols
    mov dword ptr [rip+g_rad], 14
    lea ecx, [r15-80]
    lea edx, [rbx-3]
    mov r8d, 160
    mov r9d, 30
    call rrect
    mov dword ptr [rip+g_tc], C_WHITE
    mov dword ptr [rip+g_ta], 6
    mov ecx, r15d
    mov edx, ebx
    mov r8, r14
    mov r9d, F_LABEL
    call gtext
    cmp r12d, dword ptr [rip+g_dealer]      # jeton du donneur
    jne 6f
    mov ecx, C_GOLD
    mov edx, C_GOLDDK
    call set_cols
    lea ecx, [r15+93]
    cmp r13d, 3
    jne 7f
    lea ecx, [r15-93]
7:  mov r14d, ecx
    lea edx, [rbx+12]
    mov r8d, 13
    mov r9d, 13
    call ellipse
    mov dword ptr [rip+g_tc], C_BLACK
    mov ecx, r14d
    lea edx, [rbx+2]
    lea r8, [rip+c_dd]
    mov r9d, F_SMALL
    call gtext
6:  inc r12d
    jmp .Ldl_p
.Ldl_end:
    LEAVE

draw_opp_hands:
    ENTER
    call xf_reset
    xor r12d, r12d
.Ldo_p:
    cmp r12d, dword ptr [rip+g_np]
    jge .Ldo_end
    mov ecx, r12d
    call disp_pos
    mov r13d, eax
    test r13d, r13d
    jz .Ldo_next
    lea rax, [rip+g_hn]
    mov r14d, dword ptr [rax+r12*4]
    xor r15d, r15d
.Ldo_c:
    cmp r15d, r14d
    jge .Ldo_next
    mov esi, 24                             # pas entre les dos : 24 sur les côtés, 30 en haut
    cmp r13d, 2
    jne 1f
    mov esi, 30
1:  mov eax, r14d                           # position = i * pas - (n - 1) * pas / 2
    dec eax
    imul eax, esi
    shr eax, 1
    mov ebx, eax
    mov eax, r15d
    imul eax, esi
    sub eax, ebx
    cmp r13d, 2
    je 3f
    lea rdx, [rip+t_hy]
    add eax, dword ptr [rdx+r13*4]
    cvtsi2sd xmm1, eax
    lea rdx, [rip+t_hx]
    cvtsi2sd xmm0, dword ptr [rdx+r13*4]
    movsd xmm3, qword ptr [rip+k_1p57]
    cmp r13d, 3
    jne 4f
    movsd xmm3, qword ptr [rip+k_m1p57]
    jmp 4f
3:  lea rdx, [rip+t_hx]
    add eax, dword ptr [rdx+r13*4]
    cvtsi2sd xmm0, eax
    lea rdx, [rip+t_hy]
    cvtsi2sd xmm1, dword ptr [rdx+r13*4]
    xorpd xmm3, xmm3
4:  mov rax, qword ptr [rip+k_one]
    mov qword ptr [rip+g_sq], rax
    movsd xmm2, qword ptr [rip+k_c062]
    call set_xf
    call draw_back
    inc r15d
    jmp .Ldo_c
.Ldo_next:
    inc r12d
    jmp .Ldo_p
.Ldo_end:
    call xf_reset
    LEAVE

draw_tricks:
    ENTER
    xor r15d, r15d                          # k : ordre de jeu depuis l'entame
.Ldt_k:
    cmp r15d, dword ptr [rip+g_np]
    jge .Ldt_end
    mov eax, dword ptr [rip+g_tlead]
    add eax, r15d
    xor edx, edx
    div dword ptr [rip+g_np]
    mov r12d, edx                           # joueur
    lea rax, [rip+g_tcard]
    movzx r13d, byte ptr [rax+r12]
    cmp r13d, 0xFF
    je .Ldt_next
    mov ecx, r12d
    call disp_pos
    mov r14d, eax                           # position d'affichage
    mov eax, dword ptr [rip+g_now]          # t : progression du vol, 0..1 sur 420 ms
    lea rdx, [rip+g_ast0]
    sub eax, dword ptr [rdx+r12*4]
    cvtsi2sd xmm4, eax
    divsd xmm4, qword ptr [rip+k_d420]
    xorpd xmm5, xmm5
    maxsd xmm4, xmm5
    minsd xmm4, qword ptr [rip+k_one]
    movsd qword ptr [rsp+96], xmm4
    movsd xmm5, qword ptr [rip+k_one]       # e = 1 - (1 - t)^3 : arrivée en décélérant
    subsd xmm5, xmm4
    movapd xmm6, xmm5
    mulsd xmm6, xmm5
    mulsd xmm6, xmm5
    movsd xmm7, qword ptr [rip+k_one]
    subsd xmm7, xmm6
    movsd qword ptr [rsp+104], xmm7
    movapd xmm0, xmm4                       # sin(pi t) : hauteur du vol
    mulsd xmm0, qword ptr [rip+k_pi]
    call sincos_d
    movsd qword ptr [rsp+112], xmm0
    lea rax, [rip+t_tx]
    cvtsi2sd xmm0, dword ptr [rax+r14*4]
    lea rax, [rip+t_ty]
    cvtsi2sd xmm1, dword ptr [rax+r14*4]
    movsd qword ptr [rsp+120], xmm0         # arrivée
    movsd qword ptr [rsp+128], xmm1
    movsd xmm0, qword ptr [rip+k_one]
    movsd qword ptr [rsp+136], xmm0         # facteur d'échelle de la collecte
    cmp dword ptr [rip+g_collect], 0
    je 2f
    call trick_best                         # le pli glisse vers son gagnant en rétrécissant un peu
    mov ecx, eax
    call disp_pos
    mov ebx, eax
    mov eax, dword ptr [rip+g_now]
    sub eax, dword ptr [rip+g_collect]
    cvtsi2sd xmm4, eax
    divsd xmm4, qword ptr [rip+k_d300]
    xorpd xmm5, xmm5
    maxsd xmm4, xmm5
    minsd xmm4, qword ptr [rip+k_one]
    mulsd xmm4, xmm4                        # accélère
    lea rax, [rip+t_hx]
    cvtsi2sd xmm0, dword ptr [rax+rbx*4]
    subsd xmm0, qword ptr [rsp+120]
    mulsd xmm0, xmm4
    addsd xmm0, qword ptr [rsp+120]
    movsd qword ptr [rsp+120], xmm0
    lea rax, [rip+t_hy]
    cvtsi2sd xmm1, dword ptr [rax+rbx*4]
    subsd xmm1, qword ptr [rsp+128]
    mulsd xmm1, xmm4
    addsd xmm1, qword ptr [rsp+128]
    movsd qword ptr [rsp+128], xmm1
    movsd xmm0, qword ptr [rip+k_c03]
    mulsd xmm0, xmm4
    movsd xmm1, qword ptr [rip+k_one]
    subsd xmm1, xmm0
    movsd qword ptr [rsp+136], xmm1
2:  lea rax, [rip+g_asx]                    # position = départ + (arrivée - départ) * e, moins la hauteur du vol
    cvtsi2sd xmm0, dword ptr [rax+r12*4]
    lea rax, [rip+g_asy]
    cvtsi2sd xmm1, dword ptr [rax+r12*4]
    movsd xmm6, qword ptr [rsp+104]
    movsd xmm2, qword ptr [rsp+120]
    subsd xmm2, xmm0
    mulsd xmm2, xmm6
    addsd xmm0, xmm2
    movsd xmm3, qword ptr [rsp+128]
    subsd xmm3, xmm1
    mulsd xmm3, xmm6
    addsd xmm1, xmm3
    movsd qword ptr [rsp+144], xmm0
    movsd qword ptr [rsp+152], xmm1         # y au sol (sans la hauteur)
    movsd xmm0, qword ptr [rsp+112]         # ombre portée au sol pendant le vol
    comisd xmm0, qword ptr [rip+k_c002]
    jbe 4f
    call xf_reset
    mov ecx, C_SHFLY
    mov edx, C_SHFLY
    call set_cols
    movsd xmm0, qword ptr [rsp+112]
    mulsd xmm0, qword ptr [rip+k_c34]
    addsd xmm0, qword ptr [rip+k_c30]
    cvtsd2si r8d, xmm0                      # rx = 30 + 34 sin
    movsd xmm1, qword ptr [rsp+152]
    addsd xmm1, qword ptr [rip+k_c8]
    cvtsd2si edx, xmm1
    movsd xmm0, qword ptr [rsp+144]
    addsd xmm0, qword ptr [rip+k_c8]
    cvtsd2si ecx, xmm0
    mov r9d, r8d
    shr r9d, 1
    mov eax, r9d
    shr eax, 2
    add r9d, eax
    call ellipse
4:  movsd xmm4, qword ptr [rsp+112]         # y = sol - 64 sin(pi t)
    mulsd xmm4, qword ptr [rip+k_lift]
    movsd xmm1, qword ptr [rsp+152]
    subsd xmm1, xmm4
    movsd xmm0, qword ptr [rsp+144]
    movsd xmm6, qword ptr [rsp+104]
    movsd xmm2, qword ptr [rip+k_c062]      # échelle de départ : 0.62 (bots) ou celle de la main
    test r14d, r14d
    jnz 3f
    movsd xmm2, qword ptr [rip+k_chand]
3:  movsd xmm3, qword ptr [rip+k_c10]
    subsd xmm3, xmm2
    mulsd xmm3, xmm6
    addsd xmm2, xmm3                        # échelle -> 1.0
    movsd xmm3, qword ptr [rsp+112]
    mulsd xmm3, qword ptr [rip+k_c014]
    addsd xmm2, xmm3                        # la carte grossit en volant (vers le joueur)
    mulsd xmm2, qword ptr [rsp+136]
    movsd xmm4, qword ptr [rip+k_ground]    # écrasement : 1 -> 0.62
    movsd xmm5, qword ptr [rip+k_one]
    subsd xmm4, xmm5
    mulsd xmm4, xmm6
    addsd xmm5, xmm4
    movsd qword ptr [rip+g_sq], xmm5
    lea rax, [rip+t_ang]                    # tourne en vol : de 5 x l'angle final à l'angle final
    movsd xmm3, qword ptr [rax+r14*8]
    movsd xmm4, qword ptr [rip+k_c5]
    movsd xmm5, qword ptr [rip+k_c4]
    mulsd xmm5, xmm6
    subsd xmm4, xmm5
    mulsd xmm3, xmm4
    call set_xf
    mov ecx, r13d
    call draw_card
.Ldt_next:
    inc r15d
    jmp .Ldt_k
.Ldt_end:
    call xf_reset
    LEAVE

hand_hit:                                   # (g_mx, g_my) -> eax = indice de la carte du bas sous la souris, -1
    ENTER
    mov ecx, dword ptr [rip+g_me]
    lea rax, [rip+g_hn]
    mov r12d, dword ptr [rax+rcx*4]
    mov eax, dword ptr [rip+g_my]
    cmp eax, 610
    jl .Lhh_none
    cmp eax, 764
    jg .Lhh_none
    mov r13d, r12d
.Lhh_l:
    dec r13d
    js .Lhh_none
    mov ecx, r13d
    mov edx, r12d
    call hand_cx
    mov edx, dword ptr [rip+g_mx]
    sub edx, eax
    add edx, 52
    js .Lhh_l
    cmp edx, 104
    jg .Lhh_l
    mov eax, r13d
    LEAVE
.Lhh_none:
    mov eax, -1
    LEAVE

draw_my_hand:
    ENTER
    mov dword ptr [rip+g_dim], 0
    mov r15d, dword ptr [rip+g_me]
    lea rax, [rip+g_hn]
    mov r12d, dword ptr [rax+r15*4]
    mov r14d, -1                            # tout est jouable sauf si c'est à nous de jouer
    cmp dword ptr [rip+g_phase], PH_PLAY
    jne 1f
    mov ecx, dword ptr [rip+g_turn]
    cmp ecx, r15d
    jne 1f
    call legal_mask
    mov r14d, eax
1:  xor r13d, r13d
.Ldm_c:
    cmp r13d, r12d
    jge .Ldm_end
    mov ecx, r13d
    mov edx, r12d
    call hand_cx
    cvtsi2sd xmm0, eax
    mov eax, 686
    cmp r13d, dword ptr [rip+g_hover]
    jne 2f
    bt r14d, r13d
    jnc 2f
    sub eax, 18
2:  cmp r13d, dword ptr [rip+g_hint]
    jne 3f
    sub eax, 14
3:  cvtsi2sd xmm1, eax
    mov rax, qword ptr [rip+k_one]
    mov qword ptr [rip+g_sq], rax
    movsd xmm2, qword ptr [rip+k_chand]
    xorpd xmm3, xmm3
    movsd qword ptr [rsp+96], xmm0
    movsd qword ptr [rsp+104], xmm1
    mov dword ptr [rip+g_dim], 0
    bt r14d, r13d
    jc 4f
    mov dword ptr [rip+g_dim], 1
4:  cmp r13d, dword ptr [rip+g_hint]        # halo doré sous la carte conseillée
    jne 5f
    call set_xf
    mov ecx, C_GOLD
    mov edx, C_GOLD
    call set_cols
    mov dword ptr [rip+g_rad], 16
    mov ecx, -56
    mov edx, -76
    mov r8d, 112
    mov r9d, 152
    call rrect
    movsd xmm0, qword ptr [rsp+96]
    movsd xmm1, qword ptr [rsp+104]
    movsd xmm2, qword ptr [rip+k_chand]
    xorpd xmm3, xmm3
5:  call set_xf
    lea rax, [rip+g_hand]
    lea rdx, [rax+r15*8]
    movzx ecx, byte ptr [rdx+r13]
    call draw_card
    inc r13d
    jmp .Ldm_c
.Ldm_end:
    mov dword ptr [rip+g_dim], 0
    call xf_reset
    LEAVE

draw_panels:
    ENTER
    mov ecx, C_PANEL                        # score
    mov edx, C_PANELLN
    call set_cols
    mov dword ptr [rip+g_rad], 14
    mov ecx, 14
    mov edx, 12
    mov r8d, 262
    mov r9d, 96
    call rrect
    mov r12d, dword ptr [rip+g_me]
    and r12d, 1                             # notre équipe
    mov dword ptr [rip+g_ta], 0
    mov dword ptr [rip+g_tc], C_PLAYER
    mov ecx, 30
    mov edx, 20
    lea r8, [rip+s_nous]
    cmp dword ptr [rip+g_np], 2
    jne 1f
    lea r8, [rip+s_toi]
1:  mov r9d, F_MED
    call gtext
    mov dword ptr [rip+g_tc], C_ENEMY
    mov ecx, 30
    mov edx, 54
    lea r8, [rip+s_eux]
    cmp dword ptr [rip+g_np], 2
    jne 2f
    lea r8, [rip+s_bot]
2:  mov r9d, F_MED
    call gtext
    mov dword ptr [rip+g_ta], 2             # chiffres alignés à droite
    mov dword ptr [rip+g_tc], C_WHITE
    call tb_reset
    lea rax, [rip+g_score]
    mov ecx, dword ptr [rax+r12*4]
    call tb_int
    mov ecx, 262
    mov edx, 20
    lea r8, [rip+g_tbuf]
    mov r9d, F_MED
    call gtext
    call tb_reset
    mov eax, r12d
    xor eax, 1
    lea rdx, [rip+g_score]
    mov ecx, dword ptr [rdx+rax*4]
    call tb_int
    mov ecx, 262
    mov edx, 54
    lea r8, [rip+g_tbuf]
    mov r9d, F_MED
    call gtext
    mov dword ptr [rip+g_ta], 0             # objectif et niveau
    mov dword ptr [rip+g_tc], C_TXTDIM
    call tb_reset
    lea rsi, [rip+s_obj]
    call tb_str
    mov ecx, dword ptr [rip+g_target]
    call tb_int
    lea rsi, [rip+s_stv]
    call tb_str
    mov ecx, dword ptr [rip+g_wins]
    call tb_int
    lea rsi, [rip+s_std]
    call tb_str
    mov ecx, dword ptr [rip+g_wins+4]
    call tb_int
    mov ecx, 30
    mov edx, 88
    lea r8, [rip+g_tbuf]
    mov r9d, F_SMALL
    call gtext
    mov ecx, C_PANEL                        # atout
    mov edx, C_PANELLN
    call set_cols
    mov dword ptr [rip+g_rad], 14
    mov ecx, 824
    mov edx, 12
    mov r8d, 262
    mov r9d, 96
    call rrect
    mov dword ptr [rip+g_ta], 0
    mov dword ptr [rip+g_tc], C_TXTDIM
    mov ecx, 842
    mov edx, 18
    lea r8, [rip+s_atout]
    mov r9d, F_LABEL
    call gtext
    mov eax, dword ptr [rip+g_trump]
    mov r13d, eax
    test eax, eax
    jns 3f
    mov eax, dword ptr [rip+g_turned]       # pendant les enchères : couleur de la retourne en grisé
    shr eax, 3
    mov dword ptr [rip+g_tc], C_TXTDIM
    jmp 4f
3:  mov ecx, eax
    lea rdx, [rip+t_isred]
    mov dword ptr [rip+g_tc], C_WHITE
    cmp byte ptr [rdx+rax], 0
    je 4f
    mov dword ptr [rip+g_tc], 0x006478FF
4:  mov r14d, eax
    mov dword ptr [rip+g_ta], 6
    mov ecx, 1048
    mov edx, 30
    mov r8d, r14d
    mov r9d, F_SYM2
    call gglyph
    test r13d, r13d
    js 5f
    mov dword ptr [rip+g_ta], 0
    mov dword ptr [rip+g_tc], C_TXT
    call tb_reset
    lea rsi, [rip+s_pris]
    call tb_str
    mov eax, dword ptr [rip+g_taker]
    sub eax, dword ptr [rip+g_me]
    add eax, dword ptr [rip+g_np]
    xor edx, edx
    div dword ptr [rip+g_np]
    lea rsi, [rip+s_toi]
    test edx, edx
    jz 6f
    lea rsi, [rip+s_bot]
    cmp dword ptr [rip+g_np], 2
    je 6f
    lea rsi, [rip+s_adv1]
    cmp edx, 1
    je 6f
    lea rsi, [rip+s_part]
    cmp edx, 2
    je 6f
    lea rsi, [rip+s_adv2]
6:  call tb_str
    mov ecx, 842
    mov edx, 54
    lea r8, [rip+g_tbuf]
    mov r9d, F_SMALL
    call gtext
5:  LEAVE

draw_buttons:
    ENTER
    call build_buttons
    xor r12d, r12d
1:  cmp r12d, dword ptr [rip+g_nbtn]
    jge 9f
    mov eax, r12d
    shl eax, 5
    lea rsi, [rip+g_btn]
    add rsi, rax
    mov eax, dword ptr [rsi+16]
    lea r8, [rip+s_prendre]
    test eax, eax
    jz 3f
    cmp eax, 5
    jne 2f
    lea r8, [rip+s_passer]
    jmp 3f
2:  cmp eax, 6
    jne 4f
    lea r8, [rip+s_suite]
    cmp dword ptr [rip+g_phase], PH_MATCHEND
    jne 3f
    lea r8, [rip+s_newgame]
    jmp 3f
4:  dec eax
    lea rdx, [rip+t_suitnm]
    mov r8, qword ptr [rdx+rax*8]
3:  call draw_btn
    inc r12d
    jmp 1b
9:  LEAVE

draw_bubbles:
    ENTER
    xor r12d, r12d
1:  cmp r12d, dword ptr [rip+g_np]
    jge 9f
    lea rax, [rip+g_bubt]
    mov r13, qword ptr [rax+r12*8]
    test r13, r13
    jz 8f
    lea rax, [rip+g_bube]
    mov eax, dword ptr [rax+r12*4]
    sub eax, dword ptr [rip+g_now]
    js 8f
    mov ecx, r12d
    call disp_pos
    mov r14d, eax
    mov rsi, r13
    call strlen_z
    imul r15d, eax, 10
    add r15d, 34                            # largeur
    lea rax, [rip+t_bx]
    mov ebx, dword ptr [rax+r14*4]
    lea rax, [rip+t_by]
    mov esi, dword ptr [rax+r14*4]
    mov ecx, C_IVORY
    mov edx, C_CARDLN
    call set_cols
    mov dword ptr [rip+g_rad], 14
    mov eax, r15d
    shr eax, 1
    mov ecx, ebx
    sub ecx, eax
    lea edx, [rsi-18]
    mov r8d, r15d
    mov r9d, 36
    call rrect
    mov dword ptr [rip+g_tc], C_BLACK
    mov dword ptr [rip+g_ta], 6
    mov ecx, ebx
    lea edx, [rsi-12]
    mov r8, r13
    mov r9d, F_LABEL
    call gtext
8:  inc r12d
    jmp 1b
9:  LEAVE

draw_message:
    ENTER
    lea r12, [rip+s_m_wait]
    mov eax, dword ptr [rip+g_phase]
    mov ecx, dword ptr [rip+g_turn]
    call is_human
    mov r13d, eax
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_BID1
    jne 1f
    test r13d, r13d
    jz .Ldmsg
    lea r12, [rip+s_m_bid1]
    cmp dword ptr [rip+g_help], 0
    je .Ldmsg
    call advice_bid
    jmp .Ldmsg
1:  cmp eax, PH_BID2
    jne 2f
    test r13d, r13d
    jz .Ldmsg
    lea r12, [rip+s_m_bid2]
    cmp dword ptr [rip+g_help], 0
    je .Ldmsg
    call advice_bid
    jmp .Ldmsg
2:  cmp eax, PH_PLAY
    jne 3f
    test r13d, r13d
    jz .Ldmsg
    lea r12, [rip+s_m_play]
    cmp dword ptr [rip+g_tn], 0
    jne .Ldmsg
    lea r12, [rip+s_m_lead]
    jmp .Ldmsg
3:  lea r12, [rip+s_m_next]
    mov ecx, dword ptr [rip+g_me]
    mov eax, 1
    shl eax, cl
    test eax, dword ptr [rip+g_nextmask]
    jz .Ldmsg
    lea r12, [rip+n_wnext]
.Ldmsg:
    mov dword ptr [rip+g_tc], C_TXT
    mov dword ptr [rip+g_ta], 6
    mov ecx, 550
    mov edx, 764
    mov r8, r12
    mov r9d, F_LABEL
    call gtext
    mov dword ptr [rip+g_tc], C_TXTDIM
    mov ecx, 550
    mov edx, 782
    lea r8, [rip+g_optline]
    mov r9d, F_SMALL
    call gtext
    LEAVE

advice_bid:                                 # -> r12 = texte de conseil pour l'enchère du joueur local
    ENTER
    mov ecx, dword ptr [rip+g_turn]
    call bot_bid
    mov r13d, eax
    call tb_reset
    lea rsi, [rip+s_conseil]
    call tb_str
    cmp r13d, -1
    jne 1f
    lea rsi, [rip+s_cpasse]
    call tb_str
    jmp 2f
1:  lea rsi, [rip+s_cprend]
    call tb_str
    lea rdx, [rip+t_suitnm]
    mov rsi, qword ptr [rdx+r13*8]
    call tb_str
2:  lea rsi, [rip+g_tbuf]
    lea rdi, [rip+g_msgbuf2]
    mov r12, rdi
3:  mov al, byte ptr [rsi]
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz 3b
    LEAVE

build_optline:                              # ligne des réglages
    ENTER
    call tb_reset
    lea rsi, [rip+s_o1]
    call tb_str
    mov ecx, dword ptr [rip+g_np]
    call tb_int
    lea rsi, [rip+s_o2]
    call tb_str
    mov eax, dword ptr [rip+g_botlvl]
    lea rdx, [rip+t_lvlnm]
    mov rsi, qword ptr [rdx+rax*8]
    call tb_str
    lea rsi, [rip+s_o3]
    call tb_str
    lea rsi, [rip+s_on]
    cmp dword ptr [rip+g_optann], 0
    jne 1f
    lea rsi, [rip+s_off]
1:  call tb_str
    lea rsi, [rip+s_o4]
    call tb_str
    lea rsi, [rip+s_on]
    cmp dword ptr [rip+g_help], 0
    jne 2f
    lea rsi, [rip+s_off]
2:  call tb_str
    lea rsi, [rip+s_o5]
    call tb_str
    lea rsi, [rip+g_tbuf]
    lea rdi, [rip+g_optline]
3:  mov al, byte ptr [rsi]
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz 3b
    LEAVE

player_name:                                # ecx = joueur -> rsi = nom
    mov r9d, ecx
    mov eax, ecx
    sub eax, dword ptr [rip+g_me]
    add eax, dword ptr [rip+g_np]
    xor edx, edx
    div dword ptr [rip+g_np]
    lea rsi, [rip+s_toi]
    test edx, edx
    jz 1f
    lea rax, [rip+g_lvl]                    # autre humain : JOUEUR n
    cmp dword ptr [rax+r9*4], -1
    jne 2f
    lea rsi, [rip+t_jname]
    mov eax, r9d
    shl eax, 4
    add rsi, rax
    jmp 1f
2:  lea rsi, [rip+s_bot]
    cmp dword ptr [rip+g_np], 2
    je 1f
    lea rsi, [rip+s_adv1]
    cmp edx, 1
    je 1f
    lea rsi, [rip+s_part]
    cmp edx, 2
    je 1f
    lea rsi, [rip+s_adv2]
1:  ret

draw_overlay:
    ENTER
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_ROUNDEND
    je 1f
    cmp eax, PH_MATCHEND
    jne .Ldov_end
1:  mov r15d, dword ptr [rip+g_me]
    and r15d, 1                             # notre équipe
    mov ecx, C_OVER
    mov edx, C_PANELLN
    call set_cols
    mov dword ptr [rip+g_rad], 20
    mov ecx, 250
    mov edx, 110
    mov r8d, 600
    mov r9d, 430
    call rrect
    mov dword ptr [rip+g_ta], 6
    mov dword ptr [rip+g_tc], C_GOLD
    lea r8, [rip+s_manche]
    cmp dword ptr [rip+g_phase], PH_MATCHEND
    jne 2f
    lea r8, [rip+s_win]
    mov eax, dword ptr [rip+g_rs_winner]
    cmp eax, r15d
    je 2f
    lea r8, [rip+s_lose]
2:  mov ecx, 550
    mov edx, 124
    mov r9d, F_TITLE
    call gtext
    mov dword ptr [rip+g_tc], C_WHITE       # contrat
    lea r8, [rip+s_made]
    mov eax, dword ptr [rip+g_rs_made]
    cmp eax, 1
    je 3f
    lea r8, [rip+s_dedans]
    test eax, eax
    jz 3f
    lea r8, [rip+s_litige]
3:  mov ecx, 550
    mov edx, 184
    mov r9d, F_MED
    call gtext
    call tb_reset                           # preneur et atout
    lea rsi, [rip+s_preneur]
    call tb_str
    mov ecx, dword ptr [rip+g_taker]
    call player_name
    call tb_str
    lea rsi, [rip+s_atoutn]
    call tb_str
    mov eax, dword ptr [rip+g_trump]
    lea rdx, [rip+t_suitnm]
    mov rsi, qword ptr [rdx+rax*8]
    call tb_str
    mov dword ptr [rip+g_ta], 6
    mov dword ptr [rip+g_tc], C_TXTDIM
    mov ecx, 550
    mov edx, 208
    lea r8, [rip+g_tbuf]
    mov r9d, F_SMALL
    call gtext
    mov dword ptr [rip+g_ta], 2             # en-têtes de colonnes
    mov dword ptr [rip+g_tc], C_PLAYER
    mov ecx, 640
    mov edx, 238
    lea r8, [rip+s_nous]
    cmp dword ptr [rip+g_np], 2
    jne 4f
    lea r8, [rip+s_toi]
4:  mov r9d, F_LABEL
    call gtext
    mov dword ptr [rip+g_tc], C_ENEMY
    mov ecx, 810
    mov edx, 238
    lea r8, [rip+s_eux]
    cmp dword ptr [rip+g_np], 2
    jne 5f
    lea r8, [rip+s_bot]
5:  mov r9d, F_LABEL
    call gtext
    xor r12d, r12d                          # lignes
.Ldov_row:
    cmp r12d, 6
    jge .Ldov_after
    mov eax, r12d
    imul eax, eax, 34
    add eax, 276
    mov r13d, eax                           # y
    lea rdx, [rip+t_rowtxt]
    mov r14, qword ptr [rdx+r12*8]
    mov dword ptr [rip+g_ta], 0
    mov dword ptr [rip+g_tc], C_TXT
    cmp r12d, 3
    jl 6f
    mov dword ptr [rip+g_tc], C_GOLD
6:  mov ecx, 290
    mov edx, r13d
    mov r8, r14
    mov r9d, F_LABEL
    call gtext
    xor ebx, ebx                            # colonne 0 = nous, 1 = eux
.Ldov_col:
    mov eax, ebx
    xor eax, r15d                           # équipe correspondante
    mov esi, eax
    lea rdx, [rip+t_rowsrc]
    mov rdx, qword ptr [rdx+r12*8]
    mov ecx, dword ptr [rdx+rsi*4]
    call tb_reset
    call tb_int
    mov dword ptr [rip+g_ta], 2
    mov dword ptr [rip+g_tc], C_WHITE
    mov ecx, 640
    test ebx, ebx
    jz 7f
    mov ecx, 810
7:  mov edx, r13d
    lea r8, [rip+g_tbuf]
    mov r9d, F_LABEL
    call gtext
    inc ebx
    cmp ebx, 2
    jb .Ldov_col
    inc r12d
    jmp .Ldov_row
.Ldov_after:
    cmp dword ptr [rip+g_rs_capot], 0
    jl .Ldov_end
    mov dword ptr [rip+g_ta], 6
    mov dword ptr [rip+g_tc], C_GOLD
    mov ecx, 550
    mov edx, 495
    lea r8, [rip+s_r_capot]
    mov r9d, F_LABEL
    call gtext
.Ldov_end:
    LEAVE

render_scene:
    ENTER
    call xf_reset
    call draw_table
    cmp dword ptr [rip+g_gallery], 0
    je 1f
    call draw_gallery
    LEAVE
1:
    call draw_talon
    call draw_labels
    call draw_opp_hands
    call draw_tricks
    call draw_my_hand
    call draw_panels
    call draw_bubbles
    call draw_overlay
    call draw_buttons
    call draw_message
    call draw_netpanel
    LEAVE

# ---------- souris / clavier ----------
ui_move:                                    # g_mx, g_my à jour
    ENTER
    call hand_hit
    cmp eax, dword ptr [rip+g_hover]
    je 1f
    mov dword ptr [rip+g_hover], eax
    mov dword ptr [rip+g_dirty], 1
1:  mov dword ptr [rip+g_dirty], 1          # survol des boutons
    LEAVE

btn_action:                                 # ecx = id du bouton
    ENTER
    cmp ecx, 6
    je .Lba_next
    cmp ecx, 5
    jne 1f
    mov ecx, -1
    call human_bid
    jmp .Lba_end
1:  test ecx, ecx
    jnz 2f
    mov ecx, dword ptr [rip+g_turned]
    shr ecx, 3
    call human_bid
    jmp .Lba_end
2:  dec ecx
    call human_bid
    jmp .Lba_end
.Lba_next:
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_MATCHEND
    je 3f
    cmp eax, PH_ROUNDEND
    jne .Lba_end
3:  call human_next
.Lba_end:
    mov dword ptr [rip+g_dirty], 1
    LEAVE

ui_click:
    ENTER
    cmp dword ptr [rip+g_menu], 0
    jne .Luc_end
    mov eax, dword ptr [rip+g_net]
    cmp eax, 1
    jb 4f
    cmp eax, 3
    jbe .Luc_end
4:  call build_buttons
    xor r12d, r12d
1:  cmp r12d, dword ptr [rip+g_nbtn]
    jge 3f
    mov eax, r12d
    shl eax, 5
    lea rsi, [rip+g_btn]
    add rsi, rax
    cmp dword ptr [rsi+20], 0
    je 2f
    mov eax, dword ptr [rip+g_mx]
    cmp eax, dword ptr [rsi]
    jl 2f
    sub eax, dword ptr [rsi]
    cmp eax, dword ptr [rsi+8]
    jg 2f
    mov eax, dword ptr [rip+g_my]
    cmp eax, dword ptr [rsi+4]
    jl 2f
    sub eax, dword ptr [rsi+4]
    cmp eax, dword ptr [rsi+12]
    jg 2f
    mov ecx, dword ptr [rsi+16]
    call btn_action
    jmp .Luc_end
2:  inc r12d
    jmp 1b
3:  cmp dword ptr [rip+g_phase], PH_PLAY
    jne .Luc_end
    mov ecx, dword ptr [rip+g_turn]
    call is_human
    test eax, eax
    jz .Luc_end
    call hand_hit
    test eax, eax
    js .Luc_end
    mov r12d, eax
    mov ecx, dword ptr [rip+g_turn]
    call legal_mask
    bt eax, r12d
    jnc .Luc_end
    mov ecx, r12d
    call human_play
    mov dword ptr [rip+g_hover], -1
.Luc_end:
    mov dword ptr [rip+g_dirty], 1
    LEAVE

ui_help:                                    # conseil pour la carte à jouer
    ENTER
    mov dword ptr [rip+g_hint], -1
    cmp dword ptr [rip+g_help], 0
    je 1f
    cmp dword ptr [rip+g_phase], PH_PLAY
    jne 1f
    mov ecx, dword ptr [rip+g_turn]
    call is_human
    test eax, eax
    jz 1f
    mov ecx, dword ptr [rip+g_turn]
    call bot_card
    mov dword ptr [rip+g_hint], eax
1:  mov dword ptr [rip+g_dirty], 1
    LEAVE

.section .rdata,"dr"
.balign 8
k_c352:     .double 352.0
k_c550:     .double 550.0
k_c05b:     .double 0.05
c_sp:       .asciz " : "
s_stv:      .asciz "   -   victoires "
s_std:      .asciz " / d\351faites "
s_conseil:  .asciz "Conseil : "
s_cpasse:   .asciz "passer"
s_cprend:   .asciz "prendre, atout "
s_preneur:  .asciz "Preneur : "
s_atoutn:   .asciz "   -   atout : "
c_dd:       .asciz "D"
s_o1:       .asciz "J: "
s_o2:       .asciz " joueurs   L: niveau "
s_o3:       .asciz "   A: annonces "
s_o4:       .asciz "   H: aide "
s_o5:       .asciz "   F11: plein \351cran   N: en ligne   Echap: quitter"
s_on:       .asciz "oui"
s_off:      .asciz "non"
.balign 16
t_jname:    .asciz "JOUEUR 1"
.balign 16
            .asciz "JOUEUR 2"
.balign 16
            .asciz "JOUEUR 3"
.balign 16
            .asciz "JOUEUR 4"
.balign 8
t_rowtxt:   .quad s_r_pli, s_r_bel, s_r_ann, s_r_tot, s_r_add, s_r_sc
t_rowsrc:   .quad g_rpts, g_bel, g_ann, g_rs_tot, g_rs_add, g_score
.bss
g_optline:  .skip 160

.text
draw_netpanel:
    ENTER
    cmp dword ptr [rip+g_menu], 0
    jne 1f
    mov eax, dword ptr [rip+g_net]
    cmp eax, 1
    jb .Ldn_end
    cmp eax, 3
    ja .Ldn_end
1:  mov ecx, C_OVER
    mov edx, C_PANELLN
    call set_cols
    mov dword ptr [rip+g_rad], 18
    mov ecx, 120
    mov edx, 230
    mov r8d, 860
    mov r9d, 230
    call rrect
    mov dword ptr [rip+g_ta], 6
    mov dword ptr [rip+g_tc], C_GOLD
    mov ecx, 550
    mov edx, 248
    lea r8, [rip+n_menu1]
    mov r9d, F_MED
    call gtext
    mov dword ptr [rip+g_tc], C_WHITE
    cmp dword ptr [rip+g_menu], 1
    jne 2f
    mov ecx, 550
    mov edx, 310
    lea r8, [rip+n_menu2]
    mov r9d, F_LABEL
    call gtext
    mov dword ptr [rip+g_tc], C_TXTDIM
    mov ecx, 550
    mov edx, 350
    lea r8, [rip+n_menu3]
    mov r9d, F_SMALL
    call gtext
    jmp .Ldn_end
2:  mov ecx, 550
    mov edx, 300
    lea r8, [rip+g_nl1]
    mov r9d, F_LABEL
    call gtext
    mov dword ptr [rip+g_tc], C_TXTDIM
    mov ecx, 550
    mov edx, 345
    lea r8, [rip+g_nl2]
    mov r9d, F_SMALL
    call gtext
    mov dword ptr [rip+g_tc], C_WHITE
    mov ecx, 550
    mov edx, 385
    lea r8, [rip+g_nl3]
    mov r9d, F_SMALL
    call gtext
.Ldn_end:
    LEAVE

.text
draw_gallery:                               # touche G : les 32 cartes et le dos (contrôle du dessin)
    ENTER
    mov rax, qword ptr [rip+k_one]
    mov qword ptr [rip+g_sq], rax
    mov dword ptr [rip+g_dim], 0
    xor r12d, r12d
1:  cmp r12d, 33
    jge 9f
    mov eax, r12d
    and eax, 7
    imul eax, eax, 126
    add eax, 118
    cvtsi2sd xmm0, eax
    mov eax, r12d
    shr eax, 3
    imul eax, eax, 150
    add eax, 100
    cvtsi2sd xmm1, eax
    movsd xmm2, qword ptr [rip+k_c09]
    xorpd xmm3, xmm3
    call set_xf
    cmp r12d, 32
    je 2f
    mov ecx, r12d
    call draw_card
    jmp 3f
2:  call draw_back
3:  inc r12d
    jmp 1b
9:  call xf_reset
    LEAVE
.data
g_gallery:  .long 0
