;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.2.1
;; ----------------------------------------------------------------------------
;; Retros kernel

	[org 0x0000]

	;; ===================================================================
	;; OS Call Router
	;; ===================================================================
	;; The location of this router table is fixed -- it cannot be moved
	;; from the start of this file, as the address entries must never
	;; change.
	;; 
	;; Calling a system function:
	;;
	;;    call SYS_CLEAR_SCREEN
	;;
	;; This calls address 0x0006 (see the os_call_router), which then
	;; jumps to the actual clear-screen function.
	;;
	;; The JMP instruction plus the operand occupies 3 bytes -- when new
	;; new functions are added, the next available router address can
	;; easily be calculated by adding 3 to the last entry in the current
	;; list.
	;; 
	;; TODO: These equ declarations need to be moved to an 'include' file
	;; so that they can be used by other programs.
	;; -------------------------------------------------------------------
	SYS       		equ 0x0050    ; Segment for OS call table (not currently used)
	
	SYS_RESET  		equ 0x0000    ; Restart OS
	SYS_VERSION		equ 0x0003    ; Returns with es:si pointing to the version string
	SYS_CLEAR_SCREEN	equ 0x0006    ; Clear screen (set video mode)
	SYS_PRINT_CHAR		equ 0x0009    ; Print the character in AL
	SYS_PRINT_STRING	equ 0x000C    ; Print the zero-terminated string pointed to by SI
	SYS_PRINT_HEX_BYTE	equ 0x000F    ; Print the hex-byte in AL
	SYS_PRINT_HEX_WORD	equ 0x0012    ; Print the hex-word in AX
	SYS_GET_CHAR		equ 0x0015    ; Read from the keyboard into AL
	
os_call_router:
	jmp near os_reset		; 0x0000
	jmp near os_version		; 0x0003
	jmp near os_clear_screen	; 0x0006
	jmp near os_print_char		; 0x0009
	jmp near os_print_string	; 0x000C
	jmp near os_print_hex_byte	; 0x000F
	jmp near os_print_hex_word	; 0x0012
	jmp near os_get_char		; 0x0015

	;; ===================================================================
	;; OS Reset
	;; ===================================================================
	;; Main entry point for the kernel
	;; -------------------------------------------------------------------
os_reset:	
	push cs
	pop ds			; Align the data segment with the code segment

	push 0x0050		; Put the stack in a segment near the bottom
	pop ss			; of the memory
	
	mov bp, 0xFFFF		; Give us 65k of stack space
	mov sp, bp

	mov [BOOT_DRIVE], dl	; Store the boot-drive number

	call SYS_CLEAR_SCREEN	; Set up the display and clear the screen
	
print_version_number:
	call SYS_VERSION	; Get the address of the version string
	call SYS_PRINT_STRING	; and print the string to screen
	call print_crlf

	;; Test for pixel-plotting. Only works if a graphics mode was selected
	;; in clear_screen (above).
	
	mov dx, 0x0020		; Pixel row
	mov cx, 0x0020		; Pixel column
	mov al, CL_RED		; Pixel colour
	call plot		; Plot the pixel
	
	mov dx, 0x0300		; Row 3, col 0
	call cursor_at

stack_dump:
				; Hex dump of the stack
				; -------------------------------------------- 
	push 0x0100		; Put something on the stack, as a test
	push 0xFFFF
	push 0x01FC
	
	mov ax, bp		; Print stack base address
	call SYS_PRINT_HEX_WORD
	call print_space

	mov ax, sp		; Print stack top address
	call SYS_PRINT_HEX_WORD
	call print_space

				; Stack is at ss:sp -- copy this to es:si for
				; the hex dump routine
	
	push ss			; Point es at stack segment
	pop es
	
	push sp			; Point si at stack pointer offset
	pop si
	
	mov cx, bp		; Subtract stack pointer from stack base
	sub cx, sp		; to find out how many items are on the
				; stack (the stack grows downwards, so bp
				; is actually higher than sp).
	
	call hex_dump
	call print_crlf
	call print_crlf

bda_dump:
				; Hex dump of Bios Data Area
				; -------------------------------------------- 

				; 1. COM Ports
	
	mov ax, 0x0000		; BDA is in segment 0x0000
	call SYS_PRINT_HEX_WORD
	mov al, ":"
	call SYS_PRINT_CHAR
	
	mov ax, 0x0400		; Addresses of COM ports - 4 word values
	call SYS_PRINT_HEX_WORD
	call print_space

	push 0x0000
	pop es

	push 0x0400
	pop si

	mov cx, 0x0010

	call hex_dump
	call print_crlf

				; 2. LPT Ports
	
	mov ax, 0x0000		; BDA is in segment 0x0000
	call SYS_PRINT_HEX_WORD
	mov al, ":"
	call SYS_PRINT_CHAR
	
	mov ax, 0x0408		; Addresses of LPT ports - 3 word values
	call SYS_PRINT_HEX_WORD
	call print_space

	push 0x0000
	pop es

	push 0x0408
	pop si

	mov cx, 0x000C

	call hex_dump
	call print_crlf
	call print_crlf

