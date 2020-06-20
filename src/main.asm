INCLUDE "hardware.inc"


SECTION "Header", ROM0[$100]
    di       ; Disable interrupts to avoid having to deal with them
    jp Start ; Leave this tiny space


REPT $150 - $104
    db 0
ENDR

SECTION "Game code", ROM0

Start:
    ; Turn off the LCD
.waitVBlank
    ld a, [rLY]
    cp 144            ; Check if the LCD is past VBlank
    jr c, .waitVBlank

    ld a, 0           ; We only need to reset a value with bit 7 reset, but 0 does the job
    ld [rLCDC], a     ; We will have to write to LCDC again later, so it's not a bother, really.

    ld hl, $9000
    ld de, FontTiles
    ld bc, FontTilesEnd - FontTiles

.copyFont
    ld a, [de]           ; Grab 1 byte from the source
    ld [hli], a          ; Place it at the destination, incrementing hl
    inc de               ; Move to next byte
    dec bc               ; Decrement count
    ld a, b              ; Check if count is 0, since `dec bc` doesn't update flags
    or c
    jr nz, .copyFont

    ld hl, $9800         ; This will print the string at the top-left corner of the screen
    ld de, HelloWorldStr

.copyString
    ld a, [de]
    ld [hli], a
    inc de
    and a              ; Check if the byte we just copied is zero
    jr nz, .copyString ; Continue if it's not

    ; Init display registers
    ld a, %11100100
    ld [rBGP], a

    ld a, 0
    ld [rSCY], a
    ld [rSCX], a

    ; Shut sound down
    ld [rNR52], a

    ; Turn screen on, display background
    ld a, %10000001
    ld [rLCDC], a

    ; Lock up. Stop cpu from running around
.lockup
    jr .lockup


SECTION "Font", ROM0

FontTiles:
INCBIN "font.chr"
FontTilesEnd:


SECTION "Hello World string", ROM0

HelloWorldStr:
    db "Hello Game Boy World!", 0
