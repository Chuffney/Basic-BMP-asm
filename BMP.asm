;x86_64, NASM-style assembly
;uses the C Standard Library
;MS calling convention

extern malloc
extern calloc
extern realloc
extern free
extern memset
extern strcpy
extern strcmp
extern strcat
extern strlen
extern fopen
extern fclose
extern fread
extern fwrite
extern fseek


global init
global open
global close
global exportBMP
global setSize
global setBitDepth

; used for tests ONLY
global addExtension
global swapEndianness4
global swapEndianness2
global digestColourTable
global initMemory
; end of tests section

section .rdata
fileRead:   db 'rb', 0, 0
fileWrite:  db 'wb', 0, 0
lowerCase:  db '.bmp', 0
upperCase:  db '.BMP', 0

section .text

addExtension:
    push rcx    ;rsp + 0x30 fileName
    sub rsp, 0x30
    call strlen
    mov [rsp + 0x20], rax   ;rsp + 0x20 length
    cmp ax, 5
    jb short AEchange
    mov rcx, [rsp + 0x30]
    add rcx, [rsp + 0x20]
    sub rcx, 4
    mov rdx, $lowerCase
    call strcmp
    test ax, ax
    jz short AEnoChange
    mov rcx, [rsp + 0x30]
    add rcx, [rsp + 0x20]
    sub rcx, 4
    mov rdx, $upperCase
    call strcmp
    test ax, ax
    jnz short AEchange
AEnoChange:
    mov ecx, [rsp + 0x20]
    inc ecx
    call malloc
    mov [rsp + 0x28], rax
    mov rcx, rax
    mov rdx, [rsp + 0x30]
    call strcpy
    jmp short AEcollect
AEchange:
    mov ecx, [rsp + 0x20]
    add rcx, 5
    call malloc
    mov [rsp + 0x28], rax
    mov rcx, rax
    mov rdx, [rsp + 0x30]
    call strcpy
    mov rcx, [rsp + 0x28]
    mov rdx, $lowerCase
    call strcat
    add WORD [rsp + 0x20], 5
AEcollect:
    mov ecx, [rsp + 0x20]
    mov BYTE [rax + rcx], 0
    add rsp, 0x38
    ret

swapEndianness4:    ;a c
    xor eax, eax
    ror ecx, 8
    ror cx, 8
    mov ax, cx
    shl eax, 16
    shr ecx, 16
    ror cx, 8
    mov ax, cx
    ror eax, 8
    ret

swapEndianness2:    ;a c
    xor eax, eax
    ror cx, 8
    mov ax, cx
    ret

digestColourTable:
    push rcx
    sub rsp, 0x10
    mov ecx, 0x4
    call malloc
    mov rdx, [rsp + 0x10]
    xor ecx, ecx
DCTloop:
    mov r8d, [rdx]
    cmp r8d, 0xFF00
    je short DCTg ;green
    ja short DCTopt
    mov [rax + 2], cl ;blue
    jmp short DCTcollect
DCTopt:
    cmp r8d, 0xFF0000
    je short DCTr ;red
    mov [rax + 3], cl  ;alpha
    jmp short DCTcollect
DCTg:
    mov [rax + 1], cl
    jmp short DCTcollect
DCTr:
    mov [rax], cl
DCTcollect:
    inc cl
    add rdx, 4
    cmp cl, 4
    jne short DCTloop
    add rsp, 0x18
    ret

encode:
    xor eax, eax
    add rdx, r9
    mov r10, rdx
    add r10, rcx
ENCloop:
    mov [r10], r8b
    shr r8d, 8
    dec r10
    inc eax
    cmp eax, r9d
    jne ENCloop
    ret

init:
    mov rcx, 45     ;sizeof struct BMP
    sub rsp, 0x20
    call malloc
    mov BYTE [rax], 0       ;initialised
    mov DWORD [rax + 1], 0  ;width
    mov DWORD [rax + 5], 0  ;height
    mov DWORD [rax + 9], 24 ;bit depth
    add rsp, 0x20
    ret

