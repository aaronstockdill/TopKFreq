%define SYS_EXIT    0x02000001
%define SYS_READ    0x02000003
%define SYS_WRITE   0x02000004
%define SYS_OPEN    0x02000005
%define SYS_CLOSE   0x02000006
%define SYS_MMAP    0x020000c5

%define EXIT_OK     0x00000000
%define EXIT_ERR    0x00000000

%define STDIN       0x00000000
%define STDOUT      0x00000001
%define STDERR      0x00000002

%define O_RDONLY    0x00000000

%define M_PROT_RW   0x00000006
%define M_PRIV_ANON 0x00001000



%macro zero 1
    xor %1, %1
%endmacro

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

memoryAllocFailString: db 'Error: memory allocation failed',0xa
memoryAllocFailStrLen: equ $ - memoryAllocFailString

readBufLen: equ 4096

;; This implicitly means a word is at most 64 characters.
;; Probably safe in English:
;;     https://en.wikipedia.org/wiki/Longest_word_in_English
wordBuffer: times 64 db 0x00
wordBufLen: equ 64

    section .text

_main:
    cmp rdi, 3                  ; Are there three arguments?
    jne badArguments            ; If not, exit with error

%define argv r15
%define k r12
%define fd r13
    mov argv, rsi               ; Save rsi in r15, so it won't get clobbered
    mov rdi, [argv + 0x10]      ; r12 <- k = stringToInt(argv[2], 10)
    mov rsi, 10
    call stringToInt
    mov k, rax

    mov rdi, [argv + 0x08]      ; r13 <- fd = open(argv[1])
    call openFile
    mov fd, rax

    mov rdi, fd                ; printWords(fd, k)
    mov rsi, k
    call printWords

    mov rdi, fd                ; close(fd)
    call closeFile
%undef argv
%undef fd
%undef k

    ; Fall through to exitOk
exitOk:
    mov rax, SYS_EXIT
    mov rdi, EXIT_OK
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


memoryFailure:
    write STDERR, memoryAllocFailString, memoryAllocFailStrLen
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
;; TOUCHED: rdi, rax, rcx
stringToInt:
%define strp rdi
%define base rsi
%define result rax
    zero result
    zero rcx
.loop:
    mov byte cl, [strp]
    cmp byte cl, 0x00           ; Is char null?
    je .end                     ; If yes, done
    mul base                    ; Shift Value one slot (base 10)
    and cl, 0x0f                ; Char to int
    add result, rcx
    inc strp                     ; Next char
    jmp .loop
.end:
    ; Result is already rax
%undef strp
%undef base
%undef result
%undef tmp
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
    zero rdx                    ; No mode
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


;; allocBuffer
;; Allocates 'rdi' bytes of memory, and
;; returns a pointer to that memory in 'rax'
;; INPUT: rdi = bytes to allocate
;; OUTPUT: rax = pointer to allocated memory
;; TOUCHED: rdi, rsi, rax, rdx, r8, r9, r10
allocBuffer:
    mov rax, SYS_MMAP
    mov rsi, rdi                ; Bytes
    zero rdi                    ; Address (always null)
    mov rdx, M_PROT_RW          ; Read/write
    mov r10, M_PRIV_ANON        ; Local
    mov r8, -1                  ; File (always -1)
    zero r9                     ; Offset (always 0)
    syscall
    jc memoryFailure
    ; rax correct
    ret


;; printWords
;; Print each word in the file in turn
;; INPUT: rdi = file descriptor
;;        rsi = number of words
;; TOUCHED: rdi, ????
printWords:
    multipush r12, r13, r14, r15
%define fd r12
%define buff r13
%define bufflen r14
%define k r15
    mov fd, rdi
    mov bufflen, readBufLen
    mov k, rsi
    mov rdi, bufflen
    call allocBuffer
    mov buff, rax
