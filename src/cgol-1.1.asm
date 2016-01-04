; ==================================================
; Conway's Game of Life
; Nikola Bebic / Nikola Jovanovic
; RAC 2 - ISP 2015

; v1.1, MAR/2015 	- prepoznavanje stabilizovanih konfiguracija
; v1.0, MAR/2015 	- osnovne funkcionalnosti
; ==================================================

;==================================================
;		MAIN 
;==================================================

	ORG 	256

	; Brisanje konzole i ispisivanje inicijalnog teksta
	; Izbor random generisanog / korisnicki unetog pocetnog stanja
main:	LD	DE, dead_color
	CALL	BIOS_printstr
	LD	DE, cls
	CALL	BIOS_printstr
	LD	DE, init_title
	CALL	BIOS_printstr
	LD	DE, init_text1
	CALL	BIOS_printstr
	LD	DE, init_text2
	CALL	BIOS_printstr
	LD	DE, init_text3
	CALL	BIOS_printstr
	; Brisanje memorije za prepoznavanje stabilizovanih konfiguracija
	CALL	clear_qs

	; Odabir moda
getcmd:	CALL	BIOS_getchar
	CP	'R'
	JP	Z, initR
	CP	'M'
	JP	Z, initM
	JP	getcmd
	; Inicijalizacija random moda
initR:	LD	HL, random
	CALL	init_conf
	JP 	mainloop
	; Inicijalizacija manual moda
initM:	LD	HL, manual
	LD	DE, cls
	CALL	BIOS_printstr
	; Inicijalizacija pocetnog stanja
	CALL	init_conf
	; Automatska evolucija je iskljucena na pocetku
	LD	A, 'M'
	PUSH	AF

	; Glavni ciklus
mainloop:
	; Stampanje table
	CALL	print
	; Hesiranje i provera kraja igre 
	CALL	hash_check
	; Generisanje nove table
	CALL	gen_new
	; Kopiranje nove table na odgovarajucu poziciju
	CALL	copy_new
	; Cekanje korisnickog ulaza koji resetuje ciklus
	; ili ukljucuje mod automatske evolucije
	POP	AF 
	CP	'A'
	JP	Z, auto_mode
	CALL	BIOS_getchar
auto_mode:
	PUSH	AF
	CP	'R'
	JP	Z, main
	JP	mainloop
	HALT

	; Rutina za Brisanje memorije za prepoznavanje stabilizovanih konfiguracija
clear_qs:
	; Priprema iteratora
	LD	DE, period
	LD	A, (DE)
	LD	B, A
	LD	HL, _q_hash
	LD	DE, _q_cnt
	XOR	A
	; Brisanje jednog para polja
.clear_one:
	LD 	(DE), A
	LD	(HL), A
	INC	DE
	INC	HL
	DJNZ	.clear_one
	RET


;==================================================
;	         	INIT CONF
;==================================================

	; Generisanje pocetnog stanja
	; Ciklus koji generise svako polje
init_conf:
	LD	BC, _mat_curr
	LD	DE, _mat_temp

.loop:	; Skok na rutinu koja generise sledece polje
	JP	(HL)
.save:	LD	(BC), A
	INC	BC
	LD	A, B
	CP	D
	JP	NZ, .loop
	LD	A, C
	CP	E
	JP	NZ, .loop
	RET

	; Random generisanje jednog polja
	; Random bit (random broj [0,127] se poredi sa 64)
random:
	LD	A, R
.loop:
	DEC	A
	JP	NZ, .loop
	LD	A, R
	CP	64
	LD	A, 0
	JP	M, init_conf.save
	LD	A, 1
	JP	init_conf.save

	; Korisnicki unos jednog polja
manual:
	CALL	BIOS_getchar
	CALL	BIOS_putchar
	SUB	'0'
	JP	init_conf.save

;==================================================
;	         	PRINT
;==================================================

	; Stampanje table
print:
	LD	DE, dead_color
	CALL	BIOS_printstr
	LD	DE, cls
	CALL	BIOS_printstr
	CALL	longborder
	CALL	print_border
	LD	DE, new_line
	CALL	BIOS_printstr
	CALL	print_border
	LD	HL, _mat_curr
	LD	B, $FF

	; Stampanje pojedinacnog bloka
.print_sb:	
	LD	A, (HL)
	CP	0
	JP	NZ, .alive
	LD	DE, dead_color
	JP	.color