open:
    ;rsp + 0x20     qword   data buffer
    ;rsp + 0x28     dword   padding

    ;rsi    struct BMP*
    ;rdi    header buffer/raw data ptr
    ;rbp    bit offset:depth/colourTable
    push rbp
    push rbx
    push rdi
    push rsi
    sub rsp, 0x30
    mov rsi, rcx
    mov BYTE [rsi], 0
    mov rcx, rdx
    call addExtension
    mov rbx, rax
    mov rdx, fileRead
    mov rcx, rax
    call fopen
    mov rcx, rbx
    mov rbx, rax
    call free
    test rbx, rbx
    jz OPNret   ;no such file exists/couldn't open
    mov edx, 0x2
    xor r8d, r8d
    mov rcx, rbx
    call fseek
    mov ecx, 0x8
    call malloc
    mov rdi, rax    ;header buffer
    mov edx, 1
    mov r8d, 0x8
    mov r9, rbx
    mov rcx, rax
    call fread
    mov edx, [rdi]  ;file size
    sub edx, 0xA    ;accounting for two bytes skipped and eight read
    mov ebp, edx
    mov rcx, rdi
    call realloc
    mov rdi, rax    ;data buffer
    mov [rsp + 0x20], rax
    mov rcx, rax
    mov edx, 1
    mov r8d, ebp
    mov r9, rbx
    call fread
    mov rcx, rbx
    call fclose
    mov eax, [rdi]          ;data offset
    sub eax, 0xA
    mov rcx, [rdi + 0x8]    ;height:width
    shl rax, 32
    movzx ebp, WORD [rdi + 0x12] ;bit depth
    mov [rsi + 1], rcx
    mov [rsi + 9], ebp
    or rbp, rax     ;rbp = offset:bitDepth

    mov rax, rcx
    mov edx, ecx
    shr rax, 32
    mov rcx, rsi
    mov r8d, eax
    call initMemory
    cmp ebp, 0x20
    jne OPNswitch24
    ;else - switch(32)
    shr rbp, 32     ;bit depth no longer needed, and so is discarded
    lea rcx, [rdi + 0x2C]
    add rdi, rbp
    call digestColourTable
    mov rbp, rax    ;colour table
    xor ecx, ecx
OPNswitch32control:
    cmp cl, 4
    je OPNswitch32collect
    mov edx, [rbp]
    cmp dl, cl
    jne short OPNswitch32nblue
    mov r9, [rsi + 0x1D]
    jmp short OPNdata32
OPNswitch32nblue:
    cmp dh, cl
    jne short OPNswitch32ngreen
    mov r9, [rsi + 0x15]
    jmp short OPNdata32
OPNswitch32ngreen:
    shr edx, 16
    cmp dl, cl
    jne short OPNswitch32nred
    mov r9, [rsi + 0xD]
    jmp short OPNdata32
OPNswitch32nred:
    mov r9, [rsi + 0x25]
OPNdata32:     ;this section was written at 4:00 (am)
    mov rax, [rsi + 1]
    mov edx, eax
    shr rax, 32
    mov r8, rdi
    xor r11d, r11d
    push rcx
OPNloop320:
    mov rcx, [r9]
    mov ebx, edx
    dec ebx
    OPNloop321:
        mov r10b, [r8]
        mov [rcx + rbx], r10b
        shl edx, 2  ;{
        add r8, rdx ;   r8 + (4 * rdx)
        shr edx, 2  ;}
    sub ebx, 1
    jnc short OPNloop321
    mov r10d, eax   ;{
    shl r10, 32     ;almost like push rax, push rdx but keeping them in r10 instead
    or r10, rdx     ;}
    shl eax, 2
    mul edx
    mov eax, eax    ;clearing high 32 bits of rax
    sub r8, rax
    add r8, BYTE 4
    mov edx, r10d   ;{
    shr r10, 32     ;popping rax and rdx from r10
    mov eax, r10d    ;}
    add r9, BYTE 8
    inc r11d
    cmp r11d, eax
    jne short OPNloop320

    pop rcx
    inc rdi
    inc cl
    jmp OPNswitch32control
OPNswitch32collect:
    mov rcx, rbp
    call free
    jmp OPNsuccess

