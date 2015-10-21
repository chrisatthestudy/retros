;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.1.2
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
	mov dx, 0x0300		; Row 3, col 0
	call cursor_at
get_input:
	call get_char
exit:
	jmp get_input		; Loop forever

	;; ===================================================================
	;; Print Character
	;; ===================================================================
	;; Prints the character in AL at the current cursor position
	;; -------------------------------------------------------------------
print_char:
	push ax
	push bx
	;; First check for special characters and handle them
	cmp al, 0x0D		; Carriage return
	je .do_carriage_return
	cmp al, 0x0A		; Line-feed
	je .do_line_feed
	cmp al, 0x08		; Backspace
	je .do_backspace
	cmp al, 0x20		; Low-range non-printable characters
	jl .do_non_printable
	cmp al, 0x7F		; High-range non-printable characters
	jg .do_non_printable
	jmp .do_print		; We have a standard ASCII character
.do_carriage_return:
	call cursor_down
	call cursor_line_feed
	jmp .exit
.do_line_feed:
	call cursor_line_feed
	jmp .exit
.do_backspace:
	call cursor_left
	;; Print a space (overwriting any existing character on-screen)
	mov al, " "
	mov ah, 0x09
	int 0x10
	jmp .exit
.do_non_printable:
	mov al, "."
.do_print:	
	mov bx, 0x0007		; Grey text
	mov ah, 0x09		; Print Character command
	int 0x10		; Interrupt 10 -- video commands
	call cursor_right
.exit:
	pop bx
	pop ax
	ret
	
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
	call print_char
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
	xor ah, ah		; AH = 0: input a single character
	int 0x16		; Interrupt, inputs single character into AL
	call print_char		; Echo the returned character
.exit:
	ret
	
	;; ===================================================================
	;; Cursor At
	;; -------------------------------------------------------------------
	;; Positions the cursor at row dh, col dl
	;; -------------------------------------------------------------------
cursor_at:
	push ax
	push bx
	mov ah, 0x02
	xor bh, bh
	int 0x10
	mov [CURSOR_ROW], dh
	mov [CURSOR_COL], dl
	pop bx
	pop ax
	ret

	;; ===================================================================
	;; Cursor Movement
	;; -------------------------------------------------------------------
	;; Sub-routines to move the cursor
	;; -------------------------------------------------------------------
cursor_left:
	mov dx, [CURSOR]
	cmp dl, 0
	jz .exit
	dec dl
	call cursor_at
.exit:	
	ret
	
cursor_right:
	mov dx, [CURSOR]
	inc dl
	cmp dl, 79		; Right-hand edge of screen?
	jc .exit
	call cursor_down
	call cursor_line_feed
.exit:
	call cursor_at
	ret

cursor_up:
	mov dx, [CURSOR]
	dec dh
	cmp dl, 0		; Do nothing if we hit the top of the screen
	jz .exit
	call cursor_at
.exit:
	ret

cursor_down:
	mov dx, [CURSOR]
	inc dh
	cmp dh, 25		; Bottom of the screen?
	jl .continue		; No, carry on
	push ax			; Yes, scroll the entire window
	push cx
	push dx
	mov cx, 0x0000		; Top-left
	mov dx, 0x184F		; Bottom-left
	mov ah, 0x06		; Scroll window up
	mov al, 0x01		; by one row
	int 0x10
	pop dx
	pop cx
	pop ax
	mov dh, 24		; Reset to the bottom row of the screen.
.continue:
	call cursor_at
	ret

cursor_line_feed:
	mov dx, [CURSOR]
	xor dl, dl
	call cursor_at
	ret

; Variables

BOOT_DRIVE: db 0, 0
BOOT_DRIVE_LABEL: db "Drive ", 0

HEX_DUMP_LABEL: db "Hex Dump", 0

CRLF: db 0x0D, 0x0A, 0
SPACE: db 0x20, 0
	
DISK_ERROR_MSG db "Disk read error!", 0

CURSOR:	
CURSOR_COL:	db 0
CURSOR_ROW:	db 0

version:
	db 'RetrOS, v0.1.2', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 512-($-$$) db 0	; Pad to 512 bytes with zero bytes
