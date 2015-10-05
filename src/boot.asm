;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.0.7
;; ----------------------------------------------------------------------------
;; A simple boot sector program

	[org 0x7c00]		; Intel x86 boot sectors start at address 7c00
	
	mov [BOOT_DRIVE], dl	; BIOS stores our boot drive in DL, so it’s
				; best to remember this for later.
				
	mov bp, 0x8000		; Here we set our stack safely out of the
	mov sp, bp		; way, at 0x8000
	
clear_screen:
	mov ah, 0x00		; Set video mode
	mov al, 0x03		; 720x400 VGA (?)
	int 0x10
	
print_version_number:	
	mov si, version		; Fetch the address of the start of the version string
	call print_string	; Print the version string
	mov dx, [BOOT_DRIVE]	; Print the drive
	call print_hex		;

	mov bx, 0x9000		; Load 5 sectors to 0x0000(ES):0x9000(BX)
	mov dh, 5		; from the boot disk.
	mov dl, [BOOT_DRIVE]
	call disk_read
	mov dx, [0x9000] 	; Print out the first loaded word, which
	call print_hex 		; we expect to be 0xdada , stored
				; at address 0x9000
	mov dx, [0x9000 + 512]	; Also, print the first word from the
	call print_hex		; 2nd loaded sector: should be 0xface

exit:
	jmp $			; Loop forever

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
	;; Prints (in hex) the number held in dx
	;; -------------------------------------------------------------------
print_hex:			; Routine to print hex value of dx
	push ax
	push dx
	push di
	mov di, .hex_buffer + 5	; Point bx to the end of the buffer
	std			; Set the direction flag (we are decrementing)
.next_nybble:
	mov al, dl		; Copy the low-byte of the number
	and al, 0x0F           	; Zero the high-nybble
	cmp al, 0x0A            ; Is the result greater than 10?
	jnc .use_alpha_chars	; Yes: use 'A' - 'F' for 10 - 15
	add al, 0x30            ; Convert to ASCII (add 48)
	jmp .put_char		; Put the resulting character into the buffer
.use_alpha_chars:	
	add al, 0x37            ; Convert to hex (A-F) ASCII values (add 55)
.put_char:
	stosb			; Copy al to [di] and decrement di
	shr dx, 0x04		; Next nybble of the number we're printing
	cmp di, .hex_buffer + 1 ; Start of buffer?
	jnz .next_nybble	; No -- get the next nybble
	mov si, .hex_buffer	; Done. Print the result
	call print_string	;
	pop di
	pop dx
	pop ax
	ret
.hex_buffer:			; Buffer to hold hex characters for print_hex
	db '0x'
	db '00'
	db '00'
	db 0
	
	;; load DH sectors to ES:BX from drive DL
disk_read:
	push dx 		; Store DX on stack so later we can recall
				; how many sectors were request to be read,
				; even if it is altered in the meantime
	mov ah, 0x02 		; BIOS read sector function
	mov al, dh 		; Read DH sectors
	mov ch, 0x00 		; Select cylinder 0
	mov dh, 0x00 		; Select head 0
	mov cl, 0x02 		; Start reading from second sector (i.e.
				; after the boot sector)
	int 0x13 		; BIOS interrupt
jc disk_error			; Jump if error (i.e. carry flag set)
	pop dx			; Restore DX from the stack
	cmp dh, al		; if AL (sectors read) != DH (sectors expected)
jne disk_error			; display error message
	ret
	
disk_error :
	mov si, DISK_ERROR_MSG
	call print_string
	jmp $
	
; Variables

BOOT_DRIVE: db 0, 0

DISK_ERROR_MSG db "Disk read error!", 0

version:
	db 'RetrOS, v0.0.7', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 510-($-$$) db 0	; Pad to 510 bytes with zero bytes

	dw 0xaa55		; Last two bytes (one word) form the magic number ,
				; so BIOS knows we are a boot sector.
				
; We know that BIOS will load only the first 512-byte sector from the disk,
; so if we purposely add a few more sectors to our code by repeating some
; familiar numbers , we can prove to ourselfs that we actually loaded those
; additional two sectors from the disk we booted from.
times 256 dw 0xdada
times 256 dw 0xface
