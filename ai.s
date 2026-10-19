# ============================================================
#  ai.s — les bots : enchères (évaluation de la main) et jeu des cartes (heuristiques + comptage)
# ============================================================
.data
.balign 8
g_thr1:     .long 44, 44, 44              # seuil de prise au 1er tour, par niveau
g_thr2:     .long 42, 42, 42              # seuil au 2e tour

.bss
.balign 8
g_bsc:      .skip 16                      # nombre de cartes par couleur dans la main du joueur qui décide
g_bwk:      .skip 4                       # clé de la plus petite carte gagnante
g_bwp:      .skip 4
g_bmv:      .skip 4                       # meilleure carte à donner
g_bmp:      .skip 4
g_bdv:      .skip 4                       # meilleure carte à défausser
g_bdp:      .skip 4

.text
hand_mask:                                # ecx = joueur -> eax = masque 32 bits des cartes en main
    lea rax, [rip+g_hand]
    lea r8, [rax+rcx*8]
    lea rax, [rip+g_hn]
    mov r9d, dword ptr [rax+rcx*4]
    xor eax, eax
    xor r10d, r10d
1:  cmp r10d, r9d
    jge 2f
    movzx edx, byte ptr [r8+r10]
    bts eax, edx
    inc r10d
    jmp 1b
2:  ret

is_master:                                # ecx = carte -> eax = 1 si toutes les cartes plus fortes de sa couleur sont sorties ou dans g_bmine
    mov r8d, ecx
    shr r8d, 3
    mov r9d, ecx
    and r9d, 7
    lea r10, [rip+t_ordP]
    cmp r8d, dword ptr [rip+g_trump]
    jne 1f
    lea r10, [rip+t_ordT]
1:  movzx r11d, byte ptr [r10+r9]
    mov eax, dword ptr [rip+g_seenmask]
    or eax, dword ptr [rip+g_bmine]
    xor edx, edx
2:  cmp edx, 8
    jge 4f
    movzx ecx, byte ptr [r10+rdx]
    cmp ecx, r11d
    jle 3f
    mov ecx, r8d
    shl ecx, 3
    add ecx, edx
    bt eax, ecx
    jnc 5f
3:  inc edx
    jmp 2b
4:  mov eax, 1
    ret
5:  xor eax, eax
    ret

# eval_suit : ecx = joueur, edx = couleur d'atout envisagée, r8d = 1 si on ajoute la retourne -> eax = valeur de la main
eval_suit:
    ENTER
    mov r12d, ecx
    mov r13d, edx
    call hand_mask
    mov r14d, eax
    test r8d, r8d
    jz 1f
    mov eax, dword ptr [rip+g_turned]
    bts r14d, eax
1:  xor ebx, ebx
    xor r15d, r15d
    xor edi, edi
2:  cmp edi, 32
    jge 7f
    bt r14d, edi
    jnc 6f
    mov eax, edi
    shr eax, 3
    mov ecx, edi
    and ecx, 7
    cmp eax, r13d
    jne 3f
    lea rdx, [rip+t_ptsT]
    movzx edx, byte ptr [rdx+rcx]
    add ebx, edx
    inc r15d
    cmp ecx, 4
    jne 8f
    add ebx, 6
8:  cmp ecx, 2
    jne 6f
    add ebx, 3
    jmp 6f
3:  cmp ecx, 7
    jne 4f
    add ebx, 9
    jmp 6f
4:  cmp ecx, 3
    jne 6f
    shl eax, 3
    add eax, 7
    bt r14d, eax
    jnc 6f
    add ebx, 4
6:  inc edi
    jmp 2b
7:  cmp r15d, 3
    jl 9f
    lea eax, [r15-2]
    imul eax, eax, 7
    add ebx, eax
9:  mov eax, r13d                         # belote : roi et dame d'atout
    shl eax, 3
    add eax, 5
    bt r14d, eax
    jnc 10f
    inc eax
    bt r14d, eax
    jnc 10f
    add ebx, 10
10: mov eax, ebx
    LEAVE

clamp_lvl:                                # ecx = joueur -> eax = niveau 0..2
    cmp dword ptr [rip+g_mcflag], 0
    je 3f
    mov eax, 1                            # pendant les simulations tout le monde joue « normal »
    ret
3:  lea rax, [rip+g_lvl]
    mov eax, dword ptr [rax+rcx*4]
    test eax, eax
    jns 1f
    mov eax, 1
1:  cmp eax, 2
    jle 2f
    mov eax, 2
2:  ret

bot_bid:                                  # ecx = joueur -> eax = -1 (passer) ou couleur d'atout
    ENTER
    mov r12d, ecx
    call clamp_lvl
    mov r13d, eax
    cmp eax, 2
    jne 20f
    mov ecx, r12d
    call mc_bid
    LEAVE
