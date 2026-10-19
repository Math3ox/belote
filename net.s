# ============================================================
#  net.s — parties en ligne : 2 à 4 humains, connexion TCP directe par IP (étoile : l'hôte relaie)
#
#  Principe « lockstep » : toutes les machines exécutent exactement la même partie (mêmes règles, mêmes bots,
#  même générateur aléatoire dont la graine est envoyée par l'hôte au démarrage). On n'échange que les actions
#  des humains : enchère, carte jouée (position dans la main), « suite ». 12 octets par action.
#  L'hôte est le siège 0. Les invités prennent les sièges 2, 1, 3 (4 joueurs : le 1er invité est le partenaire)
#  ou le siège 1 (belote à deux). Les sièges non occupés sont tenus par des bots.
# ============================================================
.equ NET_PORT, 4210
.equ WM_NET, 0x401
.equ NQ_N, 64

.section .rdata,"dr"
n_menu1:    .asciz "MULTIJOUEUR EN LIGNE"
n_menu2:    .asciz "H : h\351berger une partie      R : rejoindre une partie      Echap : annuler"
n_menu3:    .asciz "Tous les joueurs doivent avoir la m\352me version du jeu."
n_host1:    .asciz "En attente de joueurs...  Ton adresse IP : "
n_host2:    .asciz "Port 4210 (r\351seau local, VPN type Tailscale, ou redirection de port). Echap : annuler."
n_host3a:   .asciz " joueur(s) connect\351(s). Entr\351e : commencer maintenant (les places libres sont tenues par des bots)."
n_host3b:   .asciz "Mode \340 deux : la partie d\351marre d\350s qu'un joueur se connecte."
n_join1:    .asciz "Adresse IP de l'h\364te (Entr\351e = valider) : "
n_join2:    .asciz "Exemple : 192.168.1.20   (autre port : 192.168.1.20:4210). Echap : annuler."
n_conn1:    .asciz "Connexion en cours... (Echap : annuler)"
n_badip:    .asciz "Adresse IP invalide. Exemple : 192.168.1.20"
n_failc:    .asciz "Connexion impossible (h\364te absent ou port ferm\351)."
n_failh:    .asciz "Impossible d'\351couter sur le port 4210 (d\351j\340 utilis\351 ?)."
n_wait:     .asciz "Connect\351 ! En attente du d\351part de la partie par l'h\364te..."
n_lost:     .asciz "Connexion perdue : retour \340 la partie locale."
n_unk:      .asciz "?"
n_dot:      .asciz "."
n_slash:    .asciz "  /  "
n_us:       .asciz "_"
n_wnext:    .asciz "En attente des autres joueurs..."
n_online:   .asciz "EN LIGNE"
s_joueur:   .asciz "JOUEUR "
.balign 4
t_seat4:    .long 0, 2, 1, 3                # siège du k-ième invité (4 joueurs)

.data
.balign 4
g_net:      .long 0                         # 0 hors ligne, 1 hôte en attente, 2 connexion en cours, 3 invité connecté, 4 partie en ligne
g_menu:     .long 0                         # 0 rien, 1 choix H/R, 2 saisie de l'IP
g_nguests:  .long 0
g_humans:   .long 1                         # masque des sièges humains
g_nextmask: .long 0
nq_head:    .long 0
nq_tail:    .long 0
.balign 8
g_lsock:    .quad -1
g_csock:    .quad -1, -1, -1, -1            # sockets des invités (hôte) ; [0] = socket de l'hôte (invité)

.bss
.balign 8
ws_up:      .skip 4
ws_data:    .skip 512
ns_sa:      .skip 16
ns_out:     .skip 16
ns_rx:      .skip 4*128
ns_nrx:     .skip 16
ns_iplen:   .skip 4
ns_ip:      .skip 48
ns_tmp:     .skip 48
ns_host:    .skip 264
g_nl1:      .skip 200
g_nl2:      .skip 200
g_nl3:      .skip 200
nq:         .skip NQ_N*12
ns_one:     .skip 4

