# ============================================================
#  ui.s — interface : table, mains, plis animés, boutons, bulles, déroulement de la partie contre les bots
# ============================================================
.section .rdata,"dr"
.balign 8
k_d280:     .double 280.0
k_d300:     .double 300.0
k_c09:      .double 0.9
k_c055:     .double 0.55
k_c05:      .double 0.5
k_d420:     .double 420.0
k_pi:       .double 3.141592653589793
k_lift:     .double 64.0
k_c014:     .double 0.14
k_chand:    .double 1.04
k_c062:     .double 0.62
k_c10:      .double 1.0
k_c095:     .double 0.95
k_c002:     .double 0.02
k_c5:       .double 5.0
k_c4:       .double 4.0
k_c03:      .double 0.3
k_c34:      .double 34.0
k_c30:      .double 30.0
k_c8:       .double 8.0
k_c085:     .double 0.85
k_1p57:     .double 1.5707963267948966
k_m1p57:    .double -1.5707963267948966
t_hx:       .long 550, 92, 550, 1008          # centre de la main (bas, gauche, haut, droite)
t_hy:       .long 686, 345, 96, 345
t_tx:       .long 550, 464, 550, 636          # arrivée de la carte dans le pli
t_ty:       .long 402, 352, 302, 352
t_bx:       .long 550, 215, 550, 885          # bulles
t_by:       .long 598, 345, 172, 345
t_lx:       .long 130, 92, 550, 1008          # étiquettes
t_ly:       .long 742, 214, 24, 214
t_ang:      .double -0.06, 0.09, 0.04, -0.10
t_suitnm:   .quad s_pique, s_coeur, s_carreau, s_trefle

s_pique:    .asciz "Pique"
s_coeur:    .asciz "C\234ur"
s_carreau:  .asciz "Carreau"
s_trefle:   .asciz "Tr\350fle"
s_toi:      .asciz "TOI"
s_bot:      .asciz "BOT"
s_part:     .asciz "PARTENAIRE"
s_adv1:     .asciz "ADVERSAIRE 1"
s_adv2:     .asciz "ADVERSAIRE 2"
s_nous:     .asciz "NOUS"
s_eux:      .asciz "EUX"
s_passe:    .asciz "Je passe"
s_prends:   .asciz "Je prends : "
s_belote:   .asciz "Belote !"
s_rebelote: .asciz "Rebelote !"
s_prendre:  .asciz "PRENDRE"
s_passer:   .asciz "PASSER"
s_suite:    .asciz "SUITE"
s_newgame:  .asciz "NOUVELLE PARTIE"
s_atout:    .asciz "ATOUT"
s_obj:      .asciz "Objectif "
s_pris:     .asciz "pris par "
s_tierce:   .asciz "Tierce"
s_cinq:     .asciz "Cinquante"
s_cent:     .asciz "Cent"
s_carre:    .asciz "Carr\351"
s_ann:      .asciz "Annonce : "
t_annnm:    .quad 0, s_tierce, s_cinq, s_cent, s_carre
s_m_bid1:   .asciz "Prendre la carte retourn\351e comme atout, ou passer ?"
s_m_bid2:   .asciz "Choisis une autre couleur d'atout, ou passe."
s_m_wait:   .asciz "Les autres r\351fl\351chissent..."
s_m_play:   .asciz "\300 toi de jouer : clique sur une carte."
s_m_next:   .asciz "Espace : suite"
s_m_lead:   .asciz "Tu ouvres : joue la carte de ton choix."
s_m_must:   .asciz "Tu dois fournir la couleur, couper ou monter."
s_made:     .asciz "CONTRAT REMPLI"
s_dedans:   .asciz "DEDANS !"
s_litige:   .asciz "LITIGE"
s_manche:   .asciz "FIN DE MANCHE"
s_win:      .asciz "VICTOIRE !"
s_lose:     .asciz "D\351faite..."
s_r_pli:    .asciz "Points des plis"
s_r_bel:    .asciz "Belote-rebelote"
s_r_ann:    .asciz "Annonces"
s_r_tot:    .asciz "Total"
s_r_add:    .asciz "Marqu\351"
s_r_sc:     .asciz "Score"
s_r_capot:  .asciz "CAPOT ! (+90)"
s_r_pend:   .asciz "Litige pr\351c\351dent r\351cup\351r\351 : +"
s_hint:     .asciz "Conseil"
s_opts:     .asciz "J: 4 joueurs / \340 deux   L: niveau   A: annonces   H: aide   F11: plein \351cran   N: en ligne   Echap: quitter"
s_lvl0:     .asciz "facile"
s_lvl1:     .asciz "normal"
s_lvl2:     .asciz "difficile"
t_lvlnm:    .quad s_lvl0, s_lvl1, s_lvl2
s_title:    .asciz "Belote - jeu du bistro en 3D isom\351trique"
s_cls:      .asciz "BeloteWin"
s_talon:    .asciz "TALON"