.alive:	LD	DE, alive_color
.color:	CALL	BIOS_printstr
	LD	DE, single_block
	CALL	BIOS_printstr

	; Stampanje novog reda
	LD	A, $F
	AND	L
	CP	$F
	JP	NZ, .new_iter
	CALL	print_border
	LD	DE, new_line
	CALL	BIOS_printstr
	CALL	print_border

	; Sledeca iteracija
.new_iter:
	INC	HL
	LD	A, B
	CP	0
	JP	NZ, .skip
	CALL	longborder
	RET
.skip:	DEC	B
	JP	.print_sb

	; Stampanje okvira
print_border:
	LD	DE, border_color
	CALL	BIOS_printstr
	LD	DE, single_block
	CALL	BIOS_printstr
	RET

	; Stampanje prvog/poslednjeg reda okvira
longborder:
	LD	B, 17
.print_one:
	CALL print_border
	DJNZ .print_one
	RET

;==================================================
;	         	HASH CHECK
;==================================================


	; Hashiranje stanja i provera stabilizacije table
hash_check:
	; Izracunavanje hasha trenutnog stanja
	LD	BC, period
	LD	A, (BC)
	LD	B, A
	CALL	calc_hash	
	; Hasha stanja se nalazi u C
	LD	C, A	
	LD	DE, _q_hash
	LD	HL, _q_cnt

	; Poredjenje hasha sa prethodnim hashevima
	; i racunanje maksimalnog ponavljanja
	; u cilju otkrivanja moguce stabilizacije
.loop:
	LD	A, (DE)
	INC	(HL)
	CP	C
	JP	Z, .next_iter
	LD	(HL), 0
	; Ako je max ponavljanje jednako konstanti period
	; najverovatnije je doslo do stabilizacije

.next_iter:
	PUSH	HL
	LD	HL, period
	LD	A, (HL) 
	POP 	HL
	CP	(HL)
	JP	Z, .stable
	INC	DE
	INC	HL
	DJNZ .loop
	; Poziva se rutina koja pomera niz poslednjih hasheva
	CALL	shift
	; Upis novog hasha
	LD	HL, _q_hash
	LD	(HL), C
	RET

	; Stabilizovana je tabla, restartovanje igre
.stable:
	LD	DE, dead_color
	CALL	BIOS_printstr
	LD	DE, new_line
	CALL	BIOS_printstr
	LD	DE, stable_text
	CALL	BIOS_printstr
	CALL	BIOS_getchar
	JP	main


	; Pomeranje niza poslednjih hasheva
	; Priprema iteratora
shift:	
	LD	DE, period
	LD	A, (DE)
	DEC	A
	DEC	A
	LD	HL, _q_hash ; a = 14
	LD	E, A 
	LD	D, 0
	ADD	HL, DE
	INC	A 
	LD	B, A
	LD	D, H
	LD	E, L
	INC	DE
	; Pomeranje jednog hasha za poziciju udesno
move:	
	LD	A, (HL)
	LD	(DE), A
	DEC	HL
	DEC	DE
	DJNZ 	move
	RET

	; Racunanje hasha za trenutno stanje
calc_hash:
	; Priprema iteratora i evakuacija registra BC
	PUSH	BC
	LD	HL, _mat_curr
	LD	B, $FF
	LD	C, 0
	LD	D, 1
.add_sb:
	; Obradjivanje jednog polja
	LD	A, (HL)
	CP	0
	; Ako je polje 0, ignorise se
	JP	Z, .skip_add
	; Ako nije, na akumulator C se dodaje D
	LD	A, C 
	ADD	D
	LD	C, A

	; Korekcija broja D rotacijom ulevo
.skip_add:
	LD	A, D 
	ADD	A 
	LD	D, A
	JP	NC, .no_carry
	LD	D, 1

	; Priprema za sledecu iteraciju
.no_carry:
	LD	A, B
	CP	0
	JP	NZ, .skip
	LD	A, C
	; Ponovno ucitavanje registra BC
	POP	BC
	RET

	; Nova iteracija
.skip:	DEC 	B
	INC	HL
	JP	.add_sb

;==================================================
;	         	GEN NEW
;==================================================
	
	; Generisanje nove table
gen_new:
	LD	HL, _mat_curr
	LD	DE, _mat_temp
	LD	B, $FF
.gen_one:
	; Generisanje jednog polja
	; Racunanje zivih suseda
	CALL	cnt_adj  
	LD	C, A 	
	LD	A, (HL)
	CP	0
	JP	NZ, .alive 
	JP	.dead

	; Racunanje statusa za zivu celiju
.alive:
	LD	A, C
	CP	2
	JP	Z, .setalive
	CP	3
	JP	Z, .setalive 
	JP	.setdead

	; Racunanje statusa za mrtvu celiju