.text
net_maxguests:                              # -> eax
    mov eax, 1
    cmp dword ptr [rip+g_np], 4
    jne 1f
    mov eax, 3
1:  ret

nl_copy:                                    # rdi = destination, g_tbuf -> copie
    lea rsi, [rip+g_tbuf]
1:  mov al, byte ptr [rsi]
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz 1b
    ret

nl_set:                                     # rdi = ligne, rsi = texte constant
    mov al, byte ptr [rsi]
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz nl_set
    ret

nl_clear:
    mov byte ptr [rip+g_nl1], 0
    mov byte ptr [rip+g_nl2], 0
    mov byte ptr [rip+g_nl3], 0
    ret

ws_start:                                   # eax = 1 si Winsock est prêt
    ENTER
    cmp dword ptr [rip+ws_up], 0
    jne 1f
    mov ecx, 0x0202
    lea rdx, [rip+ws_data]
    call WSAStartup
    test eax, eax
    jnz 2f
    mov dword ptr [rip+ws_up], 1
1:  mov eax, 1
    LEAVE
2:  xor eax, eax
    LEAVE

net_make_addr:                              # rdi = sockaddr, eax = adresse IPv4 (ordre réseau), ecx = port
    mov word ptr [rdi], 2
    mov edx, ecx
    rol dx, 8
    mov word ptr [rdi+2], dx
    mov dword ptr [rdi+4], eax
    mov qword ptr [rdi+8], 0
    ret

# ---------- menu ----------
net_open:                                   # touche N
    ENTER
    cmp dword ptr [rip+g_net], 0
    je 1f
    lea rsi, [rip+n_lost]                   # déjà en ligne : on coupe
    call net_close
    jmp 9f
1:  cmp dword ptr [rip+g_menu], 0
    jne 9f
    mov dword ptr [rip+g_menu], 1
    call nl_clear
    mov dword ptr [rip+g_dirty], 1
9:  LEAVE

net_menu_key:                               # ecx = touche virtuelle (menu ouvert)
    ENTER
    cmp ecx, 0x7B
    jne 1f
    call save_bmp
    jmp 9f
1:  cmp dword ptr [rip+g_menu], 1
    jne 9f
    cmp ecx, 0x48
    je .Lnm_host
    cmp ecx, 0x52
    je .Lnm_join
    cmp ecx, 0x10
    je 9f
    cmp ecx, 0x11
    je 9f
    mov dword ptr [rip+g_menu], 0
    mov dword ptr [rip+g_dirty], 1
    jmp 9f
.Lnm_host:
    mov dword ptr [rip+g_menu], 0
    call net_host
    jmp 9f
.Lnm_join:
    mov dword ptr [rip+g_menu], 2
    call net_prompt
9:  LEAVE

net_prompt:
    ENTER
    call tb_reset
    lea rsi, [rip+n_join1]
    call tb_str
    lea rsi, [rip+ns_ip]
    call tb_str
    lea rsi, [rip+n_us]
    call tb_str
    lea rdi, [rip+g_nl1]
    call nl_copy
    lea rdi, [rip+g_nl2]
    lea rsi, [rip+n_join2]
    call nl_set
    mov dword ptr [rip+g_dirty], 1
    LEAVE

net_char:                                   # ecx = caractère (WM_CHAR) pendant la saisie de l'IP
    ENTER
    cmp dword ptr [rip+g_menu], 2
    jne .Lnch_end
    cmp ecx, 27
    jne 1f
    mov dword ptr [rip+g_menu], 0
    mov dword ptr [rip+g_dirty], 1
    jmp .Lnch_end
1:  cmp ecx, 13
    jne 2f
    call net_join
    jmp .Lnch_end
2:  cmp ecx, 8
    jne 3f
    mov eax, dword ptr [rip+ns_iplen]
    test eax, eax
    jz .Lnch_end
    dec eax
    mov dword ptr [rip+ns_iplen], eax
    lea rdx, [rip+ns_ip]
    mov byte ptr [rdx+rax], 0
    call net_prompt
    jmp .Lnch_end
