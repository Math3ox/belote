# ============================================================
#  mc.s — bots « difficile » : simulations de Monte-Carlo
#  On tire au hasard les cartes cachées (en respectant les couleurs que chaque joueur a montré ne plus avoir),
#  on joue la fin de la donne avec les heuristiques des bots « normal » pour chaque carte jouable,
#  et on garde la carte qui rapporte le plus en moyenne. Même principe pour décider de prendre ou passer.
# ============================================================
.data
.balign 4
g_mcn:      .long 60                        # tirages pour le jeu des cartes
g_mcnb:     .long 40                        # tirages pour les enchères
g_mcthr:    .long 12                        # marge moyenne minimale (points) pour prendre

.bss
.balign 8
g_snap0:    .skip 512
g_snap1:    .skip 512
g_mcsum:    .skip 32
g_mcU:      .skip 40
g_mcm:      .skip 4
g_mcsave:   .skip 16

.text
mc_snap:                                    # rdi = destination
    lea rsi, [rip+g_gs]
    lea rcx, [rip+g_gs_end]
    sub rcx, rsi
    cld
    rep movsb
    ret

mc_unsnap:                                  # rsi = source
    lea rdi, [rip+g_gs]
    lea rcx, [rip+g_gs_end]
    sub rcx, rdi
    cld
    rep movsb
    ret

mc_begin:
    mov eax, dword ptr [rip+g_logon]
    mov dword ptr [rip+g_mcsave], eax
    mov dword ptr [rip+g_logon], 0
    mov eax, dword ptr [rip+g_optann]
    mov dword ptr [rip+g_mcsave+4], eax
    mov dword ptr [rip+g_optann], 0
    mov dword ptr [rip+g_mcflag], 1
    ret

mc_end:
    mov eax, dword ptr [rip+g_mcsave]
    mov dword ptr [rip+g_logon], eax
    mov eax, dword ptr [rip+g_mcsave+4]
    mov dword ptr [rip+g_optann], eax
    mov dword ptr [rip+g_mcflag], 0
    mov dword ptr [rip+g_ev], 0
    ret

mc_rollout:                                 # joue la fin de la donne (tous les joueurs avec l'heuristique)
    ENTER
    mov r12d, 80
1:  dec r12d
    jz 9f
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_PLAY
    je 2f
    cmp eax, PH_TRICKEND
    je 3f
9:  LEAVE
2:  mov ecx, dword ptr [rip+g_turn]
    call bot_card
    mov ecx, eax
    call do_play
    jmp 1b
3:  call trick_collect
    jmp 1b

mc_value:                                   # ecx = joueur -> eax = marge de son équipe sur la donne simulée
    ENTER
    mov r12d, ecx
    call calc_round
    mov eax, r12d
    and eax, 1
    lea rdx, [rip+g_rs_add]
    mov ecx, dword ptr [rdx+rax*4]
    xor eax, 1
    sub ecx, dword ptr [rdx+rax*4]
    mov eax, ecx
    LEAVE

mc_shuffle:                                 # mélange g_mcU[0..g_mcm-1]
    ENTER
    mov esi, dword ptr [rip+g_mcm]
1:  dec esi
    jle 2f
    lea ecx, [rsi+1]
    call rng_mod
    lea rdx, [rip+g_mcU]
    movzx ecx, byte ptr [rdx+rax]
    movzx r8d, byte ptr [rdx+rsi]
    mov byte ptr [rdx+rax], r8b
    mov byte ptr [rdx+rsi], cl
    jmp 1b
2:  LEAVE

# mc_determinize : ecx = joueur qui décide. Distribue au hasard les cartes qu'il ne voit pas
mc_determinize:
    ENTER
    mov r12d, ecx
    call hand_mask
    or eax, dword ptr [rip+g_seenmask]
    not eax
    mov r13d, eax                           # cartes inconnues
    mov r14d, -1                            # retourne connue (dans la main du preneur)
    mov eax, dword ptr [rip+g_taker]
    test eax, eax
    js 1f
    cmp eax, r12d
    je 1f
    mov ecx, dword ptr [rip+g_turned]
    bt r13d, ecx
    jnc 1f
    btr r13d, ecx
    mov r14d, ecx
1:  lea rdi, [rip+g_mcU]
    xor ecx, ecx
    xor ebx, ebx
2:  bt r13d, ecx
    jnc 3f
    mov byte ptr [rdi+rbx], cl
    inc ebx
3:  inc ecx
    cmp ecx, 32
    jb 2b
    mov dword ptr [rip+g_mcm], ebx
    mov r15d, 24
.Lmd_try:
    call mc_shuffle
    xor ebx, ebx                            # indice dans la liste
    mov r13d, 1                             # distribution cohérente avec les couleurs manquantes
    xor esi, esi