OPNswitch24:
    shr rbp, 0x20   ;bit depth no longer needed, and so is discarded
    add rdi, rbp
    mov rcx, [rsi + 1]  ;width:height
    mov edx, ecx    ;edx - height
    shr rcx, 0x20   ;ecx - width
    mov ebp, 0x1D
    OPNloop240:
    mov r9, [rsi + rbp] ;**R, **G or **B
    xor r11d, r11d
    xor eax, eax
    OPNloop241:
        shl eax, 3
        mov r8, [r9 + rax]
        mov ebx, edx
        OPNloop242:
            dec ebx
            mov r10b, [rdi + r11]
            mov [r8 + rbx], r10b
            mov r10d, ecx   ;{
            add r10d, ecx   ;mov r10d, 3 * ecx
            add r10d, ecx   ;}
            add r10d, 3         ;{ padding
            and r10b, 1111_1100b;}
            add r11d, r10d
            test ebx, ebx
            jnz short OPNloop242
        shr eax, 3
        inc eax
        mov r10d, eax   ;preserving eax
        shl rcx, 0x20   ;{
        or rcx, rdx     ;} rcx -> width:height
        mov edx, 3
        mul edx
        mov r11d, eax   ;setting r11 according to the number of columns (x) passed
        mov eax, r10d
        mov edx, ecx    ;{ returning ecx and edx to their previous states
        shr rcx, 0x20   ;}
        cmp eax, ecx
        jne short OPNloop241
    inc rdi
    sub bp, 8
    cmp bp, 0xD ;pointer to red is at [rsi + 0xD]
    jae short OPNloop240

OPNsuccess:
    mov BYTE [rsi], 1
    mov rcx, [rsp + 0x20]
    call free
OPNret:
    add rsp, 0x30
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    xor eax, eax
    ret


close:
    cmp BYTE [rcx], 1
    jne retOne
    push rsi    ;iterator
    push rdi    ;width
    push rbx    ;struct BMP*
    sub rsp, 16
    mov rbx, rcx
    mov edi, [rcx + 1]
    xor esi, esi
CLSloop:
    shl esi, 3
    mov rax, [rbx + 13]
    mov rcx, [rax + rsi]
    call free
    mov rax, [rbx + 21]
    mov rcx, [rax + rsi]
    call free
    mov rax, [rbx + 29]
    mov rcx, [rax + rsi]
    call free
    cmp DWORD [rbx + 9], 32
    jne CLS24
    mov rax, [rbx + 37]
    mov rcx, [rax + rsi]
    call free
CLS24:
    shr esi, 3
    inc esi
    cmp esi, edi
    jne CLSloop
    mov rcx, [rbx + 13]
    call free
    mov rcx, [rbx + 21]
    call free
    mov rcx, [rbx + 29]
    call free
    cmp DWORD [rbx + 9], 32
    jne CLSret
    mov rcx, [rbx + 37]
    call free
CLSret:
    add rsp, 16
    pop rbx
    pop rdi
    pop rsi
    ret

exportBMP:
    ;rsp + 0x30 raw data ptr
    ;rsp + 0x28 padding
    ;rsp + 0x20 FILE*
    cmp BYTE [rcx], 1
    jne retOne
    push rbx
    push rsi    ;struct BMP*
    push rdi    ;position
    push rbp
    sub rsp, 0x50
    mov rsi, rcx
    mov rcx, rdx
    mov rdx, fileWrite
    call fopen
    cmp rax, 0  ;null if failed to write
    jz retOne
    mov [rsp + 0x20], rax ;FILE*

    cmp DWORD [rsi + 9], 32
    jne short EXPswitch024
    mov DWORD [rsp + 0x28], 0    ;padding
    mov eax, [rsi + 1]
    mov ecx, [rsi + 5]
    mul ecx
    shl eax, 2
    add eax, 0x90   ;length of header
    jmp short EXPswitch0collect ;fileSize in eax
EXPswitch024:
    mov eax, [rsi + 9]
    shr eax, 3
    mov ecx, [rsi + 1]
    mul ecx
    and al, 11b
    mov ecx, 4
    sub cl, al
    and cl, 11b
    mov [rsp + 0x28], ecx   ;padding

    mov eax, [rsi + 1]
    mov edx, eax    ;{
    add eax, edx    ;faster than multiplying
    add eax, edx    ;}
    add eax, ecx
    mov ecx, [rsi + 5]
    mul ecx
    add eax, 0x30   ;length of header