3:  cmp ecx, 48
    jb 4f
    cmp ecx, 58
    jbe 5f
    jmp .Lnch_end
4:  cmp ecx, 46
    je 5f
    jmp .Lnch_end
5:  mov eax, dword ptr [rip+ns_iplen]
    cmp eax, 21
    jae .Lnch_end
    lea rdx, [rip+ns_ip]
    mov byte ptr [rdx+rax], cl
    inc eax
    mov byte ptr [rdx+rax], 0
    mov dword ptr [rip+ns_iplen], eax
    call net_prompt
.Lnch_end:
    LEAVE

# ---------- hôte ----------
net_host:
    ENTER
    call ws_start
    test eax, eax
    jnz 1f
    lea rdi, [rip+g_nl1]
    lea rsi, [rip+n_failh]
    call nl_set
    jmp .Lnh_end
1:  mov dword ptr [rip+ns_one], 1
    mov ecx, 2
    mov edx, 1
    mov r8d, 6
    call socket
    mov qword ptr [rip+g_lsock], rax
    cmp rax, -1
    je .Lnh_fail
    mov rcx, rax
    mov edx, 0xFFFF
    mov r8d, 4
    lea r9, [rip+ns_one]
    mov dword ptr [rsp+32], 4
    call setsockopt
    lea rdi, [rip+ns_sa]
    xor eax, eax
    mov ecx, NET_PORT
    call net_make_addr
    mov rcx, qword ptr [rip+g_lsock]
    lea rdx, [rip+ns_sa]
    mov r8d, 16
    call bind
    test eax, eax
    jnz .Lnh_fail
    mov rcx, qword ptr [rip+g_lsock]
    mov edx, 4
    call listen
    mov rcx, qword ptr [rip+g_lsock]
    mov rdx, qword ptr [rip+g_hwnd]
    mov r8d, WM_NET
    mov r9d, 8
    call WSAAsyncSelect
    mov dword ptr [rip+g_net], 1
    mov dword ptr [rip+g_nguests], 0
    mov qword ptr [rip+g_csock+8], -1
    mov qword ptr [rip+g_csock+16], -1
    mov qword ptr [rip+g_csock+24], -1
    call tb_reset                           # ligne 1 : adresses IP locales
    lea rsi, [rip+n_host1]
    call tb_str
    lea rcx, [rip+ns_host]
    mov edx, 256
    call gethostname
    lea rcx, [rip+ns_host]
    call gethostbyname
    test rax, rax
    jz .Lnh_unk
    mov r15, qword ptr [rax+24]
    test r15, r15
    jz .Lnh_unk
    xor r14d, r14d
.Lnh_e:
    mov r13, qword ptr [r15+r14*8]
    test r13, r13
    jnz 4f
    test r14d, r14d
    jz .Lnh_unk
    jmp .Lnh_tail
4:  test r14d, r14d
    jz 3f
    lea rsi, [rip+n_slash]
    call tb_str
3:  xor r12d, r12d
.Lnh_b:
    movzx ecx, byte ptr [r13+r12]
    call tb_int
    inc r12d
    cmp r12d, 4
    jae .Lnh_nxt
    lea rsi, [rip+n_dot]
    call tb_str
    jmp .Lnh_b
.Lnh_nxt:
    inc r14d
    cmp r14d, 3
    jb .Lnh_e
    jmp .Lnh_tail
.Lnh_unk:
    lea rsi, [rip+n_unk]
    call tb_str
.Lnh_tail:
    lea rdi, [rip+g_nl1]
    call nl_copy
    lea rdi, [rip+g_nl2]
    lea rsi, [rip+n_host2]
    call nl_set
    call net_host_msg
    mov dword ptr [rip+g_dirty], 1
    jmp .Lnh_end