.data
.balign 8
g_me:       .long 0
g_botlvl:   .long 1
g_help:     .long 0
g_auto:     .long 0
g_wake:     .long 0
g_animend:  .long 0
g_collect:  .long 0
g_dirty:    .long 1
g_hover:    .long -1
g_mx:       .long 0
g_my:       .long 0

.bss
.balign 8
g_now:      .skip 4
g_hint:     .skip 4
g_tbp:      .skip 8
g_tbuf:     .skip 256
g_ast0:     .skip 16
g_asx:      .skip 16
g_asy:      .skip 16
g_bubt:     .skip 32                      # texte (pointeur) de chaque bulle
g_bube:     .skip 16                      # fin de la bulle (ms)
g_bubb:     .skip 4*48                    # tampons de texte des bulles
g_btn:      .skip 8*32                    # boutons : x, y, w, h, id, actif, (2 libres)
g_nbtn:     .skip 4
g_wins:     .skip 8
g_lw:       .skip 8
g_dim:      .skip 4
g_tmpd:     .skip 64
g_msgp:     .skip 8
g_msgbuf2:  .skip 128

.text
# ---------- petits utilitaires ----------
tb_reset:
    lea rax, [rip+g_tbuf]
    mov qword ptr [rip+g_tbp], rax
    mov byte ptr [rax], 0
    ret

tb_str:                                    # rsi = texte à ajouter
    mov rdx, qword ptr [rip+g_tbp]
1:  mov al, byte ptr [rsi]
    mov byte ptr [rdx], al
    test al, al
    jz 2f
    inc rsi
    inc rdx
    jmp 1b
2:  mov qword ptr [rip+g_tbp], rdx
    ret

tb_int:                                    # ecx = entier (signé)
    mov r11, qword ptr [rip+g_tbp]
    mov eax, ecx
    test eax, eax
    jns 1f
    mov byte ptr [r11], 45
    inc r11
    neg eax
1:  lea r8, [rip+g_tmpd]
    xor r9d, r9d
    mov ecx, 10
2:  xor edx, edx
    div ecx
    add edx, 48
    mov byte ptr [r8+r9], dl
    inc r9d
    test eax, eax
    jnz 2b
3:  dec r9d
    mov al, byte ptr [r8+r9]
    mov byte ptr [r11], al
    inc r11
    test r9d, r9d
    jnz 3b
    mov byte ptr [r11], 0
    mov qword ptr [rip+g_tbp], r11
    ret

disp_pos:                                  # ecx = joueur -> eax = position d'affichage (0 bas, 1 gauche, 2 haut, 3 droite)
    mov eax, ecx
    sub eax, dword ptr [rip+g_me]
    add eax, dword ptr [rip+g_np]
    xor edx, edx
    div dword ptr [rip+g_np]
    mov eax, edx
    cmp dword ptr [rip+g_np], 2
    jne 1f
    add eax, eax
1:  ret