20:
    cmp dword ptr [rip+g_bidrnd], 1
    jne .Lbb_r2
    mov edx, dword ptr [rip+g_turned]
    shr edx, 3
    mov r14d, edx
    mov ecx, r12d
    mov r8d, 1
    call eval_suit
    mov ebx, eax
    test r13d, r13d
    jnz 1f
    mov ecx, 31                           # facile : bruit
    call rng_mod
    lea ebx, [rbx+rax-15]
1:  lea rdx, [rip+g_thr1]
    cmp ebx, dword ptr [rdx+r13*4]
    jl 2f
    mov eax, r14d
    LEAVE
2:  mov eax, -1
    LEAVE
.Lbb_r2:
    mov r15d, -1                          # meilleure couleur
    mov ebx, -1000
    xor r14d, r14d
3:  mov eax, dword ptr [rip+g_turned]
    shr eax, 3
    cmp eax, r14d
    je 5f
    mov ecx, r12d
    mov edx, r14d
    mov r8d, 1
    call eval_suit
    test r13d, r13d
    jnz 4f
    push rax
    mov ecx, 31
    call rng_mod
    mov ecx, eax
    pop rax
    lea eax, [rax+rcx-15]
4:  cmp eax, ebx
    jle 5f
    mov ebx, eax
    mov r15d, r14d
5:  inc r14d
    cmp r14d, 4
    jb 3b
    lea rdx, [rip+g_thr2]
    mov eax, dword ptr [rdx+r13*4]
    cmp r12d, dword ptr [rip+g_dealer]    # le donneur parle en dernier : il prend plus facilement
    jne 6f
    sub eax, 8
6:  cmp ebx, eax
    jl 7f
    mov eax, r15d
    LEAVE
7:  mov eax, -1
    LEAVE

# ---------- jeu ----------
bot_lead:                                 # r12d = joueur, r13d = masque -> eax = position
    ENTER
    lea rax, [rip+g_bsc]                  # cartes par couleur
    mov dword ptr [rax], 0
    mov dword ptr [rax+4], 0
    mov dword ptr [rax+8], 0
    mov dword ptr [rax+12], 0
    lea rax, [rip+g_hand]
    lea rsi, [rax+r12*8]
    lea rax, [rip+g_hn]
    mov r14d, dword ptr [rax+r12*4]
    xor edi, edi
1:  cmp edi, r14d
    jge 2f
    movzx eax, byte ptr [rsi+rdi]
    shr eax, 3
    lea rdx, [rip+g_bsc]
    inc dword ptr [rdx+rax*4]
    inc edi
    jmp 1b
2:  mov r15d, -1000
    xor ebx, ebx
    xor edi, edi
3:  cmp edi, r14d
    jge .Lbl_done
    bt r13d, edi
    jnc .Lbl_next
    movzx ecx, byte ptr [rsi+rdi]
    push rcx
    call is_master
    pop rcx
    mov r8d, eax                          # maître ?
    mov eax, ecx
    shr eax, 3                            # couleur
    mov edx, ecx
    and edx, 7                            # rang
    mov r9d, dword ptr [rip+g_taker]
    xor r9d, r12d
    and r9d, 1                            # 0 : équipe preneuse
    cmp eax, dword ptr [rip+g_trump]
    jne .Lbl_plain
    lea r10, [rip+t_ordT]
    movzx r10d, byte ptr [r10+rdx]        # force
    test r9d, r9d
    jnz .Lbl_deftr
    mov r11d, 100                         # attaquant : le valet d'atout d'abord
    cmp edx, 4
    je .Lbl_score
    mov r11d, 80
    test r8d, r8d
    jnz .Lbl_score
    lea rdx, [rip+g_bsc]
    mov r11d, 5
    cmp dword ptr [rdx+rax*4], 3
    jl 4f
    mov r11d, 45
4:  sub r11d, r10d
    jmp .Lbl_score
.Lbl_deftr:
    mov r11d, 40
    test r8d, r8d
    jnz .Lbl_score
    mov r11d, -10
    sub r11d, r10d
    jmp .Lbl_score
.Lbl_plain:
    lea r10, [rip+t_ptsP]
    movzx r10d, byte ptr [r10+rdx]        # points
    test r8d, r8d
    jz 5f
    mov r11d, r10d
    shr r11d, 1
    add r11d, 60
    jmp .Lbl_score
5:  lea rdx, [rip+g_bsc]
    mov r11d, dword ptr [rdx+rax*4]
    add r11d, r11d
    add r11d, 20
    lea eax, [r10+r10]
    sub r11d, eax
.Lbl_score:
    cmp r11d, r15d
    jle .Lbl_next
    mov r15d, r11d
    mov ebx, edi
.Lbl_next:
    inc edi
    jmp 3b
.Lbl_done:
    mov eax, ebx
    LEAVE

