; 80x30 - set 80x30 video mode on VGA
; Copyright (c) 1999 Stephen Kitt
; Based on code by Miguel Martinez published in SWAG, itself based on code
; by Ignacio Garc¡a P‚rez.

[BITS 16]
[ORG 0x0100]


[SEGMENT .text]

%macro wait 0
         jmp %%end
         nop
%%end
%endmacro

; Start
start    mov ax, 0x1A00           ; Check for VGA
         int 0x10
         cmp al, 0x1A
         jne vgaerr
         cmp bl, 7
         jl vgaerr
         cmp bl, 8
         jg vgaerr
         mov ax, 0x0040
         mov es, ax
         mov word [es:0x004C], 8192     ; Page size
         mov byte [es:0x0084], 29       ; Screen rows minus one
         mov dx, [es:0x0063]            ; CRTC offset
         cli
         mov ax, 0x0C11
         out dx, ax
         mov ax, 0x0D06
         out dx, ax
         mov ax, 0x3E07
         out dx, ax
         mov ax, 0xEA10
         out dx, ax
         mov ax, 0x8C11
         out dx, ax
         mov ax, 0xDF12
         out dx, ax
         mov ax, 0xE715
         out dx, ax
         mov ax, 0x0616
         out dx, ax
         mov dx, 0x03CC
         in al, dx
         and ax, 0x33
         or ax, 0xC4
         sub dx, byte 10
         out dx, al
         sti
         mov ah, 0x12
         mov bl, 0x20
         int 0x10
         xor al, al               ; Success
end      mov ah, 0x4C
         int 0x21

vgaerr   mov dx, novga            ; No VGA present
error    push dx
         mov dx, errormsg
         mov ah, 0x09
         int 0x21
         pop dx
         int 0x21
         mov dx, fullstop
         int 0x21
         mov al, 0x01
         jmp end


[SEGMENT .data]
fullstop db '.'
crlf     db 0x0D, 0x0A, '$'
errormsg db 'Error: $'
novga    db 'no VGA present$'