is_human:                                  # ecx = joueur -> eax = 1 si c'est le joueur de cet ordinateur
    xor eax, eax
    cmp dword ptr [rip+g_auto], 0
    jne 1f
    cmp ecx, dword ptr [rip+g_me]
    jne 1f
    lea rdx, [rip+g_lvl]
    cmp dword ptr [rdx+rcx*4], -1
    jne 1f
    mov eax, 1
1:  ret

ui_note:                                   # ecx = durée d'animation à prévoir (ms)
    mov eax, dword ptr [rip+g_now]
    add eax, ecx
    cmp eax, dword ptr [rip+g_animend]
    jle 1f
    mov dword ptr [rip+g_animend], eax
1:  mov dword ptr [rip+g_dirty], 1
    ret

set_bubble:                                # ecx = joueur, rdx = texte ; ms : r8d
    lea rax, [rip+g_bubt]
    mov qword ptr [rax+rcx*8], rdx
    mov eax, dword ptr [rip+g_now]
    add eax, r8d
    lea rdx, [rip+g_bube]
    mov dword ptr [rdx+rcx*4], eax
    push rcx
    mov ecx, r8d
    call ui_note
    pop rcx
    ret

# ---------- déroulement ----------
ui_set_levels:
    lea rax, [rip+g_lvl]
    mov edx, dword ptr [rip+g_botlvl]
    mov ecx, dword ptr [rip+g_humans]
    xor r8d, r8d
1:  bt ecx, r8d
    jnc 2f
    mov dword ptr [rax+r8*4], -1
    jmp 3f
2:  mov dword ptr [rax+r8*4], edx
3:  inc r8d
    cmp r8d, 4
    jb 1b
    ret

is_bot:                                    # ecx = joueur -> eax = 1 si une décision doit être prise par l'ordinateur
    lea rdx, [rip+g_lvl]
    xor eax, eax
    cmp dword ptr [rdx+rcx*4], 0
    jge 1f
    cmp dword ptr [rip+g_auto], 0
    je 2f
    cmp ecx, dword ptr [rip+g_me]
    jne 2f
1:  mov eax, 1
2:  ret

human_bid:                                 # ecx = choix, action du joueur local
    ENTER
    mov r12d, ecx
    cmp dword ptr [rip+g_net], 4
    jne 1f
    mov ecx, NT_BID
    lea edx, [r12+1]
    call net_send_action
1:  mov ecx, r12d
    call apply_bid
    LEAVE

human_play:                                # ecx = position
    ENTER
    mov r12d, ecx
    cmp dword ptr [rip+g_net], 4
    jne 1f
    mov ecx, NT_PLAY
    mov edx, r12d
    call net_send_action
1:  mov ecx, r12d
    call apply_play
    LEAVE

human_next:                                # touche SUITE
    ENTER
    cmp dword ptr [rip+g_net], 4
    jne 1f
    mov eax, dword ptr [rip+g_me]
    mov ecx, 1
    shl ecx, 0
    mov ecx, NT_NEXT
    xor edx, edx
    call net_send_action
    mov ecx, dword ptr [rip+g_me]
    call net_mark_next
    jmp 2f
1:  call do_next_step
2:  LEAVE

ui_newmatch:
    ENTER
    call ui_set_levels
    mov dword ptr [rip+g_nextmask], 0
    call new_match
    mov ecx, dword ptr [rip+g_np]
    call rng_mod
    mov dword ptr [rip+g_dealer], eax
    call ui_newround
    LEAVE

ui_newround:
    ENTER
    call new_round
    mov eax, dword ptr [rip+g_now]
    sub eax, 2000
    lea rdx, [rip+g_ast0]
    mov dword ptr [rdx], eax
    mov dword ptr [rdx+4], eax
    mov dword ptr [rdx+8], eax
    mov dword ptr [rdx+12], eax
    lea rdx, [rip+g_bubt]
    mov qword ptr [rdx], 0
    mov qword ptr [rdx+8], 0
    mov qword ptr [rdx+16], 0
    mov qword ptr [rdx+24], 0
    mov dword ptr [rip+g_collect], 0
    mov dword ptr [rip+g_hint], -1
    mov eax, dword ptr [rip+g_now]
    add eax, 600
    mov dword ptr [rip+g_wake], eax
    mov ecx, 700
    call ui_note
    LEAVE

