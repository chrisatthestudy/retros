;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.1.1
;; ----------------------------------------------------------------------------
;; Retros kernel

	[org 0x0000]

	push cs
	pop ds			; Align the data segment with the code segment

	mov bp, 0x7DFF		; We'll overwrite the boot sector with the
	mov sp, bp		; stack, giving us about 30k for the stack,
				; from 00500 - 07DFF

	mov [BOOT_DRIVE], dl	; Store the boot-drive number
	
print_version_number:
	mov si, version		; Fetch the address of the start of the version string
	call print_string	; Print the version string
	call print_crlf
get_input:
	call get_char
exit:
	jmp get_input		; Loop forever

	;; ===================================================================
	;; Print String
	;; ===================================================================
	;; Prints the zero-terminated string pointed to by si
	;; -------------------------------------------------------------------
print_string:
	push ax
	push si
.next_char:
	cld			; Clear the direction flag (print forwards)
	lodsb			; Get the character from the string
	or al, al		; Is it zero (end of string indicator)?
	jz .print_string_done	; If yes, we're done
	mov ah, 0x0e		; Interrupt 10, command 0e: print single character
	int 0x10		; Interrupt 10 (Video Interrupts) to print the character
	jmp .next_char		; Loop back for the next character
.print_string_done:
	pop si
	pop ax
	ret

	;; ===================================================================
	;; Print Hex
	;; ===================================================================
	;; Prints (in hex) the value held in dx
	;; -------------------------------------------------------------------
print_hex:
	push dx
	mov bl, dh              ; Print the high-byte  
	call print_hex_byte
	mov bl, dl		; Print the low-byte
	call print_hex_byte
	pop dx
	ret
                    
	;; ===================================================================
	;; Print Hex Byte
	;; ===================================================================
	;; Prints (in hex) the value held in bl
	;; -------------------------------------------------------------------
print_hex_byte:                                     
	push ax    
	push bx
	push di
	push si
	mov di, .hex_buffer + 1	; Point di to the end of the buffer
	std			; Set the direction flag (we are decrementing)
.next_nybble:
	mov al, bl		; Copy the low-byte of the number
	and al, 0x0F		; Zero the high-nybble
	cmp al, 0x0A		; Is the result greater than 10?
	jnc .use_alpha_chars	; Yes, use 'A' - 'F' for 10 - 15
	add al, 0x30		; Convert to ASCII (add 48)
	jmp .put_char		; Put the resulting character into the buffer
.use_alpha_chars:
	add al, 0x37		; Convert to hex (A-F) ASCII values (add 55)
.put_char:
	stosb			; Copy al to [di] and decrement di
	shr bl, 0x04		; Next nybble fo the number we're printing
	cmp di, .hex_buffer - 1	; Start of buffer?
	jnz .next_nybble	; No -- get the next nybble
	mov si, .hex_buffer	; Done. Print the result
	call print_string
	pop si
	pop di
	pop bx
	pop ax
	ret
.hex_buffer:
	db '00', 0

	;; ===================================================================
	;; Hex Dump
	;; -------------------------------------------------------------------
	;; Prints out the hex values of the bytes from address si for a total 
	;; of cx bytes.
	;; -------------------------------------------------------------------
hex_dump:
	push ax
	push bx
	push cx
	push si
.next_byte:
	lodsb
	mov bl, al
	call print_hex_byte
	call print_space
	loop .next_byte, cx
	pop si
	pop cx
	pop bx
	pop ax
	ret
	
print_crlf:
	push si
	mov si, CRLF
	call print_string
	pop si
	ret
	
print_space:
	push si
	mov si, SPACE
	call print_string
	pop si
	ret
	
	;; ===================================================================
	;; Disk Read
	;; -------------------------------------------------------------------
	;; Loads DH sectors to ES:BX from drive DL sector CL
	;; -------------------------------------------------------------------
disk_read:
	push dx 		; Store DX on stack so later we can recall
				; how many sectors were request to be read,
				; even if it is altered in the meantime
	mov ah, 0x02 		; BIOS read sector function
	mov al, dh 		; Read DH sectors
	mov ch, 0x00 		; Select cylinder 0
	mov dh, 0x00 		; Select head 0
	int 0x13 		; BIOS interrupt
	jc disk_error		; Jump if error (i.e. carry flag set)
	pop dx			; Restore DX from the stack
	cmp dh, al		; if AL (sectors read) != DH (sectors expected)
	jne disk_error		; display error message
	ret
	
disk_error :
	mov si, DISK_ERROR_MSG      
	call print_string
	jmp $

	;; ===================================================================
	;; Get Char
	;; -------------------------------------------------------------------
	;; Reads a single character from the keyboard into AL and echoes it
	;; to the screen.
	;; -------------------------------------------------------------------
get_char:
	push ah			; Only preserve the high-byte -- the low-byte returns the character
	xor ah, ah		; AH = 0: input a single character
	int 0x16		; Interrupt, inputs single character into AL
	mov ah, 0x0E		; Echo the returned character
	int 0x10
.exit:
	pop cx
	pop bx
	pop ah
	ret
	
	
	
; Variables

BOOT_DRIVE: db 0, 0
BOOT_DRIVE_LABEL: db "Drive ", 0

HEX_DUMP_LABEL: db "Hex Dump", 0

CRLF: db 0x0D, 0x0A, 0
SPACE: db 0x20, 0
	
DISK_ERROR_MSG db "Disk read error!", 0

version:
	db 'RetrOS, v0.1.0', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 512-($-$$) db 0	; Pad to 512 bytes with zero bytes