6:  cmp esi, dword ptr [rip+g_np]
    jge 9f
    cmp esi, r12d
    je 8f
    lea rax, [rip+g_hn]
    mov r8d, dword ptr [rax+rsi*4]
    xor edi, edi
    cmp esi, dword ptr [rip+g_taker]
    jne 7f
    test r14d, r14d
    js 7f
    lea rax, [rip+g_hand]
    mov byte ptr [rax+rsi*8], r14b
    mov edi, 1
7:  cmp edi, r8d
    jge 8f
    lea rdx, [rip+g_mcU]
    movzx ecx, byte ptr [rdx+rbx]
    inc ebx
    lea rax, [rip+g_hand]
    lea r9, [rax+rsi*8]
    mov byte ptr [r9+rdi], cl
    shr ecx, 3
    lea rax, [rip+g_void]
    mov eax, dword ptr [rax+rsi*4]
    bt eax, ecx
    jnc 10f
    xor r13d, r13d
10: inc edi
    jmp 7b
8:  inc esi
    jmp 6b
9:  cmp dword ptr [rip+g_np], 2             # à deux : le reste est le talon
    jne 11f
    mov ecx, dword ptr [rip+g_dpos]
12: cmp ebx, dword ptr [rip+g_mcm]
    jge 11f
    lea rdx, [rip+g_mcU]
    movzx eax, byte ptr [rdx+rbx]
    lea r8, [rip+g_deck]
    mov byte ptr [r8+rcx], al
    inc ecx
    inc ebx
    jmp 12b
11: test r13d, r13d
    jnz 13f
    dec r15d
    jnz .Lmd_try
13: LEAVE

mc_choose:                                  # ecx = joueur -> eax = position de la carte à jouer
    ENTER
    mov r12d, ecx
    call legal_mask
    mov r13d, eax
    call mc_begin
    lea rdi, [rip+g_snap0]
    call mc_snap
    lea rdx, [rip+g_mcsum]
    xor eax, eax
    mov qword ptr [rdx], rax
    mov qword ptr [rdx+8], rax
    mov qword ptr [rdx+16], rax
    mov qword ptr [rdx+24], rax
    xor r14d, r14d
.Lmc_s:
    cmp r14d, dword ptr [rip+g_mcn]
    jge .Lmc_done
    lea rsi, [rip+g_snap0]
    call mc_unsnap
    mov ecx, r12d
    call mc_determinize
    lea rdi, [rip+g_snap1]
    call mc_snap
    xor r15d, r15d
.Lmc_c:
    cmp r15d, 8
    jge .Lmc_ns
    bt r13d, r15d
    jnc .Lmc_nc
    lea rsi, [rip+g_snap1]
    call mc_unsnap
    mov ecx, r15d
    call do_play
    call mc_rollout
    mov ecx, r12d
    call mc_value
    lea rdx, [rip+g_mcsum]
    add dword ptr [rdx+r15*4], eax
.Lmc_nc:
    inc r15d
    jmp .Lmc_c
.Lmc_ns:
    inc r14d
    jmp .Lmc_s
.Lmc_done:
    lea rsi, [rip+g_snap0]
    call mc_unsnap
    call mc_end
    mov ebx, -2000000000
    xor eax, eax
    xor ecx, ecx
1:  cmp ecx, 8
    jge 3f
    bt r13d, ecx
    jnc 2f
    lea rdx, [rip+g_mcsum]
    mov esi, dword ptr [rdx+rcx*4]
    cmp esi, ebx
    jle 2f
    mov ebx, esi
    mov eax, ecx
2:  inc ecx
    jmp 1b
3:  LEAVE

# mc_deal_bid : ecx = joueur, edx = couleur d'atout. Fabrique une donne complète compatible avec ce que voit le joueur
mc_deal_bid:
    ENTER
    mov r12d, ecx
    mov r13d, edx
    call hand_mask
    mov ecx, dword ptr [rip+g_turned]
    bts eax, ecx
    not eax
    mov r14d, eax
    lea rdi, [rip+g_mcU]
    xor ecx, ecx
    xor ebx, ebx
1:  bt r14d, ecx
    jnc 2f
    mov byte ptr [rdi+rbx], cl
    inc ebx
2:  inc ecx
    cmp ecx, 32
    jb 1b
    mov dword ptr [rip+g_mcm], ebx
    call mc_shuffle
    xor ebx, ebx
    xor esi, esi
3:  cmp esi, dword ptr [rip+g_np]
    jge 7f
    cmp esi, r12d
    je 15f
    lea rax, [rip+g_hand]
    lea r9, [rax+rsi*8]
    mov r8d, 8
    cmp dword ptr [rip+g_np], 2
    jne 4f
    mov r8d, 7
4:  xor edi, edi
5:  cmp edi, r8d
    jge 6f
    lea rdx, [rip+g_mcU]
    movzx ecx, byte ptr [rdx+rbx]
    inc ebx
    mov byte ptr [r9+rdi], cl
    inc edi
    jmp 5b