bot_follow:                               # r12d = joueur, r13d = masque -> eax = position
    ENTER
    call trick_best
    mov r14d, eax                         # joueur qui gagne
    mov r15d, edx                         # sa clé
    mov dword ptr [rip+g_bwk], 1000
    mov dword ptr [rip+g_bwp], -1
    mov dword ptr [rip+g_bmv], -1
    mov dword ptr [rip+g_bmp], 0
    mov dword ptr [rip+g_bdv], 100000
    mov dword ptr [rip+g_bdp], 0
    lea rax, [rip+g_hand]
    lea rsi, [rax+r12*8]
    lea rax, [rip+g_hn]
    mov ebx, dword ptr [rax+r12*4]
    xor edi, edi
1:  cmp edi, ebx
    jge 9f
    bt r13d, edi
    jnc 8f
    movzx ecx, byte ptr [rsi+rdi]
    push rcx
    call card_key
    cmp eax, r15d
    jle 2f
    cmp eax, dword ptr [rip+g_bwk]
    jge 2f
    mov dword ptr [rip+g_bwk], eax
    mov dword ptr [rip+g_bwp], edi
2:  pop rcx
    call card_pts
    mov r8d, eax                          # points
    mov eax, ecx
    shr eax, 3
    mov edx, ecx
    and edx, 7
    cmp eax, dword ptr [rip+g_trump]
    je 3f
    lea r9, [rip+t_ordP]
    movzx r9d, byte ptr [r9+rdx]
    lea r10d, [r8*4]                      # à donner : points x4 (hors atout)
    lea r11d, [r8*8+r9]                   # à défausser : points x8 + force
    jmp 4f
3:  lea r9, [rip+t_ordT]
    movzx r9d, byte ptr [r9+rdx]
    lea r10d, [r8*2]
    lea r11d, [r8*8+r9+400]
4:  cmp r10d, dword ptr [rip+g_bmv]
    jle 5f
    mov dword ptr [rip+g_bmv], r10d
    mov dword ptr [rip+g_bmp], edi
5:  cmp r11d, dword ptr [rip+g_bdv]
    jge 8f
    mov dword ptr [rip+g_bdv], r11d
    mov dword ptr [rip+g_bdp], edi
8:  inc edi
    jmp 1b
9:  cmp dword ptr [rip+g_np], 4           # partenaire en train de gagner ?
    jne .Lbf_opp
    mov eax, r14d
    xor eax, r12d
    test al, 1
    jnz .Lbf_opp
    mov eax, dword ptr [rip+g_np]         # dernier à jouer : on donne le maximum
    dec eax
    cmp dword ptr [rip+g_tn], eax
    je .Lbf_give
    lea rax, [rip+g_tcard]                # sinon seulement si sa carte est maîtresse et ne peut pas être coupée
    movzx ecx, byte ptr [rax+r14]
    push rcx
    call is_master
    pop rcx
    test eax, eax
    jz .Lbf_cheap
    mov eax, ecx
    shr eax, 3
    cmp eax, dword ptr [rip+g_trump]
    je .Lbf_give
    cmp dword ptr [rip+g_led], eax
    je 11f
11: mov eax, dword ptr [rip+g_led]
    cmp eax, dword ptr [rip+g_trump]
    je .Lbf_give
    mov esi, 1                            # joueurs restant à jouer après moi
10: mov eax, r12d
    add eax, esi
    xor edx, edx
    div dword ptr [rip+g_np]
    cmp edx, dword ptr [rip+g_tlead]
    je .Lbf_give
    mov ecx, dword ptr [rip+g_led]
    lea rax, [rip+g_void]
    mov eax, dword ptr [rax+rdx*4]
    bt eax, ecx
    jc .Lbf_cheap
    inc esi
    jmp 10b
.Lbf_give:
    mov eax, dword ptr [rip+g_bmp]
    LEAVE
.Lbf_cheap:
    mov eax, dword ptr [rip+g_bdp]
    LEAVE
.Lbf_opp:
    mov eax, dword ptr [rip+g_bwp]
    test eax, eax
    jns 12f
    mov eax, dword ptr [rip+g_bdp]
12: LEAVE

bot_card:                                 # ecx = joueur -> eax = position de la carte à jouer
    ENTER
    mov r12d, ecx
    call legal_mask
    mov r13d, eax
    popcnt eax, r13d
    cmp eax, 1
    jne 1f
    bsf eax, r13d
    LEAVE
1:  mov ecx, r12d
    call clamp_lvl
    cmp eax, 2
    jne 20f
    mov ecx, r12d
    call mc_choose
    LEAVE
20: test eax, eax
    jnz 3f
    mov ecx, 100                          # facile : 35 % de coups au hasard
    call rng_mod
    cmp eax, 35
    jge 3f
    popcnt ecx, r13d
    call rng_mod
    mov ecx, eax
    mov eax, r13d
2:  bsf edx, eax
    test ecx, ecx
    jz 4f
    btr eax, edx
    dec ecx
    jmp 2b
4:  mov eax, edx
    LEAVE
3:  mov ecx, r12d
    call hand_mask
    mov dword ptr [rip+g_bmine], eax
    cmp dword ptr [rip+g_tn], 0
    je 5f
    call bot_follow
    LEAVE
5:  call bot_lead
    LEAVE
