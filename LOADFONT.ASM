; LOADFONT 1.01 - loads a font on a VGA.
; Copyright (c) 1999 Stephen Kitt
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
;
; To contact the author, email steve@tardis.ed.ac.uk

[BITS 16]
[ORG 0x0100]

[SEGMENT .text]

%macro wait 0
         jmp %%end
         nop
%%end
%endmacro

; Start
start
%ifdef VERBOSE
         mov dx, title            ; Display title
         mov ah, 0x09
         int 0x21
%endif
         mov ax, 0x1A00           ; Check for VGA
         int 0x10
         cmp al, 0x1A
         jne vgaerr
         cmp bl, 7
         jl vgaerr
         cmp bl, 8
         jg vgaerr
         ; Following ten lines based on code by Tylisha C. Andersen, published
         ; in Tennie Remmel's Programming Tips & Tricks issue 7
         xor cx, cx               ; Check there's a command-line
         mov di, 0x0081
         mov cl, [di - 1]
         jcxz ncl                 ; No command line...
         inc cx
         mov ax, 0x3D20           ; AL contains ' ', AH is open file...
         repe scasb               ; Search for the first non-space character
         lea dx, [di - 1]         ; DX now points to the file name
         repne scasb              ; Search for the next space or end of line
         mov [di - 1], ch         ; Zero the end of the file name
         shl al, 1                ; AL is now 0x40, read-only, deny none
         int 0x21                 ; Open the file
         jc doserr
         mov [handle], ax         ; Store the file handle
         mov bx, ax
         mov ah, 0x3F             ; Read file
         mov cx, 16384            ; Up to 16KB
         mov dx, file
         int 0x21
         jc doserr
         mov [length], ax         ; Store the file's length
         call decode              ; Determine the file format
%ifdef VERBOSE
         mov dx, format           ; Print the format
         mov ah, 0x09
         int 0x21
         mov dx, [fid]
         int 0x21
         mov dx, fullstop
         int 0x21
%endif
         jmp setfont

vgaerr   mov dx, novga            ; No VGA present
         jmp error

ncl      mov dx, nofont           ; No font file specified
error    push dx
         mov dx, errormsg
         mov ah, 0x09
         int 0x21
         pop dx
         int 0x21
         mov dx, fullstop
         int 0x21
         jmp end

doserr   mov di, doserrls
         mov cx, doserrs
         repnz scasb
         jcxz .dosun
         sub di, doserrls+1
         mov bp, di
         shl bp, 1
         mov dx, [bp+doserrpt]
         jmp error
.dosun   mov dx, doserrun
         jmp error

; Set font.
setfont
    ; Set VGA up for font modification
         mov dx, 0x03C4
         mov ax, 0x0402           ; Write enable display memory plane 2
         out dx, ax
         wait
         mov ax, 0x0704           ; Sequential access to all text mode memory
         out dx, ax
         wait
         mov dl, 0xCE             ; DX = 0x03CE
         mov ah, 0x04             ; AX = 0x0404
         out dx, ax
         wait
         mov ax, 0x0005
         out dx, ax
         wait
         mov al, 0x06             ; AX = 0x0006
         out dx, ax
    ; Load the font
         xor cx, cx
         mov cl, [height]
         mov si, [font]
         mov ax, 0xA000
         mov es, ax
         xor di, di               ; ES:DI points to 0xA000:0x0000
         mov dx, 0x0100           ; 256 characters
         mov bx, 32
         sub bx, cx               ; BX stores the difference
         push cx                  ; Remember cell height
.loop    pop cx
         push cx
         rep movsb                ; No assumptions on cell height
         add di, bx
         dec dx
         jnz .loop
         pop cx
    ; Restore video settings
         mov dx, 0x03C4
         mov ax, 0x0302
         out dx, ax
         wait
         mov al, 0x04
         out dx, ax
         wait
         mov dl, 0xCE
         xor ah, ah
         out dx, ax
         wait
         mov ax, 0x1005
         out dx, ax
         wait
         mov ax, 0x0E06
         out dx, ax

; Store new line information if necessary.
setbios  mov ax, 0x40
         mov es, ax
         mov cl, [es:0x0084]      ; Old screen lines
         inc cl
         mov [lines], cl
         mov cl, [es:0x004A]      ; Old screen columns
         mov [columns], cl
         mov bx, [es:0x0085]      ; Old character height
         cmp bl, [height]
         je .end                  ; If same as new, leave untouched
         mov dx, 0x03D4           ; Get vertical display end
         mov al, 0x12             ; i.e. scan lines in screen
         out dx, al
         inc dx
         in al, dx
         mov bl, al               ; Main part in BL
         dec dx
         mov al, 0x07
         out dx, al
         inc dx
         in al, dx
         mov bh, al               ; Supplementary part in BH
         xor ax, ax
         mov al, bl
         test bh, 0x02
         jz .cont1
         add ah, 1
.cont1   test bh, 0x40
         jz .cont2
         add ah, 2
.cont2   inc ax                   ; Scan lines in AX
         mov bl, [height]         ; New character height
         div bl
         mov cl, al               ; New screen rows
         mov [lines], cl
         dec cl                   ; Adjust for BIOS storage
         mov [es:0x0084], cl      ; Update BIOS memory locations
         mov [es:0x0085], bx
         dec bx                   ; Adjust for VGA storage
         mov dx, 0x03D4           ; Get current value for 0x03D4/0x09
         mov al, 0x09
         out dx, al
         inc dx
         in al, dx
         and al, 0xE0             ; Clear low five bits
         or al, bl                ; Set new character height
         dec dx                   ; Store...
         push ax
         mov al, 0x09
         out dx, al
         pop ax
         inc dx
         out dx, al
