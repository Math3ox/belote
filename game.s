# ============================================================
#  game.s — règles de la belote (4 joueurs par équipes, ou belote à deux)
#  Cartes : id = couleur*8 + rang ; couleurs 0=pique 1=coeur 2=carreau 3=trèfle ; rangs 0..7 = 7 8 9 10 V D R A
#  Joueurs : 0..np-1 ; équipe = joueur & 1 ; sens de jeu = joueur+1
# ============================================================

.equ PH_DEAL,     0
.equ PH_BID1,     1
.equ PH_BID2,     2
.equ PH_PLAY,     3
.equ PH_TRICKEND, 4
.equ PH_ROUNDEND, 5
.equ PH_MATCHEND, 6

.section .rdata,"dr"
t_ptsT: .byte 0,0,14,10,20,3,4,11
t_ptsP: .byte 0,0,0,10,2,3,4,11
t_ordT: .byte 0,1,6,4,7,2,3,5
t_ordP: .byte 0,1,2,6,3,4,5,7
t_disp: .byte 0,1,3,2                     # position d'affichage de chaque couleur (alternance noir/rouge)
t_carord: .byte 0,0,7,5,8,3,4,6           # ordre des carrés : V > 9 > A > 10 > R > D
t_carval: .byte 0,0,150,100,200,100,100,100

.data
.balign 8
g_np:       .long 4
g_target:   .long 1000
g_optann:   .long 1
g_rng:      .quad 0x2545F4914F6CDD1D
g_lvl:      .long -1, 1, 1, 1             # niveau de chaque joueur : -1 humain, 0 facile, 1 normal, 2 difficile
g_dealer:   .long 0
g_score:    .long 0, 0
g_pend:     .long 0
g_logon:    .long 0

.bss
.balign 16
# ---- état de la manche (bloc contigu : copiable pour les simulations) ----
g_gs:
g_phase:    .skip 4
g_turn:     .skip 4
g_trump:    .skip 4
g_taker:    .skip 4
g_turned:   .skip 4
g_bidrnd:   .skip 4
g_passes:   .skip 4
g_dpos:     .skip 4
g_tn:       .skip 4
g_tlead:    .skip 4
g_led:      .skip 4
g_trickno:  .skip 4
g_lastwin:  .skip 4
g_belp:     .skip 4
g_seenmask: .skip 4
g_annteam:  .skip 4
g_ev:       .skip 4                       # événement pour l'interface : 1 belote, 2 rebelote
g_evp:      .skip 4
g_rpts:     .skip 8
g_rtr:      .skip 8
g_bel:      .skip 8
g_ann:      .skip 8
g_hn:       .skip 16
g_void:     .skip 16
g_anv:      .skip 16                      # valeur des annonces de chaque joueur
g_ank:      .skip 16                      # meilleure clé
g_ann_n:    .skip 16                      # nombre d'annonces
g_anl:      .skip 32                      # [4][4] mots : sorte | rang<<4 | couleur<<8
g_deck:     .skip 32
g_hand:     .skip 32
g_tcard:    .skip 8
g_gs_end:
# ---- résultat de la dernière manche ----
g_rs_add:   .skip 8
g_rs_tot:   .skip 8
g_rs_made:  .skip 4                       # 0 dedans, 1 contrat rempli, 2 litige
g_rs_capot: .skip 4
g_rs_pend:  .skip 4
g_rs_npend: .skip 4
g_mcflag:   .skip 4
g_rs_winner:.skip 4                       # gagnant de la partie (phase MATCHEND)
g_bmine:    .skip 4
g_logbuf:   .skip 4194304
g_logpos:   .skip 4
g_logh:     .skip 8
g_written:  .skip 8

.text
# ---------- aléatoire ----------
rng_next:                                 # -> eax
    mov rax, qword ptr [rip+g_rng]
    mov rdx, rax
    shl rdx, 13
    xor rax, rdx
    mov rdx, rax
    shr rdx, 7
    xor rax, rdx
    mov rdx, rax
    shl rdx, 17
    xor rax, rdx
    mov qword ptr [rip+g_rng], rax
    shr rax, 32
    ret