.Lnh_fail:
    mov rcx, qword ptr [rip+g_lsock]
    cmp rcx, -1
    je 2f
    call closesocket
2:  mov qword ptr [rip+g_lsock], -1
    lea rdi, [rip+g_nl1]
    lea rsi, [rip+n_failh]
    call nl_set
    mov dword ptr [rip+g_menu], 3           # message d'erreur affiché
    mov dword ptr [rip+g_dirty], 1
.Lnh_end:
    LEAVE

net_host_msg:                               # ligne 3 : nombre de joueurs connectés
    ENTER
    cmp dword ptr [rip+g_np], 2
    jne 1f
    lea rdi, [rip+g_nl3]
    lea rsi, [rip+n_host3b]
    call nl_set
    jmp 2f
1:  call tb_reset
    mov ecx, dword ptr [rip+g_nguests]
    inc ecx
    call tb_int
    lea rsi, [rip+n_host3a]
    call tb_str
    lea rdi, [rip+g_nl3]
    call nl_copy
2:  LEAVE

# ---------- invité ----------
net_join:
    ENTER
    mov dword ptr [rip+g_menu], 0
    lea rsi, [rip+ns_ip]
    lea rdi, [rip+ns_tmp]
    xor r13d, r13d
.Lnj_cp:
    mov al, byte ptr [rsi]
    test al, al
    jz .Lnj_cpend
    cmp al, 58
    je .Lnj_port
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    jmp .Lnj_cp
.Lnj_port:
    inc rsi
.Lnj_pd:
    movzx eax, byte ptr [rsi]
    test eax, eax
    jz .Lnj_cpend
    sub eax, 48
    cmp eax, 9
    ja .Lnj_cpend
    imul r13d, r13d, 10
    add r13d, eax
    cmp r13d, 65535
    ja .Lnj_bad
    inc rsi
    jmp .Lnj_pd
.Lnj_cpend:
    mov byte ptr [rdi], 0
    test r13d, r13d
    jnz 1f
    mov r13d, NET_PORT
1:  call ws_start
    test eax, eax
    jnz 2f
    jmp .Lnj_failc
2:  lea rcx, [rip+ns_tmp]
    call inet_addr
    cmp eax, -1
    je .Lnj_bad
    test eax, eax
    jz .Lnj_bad
    mov r14d, eax
    mov ecx, 2
    mov edx, 1
    mov r8d, 6
    call socket
    mov qword ptr [rip+g_csock], rax
    cmp rax, -1
    je .Lnj_failc
    mov rcx, rax
    mov rdx, qword ptr [rip+g_hwnd]
    mov r8d, WM_NET
    mov r9d, 0x31
    call WSAAsyncSelect
    lea rdi, [rip+ns_sa]
    mov eax, r14d
    mov ecx, r13d
    call net_make_addr
    mov rcx, qword ptr [rip+g_csock]
    lea rdx, [rip+ns_sa]
    mov r8d, 16
    call connect
    mov dword ptr [rip+g_net], 2
    mov dword ptr [rip+g_isguest], 1
    mov dword ptr [rip+ns_nrx], 0
    lea rdi, [rip+g_nl1]
    lea rsi, [rip+n_conn1]
    call nl_set
    mov byte ptr [rip+g_nl2], 0
    mov byte ptr [rip+g_nl3], 0
    mov dword ptr [rip+g_dirty], 1
    jmp .Lnj_end
.Lnj_bad:
    mov dword ptr [rip+g_menu], 2
    call net_prompt
    lea rdi, [rip+g_nl2]
    lea rsi, [rip+n_badip]
    call nl_set
    jmp .Lnj_end
.Lnj_failc:
    lea rdi, [rip+g_nl1]
    lea rsi, [rip+n_failc]
    call nl_set
    mov byte ptr [rip+g_nl2], 0
    mov dword ptr [rip+g_menu], 3
    mov dword ptr [rip+g_dirty], 1
.Lnj_end:
    LEAVE