.loop:
    cmp k, 0                    ; Is the number of words to print 0?
    jle .end                    ; If yes, then done
    mov rdi, fd
    mov rsi, buff
    mov rdx, bufflen
    call fillBuffer
    mov byte cl, [buff]
    cmp cl, 0x00
    je .end                     ; IF read buffer is empty THEN jmp .end
    mov rdi, buff
    mov rsi, bufflen
    mov rdx, k
    call prepBuffer             ; ELSE prep the buffer...
    ; mov k, rax
    mov rdi, buff
    mov rsi, bufflen
    ; mov rdx, k
    mov rdx, rax                ; updated k
    call processBuffer          ; ... then process it
    mov k, rax
    jmp .loop
.end:
%undef fd
%undef buff
%undef bufflen
%undef k
    multipop r12, r13, r14, r15
    ret


;; fillBuffer
;; Read in a fixed chunk of the file
;; INPUT: rdi = file descriptor
;;        rsi = pointer to buffer
;;        rdx = size of buffer
;; TOUCHED: rdi, rsi, rdx
fillBuffer:
    ; Save rdi, rsi
    push rdi
    push rsi
    ; Clear the buffer
    mov rdi, rsi
    mov rsi, rdx
    call clearBuffer
    ; Restore rdi, rsi
    pop rsi
    pop rdi
    mov rax, SYS_READ           ; Read file contents into buffer
    ; rdi, rsi, rdx already ok
    syscall
    ret


;; prepBuffer
;; Convert all upper-case to lower-case, and anything
;; else will become null. If there is a potential 'fragment'
;; at the end of the buffer, write it into the word buffer
;; and replace it with nulls. If there is already content
;; in the word buffer, we append move everything up to the
;; first non-character, then process the word buffer. This
;; means the word buffer will always end up with the
;; trailing 'boundary word' in it.
;; INPUT: rdi = pointer to buffer
;;        rsi = buffer length
;;        rdx = words left to process
;; OUTPUT: rax = updated words left to process
prepBuffer:
    ; TODO: unroll to work on qwords
    multipush r12, r13, r14, r15, rbx
%define rbuff r12
%define rbufflen r13
%define wbuff r14
%define wbufflen r15
%define k rbx
    mov rbuff, rdi
    mov rbufflen, rsi
    lea wbuff, [rel wordBuffer]
    mov wbufflen, wordBufLen
    mov k, rdx
%define idx rsi
.loop:
    cmp idx, 0x00               ; At end of buffer?
    jle .end
    dec idx
    mov byte cl, [rbuff + idx]
    cmp cl, 'A'
    jl .nullify
    cmp cl, 'z'
    jg .nullify
    ; Now know cl is between 'A' and 'z'...
    cmp cl, 'Z'
    jle .upper
    cmp cl, 'a'
    jge .lower
    ; Not a letter
    jmp .nullify
.upper:
    xor cl, 0x20                ; convert to lower-case
    mov byte [rbuff + idx], cl
    jmp .loop
.lower:
    ; leave it alone!
    jmp .loop
.nullify:
    mov byte [rbuff + idx], 0x00  ; Wipe them out, all of them
    jmp .loop
.end:
%undef idx
%define rp rdi
%define wp rax
    mov byte cl, [wbuff]
    cmp byte cl, 0x00
    je .endFrag
    mov rp, rbuff
    mov wp, wbuff
.loopSeekWordEnd:
    mov byte cl, [wp]
    cmp byte cl, 0x00
    je .endSeekWordEnd
    inc wp
    jmp .loopSeekWordEnd
.endSeekWordEnd:
.loopStartFrag:
    ; Handle the 'start' word fragments
    mov byte cl, [rp]
    cmp byte cl, 0x00
    je .endStartFrag            ; All necessary bytes copied
    mov byte [wp], cl           ; Else copy byte...
    mov byte [rp], 0x00         ; ... And zero the source.
    inc wp
    inc rp
    jmp .loopStartFrag
.endStartFrag:
%undef rp
    mov rdi, wbuff
    mov rsi, wp