rng_mod:                                  # ecx = n -> eax dans [0,n)
    push rcx
    call rng_next
    pop rcx
    xor edx, edx
    div ecx
    mov eax, edx
    ret

# ---------- cartes ----------
card_key:                                 # ecx = carte -> eax = clé (-1 : ne peut pas gagner) ; clobbers edx, r11
    mov eax, ecx
    shr eax, 3
    mov edx, ecx
    and edx, 7
    cmp eax, dword ptr [rip+g_trump]
    jne 1f
    lea r11, [rip+t_ordT]
    movzx eax, byte ptr [r11+rdx]
    add eax, 16
    ret
1:  cmp eax, dword ptr [rip+g_led]
    jne 2f
    lea r11, [rip+t_ordP]
    movzx eax, byte ptr [r11+rdx]
    add eax, 8
    ret
2:  mov eax, -1
    ret

card_pts:                                 # ecx = carte -> eax = points ; clobbers edx, r11
    mov eax, ecx
    shr eax, 3
    mov edx, ecx
    and edx, 7
    lea r11, [rip+t_ptsP]
    cmp eax, dword ptr [rip+g_trump]
    jne 1f
    lea r11, [rip+t_ptsT]
1:  movzx eax, byte ptr [r11+rdx]
    ret

# ---------- mains ----------
hand_add:                                 # ecx = joueur, edx = carte
    lea r8, [rip+g_hn]
    mov eax, dword ptr [r8+rcx*4]
    lea r9, [rip+g_hand]
    lea r10, [r9+rcx*8]
    mov byte ptr [r10+rax], dl
    inc eax
    mov dword ptr [r8+rcx*4], eax
    ret

hand_remove:                              # ecx = joueur, edx = position -> eax = carte
    lea r9, [rip+g_hand]
    lea r10, [r9+rcx*8]
    movzx eax, byte ptr [r10+rdx]
    lea r8, [rip+g_hn]
    mov r11d, dword ptr [r8+rcx*4]
    dec r11d
    mov dword ptr [r8+rcx*4], r11d
1:  cmp edx, r11d
    jge 2f
    movzx r9d, byte ptr [r10+rdx+1]
    mov byte ptr [r10+rdx], r9b
    inc edx
    jmp 1b
2:  ret

hand_key:                                 # ecx = carte -> eax = clé de tri d'affichage ; clobbers edx, r8
    mov eax, ecx
    shr eax, 3
    mov edx, ecx
    and edx, 7
    lea r8, [rip+t_ordP]
    cmp eax, dword ptr [rip+g_trump]
    jne 1f
    lea r8, [rip+t_ordT]
    movzx edx, byte ptr [r8+rdx]
    mov r8d, 7
    sub r8d, edx
    xor eax, eax                          # l'atout en premier
    jmp 2f
1:  movzx edx, byte ptr [r8+rdx]
    mov r8d, 7
    sub r8d, edx
    lea rdx, [rip+t_disp]
    movzx eax, byte ptr [rdx+rax]
    inc eax
2:  shl eax, 3
    add eax, r8d
    ret

hand_sort:                                # ecx = joueur (tri par insertion)
    ENTER
    mov r12d, ecx
    lea rax, [rip+g_hand]
    lea rsi, [rax+r12*8]
    lea rax, [rip+g_hn]
    mov r13d, dword ptr [rax+r12*4]
    mov edi, 1
1:  cmp edi, r13d
    jge 4f
    movzx ecx, byte ptr [rsi+rdi]
    mov r14d, ecx                         # carte à insérer
    call hand_key
    mov r15d, eax                         # sa clé
    mov ebx, edi                          # j
2:  test ebx, ebx
    jz 3f
    movzx ecx, byte ptr [rsi+rbx-1]
    call hand_key
    cmp eax, r15d
    jle 3f
    movzx ecx, byte ptr [rsi+rbx-1]
    mov byte ptr [rsi+rbx], cl
    dec ebx
    jmp 2b
3:  mov byte ptr [rsi+rbx], r14b
    inc edi
    jmp 1b
4:  LEAVE

sort_all:
    ENTER
    xor r12d, r12d
1:  cmp r12d, dword ptr [rip+g_np]
    jge 2f
    mov ecx, r12d
    call hand_sort
    inc r12d
    jmp 1b
