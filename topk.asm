%define SYS_EXIT   0x2000001
%define SYS_READ   0x2000003
%define SYS_WRITE  0x2000004
%define SYS_OPEN   0x2000005
%define SYS_CLOSE  0x2000006

%define EXIT_OK    0x0000000
%define EXIT_ERR   0x0000000

%define STDIN      0x0000000
%define STDOUT     0x0000001
%define STDERR     0x0000002

%define O_RDONLY   0x0000000



%macro write 3
    mov eax, SYS_WRITE
    mov rdi, %1
    lea rsi, [rel %2]
    mov rdx, %3
    syscall
%endmacro



    global _main

    section .data

newlineString: db 0xa
newlineStrLen: equ 1

wrongArgString: db 'Error: topk requires two arguments',0xa,\
                   'Usage: topk filename k',0xa
wrongArgStrLen: equ $ - wrongArgString

fileNotFoundString: db 'Error: file not found',0xa
fileNotFoundStrLen: equ $ - fileNotFoundString


    section .text

_main:
    cmp rdi, 3                  ; Are there three arguments?
    jne badArguments            ; If not, exit with error

    mov r15, rsi                ; Save rsi in r15, so it won't get clobbered
    mov rdi, [r15 + 0x10]       ; r12 <- k = stringToInt(argv[2])
    call stringToInt
    mov r12, rax

    mov rdi, [r15 + 0x08]       ; r13 <- fd = open(argv[1])
    call openFile
    mov r13, rax

    mov rdi, r13                ; close(fd)
    call closeFile

    ; Fall through to exitOk
exitOk:
    mov rax, SYS_EXIT
    mov rdi, r12
    syscall
exitErr:
    mov rax, SYS_EXIT
    mov rdi, EXIT_ERR
    syscall


badArguments:
    write STDERR, wrongArgString, wrongArgStrLen
    jmp exitErr


fileNotFound:
    write STDERR, fileNotFoundString, fileNotFoundStrLen
    jmp exitErr

newline:
    write STDOUT, newlineString, newlineStrLen
    ret



stringToInt:
    xor rax, rax                ; Value = 0
    mov r8, 10
    xor rcx, rcx
.loop:
    mov byte cl, [rdi]
    cmp cl, 0x0                 ; Is char null?
    je .end                     ; If yes, done
    mul r8                      ; Shift Value one slot (base 10)
    sub cl, '0'                 ; Char to int
    add rax, rcx
    inc rdi                     ; Next char
    jmp .loop
.end:
    ret


openFile:
    ret


closeFile:
    ret