# ---------- trames ----------
net_send_to:                                # rcx = socket : envoie les 12 octets de ns_out
    sub rsp, 40
    lea rdx, [rip+ns_out]
    mov r8d, 12
    xor r9d, r9d
    call send
    add rsp, 40
    ret

net_set_out:                                # ecx = type, edx = siège/octet 1, r8d = b, r9d = c, [d dans eax]
    mov byte ptr [rip+ns_out], cl
    mov byte ptr [rip+ns_out+1], dl
    mov word ptr [rip+ns_out+2], r8w
    mov dword ptr [rip+ns_out+4], r9d
    mov dword ptr [rip+ns_out+8], eax
    ret

# net_relay : envoie ns_out à tous les invités sauf celui de socket r12 (hôte) ou à l'hôte (invité)
net_relay:
    ENTER
    cmp dword ptr [rip+g_net], 4
    jne 9f
    lea rax, [rip+g_csock]
    cmp dword ptr [rip+g_isguest], 0
    je 1f
    mov rcx, qword ptr [rax]                # invité : tout part vers l'hôte
    call net_send_to
    jmp 9f
1:  mov r13d, 1
2:  cmp r13d, 3
    jg 9f
    lea rax, [rip+g_csock]
    mov rcx, qword ptr [rax+r13*8]
    cmp rcx, -1
    je 3f
    cmp rcx, r12
    je 3f
    call net_send_to
3:  inc r13d
    jmp 2b
9:  LEAVE

net_send_action:                            # ecx = type, edx = b ; émet l'action du joueur local à tous
    ENTER
    mov r8d, edx
    mov edx, dword ptr [rip+g_me]
    xor r9d, r9d
    xor eax, eax
    call net_set_out
    mov r12, -2
    call net_relay
    LEAVE

# ---------- événements WM_NET ----------
net_event:                                  # rcx = socket, edx = lParam
    ENTER
    mov r12, rcx
    mov eax, edx
    movzx r13d, ax
    shr eax, 16
    mov r14d, eax
    test r13d, 8
    jnz .Lne_accept
    test r13d, 0x10
    jnz .Lne_conn
    test r13d, 1
    jnz .Lne_read
    test r13d, 0x20
    jnz .Lne_close
    jmp .Lne_end
.Lne_accept:
    cmp dword ptr [rip+g_net], 1
    jne .Lne_end
    mov rcx, qword ptr [rip+g_lsock]
    xor edx, edx
    xor r8d, r8d
    call accept
    cmp rax, -1
    je .Lne_end
    mov r15, rax
    call net_maxguests
    cmp dword ptr [rip+g_nguests], eax
    jl 1f
    mov rcx, r15
    call closesocket
    jmp .Lne_end
1:  inc dword ptr [rip+g_nguests]
    mov ebx, dword ptr [rip+g_nguests]
    lea rax, [rip+g_csock]
    mov qword ptr [rax+rbx*8], r15
    lea rax, [rip+ns_nrx]
    mov dword ptr [rax+rbx*4], 0
    mov rcx, r15
    mov rdx, qword ptr [rip+g_hwnd]
    mov r8d, WM_NET
    mov r9d, 0x21
    call WSAAsyncSelect
    mov eax, 1                              # siège attribué
    cmp dword ptr [rip+g_np], 4
    jne 2f
    lea rdx, [rip+t_seat4]
    mov eax, dword ptr [rdx+rbx*4]
2:  mov edx, eax
    mov ecx, NT_HELLO
    mov r8d, dword ptr [rip+g_np]
    xor r9d, r9d
    xor eax, eax
    call net_set_out
    mov rcx, r15
    call net_send_to
    call net_host_msg
    mov dword ptr [rip+g_dirty], 1
    call net_maxguests
    cmp dword ptr [rip+g_nguests], eax
    jl .Lne_end
    call net_host_start
    jmp .Lne_end
.Lne_conn:
    test r14d, r14d
    jz 1f
    lea rsi, [rip+n_failc]
    call net_close
    jmp .Lne_end