2:  LEAVE

deck_draw_to:                             # ecx = joueur : lui donne la carte suivante du paquet
    lea r8, [rip+g_deck]
    mov eax, dword ptr [rip+g_dpos]
    movzx edx, byte ptr [r8+rax]
    inc eax
    mov dword ptr [rip+g_dpos], eax
    jmp hand_add

shuffle:
    ENTER
    lea rsi, [rip+g_deck]
    xor eax, eax
1:  mov byte ptr [rsi+rax], al
    inc eax
    cmp eax, 32
    jb 1b
    mov edi, 31
2:  lea ecx, [rdi+1]
    call rng_mod
    movzx ecx, byte ptr [rsi+rax]
    movzx edx, byte ptr [rsi+rdi]
    mov byte ptr [rsi+rax], dl
    mov byte ptr [rsi+rdi], cl
    dec edi
    jnz 2b
    LEAVE

deal_each:                                # ecx = nombre de cartes données à chacun, en partant de donneur+1
    ENTER
    mov r12d, ecx
    mov r13d, 1
1:  mov eax, dword ptr [rip+g_dealer]
    add eax, r13d
    xor edx, edx
    div dword ptr [rip+g_np]
    mov r14d, edx
    mov r15d, r12d
2:  test r15d, r15d
    jz 3f
    mov ecx, r14d
    call deck_draw_to
    dec r15d
    jmp 2b
3:  inc r13d
    cmp r13d, dword ptr [rip+g_np]
    jle 1b
    LEAVE

# ---------- nouvelle donne ----------
new_round:
    ENTER
    lea rdi, [rip+g_gs]
    lea rcx, [rip+g_gs_end]
    sub rcx, rdi
    xor eax, eax
    rep stosb
    mov dword ptr [rip+g_trump], -1
    mov dword ptr [rip+g_taker], -1
    mov dword ptr [rip+g_belp], -1
    mov dword ptr [rip+g_annteam], -1
    mov dword ptr [rip+g_bidrnd], 1
    mov dword ptr [rip+g_tcard], 0xFFFFFFFF
    mov dword ptr [rip+g_tcard+4], 0xFFFFFFFF
    call shuffle
    cmp dword ptr [rip+g_np], 4
    jne 1f
    mov ecx, 3
    call deal_each
    mov ecx, 2
    call deal_each
    jmp 2f
1:  mov ecx, 3
    call deal_each
    mov ecx, 3
    call deal_each
2:  lea rax, [rip+g_deck]
    mov ecx, dword ptr [rip+g_dpos]
    movzx eax, byte ptr [rax+rcx]
    mov dword ptr [rip+g_turned], eax
    inc dword ptr [rip+g_dpos]
    call sort_all
    mov dword ptr [rip+g_phase], PH_BID1
    mov eax, dword ptr [rip+g_dealer]
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
    call log_deck
    LEAVE

next_round:                               # donneur suivant, nouvelle donne
    mov eax, dword ptr [rip+g_dealer]
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_dealer], edx
    jmp new_round

new_match:
    mov dword ptr [rip+g_score], 0
    mov dword ptr [rip+g_score+4], 0
    mov dword ptr [rip+g_pend], 0
    mov dword ptr [rip+g_rs_winner], -1
    ret

# ---------- enchères ----------
take_cards:                               # le preneur ramasse la retourne, puis fin de la distribution
    ENTER
    mov ecx, dword ptr [rip+g_taker]
    mov edx, dword ptr [rip+g_turned]
    call hand_add
    cmp dword ptr [rip+g_np], 4
    jne 3f
    mov r12d, 1
1:  mov eax, dword ptr [rip+g_dealer]
    add eax, r12d
    xor edx, edx
    div dword ptr [rip+g_np]
    mov r13d, edx
    mov r14d, 3
    cmp r13d, dword ptr [rip+g_taker]
    jne 2f
    mov r14d, 2
2:  mov ecx, r13d
    call deck_draw_to
    dec r14d
    jnz 2b
    inc r12d
    cmp r12d, 4
    jle 1b
    jmp 4f
3:  mov ecx, dword ptr [rip+g_taker]      # à deux : l'adversaire pioche une carte
    inc ecx
    and ecx, 1
    call deck_draw_to
