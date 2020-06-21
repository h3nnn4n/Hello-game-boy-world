INCLUDE "hardware.inc"
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
SECTION "VBlank Interrupt", ROM0[$0040]
    jp vblank_handle
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
SECTION "Header", ROM0[$0100]
    jp Start
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
SECTION "Game code", ROM0[$0150]

Start:
    di                 ; disable interrupts
    ld  sp, $E000      ; setup stack

.wait_vbl              ; wait for vblank to properly disable lcd
    ld  a,[rLY]        ; removing this permanently fucks up the LCD
    cp  $90            ; Wait for line 144
    jr  nz, .wait_vbl

    ; Turn lcd off
    ld a, 0
    ld [rLCDC], a

    ; Shut sound down
    ld a, 0
    ld [rNR52], a

    ; Clear memory
    ld  hl, _RAM
    ld  bc, $2000-2    ; watch out for stack
    call  fill

    ; Clear HRAM
    ld  hl, _HRAM
    ld  bc, $fffe - $ff80
    call  fill

    ; Clear VRAM
    ld  hl, _VRAM
    ld  bc, $1800
    call  fill

    ;  Copy DMA code to HRAM
    ld hl, _HRAM       ; HRAM address is the destination
    ld de, dma_wait_code
    ld bc, 10          ; dma sub routine is 10 bytes long
    call copy

    ;  Copy Fonts to VRAM
    ld hl, $9000
    ld de, FontTiles
    ld bc, FontTilesEnd - FontTiles
    call copy

    ;  Copy Sprites to VRAM
    ld hl, $83F0
    ld de, sprites
    ld bc, 64          ; Each sprite is 16 bytes
    call copy

    ; Copy text to vram
    ld hl, $9800
    ld de, HelloWorldStr
    call copyString

    ; OAM stuff
    ld  a, 80          ; OAM table mirror is located at $C000, let's set up 1st sprite
    ld  [$C000], a     ; Y position
    ld  a, 82
    ld  [$C001], a     ; X position
    ld  a, $3f
    ld  [$C002], a     ; Tile/Pattern Number
    ld  a, %00000000
    ld  [$C003], a     ; Attributes/Flags

    ld  a, 80
    ld  [$C000 + 4], a
    ld  a, 90
    ld  [$C001 + 4], a
    ld  a, $41
    ld  [$C002 + 4], a
    ld  a, %00000000
    ld  [$C003 + 4], a

    ld  a, 88
    ld  [$C000 + 8], a
    ld  a, 90
    ld  [$C001 + 8], a
    ld  a, $42
    ld  [$C002 + 8], a
    ld  a, %00000000
    ld  [$C003 + 8], a

    ld  a, 88
    ld  [$C000 + 12], a
    ld  a, 82
    ld  [$C001 + 12], a
    ld  a, $40
    ld  [$C002 + 12], a
    ld  a, %00000000
    ld  [$C003 + 12], a

    ; Init palette
    ld  a, %11100100   ; 00 is white, 11 is black, the rest is gray
    ld  [rBGP], a
    ld  [rOBP0], a
    ld  [rOBP1], a

    ; LCD initialization
    ld a, 0
    ld  [rIF], a
    ld  [rLCDC], a
    ld  [rSTAT], a
    ld  [rSCX], a
    ld  [rSCY], a
    ld  [rLYC], a
    ld  [rIE], a
    ld  [rSCY], a
    ld  [rSCX], a

    ; Enable LCD
    ld  a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
    ;ld  a, %10000001
    ld  [rLCDC], a

    ; Enable vblank interrupts
    ld  a, IEF_VBLANK
    ld  [rIE], a

    ei                 ; Enable interrupts again


;-------------------------------------------------------------------------------
.mainLoop
;-------------------------------------------------------------------------------
    halt               ; sleep until an interrupt happens

    jp .mainLoop


