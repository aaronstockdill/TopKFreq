%define SYS_EXIT   0x2000001
%define SYS_READ   0x2000003
%define SYS_WRITE  0x2000004
%define SYS_OPEN   0x2000005
%define SYS_CLOSE  0x2000006

%define EXIT_OK    0x0000000
%define EXIT_ERR   0x0000000

%define O_RDONLY   0x0000000

    global _main

    section .data

    section .text

_main:
    mov rax, SYS_EXIT
    mov rdi, EXIT_OK
    syscall