4:  LEAVE

do_bid:                                   # ecx = -1 passer, sinon couleur d'atout
    ENTER
    mov r12d, ecx
    mov r13d, dword ptr [rip+g_turn]
    mov ecx, r13d
    mov edx, r12d
    call log_bid
    cmp r12d, -1
    je .Lb_pass
    mov dword ptr [rip+g_trump], r12d
    mov dword ptr [rip+g_taker], r13d
    call take_cards
    call sort_all
    mov dword ptr [rip+g_phase], PH_PLAY
    mov eax, dword ptr [rip+g_dealer]
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
    cmp dword ptr [rip+g_np], 4
    jne .Lb_end
    call compute_annonces
    jmp .Lb_end
.Lb_pass:
    inc dword ptr [rip+g_passes]
    mov eax, dword ptr [rip+g_passes]
    cmp eax, dword ptr [rip+g_np]
    jl .Lb_next
    cmp dword ptr [rip+g_bidrnd], 1
    jne .Lb_redeal
    mov dword ptr [rip+g_bidrnd], 2
    mov dword ptr [rip+g_phase], PH_BID2
    mov dword ptr [rip+g_passes], 0
    mov eax, dword ptr [rip+g_dealer]
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
    jmp .Lb_end
.Lb_redeal:
    call next_round
    jmp .Lb_end
.Lb_next:
    mov eax, r13d
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
.Lb_end:
    LEAVE

# ---------- annonces ----------
add_annonce:                              # ecx = joueur, edx = sorte(1..4), r8d = rang, r9d = couleur, r10d = valeur, r11d = clé
    lea rax, [rip+g_ann_n]
    mov esi, dword ptr [rax+rcx*4]
    cmp esi, 4
    jge 1f
    inc dword ptr [rax+rcx*4]
    mov eax, ecx
    shl eax, 2
    add esi, eax
    shl r8d, 4
    or edx, r8d
    shl r9d, 8
    or edx, r9d
    lea rax, [rip+g_anl]
    mov word ptr [rax+rsi*2], dx
    lea rax, [rip+g_anv]
    add dword ptr [rax+rcx*4], r10d
    lea rax, [rip+g_ank]
    cmp r11d, dword ptr [rax+rcx*4]
    jle 1f
    mov dword ptr [rax+rcx*4], r11d
1:  ret

compute_annonces:
    ENTER
    xor r12d, r12d                        # joueur
.Lca_p:
    cmp r12d, dword ptr [rip+g_np]
    jge .Lca_end
    sub rsp, 16                           # masques par couleur
    mov dword ptr [rsp], 0
    mov dword ptr [rsp+4], 0
    mov dword ptr [rsp+8], 0
    mov dword ptr [rsp+12], 0
    lea rax, [rip+g_hand]
    lea rsi, [rax+r12*8]
    lea rax, [rip+g_hn]
    mov r13d, dword ptr [rax+r12*4]
    xor edi, edi
1:  cmp edi, r13d
    jge 2f
    movzx ecx, byte ptr [rsi+rdi]
    mov eax, ecx
    shr eax, 3
    and ecx, 7
    mov edx, 1
    shl edx, cl
    or dword ptr [rsp+rax*4], edx
    inc edi
    jmp 1b
2:  mov r14d, 2                           # carrés : rangs 9 10 V D R A
3:  cmp r14d, 7
    jg 5f
    mov eax, 1
    mov ecx, r14d
    shl eax, cl
    mov edx, eax
    and edx, dword ptr [rsp]
    jz 4f
    mov edx, eax
    and edx, dword ptr [rsp+4]
    jz 4f
    mov edx, eax
    and edx, dword ptr [rsp+8]
    jz 4f
    and eax, dword ptr [rsp+12]
    jz 4f
    lea rax, [rip+t_carord]
    movzx r11d, byte ptr [rax+r14]
    imul r11d, r11d, 10
    add r11d, 4000
    lea rax, [rip+t_carval]
    movzx r10d, byte ptr [rax+r14]
    mov ecx, r12d
    mov edx, 4
    mov r8d, r14d
    xor r9d, r9d
    call add_annonce
4:  inc r14d
    jmp 3b