suit_name_bubble:                          # ecx = joueur, edx = couleur : "Je prends : Pique"
    ENTER
    mov r12d, ecx
    mov r13d, edx
    call tb_reset
    lea rsi, [rip+s_prends]
    call tb_str
    lea rax, [rip+t_suitnm]
    mov rsi, qword ptr [rax+r13*8]
    call tb_str
    lea rsi, [rip+g_tbuf]                   # copie dans le tampon de la bulle
    lea rdi, [rip+g_bubb]
    imul eax, r12d, 48
    add rdi, rax
    mov r14, rdi
1:  mov al, byte ptr [rsi]
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz 1b
    mov ecx, r12d
    mov rdx, r14
    mov r8d, 2200
    call set_bubble
    LEAVE

apply_bid:                                 # ecx = choix (-1 passer)
    ENTER
    mov r12d, ecx
    mov r13d, dword ptr [rip+g_turn]
    cmp r12d, -1
    jne 1f
    mov ecx, r13d
    lea rdx, [rip+s_passe]
    mov r8d, 1500
    call set_bubble
    jmp 2f
1:  mov ecx, r13d
    mov edx, r12d
    call suit_name_bubble
2:  mov ecx, r12d
    call do_bid
    mov eax, dword ptr [rip+g_now]
    add eax, 850
    mov dword ptr [rip+g_wake], eax
    mov dword ptr [rip+g_hint], -1
    mov ecx, 300
    call ui_note
    LEAVE

# position (écran) de la carte i de la main du joueur du bas
hand_cx:                                   # ecx = i, edx = n -> eax = x
    mov eax, edx
    dec eax
    imul eax, eax, 42                      # (n-1)*step/2 avec step = 84
    mov r8d, 550
    sub r8d, eax
    mov eax, ecx
    imul eax, eax, 84
    add eax, r8d
    ret

apply_play:                                # ecx = position dans la main du joueur courant
    ENTER
    mov r12d, ecx
    mov r13d, dword ptr [rip+g_turn]
    mov ecx, r13d
    call disp_pos
    mov r14d, eax
    lea rdx, [rip+g_hn]
    mov r15d, dword ptr [rdx+r13*4]
    lea rdx, [rip+t_hx]
    mov eax, dword ptr [rdx+r14*4]
    lea rdx, [rip+t_hy]
    mov ecx, dword ptr [rdx+r14*4]
    test r14d, r14d
    jnz 1f
    mov ecx, r12d
    mov edx, r15d
    call hand_cx
    mov ecx, 686
1:  lea rdx, [rip+g_asx]
    mov dword ptr [rdx+r13*4], eax
    lea rdx, [rip+g_asy]
    mov dword ptr [rdx+r13*4], ecx
    lea rdx, [rip+g_ast0]
    mov eax, dword ptr [rip+g_now]
    mov dword ptr [rdx+r13*4], eax
    mov ecx, r12d
    call do_play
    cmp dword ptr [rip+g_ev], 0
    je 2f
    mov eax, dword ptr [rip+g_ev]
    mov ecx, dword ptr [rip+g_evp]
    lea rdx, [rip+s_belote]
    cmp eax, 1
    je 3f
    lea rdx, [rip+s_rebelote]
3:  mov r8d, 1800
    call set_bubble
    mov dword ptr [rip+g_ev], 0
2:  mov eax, dword ptr [rip+g_now]
    cmp dword ptr [rip+g_phase], PH_TRICKEND
    jne 4f
    add eax, 1250
    jmp 5f
4:  add eax, 700
5:  mov dword ptr [rip+g_wake], eax
    mov dword ptr [rip+g_hint], -1
    mov ecx, 560
    call ui_note
    LEAVE

annonce_bubbles:                           # après le 1er pli : les annonces de l'équipe gagnante
    ENTER
    cmp dword ptr [rip+g_annteam], 0
    jl 9f
    xor r12d, r12d