;-------------------------------------------------------------------------------
; Tetris read keys function
read_keys:
; @return: b -> raw state
; @return: c -> debounced state
;-------------------------------------------------------------------------------
    ld   a, $20        ; get a, b, select, start
    ldh  [rP1], a
    ldh  a, [rP1]
    ldh  a, [rP1]
    cpl                ; Invert all the bits to make 1 mean pressed
    and  $0f           ; only keep the lower 4 bits, which has a, b, select and start
    swap a             ; Swap nibbles
    ld   b, a

    ld   a, $10        ; get up, down, left, right
    ldh  [rP1], a
    ldh  a, [rP1]
    ldh  a, [rP1]
    ldh  a, [rP1]
    ldh  a, [rP1]
    ldh  a, [rP1]
    ldh  a, [rP1]
    cpl                ; Invert all the bits to make 1 mean pressed
    and  $0f           ; keep lower 4 bits, which has up, down, left and right
    or   b             ; combine the state of all keys into a byte
    ld   b, a          ; store it

    ldh  a, [previous] ;
    xor  b             ; Check which keys changed
    and  b             ; Only keep the keys that were pressed (i.e. throw away the releases)
    ldh  [current], a  ; Store the current state
    ld   c, a          ; Copy debounced state to c
    ld   a, b          ; Copy current state to b
    ldh  [previous], a ; Store previous state

    ld   a, $30        ; reset rP1
    ldh  [rP1], a

    ret


;-------------------------------------------------------------------------------
; copies [bc] bytes from [de] to [dl]
copy:
; @param: de -> source
; @param: bc -> byte count
; @param: hl -> destination
;-------------------------------------------------------------------------------
    ld a, [de]         ; Grab 1 byte from the source
    ld [hli], a        ; Place it at the destination
    inc de             ; Move to next byte
    dec bc             ; Decrement count
    ld a, b            ; Check if count is 0, since `dec bc` doesn't update flags
    or c
    jr nz, copy
    ret


;-------------------------------------------------------------------------------
; Copies [de] to [hl] until a zero is found
copyString:
; @param: de -> source
; @param: hl -> destination
;-------------------------------------------------------------------------------
    ld a, [de]
    ld [hli], a
    inc de
    and a              ; Check if the byte we just copied is zero
    jr nz, copyString  ; Continue if it's not
    ret


;-------------------------------------------------------------------------------
; Fill [bc] bytes starting from [hl] with the value in a
fill:
; @param: a  -> byte to fill with
; @param: hl -> destination address
; @param: bc -> size of area to fill
;-------------------------------------------------------------------------------
    inc  b
    inc  c
    jr  .skip
.fill
    ld  [hl+], a
.skip
    dec  c
    jr  nz, .fill
    dec  b
    jr  nz, .fill
    ret


;-------------------------------------------------------------------------------
vblank_handle:
    call  $FF80          ; copy OAM mirror table using DMA
    reti


;-------------------------------------------------------------------------------
dma_wait_code:
;-------------------------------------------------------------------------------
.run_dma
    ld a, $c0
    ldh  [$FF46], a      ; start DMA transfer (starts right after instruction)
    ld  a, $28           ; delay
.wait:                 ; total 4x40 cycles, approx 160 μs
    dec a                ; 1 cycle
    jr  nz, .wait        ; 3 cycles
    ret


;-------------------------------------------------------------------------------
SECTION	"Vars", HRAM[$FF8A]

current:  DS  1        ; Currently pressed keys
previous: DS  1        ; Debounced keys


;-------------------------------------------------------------------------------
SECTION "Font", ROM0

FontTiles:
INCBIN "font.chr"
FontTilesEnd:


;-------------------------------------------------------------------------------
SECTION "Hello World string", ROM0

HelloWorldStr:
    db "Hello World", 0

sprites:
    db  $00, $00, $00, $00, $07, $07, $0f, $0f, $1f, $1f, $1f, $1f, $19, $19, $11, $11
    db  $11, $11, $1f, $1f, $0e, $0e, $07, $07, $07, $07, $05, $05, $00, $00, $00, $00
    db  $00, $00, $00, $00, $f0, $f0, $f8, $f8, $fc, $fc, $fc, $fc, $cc, $cc, $c4, $c4
    db  $c4, $c4, $7c, $7c, $38, $38, $f0, $f0, $f0, $f0, $50, $50, $00, $00, $00, $00