5:  xor r14d, r14d                        # suites par couleur
6:  cmp r14d, 4
    jge 11f
    mov r15d, dword ptr [rsp+r14*4]
    xor ebx, ebx                          # rang courant
7:  cmp ebx, 8
    jge 10f
    bt r15d, ebx
    jnc 9f
    mov edi, ebx                          # début de la série
8:  inc ebx
    cmp ebx, 8
    jge 12f
    bt r15d, ebx
    jc 8b
12: mov eax, ebx
    sub eax, edi                          # longueur
    cmp eax, 3
    jl 7b
    lea r8d, [rbx-1]                      # rang le plus haut
    mov r9d, r14d
    mov r11d, r8d
    imul r11d, r11d, 10
    cmp r14d, dword ptr [rip+g_trump]
    jne 13f
    add r11d, 5
13: cmp eax, 5
    jl 14f
    mov r10d, 100
    mov edx, 3
    add r11d, 3000
    jmp 15f
14: cmp eax, 4
    jne 16f
    mov r10d, 50
    mov edx, 2
    add r11d, 2000
    jmp 15f
16: mov r10d, 20
    mov edx, 1
    add r11d, 1000
15: mov ecx, r12d
    call add_annonce
    jmp 7b
9:  inc ebx
    jmp 7b
10: inc r14d
    jmp 6b
11: add rsp, 16
    inc r12d
    jmp .Lca_p
.Lca_end:
    LEAVE

eval_annonces:                            # après le 1er pli : quelle équipe marque ses annonces
    ENTER
    xor r12d, r12d                        # meilleure clé équipe 0
    xor r13d, r13d                        # équipe 1
    mov dword ptr [rip+g_annteam], -1
    xor r14d, r14d
1:  cmp r14d, 4
    jge 3f
    lea rax, [rip+g_ank]
    mov eax, dword ptr [rax+r14*4]
    test r14d, 1
    jnz 2f
    cmp eax, r12d
    jle 4f
    mov r12d, eax
    jmp 4f
2:  cmp eax, r13d
    jle 4f
    mov r13d, eax
4:  inc r14d
    jmp 1b
3:  cmp r12d, r13d
    jg .Lea_t0
    jl .Lea_t1
    test r12d, r12d
    jz .Lea_end
    xor r14d, r14d                        # égalité : l'équipe du premier joueur qui annonce
5:  mov eax, dword ptr [rip+g_dealer]
    inc eax
    add eax, r14d
    xor edx, edx
    div dword ptr [rip+g_np]
    lea rax, [rip+g_ank]
    cmp dword ptr [rax+rdx*4], r12d
    je 6f
    inc r14d
    jmp 5b
6:  and edx, 1
    mov dword ptr [rip+g_annteam], edx
    jmp .Lea_sum
.Lea_t0:
    mov dword ptr [rip+g_annteam], 0
    jmp .Lea_sum
.Lea_t1:
    mov dword ptr [rip+g_annteam], 1
.Lea_sum:
    mov r12d, dword ptr [rip+g_annteam]
    xor r13d, r13d
    xor r14d, r14d
7:  cmp r14d, 4
    jge 8f
    mov eax, r14d
    and eax, 1
    cmp eax, r12d
    jne 9f
    lea rax, [rip+g_anv]
    add r13d, dword ptr [rax+r14*4]
9:  inc r14d
    jmp 7b
8:  lea rax, [rip+g_ann]
    mov dword ptr [rax+r12*4], r13d
.Lea_end:
    LEAVE

# ---------- jeu des plis ----------
trick_best:                               # -> eax = joueur qui gagne le pli, edx = sa clé
    xor r8d, r8d
    mov r9d, -2
    xor r10d, r10d
1:  lea rax, [rip+g_tcard]
    movzx ecx, byte ptr [rax+r8]
    cmp ecx, 0xFF
    je 2f
    push r8
    push r9
    push r10
    call card_key
    pop r10
    pop r9
    pop r8
    cmp eax, r9d
    jle 2f
    mov r9d, eax
    mov r10d, r8d
2:  inc r8d
    cmp r8d, 4
    jb 1b
    mov eax, r10d
    mov edx, r9d
    ret