disk_write_test:
	;; As a test, write the version string to a random location on the
	;; floppy drive
	mov al, 1		; Write 1 sector
	push ds			; from this data segment
	pop es
	mov bx, version		; Write the version string
	mov dl, 1		; to floppy disk B (the kernel image)
	mov dh, 0		; head 0
	mov ch, 0		; cylinder 0
	mov cl, 0x03		; sector 3
	call disk_write
	
get_input:
	call SYS_GET_CHAR
exit:
	jmp get_input		; Loop forever

	;; ===================================================================
	;; Clear Screen
	;; ===================================================================
	;; This actually sets the video mode, which has the inevitable
	;; side-effect of resetting the screen display.
	;; -------------------------------------------------------------------
os_clear_screen:
	push ax
	push bx
	mov ah, 0x00		; Set video mode
	mov al, 0x03		; Alternatives: 0x03 (text), 0x12 or 0x13 (graphics)
	int 0x10

	mov ah, 0x0B		; Set background colour
	xor bh, bh
	mov bl, CL_BLUE		; Select colour
	int 0x10
	pop bx
	pop ax
	ret

	;; ===================================================================
	;; Version
	;; ===================================================================
	;; Returns the address of the version string, in es:si. Calling
	;; SYS_PRINT_STRING immediately after calling this function will
	;; print the version string.
os_version:
	push ds			; The version string is in the current data
	pop es			; segment.
	mov si, version		; Set SI to the offset of the string
	ret
	
	;; ===================================================================
	;; Print Character
	;; ===================================================================
	;; Prints the character in AL at the current cursor position
	;; -------------------------------------------------------------------
os_print_char:
	push ax
	push bx
	push cx
	mov cx, 0x0001	 	; Only write the character once
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
	mov al, "."		; For non-printable characters, print a .
.do_print:	
	mov bx, CL_SILVER	; Grey text
	mov ah, 0x09		; Print Character command
	int 0x10		; Interrupt 10 -- video commands
	call cursor_right
.exit:
	pop cx
	pop bx
	pop ax
	ret
	
	;; ===================================================================
	;; Print String
	;; ===================================================================
	;; Prints the zero-terminated string pointed to by si
	;; -------------------------------------------------------------------
os_print_string:
	push ax
	push si
.next_char:
	cld			; Clear the direction flag (print forwards)
	lodsb			; Get the character from the string
	or al, al		; Is it zero (end of string indicator)?
	jz .exit		; If yes, we're done
	call SYS_PRINT_CHAR
	jmp .next_char		; Loop back for the next character
.exit:
	pop si
	pop ax
	ret

	;; ===================================================================
	;; Print Hex Word
	;; ===================================================================
	;; Prints (in hex) the value held in ax
	;; -------------------------------------------------------------------
os_print_hex_word:
	push ax
	push dx
	mov dx, ax		; Store a working copy in dx 
	mov al, dh              ; Print the high-byte  
	call SYS_PRINT_HEX_BYTE
	mov al, dl		; Print the low-byte
	call SYS_PRINT_HEX_BYTE
	pop dx
	pop ax
	ret
                    
	;; ===================================================================
	;; Print Hex Byte
	;; ===================================================================
	;; Prints (in hex) the value held in al
	;; -------------------------------------------------------------------
os_print_hex_byte:                                     
	push ax    
	push bx
	push di
	push es
	push si
	push ds
	pop es
	mov di, .hex_buffer + 1	; Point di to the end of the buffer
	std			; Set the direction flag (we are decrementing)
	mov bl, al		; Store a working copy in bl
.next_nybble:
	mov al, bl		; Retrieve the working copy of the byte
	and al, 0x0F		; Zero the high-nybble
	cmp al, 0x0A		; Is the result greater than 10?
	jnc .use_alpha_chars	; Yes, use 'A' - 'F' for 10 - 15
	add al, 0x30		; Convert to ASCII (add 48)
	jmp .put_char		; Put the resulting character into the buffer
.use_alpha_chars:
	add al, 0x37		; Convert to hex (A-F) ASCII values (add 55)
.put_char:
	stosb			; Copy al to [es:di] and decrement di
	shr bl, 0x04		; Next nybble of the number we're printing
	cmp di, .hex_buffer - 1	; Start of buffer?
	jnz .next_nybble	; No -- get the next nybble
	mov si, .hex_buffer	; Done. Print the result
	call SYS_PRINT_STRING
	pop si
	pop es
	pop di
	pop bx
	pop ax
	ret
.hex_buffer:
	db 'FF', 0

	;; ===================================================================
	;; Hex Dump
	;; -------------------------------------------------------------------
	;; Prints out the hex values of the bytes from address es:si for a total 
	;; of cx bytes.
	;; -------------------------------------------------------------------
hex_dump:
	push ax
	push bx
	push cx
	push si