1:  cmp r12d, 4
    jge 9f
    mov eax, r12d
    and eax, 1
    cmp eax, dword ptr [rip+g_annteam]
    jne 8f
    lea rax, [rip+g_ann_n]
    cmp dword ptr [rax+r12*4], 0
    je 8f
    lea rax, [rip+g_anl]
    mov eax, r12d
    shl eax, 3
    lea rdx, [rip+g_anl]
    movzx r13d, word ptr [rdx+rax]          # première annonce du joueur
    mov eax, r13d
    and eax, 15
    lea rdx, [rip+t_annnm]
    mov rdx, qword ptr [rdx+rax*8]
    mov ecx, r12d
    mov r8d, 2600
    call set_bubble
8:  inc r12d
    jmp 1b
9:  LEAVE

ui_collect_done:                           # le pli a fini de glisser : on le range
    ENTER
    mov dword ptr [rip+g_collect], 0
    call trick_collect
    cmp dword ptr [rip+g_phase], PH_MATCHEND
    jne 2f
    cmp dword ptr [rip+g_net], 0
    jne 2f
    mov eax, dword ptr [rip+g_rs_winner]    # victoires / défaites enregistrées (parties locales)
    xor eax, dword ptr [rip+g_me]
    and eax, 1
    lea rdx, [rip+g_wins]
    inc dword ptr [rdx+rax*4]
    call opt_save
2:  cmp dword ptr [rip+g_trickno], 1
    jne 1f
    cmp dword ptr [rip+g_phase], PH_PLAY
    jne 1f
    call annonce_bubbles
1:  mov eax, dword ptr [rip+g_now]
    add eax, 500
    mov dword ptr [rip+g_wake], eax
    mov ecx, 300
    call ui_note
    LEAVE

ui_tick:
    ENTER
    call GetTickCount64
    mov dword ptr [rip+g_now], eax
    mov eax, dword ptr [rip+g_now]
    cmp eax, dword ptr [rip+g_animend]
    jg 1f
    mov dword ptr [rip+g_dirty], 1
1:  cmp dword ptr [rip+g_net], 4
    jne 4f
    call net_pump
4:  cmp dword ptr [rip+g_help], 0
    je 5f
    cmp dword ptr [rip+g_hint], -1
    jne 5f
    cmp dword ptr [rip+g_phase], PH_PLAY
    jne 5f
    call ui_help
5:  mov eax, dword ptr [rip+g_now]
    sub eax, dword ptr [rip+g_wake]
    js .Lut_end                             # pas encore l'heure
    mov r12d, dword ptr [rip+g_phase]
    cmp r12d, PH_BID1
    je .Lut_bid
    cmp r12d, PH_BID2
    je .Lut_bid
    cmp r12d, PH_PLAY
    je .Lut_play
    cmp r12d, PH_TRICKEND
    je .Lut_tr
    cmp r12d, PH_ROUNDEND
    je .Lut_re
    cmp r12d, PH_MATCHEND
    je .Lut_re
    jmp .Lut_end
.Lut_bid:
    mov ecx, dword ptr [rip+g_turn]
    call is_bot
    test eax, eax
    jz .Lut_end
    mov ecx, dword ptr [rip+g_turn]
    call bot_bid
    mov ecx, eax
    lea rdx, [rip+g_lvl]
    mov eax, dword ptr [rip+g_turn]
    cmp dword ptr [rdx+rax*4], -1           # siège humain joué par l'ordinateur (mode U) : action diffusée
    jne 5f
    call human_bid
    jmp .Lut_end
5:  call apply_bid
    jmp .Lut_end
.Lut_play:
    mov ecx, dword ptr [rip+g_turn]
    call is_bot
    test eax, eax
    jz .Lut_end
    mov ecx, dword ptr [rip+g_turn]
    call bot_card
    mov ecx, eax
    lea rdx, [rip+g_lvl]
    mov eax, dword ptr [rip+g_turn]
    cmp dword ptr [rdx+rax*4], -1
    jne 6f
    call human_play
    jmp .Lut_end
