; RetrOS
; ============================================================================
; v0.0.4
; ----------------------------------------------------------------------------
; A simple boot sector program

	[org 0x7c00]		; Intel x86 boot sectors start at address 7c00

clear_screen:
	mov ah, 0x00		; Set video mode
	mov al, 0x03		; 720x400 VGA (?)
	int 0x10
	
print_version_number:	
	mov bx, version		; Fetch the address of the start of the version string
	call print_string	; Print the version string
exit:
	jmp $			; Loop forever

print_string:
next_char:
	mov al, [bx]		; Get the character from the string
	cmp al, 0		; Is it zero (end of string indicator)?
	jz print_string_done	; If yes, we're done
	mov ah, 0x0e		; Interrupt 10, command 0e: print single character
	int 0x10		; Interrupt 10 (Video Interrupts) to print the character
	add bx, 1		; Point to the next character in the string
	jmp next_char		; Loop back for the next character
print_string_done:
	ret
	
version:
	db 'RetrOS, v0.0.4', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0
	
	times 510-($-$$) db 0	; Pad to 510 bytes with zero bytes

	dw 0xaa55		; Last two bytes (one word) form the magic number ,
				; so BIOS knows we are a boot sector.
