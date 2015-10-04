; ============================================================================
; RetrOS
; ============================================================================
; v0.0.5
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
	mov dx, 1234d		; Test the hex print routine
	call print_hex		; -- should print 0x04D2
exit:
	jmp $			; Loop forever

	;; ===================================================================
	;; Print String
	;; ===================================================================
	;; Prints the zero-terminated string pointed to by bx
	;; -------------------------------------------------------------------
print_string:
	push eax
	push ebx
.next_char:
	mov al, [bx]		; Get the character from the string
	cmp al, 0		; Is it zero (end of string indicator)?
	jz .print_string_done	; If yes, we're done
	mov ah, 0x0e		; Interrupt 10, command 0e: print single character
	int 0x10		; Interrupt 10 (Video Interrupts) to print the character
	add bx, 1		; Point to the next character in the string
	jmp .next_char		; Loop back for the next character
.print_string_done:
	pop ebx
	pop eax
	ret

	;; ===================================================================
	;; Print Hex
	;; ===================================================================
	;; Prints (in hex) the number held in dx
	;; -------------------------------------------------------------------
print_hex:			; Routine to print hex value of dx
	push eax
	push ebx
	push edx
	mov bx, .hex_buffer + 5	; Point bx at the start of the buffer
	mov ah, 0x04            ; Use high-byte of ax register as counter
.next_byte:
	mov al, dl		; Copy the low-byte
	and al, 0x0F           	; Zero the high-nibble
	cmp al, 0x0A            ; Is the result less than 10?
	jnc .use_alpha		; No: use 'A' - 'F' for 10 - 15
	add al, 0x30            ; Convert to ASCII (add 48)
	jmp .put_char		; Put the resulting character into the buffer
.use_alpha:	
	add al, 0x37            ; Convert to hex ASCII (add 55)
.put_char:
	mov [bx], al		; Copy the result to the buffer
	sub bx, 1		; Next buffer byte
	shr dx, 0x04		; Next nibble
	sub ah, 0x01            ; Count down
	jnz .next_byte
	mov bx, .hex_buffer	; Done. Print the result
	call print_string	;
	pop edx
	pop ebx
	pop eax
	ret
.hex_buffer:
	db '0x0000', 0		; Buffer to hold hex characters for print_hex
	
version:
	db 'RetrOS, v0.0.5', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 510-($-$$) db 0	; Pad to 510 bytes with zero bytes

	dw 0xaa55		; Last two bytes (one word) form the magic number ,
				; so BIOS knows we are a boot sector.
