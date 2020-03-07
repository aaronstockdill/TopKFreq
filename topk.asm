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

readBuffer: times 64 db 0x0
readBufLen: equ 64


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
    and cl, 0x0f                ; Char to int
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
;;        rsi = number of words
;; TOUCHED: rdi, ????
printWords:
    multipush r12, r13, r14, r15
    mov r12, rdi                ; File descriptor
    lea r13, [rel readBuffer]   ; Read buffer pointer
    mov r14, readBufLen         ; Read buffer length
    mov r15, rsi                ; Words to print
.loop:
    cmp r15, 0                  ; Is the number of words to print 0?
    jle .end                    ; If yes, then done
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call fillBuffer
    ; IF read buffer is empty AND word buffer is empty THEN jmp .end
    ; Currently no word buffer...
    mov byte cl, [r13]
    cmp cl, 0x0
    je .end
    mov rdi, r13
    mov rsi, r14
    ; TODO: word buffer
    call prepBuffer
    mov rdi, r13
    mov rsi, r14
    mov rdx, r15
    call processBuffer
    mov r15, rax
    jmp .loop
.end:
    multipop r12, r13, r14, r15
    ret


;; fillBuffer
;; Read in a fixed chunk of the file
;; INPUT: rdi = file descriptor
;;        rsi = pointer to buffer
;;        rdx = size of buffer
;; TOUCHED: rdi, rsi, rdx
fillBuffer:
    push rdi
    push rsi
    mov rdi, rsi
    mov rsi, rdx
    call clearBuffer
    pop rsi
    pop rdi
    mov rax, SYS_READ
    ; rdi, rsi, rdx already ok
    syscall
    ret


;; prepBuffer
;; Convert all upper-case to lower-case, and anything
;; else will become null. If there is a potential 'fragment'
;; at the end of the buffer, write it into the word buffer
;; and replace it with nulls.
;; INPUT: rdi = pointer to buffer
;;        rsi = buffer length
;;        rdx = pointer to word buffer
prepBuffer:
    ; TODO: unroll to work on qwords
.loop:
    cmp rsi, 0x0                ; At end of buffer?
    jle .end
    dec rsi
    mov byte cl, [rdi + rsi]
    cmp cl, 'A'
    jl .nullify
    cmp cl, 'z'
    jg .nullify

    ; cl is between 'A' and 'z'...
    cmp cl, 'Z'
    jle .upper
    cmp cl, 'a'
    jge .lower
    ; Not a letter
    jmp .nullify
.upper:
    xor cl, 0x20                ; convert to lower-case
    mov byte [rdi + rsi], cl
    jmp .loop
.lower:
    ; leave it alone!
    jmp .loop
.nullify:
    mov byte [rdi + rsi], 0x00  ; Wipe them out, all of them
    jmp .loop
.end:
    ret


;; processBuffer
;; Write each word to STDOUT, followed by a newline.
;; This is done at most 'rdx' times.
;; INPUT: rdi = pointer to buffer
;;        rsi = buffer length
;;        rdx = words left to write
;; OUTPUT: rax = updated number of words left to write
;; TOUCHED: rdi, rsi, rax, rcx, rdx, r11-14
processBuffer:
    ; head, tail, buff-len, words-left
    multipush r15, r12, r13, r14
    mov r15, rdi
    mov r13, rsi
    mov r14, rdx,
    ; We will inchworm our way through the buffer
.loopWord:
    cmp r14, 0                  ; Check how many more words we can write
    jle .endWord                 ; If no more, done
    mov r12, r15                ; rdi head, rcx tail
.loopChar:
    inc r15                     ; Step head
    dec r13                     ; Lower distance to end of buffer
    jz .endWord                 ; If we're out of space, must be done!
                                ; Note: words must be null terminated,
    mov byte cl, [r15]          ; Read in char
    cmp cl, 0x00                ; If not null...
    jne .loopChar               ; ... keep reading word. Else done.
.endChar:
    sub r15, r12                ; head - tail
    cmp r15, 1
    jle .noprint                ; If only 1 apart, empty word: skip print
    mov rax, SYS_WRITE          ; Otherwise, print that thing out!
    mov rdi, STDOUT
    mov rsi, r12
    mov rdx, r15
    syscall
    call newline
    dec r14
.noprint:
    add r15, r12
    jmp .loopWord
.endWord:
    mov rax, r14
    multipop r15, r12, r13, r14
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
    jz .doneRemainder           ; If zero, done with remainder
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