1:  mov dword ptr [rip+g_net], 3
    lea rdi, [rip+g_nl1]
    lea rsi, [rip+n_wait]
    call nl_set
    mov byte ptr [rip+g_nl2], 0
    mov byte ptr [rip+g_nl3], 0
    mov dword ptr [rip+g_dirty], 1
    jmp .Lne_end
.Lne_read:
    mov rcx, r12
    call net_recv
    jmp .Lne_end
.Lne_close:
    lea rsi, [rip+n_lost]
    call net_close
.Lne_end:
    LEAVE

net_recv:                                   # rcx = socket
    ENTER
    mov r12, rcx
    xor r13d, r13d                          # indice de la socket
    lea rax, [rip+g_csock]
    cmp dword ptr [rip+g_isguest], 0
    je 1f
    jmp 3f                                  # invité : indice 0
1:  mov r13d, 1
2:  cmp r13d, 3
    jg .Lnr_end
    cmp qword ptr [rax+r13*8], r12
    je 3f
    inc r13d
    jmp 2b
3:  mov r15d, r13d
    imul r15d, r15d, 128                    # tampon de cet invité
    lea r14, [rip+ns_rx]
    add r14, r15
.Lnr_l:
    lea rax, [rip+ns_nrx]
    mov eax, dword ptr [rax+r13*4]
    mov r8d, 128
    sub r8d, eax
    jle .Lnr_end
    mov rcx, r12
    lea rdx, [r14+rax]
    xor r9d, r9d
    call recv
    test eax, eax
    jle .Lnr_end
    lea rdx, [rip+ns_nrx]
    add dword ptr [rdx+r13*4], eax
.Lnr_f:
    lea rdx, [rip+ns_nrx]
    mov eax, dword ptr [rdx+r13*4]
    cmp eax, 12
    jb .Lnr_l
    mov rsi, r14
    call net_frame
    lea rdx, [rip+ns_nrx]
    sub dword ptr [rdx+r13*4], 12
    mov ecx, dword ptr [rdx+r13*4]
    mov rdi, r14
    lea rsi, [r14+12]
    cld
    rep movsb
    jmp .Lnr_f
.Lnr_end:
    LEAVE

net_frame:                                  # rsi = trame ; r12 = socket d'origine
    ENTER
    movzx eax, byte ptr [rsi]
    cmp eax, NT_HELLO
    je .Lnf_hello
    cmp eax, NT_START
    je .Lnf_start
    cmp eax, NT_BID
    jb .Lnf_end
    cmp eax, NT_NEXT
    ja .Lnf_end
    mov ecx, dword ptr [rip+nq_tail]
    lea edx, [rcx+1]
    and edx, NQ_N-1
    cmp edx, dword ptr [rip+nq_head]
    je .Lnf_end
    imul r8d, ecx, 12
    lea r9, [rip+nq]
    mov rax, qword ptr [rsi]
    mov qword ptr [r9+r8], rax
    mov eax, dword ptr [rsi+8]
    mov dword ptr [r9+r8+8], eax
    mov dword ptr [rip+nq_tail], edx
    mov rax, qword ptr [rsi]                # l'hôte relaie aux autres invités
    mov qword ptr [rip+ns_out], rax
    mov eax, dword ptr [rsi+8]
    mov dword ptr [rip+ns_out+8], eax
    cmp dword ptr [rip+g_isguest], 0
    jne .Lnf_end
    call net_relay
    jmp .Lnf_end
.Lnf_hello:
    movzx eax, byte ptr [rsi+1]
    mov dword ptr [rip+g_me], eax
    jmp .Lnf_end
.Lnf_start:
    cmp dword ptr [rip+g_isguest], 0
    je .Lnf_end
    movzx eax, byte ptr [rsi+1]             # configuration
    movzx ecx, word ptr [rsi+2]             # objectif
    mov r8d, dword ptr [rsi+4]
    mov r9d, dword ptr [rsi+8]
    shl r9, 32
    or r8, r9                               # graine
    call net_begin