.next_byte:
	es lodsb
	call SYS_PRINT_HEX_BYTE
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
	call SYS_PRINT_STRING
	pop si
	ret
	
print_space:
	push si
	mov si, SPACE
	call SYS_PRINT_STRING
	pop si
	ret
	
	;; ===================================================================
	;; Disk Read
	;; -------------------------------------------------------------------
	;; Loads DH sectors to ES:BX from drive DL sector CL
	;; -------------------------------------------------------------------
disk_read:
	push ax
	push cx
	push dx 		; Store DX on stack so later we can recall
				; how many sectors were request to be read,
				; even if it is altered in the meantime
	mov ah, 0x02 		; BIOS read sector function
	mov al, dh 		; Read DH sectors
	mov ch, 0x00 		; Select cylinder 0
	mov dh, 0x00 		; Select head 0
	int 0x13 		; BIOS interrupt
	jc .disk_read_error	; Jump if error (i.e. carry flag set)
	pop dx			; Restore DX from the stack
	cmp dh, al		; if AL (sectors read) != DH (sectors expected)
	push dx			; Put dx back on the stack
	je .exit		; All ok

.disk_read_error:
	push si
	mov si, DISK_READ_ERROR_MSG      
	call SYS_PRINT_STRING
	mov al, ah
	call SYS_PRINT_HEX_BYTE
	call print_crlf
	pop si

.exit:
	pop dx
	pop cx
	pop ax
	ret

	;; ===================================================================
	;; Disk Write
	;; -------------------------------------------------------------------
	;; Writes AL sectors from ES:BX to drive DL, head DH, cylinder CH, sector CL
	;; -------------------------------------------------------------------
disk_write:
	push ax
	mov ah, 0x03    	; Disk write command
	int 13h
	jnc .exit		; Exit if all ok (i.e. carry flag cleared)

.disk_write_error:
	push si
	mov si, DISK_WRITE_ERROR_MSG
	call SYS_PRINT_STRING
	mov al, ah
	call SYS_PRINT_HEX_BYTE
	call print_crlf
	pop si

.exit:
	pop ax
	ret

	;; ===================================================================
	;; Get Char
	;; -------------------------------------------------------------------
	;; Reads a single character from the keyboard into AL and echoes it
	;; to the screen.
	;; -------------------------------------------------------------------
os_get_char:
	xor ah, ah		; AH = 0: input a single character
	int 0x16		; Interrupt, inputs single character into AL
	call SYS_PRINT_CHAR	; Echo the returned character
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
	push dx
	mov dx, [CURSOR]
	cmp dl, 0
	jz .exit
	dec dl
	call cursor_at
.exit:
	pop dx
	ret
	
cursor_right:
	push dx
	mov dx, [CURSOR]
	inc dl
	cmp dl, 79		; Right-hand edge of screen?
	jc .exit
	call cursor_down
	call cursor_line_feed
.exit:
	call cursor_at
	pop dx
	ret

cursor_up:
	push dx
	mov dx, [CURSOR]
	dec dh
	cmp dl, 0		; Do nothing if we hit the top of the screen
	jz .exit
	call cursor_at
.exit:
	pop dx
	ret

cursor_down:
	push dx
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
	pop dx
	ret

cursor_line_feed:
	push dx
	mov dx, [CURSOR]
	xor dl, dl
	call cursor_at
	pop dx
	ret

plot:
	push ax
	mov ah, 0x0C		; Write pixel command
	int 0x10		; Call the interrupt
	pop ax
	ret

; Variables

BOOT_DRIVE: db 0, 0
BOOT_DRIVE_LABEL: db "Drive ", 0

HEX_DUMP_LABEL: db "Hex Dump", 0

CRLF: db 0x0D, 0x0A, 0
SPACE: db 0x20, 0
	
DISK_READ_ERROR_MSG db "Disk read error!", 0
DISK_WRITE_ERROR_MSG db "Disk write error: ", 0
	

CURSOR:	
CURSOR_COL:	db 0
CURSOR_ROW:	db 0

CL_BLACK	equ	0x00
CL_NAVY		equ 	0x01
CL_OLIVE  	equ 	0x02
CL_CYAN  	equ 	0x03
CL_MAROON  	equ 	0x04
CL_MAGENTA	equ 	0x05
CL_BROWN  	equ 	0x06
CL_SILVER  	equ 	0x07
CL_GREY  	equ 	0x08
CL_BLUE  	equ 	0x09
CL_GREEN  	equ 	0x0A
CL_AQUA  	equ 	0x0B
CL_RED  	equ 	0x0C
CL_PURPLE  	equ 	0x0D
CL_YELLOW  	equ 	0x0E
CL_WHITE  	equ 	0x0F

MSG_INVALID_OS_CALL:	db "Invalid OS call: ", 0

version:
	db 'RetrOS, v0.2.1', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 65535-($-$$) db 0	; Pad to 65535 bytes with zero bytes