EXPswitch0collect:
    mov edi, eax    ;temporarily using di for fileSize before storing data pointer
    mov ecx, eax    ;fileSize
    call malloc     ;memory for output string
    mov [rsp + 0x30], rax
    mov WORD [rax], 'BM'    ;magic bytes
    mov [rax + 2], edi
    mov DWORD [rax + 6], 0
    cmp BYTE [rsi + 9], 32
    jne EXPheader24

    mov DWORD [rax + 0xA], 0x90 ;data offset
    mov DWORD [rax + 0xE], 0x7C ;length of header
    mov ecx, [rsi + 1]
    mov edx, [rsi + 5]
    mov [rax + 0x12], ecx
    mov [rax + 0x16], edx
    mov WORD [rax + 0x1A], 1    ;number of planes
    mov WORD [rax + 0x1C], 0x20   ;bit depth
    mov DWORD [rax + 0x1E], 3
    mov eax, [rsi + 1]
    mov ecx, [rsi + 5]
    mul ecx
    mov edx, eax
    mov rax, [rsp + 0x30]
    shl edx, 2
    mov [rax + 0x22], edx   ;length of raw data
    mov r8, 0x00000B13_00000B13
    mov [rax + 0x26], r8
    mov QWORD [rax + 0x2E], 0
    mov r9, 0x00FF0000_FF000000 ;{  colour table
    mov [rax + 0x36], r9        ;
    mov r8, 0x000000FF_0000FF00 ;
    mov [rax + 0x3E], r8        ;}
    mov QWORD [rax + 0x46], 'BGRs'
    mov WORD [rax + 0x4E], 0
    pxor xmm0, xmm0
    movdqa [rax + 0x50], xmm0   ;{  requires 16-byte heap alignment
    movdqa [rax + 0x60], xmm0   ;
    movdqa [rax + 0x70], xmm0   ;
    movdqa [rax + 0x80], xmm0   ;}
    lea rdi, [rax + 0x90]
    jmp short EXPheaderCollect
EXPheader24:
    mov DWORD [rax + 0xA], 0x30 ;data offset
    mov DWORD [rax + 0xE], 0x22 ;length of header
    mov ecx, [rsi + 1]
    mov edx, [rsi + 5]
    mov [rax + 0x12], ecx
    mov [rax + 0x16], edx
    mov WORD [rax + 0x1A], 1
    movzx edx, WORD [rsi + 9]
    mov [rax + 0x1C], edx
    pxor xmm0, xmm0
    movdqa [rax + 0x20], xmm0   ;requires 16-byte heap alignment
    lea rdi, [rax + 0x30]
EXPheaderCollect:

    cmp DWORD [rsi + 9], 32
    jne EXPdataPadding

    xor ebx, ebx
    mov r9, [rsi + 0x25]
    mov ecx, [rsi + 1]
    xor edx, edx
    xor r10d, r10d
EXPloopA0:
    shl ebx, 3
    mov r8, [r9 + rbx]
    mov ebp, [rsi + 5]
    EXPloopA1:
        dec ebp
        mov al, [r8 + rbp]
        mov [rdi + r10], al
        shl ecx, 2      ;{
        add r10d, ecx   ;add 4 * ecx to r10d, ecx = bmp->width
        shr ecx, 2      ;}
        test ebp, ebp
        jne short EXPloopA1
    add edx, BYTE 4
    mov r10d, edx
    shr ebx, 3
    inc ebx
    cmp ebx, ecx
    jne short EXPloopA0
    inc rdi
    jmp short EXPdataBGR
EXPdataPadding:
    cmp BYTE [rsp + 0x28], 0
    je short EXPdataBGR
    mov edx, [rsi + 1]
    mov ebx, edi
    mov ecx, edx
    add ecx, edx
    add ecx, edx
    add ecx, 3
    and cl, 1111_1100b
    xor edx, edx
EXPpaddingLoop:
    add ebx, ecx
    mov DWORD [ebx], 0
    inc edx
    cmp edx, [rsi + 1]
    jne short EXPpaddingLoop

EXPdataBGR:
    xor ebx, ebx
    mov r9, [rsi + 0x1D]
    mov ecx, [rsi + 1]
    xor edx, edx
    xor r10d, r10d
EXPloopB0:
    shl ebx, 3
    mov r8, [r9 + rbx]
    mov ebp, [rsi + 5]
    EXPloopB1:
        dec ebp
        mov al, [r8 + rbp]
        mov [rdi + r10], al
        cmp DWORD [rsi + 9], 32
        jne short EXPloopB124
        add r10d, ecx   ;add 4 * ecx to r10d, ecx = bmp->width
    EXPloopB124:
        add r10d, ecx
        add r10d, ecx
        add r10d, ecx
        test ebp, ebp
        jne short EXPloopB1
    add edx, BYTE 4
    mov r10d, edx
    shr ebx, 3
    inc ebx
    cmp ebx, ecx
    jne short EXPloopB0
    inc rdi

    xor ebx, ebx
    mov r9, [rsi + 0x15]
    mov ecx, [rsi + 1]
    xor edx, edx
    xor r10d, r10d