6:  call apply_play
    jmp .Lut_end
.Lut_tr:
    cmp dword ptr [rip+g_collect], 0
    jne 2f
    mov eax, dword ptr [rip+g_now]          # le pli reste visible, puis glisse vers le gagnant
    mov dword ptr [rip+g_collect], eax
    add eax, 320
    mov dword ptr [rip+g_wake], eax
    mov ecx, 400
    call ui_note
    jmp .Lut_end
2:  call ui_collect_done
    jmp .Lut_end
.Lut_re:
    cmp dword ptr [rip+g_auto], 0           # mode automatique (test) : on enchaîne
    je .Lut_end
    mov eax, dword ptr [rip+g_me]
    mov ecx, 1
    xchg ecx, eax
    shl eax, cl
    test eax, dword ptr [rip+g_nextmask]
    jnz .Lut_end
    call human_next
.Lut_end:
    LEAVE

ui_newround_after:                         # new_round vient d'être fait par next_round
    mov eax, dword ptr [rip+g_now]
    sub eax, 2000
    lea rdx, [rip+g_ast0]
    mov dword ptr [rdx], eax
    mov dword ptr [rdx+4], eax
    mov dword ptr [rdx+8], eax
    mov dword ptr [rdx+12], eax
    mov dword ptr [rip+g_collect], 0
    mov eax, dword ptr [rip+g_now]
    add eax, 600
    mov dword ptr [rip+g_wake], eax
    mov dword ptr [rip+g_dirty], 1
    ret

# ---------- boutons ----------
add_btn:                                   # ecx = x, edx = y, r8d = w, r9d = h, [rsp+8] = id, [rsp+16] = actif (valeurs passées dans r10d, r11d)
    mov eax, dword ptr [rip+g_nbtn]
    shl eax, 5
    lea rsi, [rip+g_btn]
    add rsi, rax
    mov dword ptr [rsi], ecx
    mov dword ptr [rsi+4], edx
    mov dword ptr [rsi+8], r8d
    mov dword ptr [rsi+12], r9d
    mov dword ptr [rsi+16], r10d
    mov dword ptr [rsi+20], r11d
    inc dword ptr [rip+g_nbtn]
    ret

# ids : 0 = prendre, 1..4 = couleur 0..3 (id-1), 5 = passer, 6 = suite
build_buttons:
    ENTER
    mov dword ptr [rip+g_nbtn], 0
    mov ecx, dword ptr [rip+g_turn]
    call is_human
    mov r12d, eax                           # c'est mon tour ?
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_BID1
    jne 1f
    test r12d, r12d
    jz .Lbb_end
    mov ecx, 400
    mov edx, 560
    mov r8d, 140
    mov r9d, 48
    xor r10d, r10d
    mov r11d, 1
    call add_btn
    mov ecx, 560
    mov edx, 560
    mov r8d, 140
    mov r9d, 48
    mov r10d, 5
    mov r11d, 1
    call add_btn
    jmp .Lbb_end
1:  cmp eax, PH_BID2
    jne 2f
    test r12d, r12d
    jz .Lbb_end
    xor r13d, r13d
3:  mov ecx, r13d
    imul ecx, ecx, 98
    add ecx, 270
    mov edx, 560
    mov r8d, 88
    mov r9d, 48
    lea r10d, [r13+1]
    mov r11d, 1
    mov eax, dword ptr [rip+g_turned]
    shr eax, 3
    cmp eax, r13d
    jne 4f
    xor r11d, r11d
4:  call add_btn
    inc r13d
    cmp r13d, 4
    jb 3b
    mov ecx, 676
    mov edx, 560
    mov r8d, 130
    mov r9d, 48
    mov r10d, 5
    mov r11d, 1
    call add_btn
    jmp .Lbb_end
2:  cmp eax, PH_ROUNDEND
    je 5f
    cmp eax, PH_MATCHEND
    jne .Lbb_end
