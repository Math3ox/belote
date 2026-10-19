# ============================================================
#  sim.s — journal des parties et banc d'essai sans fenêtre (-sim)
#  belote.exe -sim <parties> <graine> <joueurs> <niv0> <niv1> <journal> [seuil1 seuil2 seuil1' seuil2']
# ============================================================
.text
lg_ch:                                    # al = caractère
    mov ecx, dword ptr [rip+g_logpos]
    lea rdx, [rip+g_logbuf]
    mov byte ptr [rdx+rcx], al
    inc ecx
    mov dword ptr [rip+g_logpos], ecx
    ret

lg_num:                                   # ecx = entier signé (suivi d'un espace)
    ENTER
    mov eax, ecx
    test eax, eax
    jns 1f
    neg eax
    mov r12d, eax
    mov eax, 45
    call lg_ch
    mov eax, r12d
1:  lea rsi, [rsp+64]
    xor edi, edi
    mov ecx, 10
2:  xor edx, edx
    div ecx
    add edx, 48
    mov byte ptr [rsi+rdi], dl
    inc edi
    test eax, eax
    jnz 2b
3:  dec edi
    movzx eax, byte ptr [rsi+rdi]
    call lg_ch
    test edi, edi
    jnz 3b
    mov eax, 32
    call lg_ch
    LEAVE

lg_nl:
    ENTER
    mov eax, 10
    call lg_ch
    cmp dword ptr [rip+g_logpos], 4190000
    jb 1f
    call log_flush
1:  LEAVE

log_flush:
    ENTER
    cmp qword ptr [rip+g_logh], 0
    je 1f
    mov rcx, qword ptr [rip+g_logh]
    lea rdx, [rip+g_logbuf]
    mov r8d, dword ptr [rip+g_logpos]
    lea r9, [rip+g_written]
    mov qword ptr [rsp+32], 0
    call WriteFile
1:  mov dword ptr [rip+g_logpos], 0
    LEAVE

log_deck:
    cmp dword ptr [rip+g_logon], 0
    jne 1f
    ret
1:  ENTER
    mov eax, 68                           # D
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, dword ptr [rip+g_np]
    call lg_num
    mov ecx, dword ptr [rip+g_dealer]
    call lg_num
    xor r12d, r12d
2:  lea rax, [rip+g_deck]
    movzx ecx, byte ptr [rax+r12]
    call lg_num
    inc r12d
    cmp r12d, 32
    jb 2b
    call lg_nl
    LEAVE

log_bid:                                  # ecx = joueur, edx = choix
    cmp dword ptr [rip+g_logon], 0
    jne 1f
    ret
1:  ENTER
    mov r12d, ecx
    mov r13d, edx
    mov eax, 66                           # B
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, r12d
    call lg_num
    mov ecx, r13d
    call lg_num
    call lg_nl
    LEAVE

log_play:                                 # ecx = joueur, edx = carte
    cmp dword ptr [rip+g_logon], 0
    jne 1f
    ret
1:  ENTER
    mov r12d, ecx
    mov r13d, edx
    mov eax, 80                           # P
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, r12d
    call lg_num
    mov ecx, r13d
    call lg_num
    mov eax, 124                          # | puis la main restante, pour recoupement
    call lg_ch
    mov eax, 32
    call lg_ch
    lea rax, [rip+g_hn]
    mov r14d, dword ptr [rax+r12*4]
    lea rax, [rip+g_hand]
    lea r15, [rax+r12*8]
    xor ebx, ebx
2:  cmp ebx, r14d
    jge 3f
    movzx ecx, byte ptr [r15+rbx]
    call lg_num
    inc ebx
    jmp 2b
3:  call lg_nl
    LEAVE

log_score:
    cmp dword ptr [rip+g_logon], 0
    jne 1f
    ret
1:  ENTER
    mov eax, 83                           # S
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, dword ptr [rip+g_rs_add]
    call lg_num
    mov ecx, dword ptr [rip+g_rs_add+4]
    call lg_num
    mov ecx, dword ptr [rip+g_score]
    call lg_num
    mov ecx, dword ptr [rip+g_score+4]
    call lg_num
    mov ecx, dword ptr [rip+g_rs_made]
    call lg_num
    mov ecx, dword ptr [rip+g_rs_capot]
    call lg_num
    mov ecx, dword ptr [rip+g_rs_pend]
    call lg_num
    call lg_nl
    LEAVE

# parse_args : rsi = texte -> g_args[] (entiers) ; nombre lu dans eax
parse_args:
    xor ecx, ecx
1:  movzx eax, byte ptr [rsi]
    test al, al
    jz 5f
    cmp al, 32
    jne 2f
    inc rsi
    jmp 1b
2:  xor edx, edx                          # signe
    cmp al, 45
    jne 3f
    mov edx, 1
    inc rsi
3:  xor r8d, r8d
4:  movzx eax, byte ptr [rsi]
    sub eax, 48
    cmp eax, 9
    ja 6f
    imul r8d, r8d, 10
    add r8d, eax
    inc rsi
    jmp 4b
6:  test edx, edx
    jz 7f
    neg r8d
7:  lea rax, [rip+g_args]
    mov dword ptr [rax+rcx*4], r8d
    inc ecx
    cmp ecx, 16
    jb 1b
5:  mov eax, ecx
    ret