.Lnf_end:
    LEAVE

# net_host_start : tous les invités attendus sont là (ou l'hôte lance)
net_host_start:
    ENTER
    mov eax, dword ptr [rip+g_nguests]
    test eax, eax
    jz 9f
    mov ebx, 1                              # masque des humains
    cmp dword ptr [rip+g_np], 2
    jne 1f
    mov ebx, 3
    jmp 3f
1:  mov r12d, 1
2:  cmp r12d, dword ptr [rip+g_nguests]
    jg 3f
    lea rdx, [rip+t_seat4]
    mov ecx, dword ptr [rdx+r12*4]
    mov eax, 1
    shl eax, cl
    or ebx, eax
    inc r12d
    jmp 2b
3:  mov eax, ebx                            # octet de configuration
    mov ecx, dword ptr [rip+g_optann]
    shl ecx, 4
    or eax, ecx
    mov ecx, dword ptr [rip+g_botlvl]
    shl ecx, 5
    or eax, ecx
    cmp dword ptr [rip+g_np], 4
    jne 4f
    or eax, 0x80
4:  mov r13d, eax
    mov r14, qword ptr [rip+g_rng]          # graine
    rdtsc
    shl rdx, 32
    or rax, rdx
    xor r14, rax
    or r14, 1
    mov ecx, NT_START
    mov edx, r13d
    mov r8d, dword ptr [rip+g_target]
    mov r9d, r14d
    mov rax, r14
    shr rax, 32
    call net_set_out
    mov r12, -2
    mov dword ptr [rip+g_net], 4
    call net_relay
    mov eax, r13d
    mov ecx, dword ptr [rip+g_target]
    mov r8, r14
    xor edx, edx
    mov dword ptr [rip+g_isguest], 0
    mov dword ptr [rip+g_me], 0
    call net_begin
9:  LEAVE

# net_begin : eax = octet de configuration, ecx = objectif, r8 = graine
net_begin:
    ENTER
    mov r12d, eax
    mov dword ptr [rip+g_target], ecx
    mov qword ptr [rip+g_rng], r8
    mov eax, r12d
    and eax, 15
    mov dword ptr [rip+g_humans], eax
    mov eax, r12d
    shr eax, 4
    and eax, 1
    mov dword ptr [rip+g_optann], eax
    mov eax, r12d
    shr eax, 5
    and eax, 3
    cmp eax, 2
    jbe 1f
    mov eax, 1
1:  mov dword ptr [rip+g_botlvl], eax
    mov eax, 2
    test r12d, 0x80
    jz 2f
    mov eax, 4
2:  mov dword ptr [rip+g_np], eax
    mov dword ptr [rip+g_net], 4
    mov dword ptr [rip+g_menu], 0
    mov dword ptr [rip+nq_head], 0
    mov dword ptr [rip+nq_tail], 0
    mov dword ptr [rip+g_nextmask], 0
    call ui_newmatch
    LEAVE

net_close:                                  # rsi = message
    ENTER
    mov r12, rsi
    xor r13d, r13d
1:  lea rax, [rip+g_csock]
    mov rcx, qword ptr [rax+r13*8]
    cmp rcx, -1
    je 2f
    call closesocket
    lea rax, [rip+g_csock]
    mov qword ptr [rax+r13*8], -1
2:  inc r13d
    cmp r13d, 4
    jb 1b
    cmp qword ptr [rip+g_lsock], -1
    je 3f
    mov rcx, qword ptr [rip+g_lsock]
    call closesocket
    mov qword ptr [rip+g_lsock], -1