EXPloopG0:
    shl ebx, 3
    mov r8, [r9 + rbx]
    mov ebp, [rsi + 5]
    EXPloopG1:
        dec ebp
        mov al, [r8 + rbp]
        mov [rdi + r10], al
        cmp DWORD [rsi + 9], 32
        jne short EXPloopG124
        add r10d, ecx   ;add 4 * ecx to r10d, ecx = bmp->width
    EXPloopG124:
        add r10d, ecx
        add r10d, ecx
        add r10d, ecx
        test ebp, ebp
        jne short EXPloopG1
    add edx, BYTE 4
    mov r10d, edx
    shr ebx, 3
    inc ebx
    cmp ebx, ecx
    jne short EXPloopG0
    inc rdi

    xor ebx, ebx
    mov r9, [rsi + 0xD]
    mov ecx, [rsi + 1]
    xor edx, edx
    xor r10d, r10d
EXPloopR0:
    shl ebx, 3
    mov r8, [r9 + rbx]
    mov ebp, [rsi + 5]
    EXPloopR1:
        dec ebp
        mov al, [r8 + rbp]
        mov [rdi + r10], al
        cmp DWORD [rsi + 9], 32
        jne short EXPloopR124
        add r10d, ecx   ;add 4 * ecx to r10d, ecx = bmp->width
    EXPloopR124:
        add r10d, ecx
        add r10d, ecx
        add r10d, ecx
        test ebp, ebp
        jne short EXPloopR1
    add edx, BYTE 4
    mov r10d, edx
    shr ebx, 3
    inc ebx
    cmp ebx, ecx
    jne short EXPloopR0

    mov rbx, [rsp + 0x30]   ;output string ptr
    mov edx, [rbx + 2]
    mov rcx, rbx
    mov r8d, 1
    mov r9, [rsp + 0x20]
    mov rdi, r9     ;storing FILE* for freeing
    call fwrite
    mov rcx, rdi
    call fclose
    mov rcx, rbx
    call free
;EXPret:
    add rsp, 0x50
    pop rbp
    pop rdi
    pop rsi
    pop rbx
    xor eax, eax
    ret

retOne:
    mov rax, 1
    ret

retZero:
    xor eax, eax
    ret

initMemory:
    cmp BYTE [rcx], 0
    jne IMret
    push rbx
    push rsi
    push rcx    ;struct BMP*
    push rdx    ;width
    push r8     ;height
    sub rsp, 0x20
    mov rsi, rcx
    mov rcx, rdx
    shl rcx, 3
    call malloc
    mov [rsi + 13], rax
    mov rcx, [rsp + 0x28]
    shl rcx, 3
    call malloc
    mov [rsi + 21], rax
    mov rcx, [rsp + 0x28]
    shl rcx, 3
    call malloc
    mov [rsi + 29], rax
    cmp DWORD [rsi + 9], 32
    jne IMpreLoop
    mov rcx, [rsp + 0x28]
    shl rcx, 3
    call malloc
    mov [rsi + 37], rax
IMpreLoop:
    xor ebx, ebx
IMloop:
    shl ebx, 3
    mov ecx, [rsp + 0x20]
    mov rdx, 1
    call calloc
    mov rdx, [rsi + 13]
    mov [rdx + rbx], rax

    mov rcx, [rsp + 0x20]
    mov rdx, 1
    call calloc
    mov rdx, [rsi + 21]
    mov [rdx + rbx], rax

    mov rcx, [rsp + 0x20]
    mov rdx, 1
    call calloc
    mov rdx, [rsi + 29]
    mov [rdx + rbx], rax

    cmp DWORD [rsi + 9], 32
    jne IM24
    mov rcx, [rsp + 0x20]
    call malloc
    mov rdx, [rsi + 37]
    mov [rdx + rbx], rax
    xor ecx, ecx
    mov edx, [rsi + 5]
IM32loop:
    mov BYTE [rax + rcx], 0xFF
    inc ecx
    cmp ecx, edx
    jne IM32loop
