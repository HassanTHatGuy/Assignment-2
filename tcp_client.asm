; tcp_client.asm
; Usage: ./tcp_client <port> <message>
; Connects to 127.0.0.1:<port>, sends <message>, shutdown(SHUT_WR),
; receives reply, prints to stdout, exits 0 on success.

BITS 64
GLOBAL _start

SECTION .data
ip_netorder    dd 0x0100007F           ; 127.0.0.1 (7F 00 00 01)
usage_msg      db "Usage: ./tcp_client <port> <message>",10,0
sock_fail_msg  db "socket() failed",10,0
conn_fail_msg  db "connect() failed",10,0
send_fail_msg  db "send failed",10,0
newline        db 10

SECTION .bss
sockaddr       resb 16                 ; struct sockaddr_in
recvbuf        resb 4096

SECTION .text
; Minimal helpers ------------------------------------------------------------
; write(fd=rdi, buf=rsi, len=rdx)
%macro sys_write 0
    mov rax, 1
    syscall
%endmacro

; exit(code=rdi)
%macro sys_exit 0
    mov rax, 60
    syscall
%endmacro

; close(fd=rdi)
%macro sys_close 0
    mov rax, 3
    syscall
%endmacro

_start:
    ; argv parsing: need 2 args after program name
    mov     rbx, rsp
    mov     rdi, [rbx]                ; argc
    cmp     rdi, 3
    jl      .print_usage

    mov     r12, [rbx+16]             ; argv1 -> port string
    mov     r13, [rbx+24]             ; argv2 -> message string

    ; parse port (decimal) -> r14w
    xor     r14d, r14d
.p_loop:
    mov     al, [r12]
    test    al, al
    jz      .p_done
    sub     al, '0'
    cmp     al, 9
    ja      .print_usage
    imul    r14d, r14d, 10
    add     r14d, eax
    inc     r12
    jmp     .p_loop
.p_done:
    mov     ax, r14w
    xchg    al, ah                    ; htons
    mov     r15w, ax                  ; network-order port

    ; sockaddr_in setup (16 bytes total)
    lea     rdi, [rel sockaddr]
    xor     eax, eax
    mov     rcx, 2
    rep stosq                         ; zero 16B
    lea     rdi, [rel sockaddr]
    mov     word [rdi], 2             ; AF_INET
    mov     word [rdi+2], r15w        ; sin_port
    mov     eax, [rel ip_netorder]
    mov     [rdi+4], eax              ; sin_addr = 127.0.0.1

    ; compute msg length -> rdx
    mov     rsi, r13
    xor     rcx, rcx
.len_loop:
    cmp     byte [rsi+rcx], 0
    je      .len_done
    inc     rcx
    jmp     .len_loop
.len_done:
    mov     rdx, rcx

    ; socket(AF_INET, SOCK_STREAM, 0)
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 1
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .sock_fail
    mov     rbx, rax                  ; sockfd

    ; connect(sockfd, &sockaddr, 16)
    mov     rax, 42
    mov     rdi, rbx
    lea     rsi, [rel sockaddr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .conn_fail

    ; send via write(sockfd, msg, len)
    mov     rax, 1
    mov     rdi, rbx
    mov     rsi, r13
    ; rdx already message length
    syscall
    test    rax, rax
    js      .send_fail

    ; shutdown(sockfd, SHUT_WR=1) to signal EOF to server
    mov     rax, 48
    mov     rdi, rbx
    mov     rsi, 1
    syscall

    ; recv loop until EOF or buffer full
    xor     r12, r12                  ; total read
.recv_loop:
    mov     rax, 45                   ; recvfrom
    mov     rdi, rbx
    lea     rsi, [rel recvbuf]
    add     rsi, r12
    mov     rdx, 4096
    sub     rdx, r12                  ; remaining space
    xor     r10, r10                  ; flags = 0
    xor     r8,  r8                   ; src=NULL
    xor     r9,  r9                   ; addrlen=NULL
    syscall
    cmp     rax, 0
    jle     .print_reply
    add     r12, rax
    cmp     r12, 4096
    jb      .recv_loop

.print_reply:
    ; write(1, recvbuf, total)
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [rel recvbuf]
    mov     rdx, r12
    syscall

    ; newline for cleanliness
    mov     rdi, 1
    lea     rsi, [rel newline]
    mov     rdx, 1
    sys_write

    ; close & exit 0
    mov     rdi, rbx
    sys_close
    xor     rdi, rdi
    sys_exit

; ------- error paths -------
.sock_fail:
    mov     rdi, 2
    lea     rsi, [rel sock_fail_msg]
    mov     rdx, 17
    sys_write
    mov     rdi, 1
    sys_exit

.conn_fail:
    mov     rdi, 2
    lea     rsi, [rel conn_fail_msg]
    mov     rdx, 17
    sys_write
    mov     rdi, 1
    ; best effort close
    mov     rdi, rbx
    sys_close
    mov     rdi, 1
    sys_exit

.send_fail:
    mov     rdi, 2
    lea     rsi, [rel send_fail_msg]
    mov     rdx, 12
    sys_write
    mov     rdi, rbx
    sys_close
    mov     rdi, 1
    sys_exit

.print_usage:
    mov     rdi, 2
    lea     rsi, [rel usage_msg]
    mov     rdx, 36
    sys_write
    mov     rdi, 1
    sys_exit