.dead:
	LD	A, C
	CP	3
	JP	Z, .setalive
	JP	.setdead

	; Celija je ziva
.setalive:
	LD	A, 1
	JP	.new_iter

	; Celija je mrtva
.setdead:
	LD	A, 0
	JP	.new_iter

	; Upisujemo novi status celije
.new_iter:
	LD	(DE), A

	; Nova iteracija
	INC	HL
	INC	DE
	LD	A, B
	CP	0
	RET	Z
	DEC	B
	JP	.gen_one

	; Racunanje zivih suseda za pojedinacno polje

cnt_adj:
	; Backup podataka
	PUSH	BC
	PUSH	DE
	PUSH	HL

	LD	D, H
	LD	C, 0

	; Provera da li moze desno
	LD	A, L		
	AND	$0F
	CP	$0f
	JP	Z, .skip_r

	LD	A, L
	SUB	15
	JP	C, .skip_tr

	; Gore desno
	LD	E, A		
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

	; Dole desno
.skip_tr:
	LD	A, L		
	ADD	17
	JP	C, .skip_br

	LD	E, A
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

	; Desno
.skip_br:
	LD	A, L		; inc if right
	ADD	1
	LD	E, A
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

	; Provera da li moze levo
.skip_r:
	LD	A, L		
	AND	$0f
	CP	0
	JP	Z, .skip_l

	LD	A, L		
	SUB	17
	JP	C, .skip_tl

	; Gore levo
	LD	E, A		
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

	; Dole levo
.skip_tl:
	LD	A, L
	ADD	15
	JP	C, .skip_bl

	LD	E, A		
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

	; Levo
.skip_bl:
	LD	A, L
	SUB	1
	JP	C, .skip_l

	LD	E, A		
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc

.skip_l:
	LD	A, L
	SUB	16
	JP	C, .skip_top

	; Gore
	LD	E, A	
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc
.skip_top:
	LD	A, L
	ADD	16
	JP	C, .skip_bottom

	; Dole
	LD	E, A		
	LD	A, (DE)
	CP	0
	CALL	NZ, .inc
.skip_bottom:
	LD	A, C

	; Retrieve podataka
	POP	HL
	POP	DE
	POP	BC

	RET

	; Pomocna rutina za INC C
.inc:
	INC 	C
	RET

;==================================================
;	         	COPY NEW
;==================================================

	; Kopiranje nove table iz pomocnog prostora
copy_new:
	LD	HL, _mat_curr
	LD	BC, _mat_temp
	LD	DE, _mat_temp
.loop:
	LD	A, (DE)
	LD	(HL), A
	INC	HL
	INC	DE
	LD	A, H
	CP	B
	JP	NZ, .loop
	LD	A, L
	CP	C
	JP	NZ, .loop
	RET	

;==================================================
;	         	DATA
;==================================================

	; Naslov
init_title:
	DB	"*** Conway's Game of Life v1.1 ***",10, 13, 0
	; Tekst za odabir moda koji se prikazuje pri pokretanju
init_text1:
	DB	"Pocetna konfiguracija : (R)andom / (M)anual",10, 13, 0
	; Obavestenje o pokretanju koraka evolucije
init_text2:
	DB	"Pritisak na bilo koje dugme aktivira korak evolucije",10, 13, 0
	; Obavestenje o pokretanju automatske evolucije
init_text3:
	DB	"Postoji mogucnost aktivacije (A)utomatske evolucije",10, 13, 0
	; Stabilizacija
stable_text:
	DB	"Tabla se stabilizovala", 10, 13, "Bilo koje dugme za restart",10, 13, 0

	; Boje za mrtvu/zivu celiju
dead_color:
	DB	$1b, "[40m", 0
alive_color:
	DB	$1b, "[45m", 0
border_color:
	DB	$1b, "[47m", 0

	; Znaci za pojedinacnu celiju
single_block:
	DB	"  ", 0

	; Komanda za brisanje konzole
cls:	
	DB	$1b, "[2J", $1b, "[H", 0

	; Nova linija
new_line:
	DB	10, 13, 0

	; Pozicije glavne i pomocne table
_mat_curr:EQU	$500
_mat_temp:EQU 	$600

	; Konstanta za period posle kog 
	; mozemo da ustanovimo stabilizaciju
period:
	DB	16

	; Pointeri na queue
_q_hash:	EQU	$700
_q_cnt:	EQU 	$710 ;Pomeriti na vise, period

	; BIOS
include "src/PetnicaBIOS.asm"