legal_mask:                               # ecx = joueur -> eax = masque des positions jouables
    ENTER
    mov r15d, ecx
    lea rax, [rip+g_hn]
    mov r14d, dword ptr [rax+r15*4]
    mov ecx, r14d
    mov ebx, 1
    shl ebx, cl
    dec ebx
    cmp dword ptr [rip+g_tn], 0
    je .Llm_ret
    cmp dword ptr [rip+g_np], 2
    jne 1f
    cmp dword ptr [rip+g_dpos], 32        # à deux, talon non vide : aucune obligation
    jl .Llm_ret
1:  mov r13d, 15
    xor r8d, r8d
2:  lea rax, [rip+g_tcard]
    movzx ecx, byte ptr [rax+r8]
    cmp ecx, 0xFF
    je 3f
    mov eax, ecx
    shr eax, 3
    cmp eax, dword ptr [rip+g_trump]
    jne 3f
    call card_key
    cmp eax, r13d
    jle 3f
    mov r13d, eax
3:  inc r8d
    cmp r8d, 4
    jb 2b
    lea rax, [rip+g_hand]
    lea rsi, [rax+r15*8]
    xor edi, edi
    xor r9d, r9d                          # cartes de la couleur demandée
    xor r10d, r10d                        # atouts
    xor r12d, r12d                        # atouts qui montent
4:  cmp edi, r14d
    jge 5f
    movzx ecx, byte ptr [rsi+rdi]
    mov eax, ecx
    shr eax, 3
    cmp eax, dword ptr [rip+g_led]
    jne 6f
    bts r9d, edi
6:  cmp eax, dword ptr [rip+g_trump]
    jne 7f
    bts r10d, edi
    call card_key
    cmp eax, r13d
    jle 7f
    bts r12d, edi
7:  inc edi
    jmp 4b
5:  mov eax, dword ptr [rip+g_led]
    cmp eax, dword ptr [rip+g_trump]
    jne .Llm_plain
    test r10d, r10d
    jz .Llm_ret
    test r12d, r12d
    jz 8f
    mov ebx, r12d
    jmp .Llm_ret
8:  mov ebx, r10d
    jmp .Llm_ret
.Llm_plain:
    test r9d, r9d
    jz 9f
    mov ebx, r9d
    jmp .Llm_ret
9:  cmp dword ptr [rip+g_np], 4
    jne 10f
    push r10
    call trick_best
    pop r10
    xor eax, r15d
    test al, 1
    jz .Llm_ret                           # le partenaire est maître : pas d'obligation de couper
10: test r10d, r10d
    jz .Llm_ret
    test r12d, r12d
    jz 11f
    mov ebx, r12d
    jmp .Llm_ret
11: mov ebx, r10d
.Llm_ret:
    mov eax, ebx
    LEAVE

hand_has:                                 # ecx = joueur, edx = carte -> eax = 1 si en main
    lea rax, [rip+g_hand]
    lea r8, [rax+rcx*8]
    lea rax, [rip+g_hn]
    mov r9d, dword ptr [rax+rcx*4]
    xor eax, eax
1:  cmp eax, r9d
    jge 2f
    movzx r10d, byte ptr [r8+rax]
    cmp r10d, edx
    je 3f
    inc eax
    jmp 1b
2:  xor eax, eax
    ret
3:  mov eax, 1
    ret

do_play:                                  # ecx = position dans la main du joueur dont c'est le tour
    ENTER
    mov r12d, ecx
    mov r13d, dword ptr [rip+g_turn]
    mov ecx, r13d
    mov edx, r12d
    call hand_remove
    mov r14d, eax
    mov ecx, r13d
    mov edx, r14d
    call log_play
    mov eax, r14d
    shr eax, 3
    cmp dword ptr [rip+g_tn], 0
    jne 1f
    mov dword ptr [rip+g_led], eax
    mov dword ptr [rip+g_tlead], r13d
    jmp 2f
1:  cmp eax, dword ptr [rip+g_led]
    je 2f
    mov ecx, dword ptr [rip+g_led]
    mov eax, 1
    shl eax, cl
    lea rdx, [rip+g_void]
    or dword ptr [rdx+r13*4], eax