5:  mov ecx, 425
    mov edx, 548
    mov r8d, 250
    mov r9d, 52
    mov r10d, 6
    mov r11d, 1
    call add_btn
.Lbb_end:
    LEAVE

draw_btn:                                  # esi -> entrée du bouton ; r8 = texte
    ENTER
    mov r14, rsi
    mov r15, r8
    mov ecx, C_BTN
    mov edx, C_BTNDK
    cmp dword ptr [r14+20], 0
    jne 1f
    mov ecx, C_BTNOFF
    mov edx, C_PANEL
1:  mov eax, dword ptr [rip+g_mx]
    cmp dword ptr [r14+20], 0
    je 2f
    cmp eax, dword ptr [r14]
    jl 2f
    mov r8d, dword ptr [r14]
    add r8d, dword ptr [r14+8]
    cmp eax, r8d
    jg 2f
    mov eax, dword ptr [rip+g_my]
    cmp eax, dword ptr [r14+4]
    jl 2f
    mov r8d, dword ptr [r14+4]
    add r8d, dword ptr [r14+12]
    cmp eax, r8d
    jg 2f
    mov ecx, 0x00A0E0A0                     # survol
2:  call set_cols
    mov dword ptr [rip+g_rad], 12
    mov ecx, dword ptr [r14]
    mov edx, dword ptr [r14+4]
    mov r8d, dword ptr [r14+8]
    mov r9d, dword ptr [r14+12]
    call rrect
    mov dword ptr [rip+g_tc], C_WHITE
    cmp dword ptr [r14+20], 0
    jne 3f
    mov dword ptr [rip+g_tc], C_TXTDIM
3:  mov dword ptr [rip+g_ta], 6
    mov ecx, dword ptr [r14+8]
    shr ecx, 1
    add ecx, dword ptr [r14]
    mov edx, dword ptr [r14+4]
    add edx, 11
    mov r8, r15
    mov r9d, F_BTN
    call gtext
    LEAVE

# ---------- dessin de la scène ----------
draw_table:
    ENTER
    xor ecx, ecx                            # fond
    xor edx, edx
    mov ecx, C_BG
    mov edx, C_BG
    call set_cols
    mov dword ptr [rip+g_rad], 0
    xor ecx, ecx
    xor edx, edx
    mov r8d, WW
    mov r9d, WH
    call rrect
    mov ecx, 0x00080A0E                     # ombre au sol
    mov edx, ecx
    call set_cols
    mov ecx, 550
    mov edx, 392
    mov r8d, 520
    mov r9d, 282
    call ellipse
    mov ecx, C_WOODDK                       # tranche du plateau
    mov edx, C_WOODDK
    call set_cols
    mov ecx, 550
    mov edx, 376
    mov r8d, 500
    mov r9d, 280
    call ellipse
    mov ecx, C_WOOD
    mov edx, C_WOODHI
    call set_cols
    mov ecx, 550
    mov edx, 352
    mov r8d, 500
    mov r9d, 280
    call ellipse
    xor r12d, r12d                          # tapis : 12 anneaux en dégradé
.Ldt_f:
    imul eax, r12d, 20
    cdq
    mov ecx, 11
    idiv ecx
    add eax, 14
    mov r13d, eax                           # rouge
    imul eax, r12d, 46
    cdq
    idiv ecx
    add eax, 92
    shl eax, 8
    or r13d, eax                            # vert
    imul eax, r12d, 32
    cdq
    idiv ecx
    add eax, 62
    shl eax, 16
    or r13d, eax                            # bleu
    mov ecx, r13d
    mov edx, C_FELTEDGE
    test r12d, r12d
    jz 1f
    mov edx, r13d
1:  call set_cols
    imul r8d, r12d, 26
    neg r8d
    add r8d, 474
    imul r9d, r12d, 15
    neg r9d
    add r9d, 258
    mov ecx, 550
    mov edx, 352
    call ellipse
    inc r12d
    cmp r12d, 12
    jb .Ldt_f
    LEAVE
