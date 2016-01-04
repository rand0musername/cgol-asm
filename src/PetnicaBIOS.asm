; ==================================================
; Petnica BIOS v1.1, MAR/2015 - dodat BIOS_scanchar
; Petnica BIOS v1.0, FEB/2014
; Z80Emu port, tniASM syntax
; ==================================================

; --------------------------------------------------
; Rutina za ocitavanje jednog tastera. Ceka se da
; otkucani znak bude na raspolaganju pa se vraca
; u registru A.

BIOS_getchar:
         
.waitgc:
        in       a,(12h)
        bit      1,a
        jr       z,.waitgc

        in       a,(13h)
        ret

; --------------------------------------------------         
; Rutina za ispisivanje jednog karaktera na terminalu.
; Karakter se prosledjuje kroz registar A. Rutina ceka
; terminal da bude spreman za upis.
         
BIOS_putchar:
        push     af

.waitpc:
        in       a,(12h)
        bit      2,a
        jr       z,.waitpc
        
        pop      af
        out      (13h),a
        ret

; --------------------------------------------------
; Rutina za ispis NULL terminisanog stringa.
; Registar DE se koristi kao pocetna adresa
; stringa koji treba ispisati. Po zavrsetku
; DE pokazuje na NULL karakter a ostali registri
; su nepromenjeni.

BIOS_printstr:
        push     af
         
.seeknull:
        ld       a,(de)
        cp       0
        jr       z,.exitps
        
        call     BIOS_putchar
        inc      de
        jr       .seeknull
         
.exitps:
        pop       af
        ret

; --------------------------------------------------
; Rutina za ocitavanje niza karaktera sa tastature
; i smestanje u memoriju. Po pritisku ENTER na kraj
; se upisuje NULL i prekida se citanje.

LINE_BUFFER: EQU     0

BIOS_getcommand:
        push     af
        push     bc
        push     hl
        
        ld       hl,LINE_BUFFER
        ld       b,127
         
.cmdloop:
        call     BIOS_getchar
        
        ; Proveri da li je pritisnut ENTER,
        ; pa ako jeste, zavrsi sa unosom linije:
        
        cp       13
        jr       z,.exitgc
        
        ; Provera da li je unet maksimalni broj
        ; karaktera, pa ako jeste vrati se na
        ; ocitavanje bez promene brojaca:
        
        ex       af,af'
        ld       a,b
        cp       0
        jr       z,.cmdloop
        
        ; Upisi karakter u memoriju:
        
        ex       af,af'
        ld       (hl),a
        call     BIOS_putchar
        inc      hl
        dec      b
        jr       .cmdloop

.exitgc:
        ld       (hl),0
        pop      hl
        pop      bc
        pop      af
        ret
         
; --------------------------------------------------
; Rutina za skeniranje jednog tastera. Proverava da
; li je pritisnut neki taster i ako jeste odmah vraca
; njegov ASCII kod, inace vraca 0

BIOS_scanchar:

.wait:  
        in      a, (0x12)
        bit     1, a
        jp      z, .not_ready
        in      a, (0x13)
        ret

.not_ready:
        xor     a
        ret