6:  lea rax, [rip+g_hn]
    mov r8d, 8
    cmp dword ptr [rip+g_np], 2
    jne 8f
    mov r8d, 7
8:  mov dword ptr [rax+rsi*4], r8d
15: inc esi
    jmp 3b
7:  lea rax, [rip+g_hand]                   # le preneur ramasse la retourne
    lea r9, [rax+r12*8]
    lea rax, [rip+g_hn]
    mov edi, dword ptr [rax+r12*4]
    mov ecx, dword ptr [rip+g_turned]
    mov byte ptr [r9+rdi], cl
    inc edi
    cmp dword ptr [rip+g_np], 4
    jne 9f
10: cmp edi, 8                              # à 4 : les 2 cartes restantes
    jge 9f
    lea rdx, [rip+g_mcU]
    movzx ecx, byte ptr [rdx+rbx]
    inc ebx
    mov byte ptr [r9+rdi], cl
    inc edi
    jmp 10b
9:  lea rax, [rip+g_hn]
    mov dword ptr [rax+r12*4], edi
    cmp dword ptr [rip+g_np], 2             # à deux : le reste est le talon
    jne 14f
    mov dword ptr [rip+g_dpos], 14
    mov ecx, 14
11: cmp ebx, dword ptr [rip+g_mcm]
    jge 14f
    lea rdx, [rip+g_mcU]
    movzx eax, byte ptr [rdx+rbx]
    lea r8, [rip+g_deck]
    mov byte ptr [r8+rcx], al
    inc ecx
    inc ebx
    jmp 11b
14: mov dword ptr [rip+g_trump], r13d
    mov dword ptr [rip+g_taker], r12d
    mov dword ptr [rip+g_phase], PH_PLAY
    mov dword ptr [rip+g_tn], 0
    mov dword ptr [rip+g_trickno], 0
    mov dword ptr [rip+g_seenmask], 0
    mov dword ptr [rip+g_belp], -1
    mov dword ptr [rip+g_annteam], -1
    mov eax, dword ptr [rip+g_dealer]
    inc eax
    xor edx, edx
    div dword ptr [rip+g_np]
    mov dword ptr [rip+g_turn], edx
    xor eax, eax
    lea rdx, [rip+g_rpts]
    mov qword ptr [rdx], rax
    lea rdx, [rip+g_rtr]
    mov qword ptr [rdx], rax
    lea rdx, [rip+g_bel]
    mov qword ptr [rdx], rax
    lea rdx, [rip+g_ann]
    mov qword ptr [rdx], rax
    lea rdx, [rip+g_void]
    mov qword ptr [rdx], rax
    mov qword ptr [rdx+8], rax
    mov dword ptr [rip+g_tcard], 0xFFFFFFFF
    mov dword ptr [rip+g_tcard+4], 0xFFFFFFFF
    LEAVE

mc_bid:                                     # ecx = joueur -> eax = -1 (passer) ou couleur
    ENTER
    mov r12d, ecx
    call mc_begin
    lea rdi, [rip+g_snap0]
    call mc_snap
    mov r15d, -1                            # meilleure couleur
    mov dword ptr [rip+g_mcsum], -2000000000
    xor r13d, r13d
.Lmb_s:
    cmp r13d, 4
    jge .Lmb_done
    mov eax, dword ptr [rip+g_turned]
    shr eax, 3
    cmp dword ptr [rip+g_bidrnd], 1
    jne 1f
    cmp eax, r13d
    jne .Lmb_next
    jmp 2f
1:  cmp eax, r13d
    je .Lmb_next
2:  xor ebx, ebx
    xor r14d, r14d
.Lmb_n:
    cmp r14d, dword ptr [rip+g_mcnb]
    jge .Lmb_avg
    lea rsi, [rip+g_snap0]
    call mc_unsnap
    mov ecx, r12d
    mov edx, r13d
    call mc_deal_bid
    call mc_rollout
    mov ecx, r12d
    call mc_value
    add ebx, eax
    inc r14d
    jmp .Lmb_n
.Lmb_avg:
    mov eax, ebx
    cdq
    idiv dword ptr [rip+g_mcnb]
    cmp eax, dword ptr [rip+g_mcsum]
    jle .Lmb_next
    mov dword ptr [rip+g_mcsum], eax
    mov r15d, r13d
.Lmb_next:
    inc r13d
    jmp .Lmb_s
.Lmb_done:
    lea rsi, [rip+g_snap0]
    call mc_unsnap
    call mc_end
    mov eax, -1
    cmp r15d, 0
    jl 9f
    mov ecx, dword ptr [rip+g_mcthr]
    cmp dword ptr [rip+g_mcsum], ecx
    jl 9f
    mov eax, r15d
9:  LEAVE
