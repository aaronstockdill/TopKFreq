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

%macro multipush 1-*
  %rep %0
    push %1
  %rotate 1
  %endrep
%endmacro

%macro multipop 1-*
  %rep %0
  %rotate -1
    pop %1
  %endrep
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
    mov rdi, [r15 + 0x10]       ; r12 <- k = stringToInt(argv[2], 10)
    mov rsi, 10
    call stringToInt
    mov r12, rax

    mov rdi, [r15 + 0x08]       ; r13 <- fd = open(argv[1])
    call openFile
    mov r13, rax

    mov rdi, r13                ; printWords(fd, k)
    mov rsi, r12
    call printWords

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


;; newline
;; Write a newline to stdout.
;; TOUCHED: rax, rdi, rsi
newline:
    write STDOUT, newlineString, newlineStrLen
    ret


;; stringToInt
;; Reads the pointed-to string as a positive integer.
;; INPUT: rdi = pointer to string
;;        rsi = base of integer
;; OUTPUT: rax = integer
;; TOUCHED: rdi, rax, rcx, r8
stringToInt:
    xor rax, rax                ; Value = 0
    xor rcx, rcx                ; Clear tmp byte
.loop:
    mov byte cl, [rdi]
    cmp cl, 0x0                 ; Is char null?
    je .end                     ; If yes, done
    mul rsi                     ; Shift Value one slot (base 10)
    sub cl, '0'                 ; Char to int
    add rax, rcx
    inc rdi                     ; Next char
    jmp .loop
.end:
    ret


;; openFile
;; Open the file with the path specified as a string
;; pointed to by rdi. The file is opened for reading only.
;; The file descriptor is returned in the rax register.
;; INPUT: rdi = pointer to string
;; OUTPUT: rax = file descriptor
;; TOUCHED: rdi, rsi, rax, rdx
openFile:
    mov rax, SYS_OPEN
    ; rdi already correct
    mov rsi, O_RDONLY
    mov rdx,  0x0               ; No mode
    syscall
    jc fileNotFound             ; Report error with file
    ; rax now correct
    ret


;; closeFile
;; Close the file whose file descriptor is in rdi.
;; INPUT: rdi = file descriptor
;; TOUCHED: rax
closeFile:
    mov rax, SYS_CLOSE
    ; rdi already correct
    syscall
    ret


;; printWords
;; Print each word in the file in turn
;; INPUT: rdi = file descriptor
;; TOUCHED: rdi, ????
printWords:
.loop:
    call fillBuffer
    ; IF read buffer is empty AND word buffer is empty THEN jmp .end
    call cleanBuffer
    call processBuffer
    ; jmp .loop
.end:
    ret


;; fillBuffer
;; Read in a fixed chunk of the file
;; INPUT: rdi = file descriptor
;;        rsi = pointer to buffer
;;        rdx = size of buffer
;; TOUCHED: rdi
fillBuffer:
    ret


cleanBuffer:
    ret


processBuffer:
    ret


;; clearBuffer
;; Overwrite the given buffer with zeros
;; INPUT: rdi = pointer to buffer
;;        rsi = size of buffer
;; TOUCHED: rsi, rcx
clearBuffer:
.loopRemainder:
    mov rcx, rsi
    and rcx, 0x07               ; size mod 8
    cmp rcx, 0x0                ; Does size mod 8 == 0?
    je .doneRemainder           ; If yes, done with remainder
    mov byte [rdi + rsi], 0x0
    dec rsi
    jmp .loopRemainder
.doneRemainder:
    shr rsi, 3                  ; size div 8
    dec rsi
.loopMain:
    mov qword [rdi + rsi*8], 0x0
    cmp rsi, 0x0                ; Is buffer done?
    je .doneMain                ; If yes, done
    dec rsi
    jmp .loopMain
.doneMain:
    ret