# sim_main : rsi = arguments
sim_main:
    ENTER
    lea rdi, [rip+g_args]
    mov dword ptr [rdi], 10               # parties
    mov dword ptr [rdi+4], 1              # graine
    mov dword ptr [rdi+8], 4              # joueurs
    mov dword ptr [rdi+12], 1             # niveau équipe 0
    mov dword ptr [rdi+16], 1             # niveau équipe 1
    mov dword ptr [rdi+20], 0             # journal
    mov dword ptr [rdi+24], -1000
    mov dword ptr [rdi+40], -1000
    mov dword ptr [rdi+44], -1000
    mov dword ptr [rdi+48], -1000
    call parse_args
    lea rdi, [rip+g_args]
    mov eax, dword ptr [rdi+4]
    mov rcx, 0x9E3779B97F4A7C15
    imul rax, rcx
    or rax, 1
    mov qword ptr [rip+g_rng], rax
    mov eax, dword ptr [rdi+8]
    mov dword ptr [rip+g_np], eax
    mov eax, dword ptr [rdi+20]
    mov dword ptr [rip+g_logon], eax
    cmp dword ptr [rdi+24], -1000         # seuils éventuels
    je 1f
    mov eax, dword ptr [rdi+24]
    mov dword ptr [rip+g_thr1+4], eax
    mov eax, dword ptr [rdi+28]
    mov dword ptr [rip+g_thr2+4], eax
    mov eax, dword ptr [rdi+32]
    mov dword ptr [rip+g_thr1+8], eax
    mov eax, dword ptr [rdi+36]
    mov dword ptr [rip+g_thr2+8], eax
1:  cmp dword ptr [rdi+40], -1000
    je 4f
    mov eax, dword ptr [rdi+40]
    mov dword ptr [rip+g_mcn], eax
4:  cmp dword ptr [rdi+44], -1000
    je 5f
    mov eax, dword ptr [rdi+44]
    mov dword ptr [rip+g_mcnb], eax
5:  cmp dword ptr [rdi+48], -1000
    je 6f
    mov eax, dword ptr [rdi+48]
    mov dword ptr [rip+g_mcthr], eax
6:  mov eax, dword ptr [rdi+12]
    mov edx, dword ptr [rdi+16]
    lea rcx, [rip+g_lvl]
    cmp dword ptr [rip+g_np], 4
    jne 2f
    mov dword ptr [rcx], eax
    mov dword ptr [rcx+8], eax
    mov dword ptr [rcx+4], edx
    mov dword ptr [rcx+12], edx
    jmp 3f
2:  mov dword ptr [rcx], eax
    mov dword ptr [rcx+4], edx
3:  lea rcx, [rip+c_simfile]               # fichier du journal
    mov edx, 0x40000000
    xor r8d, r8d
    xor r9d, r9d
    mov dword ptr [rsp+32], 2
    mov dword ptr [rsp+40], 0x80
    mov qword ptr [rsp+48], 0
    call CreateFileA
    mov qword ptr [rip+g_logh], rax
    xor r14d, r14d                        # parties jouées
    xor r15d, r15d                        # manches
    xor ebx, ebx                          # victoires équipe 0
    xor r13d, r13d                        # victoires équipe 1
.Lsm_match:
    lea rdi, [rip+g_args]
    cmp r14d, dword ptr [rdi]
    jge .Lsm_done
    call new_match
    mov ecx, 2
    cmp dword ptr [rip+g_np], 2
    je 4f
    mov ecx, 4
4:  call rng_mod
    mov dword ptr [rip+g_dealer], eax
    call new_round
.Lsm_step:
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_BID1
    je .Lsm_bid
    cmp eax, PH_BID2
    je .Lsm_bid
    cmp eax, PH_PLAY
    je .Lsm_play
    cmp eax, PH_TRICKEND
    je .Lsm_coll
    cmp eax, PH_ROUNDEND
    je .Lsm_next
    jmp .Lsm_end
.Lsm_bid:
    mov ecx, dword ptr [rip+g_turn]
    call bot_bid
    mov ecx, eax
    call do_bid
    jmp .Lsm_step
.Lsm_play:
    mov ecx, dword ptr [rip+g_turn]
    call bot_card
    mov r12d, eax
    cmp dword ptr [rip+g_logon], 0
    je 7f
    mov eax, 81                           # Q pos masque n
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, r12d
    call lg_num
    mov ecx, dword ptr [rip+g_turn]
    call legal_mask
    mov ecx, eax
    call lg_num
    mov ecx, dword ptr [rip+g_turn]
    lea rax, [rip+g_hn]
    mov ecx, dword ptr [rax+rcx*4]
    call lg_num
    call lg_nl
7:  mov ecx, r12d
    call do_play
    jmp .Lsm_step
.Lsm_coll:
    call trick_collect
    jmp .Lsm_step
.Lsm_next:
    inc r15d
    call next_round
    jmp .Lsm_step
.Lsm_end:
    inc r15d
    cmp dword ptr [rip+g_rs_winner], 0
    jne 5f
    inc ebx
    jmp 6f
5:  inc r13d
6:  inc r14d
    jmp .Lsm_match
.Lsm_done:
    mov eax, 35                           # ligne de bilan : # parties v0 v1 manches
    call lg_ch
    mov eax, 32
    call lg_ch
    mov ecx, r14d
    call lg_num
    mov ecx, ebx
    call lg_num
    mov ecx, r13d
    call lg_num
    mov ecx, r15d
    call lg_num
    call lg_nl
    call log_flush
    mov rcx, qword ptr [rip+g_logh]
    call CloseHandle
    LEAVE