IM24:
    shr ebx, 3
    inc ebx
    cmp ebx, [rsi + 1]
    jne IMloop
    add rsp, 0x38
    pop rsi
    pop rbx
IMret:
    ret

setSize:
    cmp BYTE [rcx], 0    ;check if BMP not initialised
    je SSninit
    push rbx
    push rsi
    push rdx    ;rsp + 0x28     width arg
    push r8     ;rsp + 0x20     height arg
    sub rsp, 0x20
    mov rsi, rcx
    cmp edx, [rsi + 1]  ;change image width?
    ja SScommon
    je SSheight

    mov ebx, [rsi + 1]      ;iterator = BMP.width
SSloop0:
    shl ebx, 3      ;make iterator pointer-alligned
    mov rcx, [rsi + 0xD]
    add rcx, rbx
    call free
    mov rcx, [rsi + 0x15]
    add rcx, rbx
    call free
    mov rcx, [rsi + 0x1D]
    add rcx, rbx
    call free
    cmp DWORD [rsi + 9], 32
    jne short SSloop024
    mov rcx, [rsi + 0x25]
    add rcx, rbx
    call free
SSloop024:
    shr ebx, 3  ;reverse pointer-allignment
    inc ebx     ;i++
    cmp ebx, [rsp + 0x28]
    jne short SSloop0
SScommon:      ;this part of code is used in both widening and narrowing
    mov rcx, [rsi + 0xD]
    mov edx, [rsp + 0x28]
    shl edx, 3
    call realloc
    mov [rsi + 0xD], rax
    mov rcx, [rsi + 0x15]
    mov edx, [rsp + 0x28]
    shl edx, 3
    call realloc
    mov [rsi + 0x15], rax
    mov rcx, [rsi + 0x1D]
    mov edx, [rsp + 0x28]
    shl edx, 3
    call realloc
    mov [rsi + 0x1D], rax
    cmp DWORD [rsi + 9], 32
    jne SSheight
    mov rcx, [rsi + 0x25]
    mov edx, [rsp + 0x28]
    shl edx, 3
    call realloc
    mov [rsi + 0x25], rax
    mov eax, [rsi + 1]
    cmp [rsp + 0x28], eax
    jna SSheight

    mov ebx, [rsi + 1]  ;iterator = BMP.width
SSloop1:
    shl ebx, 3  ;make iterator pointer-alligned
    mov ecx, [rsp + 0x20]
    mov edx, 1
    call calloc
    mov rcx, [rsi + 0xD]
    mov [rcx + rbx], rax
    mov ecx, [rsp + 0x20]
    mov edx, 1
    call calloc
    mov rcx, [rsi + 0x15]
    mov [rcx + rbx], rax
    mov ecx, [rsp + 0x20]
    mov edx, 1
    call calloc
    mov rcx, [rsi + 0x1D]
    mov [rcx + rbx], rax
    cmp DWORD  [rsi + 9], 32
    jne short SSloop124
    mov ecx, [rsp + 0x20]
    call malloc
    mov rcx, [rsi + 0x25]
    mov [rcx + rbx], rax
    mov rcx, rax
    mov edx, 0xFF
    mov r8d, [rsp + 0x20]
    call memset
SSloop124:
    shr ebx, 3  ;reverse pointer-allignment
    inc ebx
    cmp ebx, [rsp + 0x28]
    jne SSloop1
SSheight:
    mov eax, [rsi + 5]
    cmp [rsp + 0x20], eax
    je SSret

    xor ebx, ebx    ;iterator = 0
SSloop2:
    shl ebx, 3
    mov rcx, [rsi + 0xD]
    mov rcx, [rcx + rbx]
    mov edx, [rsp + 0x20]
    call realloc
    mov rcx, [rsi + 0xD]
    mov [rcx + rbx], rax
    mov rcx, [rsi + 0x15]
    mov rcx, [rcx + rbx]
    mov edx, [rsp + 0x20]
    call realloc
    mov rcx, [rsi + 0x15]
    mov [rcx + rbx], rax
    mov rcx, [rsi + 0x1D]
    mov rcx, [rcx + rbx]
    mov edx, [rsp + 0x20]
    call realloc
    mov rcx, [rsi + 0x1D]
    mov [rcx + rbx], rax
    cmp DWORD [rsi + 9], 32
    jne short SSloop224
    mov rcx, [rsi + 0x25]
    mov rcx, [rcx + rbx]
    mov edx, [rsp + 0x20]
    call realloc
    mov rcx, [rsi + 0x25]
    mov [rcx + rbx], rax
