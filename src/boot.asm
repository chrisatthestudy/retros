; StudiOS
; ============================================================================
; v0.0.1
; ----------------------------------------------------------------------------
; A simple boot sector program that loops forever.

	mov ah, 0x0e        	; Interrupt 10, command 0e: print single character	
	mov al, 'm'		; Set the character
	int 0x10		; Print the character
	mov al, 'y'
	int 0x10
	mov al, 'O'
	int 0x10
	mov al, 'S'
	int 0x10
	jmp $
	
	times 510-($-$$) db 0 	; Pad to 510 bytes with zeros

	dw 0xaa55 		; The last two bytes of this 512-byte sector
				; must hold the magic number aa55, which
				; identifies this to the BIOS as a boot
				; sector.