%undef wp
    sub rsi, wbuff
    inc rsi
    mov rdx, k
    call processBuffer          ; Process the word buffer now
    mov k, rax
    mov rdi, wbuff
    mov rsi, wbufflen
    call clearBuffer            ; Clear it for future use
.endFrag:
%define rp rdi
%define wp rax
    mov wp, wbuff
    mov rp, rbuff
    add rp, rbufflen            ; Go to end of buffer
    dec rp                      ; (Correct overshoot)
.loopEndFrag:
    ; Handle the 'end' word fragments
    mov byte cl, [rp]
    cmp byte cl, 0x00
    je .endEndFrag              ; If null, finished copy
    mov byte [wp], cl           ; Else copy the byte ...
    mov byte [rp], 0x00         ; ... zero the source...
    dec rp                      ; ... and step back
    inc wp
    jmp .loopEndFrag
.endEndFrag:
    ; Note that the word buffer is backwards!
%undef rp
    mov rsi, wp
%undef wp
    dec rsi                     ; (Correct overshoot)
    mov rdi, wbuff
    call revBuffer              ; Reverse word buffer
    mov rax, k
%undef rbuff
%undef rbufflen
%undef wbuff
%undef wbufflen
%undef k
    multipop r12, r13, r14, r15, rbx
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
    multipush r12, r13, r14, r15
%define head r15
%define tail r12
%define bufflen r13
%define k r14
    mov head, rdi
    mov bufflen, rsi
    mov k, rdx
.loopWord:                      ; We will inchworm our way through the buffer
    cmp k, 0                    ; Check how many more words we can write
    jle .endWord                ; If no more, done
    mov tail, head              ; rdi head, rcx tail
.loopChar:
    inc head                    ; Step head
    dec bufflen                 ; Lower distance to end of buffer
    jz .endWord                 ; If we're out of space, must be done!
                                ; Note: words must be null terminated,
    mov byte cl, [head]         ; Read in char
    cmp cl, 0x00                ; If not null...
    jne .loopChar               ; ... keep reading word. Else done.
.endChar:
    sub head, tail
%define len head
    cmp len, 1
    jle .noprint                ; If only 1 apart, empty word: skip print
    mov rax, SYS_WRITE          ; Otherwise, print that thing out!
    mov rdi, STDOUT
    mov rsi, tail
    mov rdx, len
    syscall
%undef len
    call newline
    dec k
.noprint:
    add head, tail
    jmp .loopWord
.endWord:
    mov rax, k
%undef head
%undef tail
%undef bufflen
%undef k
    multipop r12, r13, r14, r15
    ret


;; clearBuffer
;; Overwrite the given buffer with zeros
;; INPUT: rdi = pointer to buffer
;;        rsi = size of buffer
;; TOUCHED: rsi, rcx
clearBuffer:
%define buff rdi
%define idx rsi
.loopRemainder:
    mov rcx, idx
    and rcx, 0x07               ; size mod 8
    cmp rcx, 0x00
    je .endRemainder            ; If zero, done with remainder
    dec idx
    mov byte [buff + idx], 0x00
    jmp .loopRemainder
.endRemainder:
    shr idx, 3                  ; size div 8
    dec idx
.loopMain:
    mov qword [buff + idx*8], 0x00
    cmp idx, 0x00               ; Is buffer done?
    je .endMain                 ; If yes, done
    dec idx
    jmp .loopMain
.endMain:
%undef buff
%undef idx
    ret


;; revBuffer
;; Reverse the contents of the buffer
;; INPUT: rdi = buffer start
;;        rsi = buffer end
;; TOUCHES: rdi, rsi, rcx, rdx
revBuffer:
    ; TODO: unroll for qwords
%define left rdi
%define right rsi
.loop:
    cmp left, right
    jge .end
    mov byte cl, [left]
    mov byte dl, [right]
    mov byte [right], cl
    mov byte [left], dl
    inc left
    dec right
    jmp .loop
.end:
%undef left
%undef right
    ret