SSloop224:
    shr ebx, 3
    inc ebx
    cmp ebx, [rsi + 1]
    jne SSloop2
    mov eax, [rsi + 5]
    cmp [rsp + 0x20], eax
    jb SSret   ;if the image was cropped nothing more needs to be done
    xor ebx, ebx
    mov [rsp + 0x18], rdi
    mov edi, [rsp + 0x20]
    sub edi, [rsi + 5]
    sub rsp, 8
SSloop3:       ;fill extended part of image approprietly
    shl ebx, 3
    mov rcx, [rsi + 0xD]
    mov rcx, [rcx + rbx]
    mov eax, [rsi + 5]
    add rcx, rax
    xor dl, dl
    mov r8d, edi
    call ersatzMemset
    mov rcx, [rsi + 0x15]
    mov rcx, [rcx + rbx]
    mov eax, [rsi + 5]
    add rcx, rax
    xor dl, dl
    mov r8d, edi
    call ersatzMemset
    mov rcx, [rsi + 0x1D]
    mov rcx, [rcx + rbx]
    mov eax, [rsi + 5]
    add rcx, rax
    xor dl, dl
    mov r8d, edi
    call ersatzMemset
    cmp DWORD [rsi + 9], 32
    jne short SSloop324
    mov rcx, [rsi + 0x25]
    mov rcx, [rcx + rbx]
    mov eax, [rsi + 5]
    add rcx, rax
    mov dl, 0xFF
    mov r8d, edi
    call ersatzMemset
SSloop324:
    shr ebx, 3
    inc ebx
    cmp ebx, [rsi + 1]
    jne short SSloop3
    add rsp, 8
    mov rdi, [rsp + 0x18]
    jmp short SSret
SSninit:
    mov BYTE [rcx], 1
    mov [rcx + 1], edx
    mov [rcx + 5], r8d
    call initMemory
    ret
SSret:
    add rsp, 0x20
    pop r8
    pop rdx
    mov [rsi + 1], edx
    mov [rsi + 5], r8d
    pop rsi
    pop rbx
    ret


setBitDepth:
    cmp edx, 24
    je SBDgood
    cmp edx, 32
    jne retOne
SBDgood:
    cmp edx, [rcx + 9]
    je retZero
    push rsi
    push rbx
    push rdx
    sub rsp, 0x18
    mov rsi, rcx    ;struct BMP*
    xor ebx, ebx
    cmp edx, [rcx + 9]
    jb SBDfree
    mov ecx, [rsi + 1]
    call malloc
    mov [rsi + 37], rax
SBDloop1:
    shl ebx, 3
    mov ecx, [rsi + 5]
    call malloc
    mov rdx, [rsi + 37]
    lea rcx, [rdx + rbx]
    mov [rcx], rax
    mov edx, 0xFF
    mov r8d, [rsi + 5]
    call memset

    shr ebx, 3
    inc ebx
    cmp ebx, [rsi + 1]
    jne SBDloop1
    jmp SBDret
SBDfree:
    shl ebx, 3
    mov rdx, [rsi + 37]
    lea rcx, [rdx + rbx]
    call free

    shr ebx, 3
    inc ebx
    cmp ebx, [rsi + 1]
    jne SBDfree
    mov rcx, [rsi + 37]
    call free
SBDret:
    add rsp, 0x18
    mov edx, [rsp]
    mov [rsi + 9], edx
    add rsp, 8
    pop rbx
    pop rsi
    xor eax, eax
    ret

ersatzMemset:
    xor eax, eax
EMloop:
    mov [rcx + rax], dl
    inc eax
    cmp eax, r8d
    jne EMloop
    ret


;in the beginning of writing this library I've made a mistake of not aligning the BMP struct

;struct BMP
;{
;    bool initialised;          0       0x0
;    unsigned int width;        1       0x1
;    unsigned int height;       5       0x5
;    unsigned int bitDepth;     9       0x9
;    uint8_t **R;               13      0xD
;    uint8_t **G;               21      0x15
;    uint8_t **B;               29      0x1D
;    uint8_t **A;               37      0x25
;}