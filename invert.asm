; INVERT - invert the VGA DAC
; Copyright © 2017 Stephen Kitt

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

; See https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

; Based on an idea by Jerry Coffin
; https://retrocomputing.stackexchange.com/q/5172/79

; Assemble with NASM:
; nasm invert.asm -f bin -o invert.com

[BITS 16]
[ORG 0x0100]


[SEGMENT .text]

; Start
start	mov ax, 0x1A00		; Check for VGA
        int 0x10
        cmp al, 0x1A
        jne vgaerr
        cmp bl, 7
        jl vgaerr
        cmp bl, 8
        jg vgaerr
	; Read the DAC, one byte at a time
	push ds
	pop es
	mov di, dacbuf
	mov cx, 768
	xor ax, ax
	mov dx, 0x03C7		; DAC address read mode register
	cli
	out dx, al		; Start reading from the beginning
	mov dx, 0x03C9		; DAC data register
	cld
readloop:
	in al, dx
	stosb
	loop readloop
	; Flip the palette, one byte at a time
	mov si, dacbuf
	mov di, dacbuf
	mov cx, 768
fliploop:
	lodsb
	mov bl, 0x3F		; Six bits per colour
	sub bl, al
	mov al, bl
	stosb
	loop fliploop
	; Write the DAC, one byte at a time
	mov si, dacbuf
	mov cx, 768
	xor ax, ax
	mov dx, 0x03C8		; DAC address write mode register
	out dx, al		; Start writing from the beginning
	inc dx
writeloop:
	lodsb
	out dx, al
	loop writeloop
	sti
end	mov ah, 0x4C
	int 0x21

vgaerr	mov dx, novga		; No VGA present
error	push dx
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
dacbuf   resb 768