2:  lea rax, [rip+g_tcard]
    mov byte ptr [rax+r13], r14b
    inc dword ptr [rip+g_tn]
    bts dword ptr [rip+g_seenmask], r14d
    mov eax, r14d                         # belote - rebelote
    shr eax, 3
    cmp eax, dword ptr [rip+g_trump]
    jne 5f
    mov edx, r14d
    and edx, 7
    cmp edx, 5
    je 3f
    cmp edx, 6
    jne 5f
3:  mov r15d, r14d                        # l'autre carte du couple
    xor r15d, 3                           # 5 <-> 6
    mov ecx, r13d
    mov edx, r15d
    call hand_has
    test eax, eax
    jz 4f
    mov dword ptr [rip+g_belp], r13d
    mov dword ptr [rip+g_ev], 1
    mov dword ptr [rip+g_evp], r13d
    jmp 5f
4:  cmp dword ptr [rip+g_belp], r13d
    jne 5f
    mov eax, r13d
    and eax, 1
    lea rdx, [rip+g_bel]
    mov dword ptr [rdx+rax*4], 20
    mov dword ptr [rip+g_belp], -1
    mov dword ptr [rip+g_ev], 2
    mov dword ptr [rip+g_evp], r13d
5:  mov eax, dword ptr [rip+g_tn]
    cmp eax, dword ptr [rip+g_np]
    jl 6f
    mov dword ptr [rip+g_phase], PH_TRICKEND
    jmp 7f
6:  mov eax, r13d
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
7:  LEAVE

trick_collect:                            # résout le pli complet, prépare le suivant ou termine la manche
    ENTER
    call trick_best
    mov r12d, eax                         # gagnant
    xor r13d, r13d                        # points du pli
    xor r14d, r14d
1:  lea rax, [rip+g_tcard]
    movzx ecx, byte ptr [rax+r14]
    cmp ecx, 0xFF
    je 2f
    call card_pts
    add r13d, eax
2:  inc r14d
    cmp r14d, 4
    jb 1b
    xor eax, eax                          # dernier pli ? (mains vides, talon vide)
    lea rdx, [rip+g_hn]
    or eax, dword ptr [rdx]
    or eax, dword ptr [rdx+4]
    or eax, dword ptr [rdx+8]
    or eax, dword ptr [rdx+12]
    jnz 3f
    cmp dword ptr [rip+g_np], 4
    je 4f
    cmp dword ptr [rip+g_dpos], 32
    jl 3f
4:  add r13d, 10
3:  mov eax, r12d
    and eax, 1
    lea rdx, [rip+g_rpts]
    add dword ptr [rdx+rax*4], r13d
    lea rdx, [rip+g_rtr]
    inc dword ptr [rdx+rax*4]
    mov dword ptr [rip+g_lastwin], r12d
    inc dword ptr [rip+g_trickno]
    cmp dword ptr [rip+g_trickno], 1
    jne 5f
    cmp dword ptr [rip+g_np], 4
    jne 5f
    cmp dword ptr [rip+g_optann], 0
    je 5f
    call eval_annonces
5:  mov dword ptr [rip+g_tcard], 0xFFFFFFFF
    mov dword ptr [rip+g_tcard+4], 0xFFFFFFFF
    mov dword ptr [rip+g_tn], 0
    mov dword ptr [rip+g_turn], r12d
    cmp dword ptr [rip+g_np], 2
    jne 7f
    cmp dword ptr [rip+g_dpos], 32        # à deux : le gagnant pioche en premier
    jge 7f
    mov ecx, r12d
    call deck_draw_to
    mov ecx, r12d
    inc ecx
    and ecx, 1
    call deck_draw_to
    xor ecx, ecx
    call hand_sort
    mov ecx, 1
    call hand_sort
7:  xor eax, eax
    lea rdx, [rip+g_hn]
    or eax, dword ptr [rdx]
    or eax, dword ptr [rdx+4]
    or eax, dword ptr [rdx+8]
    or eax, dword ptr [rdx+12]
    jnz 8f
    cmp dword ptr [rip+g_mcflag], 0
    jne 9f
    call score_round
    LEAVE
9:  mov dword ptr [rip+g_phase], PH_ROUNDEND  # simulation (bots difficiles) : on ne marque rien
    LEAVE