3:  mov eax, dword ptr [rip+g_net]
    mov dword ptr [rip+g_net], 0
    mov dword ptr [rip+g_isguest], 0
    mov dword ptr [rip+g_nguests], 0
    mov dword ptr [rip+nq_head], 0
    mov dword ptr [rip+nq_tail], 0
    lea rdi, [rip+ns_nrx]
    xor ecx, ecx
    mov dword ptr [rdi], 0
    mov dword ptr [rdi+4], 0
    mov dword ptr [rdi+8], 0
    mov dword ptr [rdi+12], 0
    mov dword ptr [rip+g_menu], 0
    cmp eax, 4
    jne 4f
    mov dword ptr [rip+g_humans], 1         # partie en ligne terminée : retour à une partie locale
    mov dword ptr [rip+g_me], 0
    call ui_newmatch
    lea rdi, [rip+g_nl1]
    mov rsi, r12
    call nl_set
    mov byte ptr [rip+g_nl2], 0
    mov byte ptr [rip+g_nl3], 0
    mov dword ptr [rip+g_menu], 3           # message d'information
4:  mov dword ptr [rip+g_dirty], 1
    LEAVE

net_cancel:                                 # Échap
    ENTER
    lea rsi, [rip+n_lost]
    call net_close
    mov dword ptr [rip+g_menu], 0
    LEAVE

# ---------- application des actions reçues ----------
net_pump:
    ENTER
.Lnp_again:
    cmp dword ptr [rip+g_net], 4
    jne .Lnp_end
    mov ecx, dword ptr [rip+nq_head]
    cmp ecx, dword ptr [rip+nq_tail]
    je .Lnp_end
    imul eax, ecx, 12
    lea rdx, [rip+nq]
    add rdx, rax
    movzx r12d, byte ptr [rdx]
    movzx r13d, byte ptr [rdx+1]            # siège
    movzx r14d, word ptr [rdx+2]
    cmp r12d, NT_BID
    je .Lnp_bid
    cmp r12d, NT_PLAY
    je .Lnp_play
    cmp r12d, NT_NEXT
    je .Lnp_next
    jmp .Lnp_pop
.Lnp_bid:
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_BID1
    je 1f
    cmp eax, PH_BID2
    jne .Lnp_end
1:  cmp r13d, dword ptr [rip+g_turn]
    jne .Lnp_end
    call .Lnp_popq
    lea ecx, [r14-1]
    movsx ecx, cx
    call apply_bid
    jmp .Lnp_again
.Lnp_play:
    cmp dword ptr [rip+g_phase], PH_PLAY
    jne .Lnp_end
    cmp r13d, dword ptr [rip+g_turn]
    jne .Lnp_end
    call .Lnp_popq
    mov ecx, r14d
    call apply_play
    jmp .Lnp_again
.Lnp_next:
    mov eax, dword ptr [rip+g_phase]
    cmp eax, PH_ROUNDEND
    je 2f
    cmp eax, PH_MATCHEND
    jne .Lnp_end
2:  call .Lnp_popq
    mov ecx, r13d
    call net_mark_next
    jmp .Lnp_again
.Lnp_pop:
    call .Lnp_popq
    jmp .Lnp_again
.Lnp_popq:
    mov ecx, dword ptr [rip+nq_head]
    inc ecx
    and ecx, NQ_N-1
    mov dword ptr [rip+nq_head], ecx
    ret
.Lnp_end:
    LEAVE

net_mark_next:                              # ecx = siège qui a appuyé sur SUITE
    ENTER
    mov eax, 1
    shl eax, cl
    or dword ptr [rip+g_nextmask], eax
    mov eax, dword ptr [rip+g_nextmask]
    and eax, dword ptr [rip+g_humans]
    cmp eax, dword ptr [rip+g_humans]
    jne 9f
    mov dword ptr [rip+g_nextmask], 0
    call do_next_step
9:  LEAVE

do_next_step:                               # passe à la manche / partie suivante
    ENTER
    cmp dword ptr [rip+g_phase], PH_MATCHEND
    jne 1f
    call ui_newmatch
    jmp 2f
1:  cmp dword ptr [rip+g_phase], PH_ROUNDEND
    jne 2f
    call next_round
    call ui_newround_after
2:  mov dword ptr [rip+g_dirty], 1
    LEAVE

.data
g_isguest:  .long 0
