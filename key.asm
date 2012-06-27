; key echo program 
;
; Based On:
; Mini Type writer demo for 65EL02 by admin 
; @ http://ibm5100.net/redpower/getting-user-input-to-work-in-assembly-with-redpower-cpu65el02-part-2/

!cpu 65EL02		; removes the requirement to specify processor type when using ACME
!to "key.img",plain	; name of output file

*=0x500        	;set offset to 0x500

CLC            	;clear carry flag
XCE            	;set emulation flag
REP #$30    	;set to 16bit mode
!al         	;need this to make acc 16bit

LDA #$1     	;map device 1 (monitor) to redbus window
MMU #$0
LDA #$300   	;set redbus window offset to 0x300
MMU #1
MMU #2      	;enable redbus

LDA #$400   	;set external memory mapped window to 0x400
MMU    #$3
MMU    #$4  	;enable external memory mapped window

LDA #$500    	;Set POR to 0x500
MMU #$6

;setup display registers

	;setup blitter to allow full screen scroll
	LDA #$0
	STA $308    ;set blit x start to 0
	STA $30A    ;set blit x offset to 0
	STA $30B    ;set blit y offset to 0

	LDA #$01
	STA $309    ;set blit y start to 1, this will shift row 1 to 0, 2 to 1


	LDA #$60    ;set blit width to 80 characters
	STA $30C
	LDA #$31    ;set blit height to 49 lines
	STA $30D

	; done with blitter, setup for main program output

	LDA #$2     ;set memory access row to 2, boot message is in row 0 and 1
	STA $300

	LDA #$01    ;set cursor solid
	STA $303

; done with display registers

SEP #$30    	;switch to 8bit mode
!as            	;need this to switch back accu to 8bit mode

;enter main program
CLC            	;clear carry flag
LDA #$02    	;make variable for memory access row
STA $03
LDA #$0D    	;store ASCII Code for carriage return in zero page
STA $01
LDA #$08    	;store ASCII Code for delete key in zero page
STA $02

LDX #$00    	;Set output column to 0

.cursorloop
;LDA #$3C    	;display a cursor
;STA $310,X

; Move monitor's built in cursor to current location
STX $301		;Put current column into Cursor-X
LDA $03			;Get current monitor row
STA $302		;Put current monitor row into Cursor-Y

.loop

LDA $304    	;load keybuffer start to Accu
STA $00     	;store keybuffer in zeropage
LDA $305    	;load keybuffer position in Accu
CMP $00     	; compare keybuffer start and position for key detection
				;note: if keypress is detected 305 will increment
				;buffer start(remains 0?) and position(incremented) will be unequal and bne will branch
BNE +       	;if Accu does not equal value in $5D0 branch (+ means go to next + on branch)
JMP .loop   	;if no keypress was detected loop

+ LDA #$00  	;branch here from bne and load 00 in Accu
STA $305    	;set keybuffer position to 0 (Reset keybuff position as it has incremented)
LDA $306    	;load newly typed character from start of keybuffer

CMP $01     	;if entered character is "carriage return" branch to next +
BEQ .processReturn

CMP $02     	;if entered character is "delete" branch to next ++
BEQ .processDelete

STA $310,X  	;store accu at 316 + x (prints key on monitor)
INX         	;increment x

JMP .cursorloop

;processing carriage return
.processReturn
LDA #$20 		;fill one column ahead with a space to hide cursor
STA $310,X		;note: Only needed if not using built in cursor

LDX #$00 		;reset X (go back to start of line)


LDA #$30 		; Check to see if we're not at the last row
CMP $03
BNE .nextline

; We're at the last line, scroll the display instead of moving to next line
LDA #$3			;set blit mode to shift
STA $307    	;execute scroll screen
- wai
cmp $0307	; wait for execution
beq -

JMP .cursorloop

; Was not at last line, move cursor to next line
.nextline
INC $03        ;increment memory access row variable
LDA $03        ;load current line we are on
STA $300    ;reflect the change on monitor
JMP .cursorloop

;processing delete
.processDelete
LDA #$20    ;fill current char with space
STA $310,X
STA $311,X    ;and the cursor too
DEX            ;decrement X to go one character back
JMP .cursorloop

STP

!fi 128, $00 ;fill disk with 0's to make the disk at least 128bytes