8:  mov dword ptr [rip+g_phase], PH_PLAY
    LEAVE

# ---------- décompte ----------
calc_round:                                 # calcule g_rs_* sans rien appliquer
    ENTER
    mov r12d, dword ptr [rip+g_taker]
    and r12d, 1                           # équipe preneuse
    mov r13d, r12d
    xor r13d, 1                           # défenseurs
    mov dword ptr [rip+g_rs_capot], -1
    mov eax, dword ptr [rip+g_trickno]
    cmp dword ptr [rip+g_rtr], eax
    jne 1f
    mov dword ptr [rip+g_rs_capot], 0
1:  cmp dword ptr [rip+g_rtr+4], eax
    jne 2f
    mov dword ptr [rip+g_rs_capot], 1
2:  xor r14d, r14d                        # totaux des deux équipes
    lea r15, [rip+g_rs_tot]
3:  lea rax, [rip+g_rpts]
    mov eax, dword ptr [rax+r14*4]
    lea rdx, [rip+g_bel]
    add eax, dword ptr [rdx+r14*4]
    lea rdx, [rip+g_ann]
    add eax, dword ptr [rdx+r14*4]
    cmp dword ptr [rip+g_rs_capot], r14d
    jne 4f
    add eax, 90
4:  mov dword ptr [r15+r14*4], eax
    inc r14d
    cmp r14d, 2
    jb 3b
    lea r15, [rip+g_rs_tot]
    mov esi, dword ptr [r15+r12*4]        # ta
    mov edi, dword ptr [r15+r13*4]        # tb
    lea r14, [rip+g_rs_add]
    mov dword ptr [rip+g_rs_pend], 0
    mov dword ptr [rip+g_rs_npend], 0
    cmp esi, edi
    jl .Lsr_dedans
    jg .Lsr_made
    mov dword ptr [rip+g_rs_made], 2      # litige
    mov dword ptr [r14+r13*4], edi
    mov dword ptr [r14+r12*4], 0
    mov eax, dword ptr [rip+g_pend]
    add eax, esi
    mov dword ptr [rip+g_rs_npend], eax
    LEAVE
.Lsr_made:
    mov dword ptr [rip+g_rs_made], 1
    mov dword ptr [r14+r12*4], esi
    mov dword ptr [r14+r13*4], edi
    mov ebx, r12d                         # équipe qui récupère un litige précédent
    jmp .Lsr_pend
.Lsr_dedans:
    mov dword ptr [rip+g_rs_made], 0
    mov eax, 162
    cmp dword ptr [rip+g_rs_capot], r13d
    jne 5f
    add eax, 90
5:  lea rdx, [rip+g_ann]
    add eax, dword ptr [rdx]
    add eax, dword ptr [rdx+4]
    lea rdx, [rip+g_bel]
    add eax, dword ptr [rdx+r13*4]
    mov dword ptr [r14+r13*4], eax
    mov eax, dword ptr [rdx+r12*4]
    mov dword ptr [r14+r12*4], eax
    mov ebx, r13d
.Lsr_pend:
    mov eax, dword ptr [rip+g_pend]
    mov dword ptr [rip+g_rs_pend], eax
    add dword ptr [r14+rbx*4], eax
    LEAVE

score_round:
    ENTER
    call calc_round
    mov eax, dword ptr [rip+g_rs_npend]
    mov dword ptr [rip+g_pend], eax
    lea r14, [rip+g_rs_add]
    lea rdx, [rip+g_score]
    mov eax, dword ptr [r14]
    add dword ptr [rdx], eax
    mov eax, dword ptr [r14+4]
    add dword ptr [rdx+4], eax
    mov dword ptr [rip+g_phase], PH_ROUNDEND
    mov eax, dword ptr [rdx]
    mov ecx, dword ptr [rdx+4]
    mov esi, dword ptr [rip+g_target]
    cmp eax, esi
    jge 6f
    cmp ecx, esi
    jl 8f
6:  mov dword ptr [rip+g_phase], PH_MATCHEND
    xor edx, edx
    cmp ecx, eax
    jle 7f
    mov edx, 1
7:  mov dword ptr [rip+g_rs_winner], edx
8:  call log_score
    LEAVE