.end

%ifdef VERBOSE
; Print the new settings.
report   mov dx, fontsize
         mov ah, 0x09
         int 0x21
         mov al, 8
         call printb
         mov dl, 'x'
         mov ah, 0x02
         int 0x21
         mov al, [height]
         call printb
         mov dx, scrnsize
         mov ah, 0x09
         int 0x21
         mov al, [columns]
         call printb
         mov dl, 'x'
         mov ah, 0x02
         int 0x21
         mov al, [lines]
         call printb
         mov dx, fullstop
         mov ah, 0x09
         int 0x21
%endif

; Finish...
end      mov bx, [handle]         ; Quit, closing files if necessary
         or bx, bx
         jz .nofiles
         mov ah, 0x3E
         int 0x21
.nofiles ret

; Decode a loaded file's format
; This routine should remain separate, since multiple ret's are smaller than
; multiple jmp's.
decode   cmp word [file], 0x55AA
         je .cafe
         cld
         mov di, cafecom
         mov si, file + 3
         mov cx, 9
         repz cmpsb
         jcxz .cafecom
         mov di, fontedit
         mov si, file
         mov cx, 17
         repz cmpsb
         jcxz .fontedit
         mov di, pcmagcom
         mov si, file + 10
         mov cx, 11
         repz cmpsb
         jcxz .pcmagcom
         jmp .raw
.cafe    mov word [font], file + 8 ; CAFE font file
         mov ax, [file + 4]
         mov [height], al
%ifdef VERBOSE
         mov word [fid], fcafe
%endif
         ret
.cafecom mov ax, [file + 14]      ; CAFE executable
         add ax, file
         mov [font], ax
         mov al, [file + 12]
         mov [height], al
%ifdef VERBOSE
         mov word [fid], fcafecom
         mov byte [cafecom + 4], ' ' ; Correct format message
%endif
         ret
.fontedit                         ; FONTEDIT 1.0 font file
         mov word [font], file + 18
         mov ax, [length]
         sub ax, 18
%ifdef VERBOSE
         mov word [fid], ffontedt
%endif
         jmp .height
.pcmagcom                         ; PC Magazine FONTEDIT executable
         mov word [font], file + 99
         mov al, [file + 50]
         mov [height], al
%ifdef VERBOSE
         mov word [fid], fpcmag
%endif
         ret
.raw     mov word [font], file    ; Raw font file
         mov ax, [length]
%ifdef VERBOSE
         mov word [fid], fraw
%endif
.height  mov [height], ah         ; Length divided by 256...
         ret

%ifdef VERBOSE
; Print the byte in AL in decimal.
printb   xor ah, ah
; Print the word in AX in decimal.
printw   xor cx, cx               ; Counter
         mov bl, 10               ; Divisor
.loop1   div bl
         push ax
         inc cx
         xor ah, ah               ; Clear the remainder
         test al, al
         jnz .loop1
.loop2   pop ax
         mov dl, ah
         add dl, 0x30             ; Make DL a digit
         mov ah, 0x02             ; Print single character
         int 0x21
         loop .loop2
         ret
%endif

%ifdef VERBOSE
title    db 'LOADFONT 1.01 þ Copyright (c) 1999 Stephen Kitt'
%endif
fullstop db '.'
crlf     db 0x0D, 0x0A, '$'
errormsg db 'Error: $'
nofont   db 'no font file specified$'
novga    db 'no VGA present$'
doserr01 db 'invalid function number$'
doserr02 db 'file not found$'
doserr03 db 'path not found$'
doserr04 db 'too many open files$'
doserr05 db 'access denied$'
doserr0C db 'access code invalid$'
doserr56 db 'invalid password$'
doserrun db 'unknown DOS error$'
doserrls db 0x01, 0x02, 0x03, 0x04, 0x05, 0x0C, 0x56
doserrs  equ 7
doserrpt dw doserr01, doserr02, doserr03, doserr04, doserr05, doserr0C,
         dw doserr56

handle   dw   0x0000              ; Font file handle

fontedit db 'fontedit 1.0 file'

%ifdef VERBOSE
format   db 'Font format: $'
fcafe    db 'CAFE or Tseng FEDIT$'
%endif
cafecom                           ; Signature combined with message
fcafecom db 'CAFE!exec'           ; This needs modified before printing
%ifdef VERBOSE
         db 'utable$'
ffontedt db 'Chris Howe', 39, 's FONTEDIT 1.0$'
%endif
pcmagcom                          ; Signature combined with message
fpcmag   db 'PC Magazine'
%ifdef VERBOSE
         db 39, 's FONTEDIT executable$'
fraw     db 'raw$'

fontsize db 'Font size: $'
scrnsize db '; screen size: $'
%endif

[SEGMENT .bss]
length   resw 1                   ; Font file length
font     resw 1                   ; Pointer to font data
height   resb 1                   ; Cell height
%ifdef VERBOSE
fid      resw 1                   ; File format
%endif
columns  resb 1                   ; Screen columns
lines    resb 1                   ; Screen lines
file     resb 16384               ; File
