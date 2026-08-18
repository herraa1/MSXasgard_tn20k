; ===========================================================================
; slave_rom / main.asm
;
; ROM de cartucho para el MSX ANFITRION del MSX2+ Goauld.
;
; El Z80 del anfitrion queda secuestrado por completo desde la llamada a INIT:
; no vuelve a la BIOS, no usa RAM y no usa pila (ni CALL/RET ni PUSH/POP), y
; entra con DI. Asi el proxy es inmune a la configuracion de slots y de RAM
; del anfitrion, y funciona en cualquier MSX.
;
;   1. Programa el VDP del anfitrion (solo R0-R7, subconjunto TMS9918, por lo
;      que vale igual en MSX1 y MSX2) en TEXT1 y muestra el aviso de que el
;      video se ha movido a la salida HDMI.
;   2. Entra en un bucle infinito que barre las 16 filas de la matriz de
;      teclado y los dos puertos de joystick, los deja en los registros de
;      intercambio del cartucho, y devuelve los LEDs (CAPS/KANA) que pide el
;      MSX2+.
;
; La firma se escribe al FINAL de cada pasada: asi host_ready solo se libera
; cuando ya hay un barrido completo y valido en los registros.
; ===========================================================================

.ZILOG

; --- Puertos del anfitrion -------------------------------------------------
VDP_DATA    equ #98
VDP_CTRL    equ #99
PSG_ADDR    equ #A0
PSG_WDATA   equ #A1
PSG_RDATA   equ #A2
PPI_PORTB   equ #A9		; lectura de la fila de teclado
PPI_PORTC   equ #AA		; b3-b0 fila, b4 motor cassette, b5 cassette write,
				; b6 LED CAPS, b7 click de teclas (1 = off/high en todos)

; --- Registros de intercambio del cartucho ---------------------------------
XCHG_KEYS   equ #5000		; 16 bytes: filas 0-15
XCHG_JOY1   equ #5010
XCHG_JOY2   equ #5011
XCHG_BEAT   equ #5012
XCHG_SIG    equ #5013
XCHG_LEDS   equ #5020		; lectura: b0 = CAPS, b1 = KANA (los pide el MSX2+)

PROXY_SIG   equ #5A		; firma que libera host_ready en la FPGA

; Del puerto C solo se tocan el LED de CAPS (b6, 0 = encendido) y la fila de
; teclado (b3-b0). El click (b7), la escritura de cassette (b5) y el motor de
; cassette (b4) se CONSERVAN tal como los dejo la BIOS del anfitrion: no son
; cosa nuestra y ponerle un valor propio a b4 encendia el rele del motor.
PPIC_KEEP   equ #B0		; b7, b5 y b4 se conservan
PPIC_CAPSOFF equ #40		; b6 = 1 apaga el LED de CAPS

; R15 del PSG (salidas):
;   b0-b3  pines 6 y 7 de los dos puertos. TIENEN que estar a 1 para poder leer
;          los gatillos en r#14; a 0 los botones no responderian nunca.
;   b4-b5  pin 8 de cada puerto, en alto = reposo.
;   b6     seleccion de puerto para r#14: 0 = puerto 1, 1 = puerto 2.
;   b7     LED KANA, 1 = apagado.
PSG_R15         equ #BF	; KANA apagado, puerto 1
PSG_R15_KANA    equ #3F	; igual pero con KANA encendido (solo cambia b7)

; Tabla de patrones del VDP en TEXT1 (R4 = 1)
PATTERN_HI  equ #08		; base 0x0800, byte alto

.org #4000

; ############## Cabecera de cartucho MSX
	.db #41,#42			; "AB"
	.dw init				; INIT
	.dw #0000				; STATEMENT
	.dw #0000				; DEVICE
	.dw #0000				; TEXT
	.dw #0000
	.dw #0000
	.dw #0000				; reservado

; ############## Inicializacion
init:
	di

	in   a,(VDP_CTRL)		; resetea el latch registro/direccion del VDP

	; --- R0..R7 en TEXT1, pantalla apagada ---
	ld   hl, vdp_init_tab
	ld   c, 0
.reg_loop:
	ld   a,(hl)
	inc  hl
	out  (VDP_CTRL),a		; dato del registro
	ld   a,c
	or   #80
	out  (VDP_CTRL),a		; 0x80 | nº de registro
	inc  c
	ld   a,c
	cp   8
	jr   nz,.reg_loop

	; --- Sube cada glifo a PATTERN + ascii*8, para poder escribir los
	;     mensajes en ASCII directo en la tabla de nombres ---
	ld   hl, font_data
	ld   b, font_count
.glyph_loop:
	ld   a,(hl)			; codigo ascii de este glifo
	inc  hl
	ld   e,a				; de = ascii * 8 + 0x0800
	ld   d,0
	sla  e
	rl   d
	sla  e
	rl   d
	sla  e
	rl   d
	ld   a,d
	or   PATTERN_HI
	ld   d,a
	ld   a,e				; direccion de escritura en VRAM
	out  (VDP_CTRL),a
	ld   a,d
	or   #40
	out  (VDP_CTRL),a
	ld   c,8
.glyph_byte:
	ld   a,(hl)
	out  (VDP_DATA),a
	inc  hl
	dec  c
	jr   nz,.glyph_byte
	djnz .glyph_loop

	; --- Limpia la tabla de nombres (40x24 = 960) con espacios ---
	xor  a
	out  (VDP_CTRL),a
	ld   a,#40			; 0x0000 | escritura
	out  (VDP_CTRL),a
	ld   bc,960
.clear_loop:
	ld   a,#20
	out  (VDP_DATA),a
	dec  bc
	ld   a,b
	or   c
	jr   nz,.clear_loop

	; --- Escribe las lineas del aviso ---
	ld   hl, msg_table
.msg_outer:
	ld   e,(hl)			; offset en la tabla de nombres, byte bajo
	inc  hl
	ld   d,(hl)			; byte alto (0x0000 marca el final de la tabla)
	inc  hl
	ld   a,d
	or   e
	jr   z,.msg_done
	ld   a,e
	out  (VDP_CTRL),a
	ld   a,d
	or   #40
	out  (VDP_CTRL),a
	ld   b,(hl)			; longitud
	inc  hl
.msg_inner:
	ld   a,(hl)
	out  (VDP_DATA),a
	inc  hl
	djnz .msg_inner
	jr   .msg_outer
.msg_done:

	; --- Enciende la pantalla (R1 bit 6) ---
	ld   a,#D0			; 16K + display ON + M1 (text)
	out  (VDP_CTRL),a
	ld   a,#81			; 0x80 | 1
	out  (VDP_CTRL),a

	xor  a
	ex   af,af'			; A' = contador de heartbeat

; ############## Bucle de barrido
main_loop:
	; --- LEDs que pide el MSX2+ ---
	ld   a,(XCHG_LEDS)		; b0 = CAPS, b1 = KANA
	ld   b,a

	; Puerto C: se leen los bits altos y se devuelven tal cual. En la primera
	; pasada son los que dejo la BIOS; en las siguientes, los que escribimos
	; nosotros, que son los mismos. El latch de salida del 8255 en modo 0 se
	; puede releer, asi que esto es estable.
	in   a,(PPI_PORTC)
	and  PPIC_KEEP
	bit  0,b
	jr   nz,.caps_done		; CAPS encendido -> b6 = 0, ya lo esta tras el AND
	or   PPIC_CAPSOFF		; CAPS apagado   -> b6 = 1
.caps_done:
	ld   c,a

	ld   d,PSG_R15		; base de R15, KANA invertido
	bit  1,b
	jr   z,.kana_done
	ld   d,PSG_R15_KANA
.kana_done:

	; --- 16 filas de la matriz de teclado ---
	ld   hl,XCHG_KEYS
	ld   e,0
.row_loop:
	ld   a,c
	or   e				; nibble alto + numero de fila
	out  (PPI_PORTC),a
	nop					; asentamiento de la matriz
	nop
	in   a,(PPI_PORTB)
	ld   (hl),a
	inc  hl
	inc  e
	ld   a,e
	cp   16
	jr   nz,.row_loop

	; --- Joystick puerto 1 (R15 b6 = 0) ---
	ld   a,#0F
	out  (PSG_ADDR),a
	ld   a,d
	out  (PSG_WDATA),a
	ld   a,#0E
	out  (PSG_ADDR),a
	nop
	nop
	in   a,(PSG_RDATA)
	ld   (XCHG_JOY1),a

	; --- Joystick puerto 2 (R15 b6 = 1) ---
	ld   a,#0F
	out  (PSG_ADDR),a
	ld   a,d
	or   #40
	out  (PSG_WDATA),a
	ld   a,#0E
	out  (PSG_ADDR),a
	nop
	nop
	in   a,(PSG_RDATA)
	ld   (XCHG_JOY2),a

	; --- Heartbeat: permite distinguir "sin teclas" de "proxy muerto" ---
	ex   af,af'
	inc  a
	ld   (XCHG_BEAT),a
	ex   af,af'

	; --- Firma, al final de la pasada ---
	ld   a,PROXY_SIG
	ld   (XCHG_SIG),a

	jr   main_loop

; ############## Datos

; R0..R7. R1 arranca con display OFF; se enciende tras cargar la VRAM.
vdp_init_tab:
	.db #00		; R0: TEXT1
	.db #90		; R1: 16K + M1 (text), display OFF
	.db #00		; R2: tabla de nombres @ 0x0000
	.db #00		; R3: tabla de color, no usada en TEXT1
	.db #01		; R4: generador de patrones @ 0x0800
	.db #00		; R5: atributos de sprites, no usado
	.db #00		; R6: generador de sprites, no usado
	.db #F4		; R7: texto blanco sobre fondo azul oscuro

; Tabla de mensajes: offset en la tabla de nombres (word), longitud (byte),
; texto. Un offset 0x0000 marca el final. 40 columnas por fila.
msg_table:
	.dw #014E				; fila 8, columna 14
	.db 12
	.db "MSX2+ ASGARD"
	.dw #0198				; fila 10, columna 8
	.db 23
	.db "VIDEO AND SOUND IN HDMI"
	.dw #01F0				; fila 12, columna 16
	.db 7
	.db "FW 0.50"
	.dw #0000				; fin

; Fuente 8x8, glifos de 5 px en los bits 7..3 (TEXT1 usa celdas de 6 px, bits
; 7..2). Cada entrada es: codigo ascii + 8 bytes de patron.
;
; Juego completo: espacio, '+', '.', los diez digitos y las 26 mayusculas, para
; poder cambiar los mensajes sin tener que dibujar glifos nuevos. Cada glifo se
; sube a PATTERN + ascii*8, asi que los mensajes se escriben en ASCII directo.
; El mas alto es la 'Z' (0x5A): 0x5A*8 + 0x800 = 0x0AD0, dentro de la tabla de
; patrones (0x0800-0x0FFF).
font_data:
	.db #20, #00,#00,#00,#00,#00,#00,#00,#00	; espacio
	.db #2B, #00,#20,#20,#F8,#20,#20,#00,#00	; +
	.db #2E, #00,#00,#00,#00,#00,#60,#60,#00	; .
	.db #30, #70,#88,#98,#A8,#C8,#88,#70,#00	; 0
	.db #31, #20,#60,#20,#20,#20,#20,#70,#00	; 1
	.db #32, #70,#88,#08,#10,#20,#40,#F8,#00	; 2
	.db #33, #70,#88,#08,#30,#08,#88,#70,#00	; 3
	.db #34, #10,#30,#50,#90,#F8,#10,#10,#00	; 4
	.db #35, #F8,#80,#F0,#08,#08,#88,#70,#00	; 5
	.db #36, #30,#40,#80,#F0,#88,#88,#70,#00	; 6
	.db #37, #F8,#08,#10,#20,#40,#40,#40,#00	; 7
	.db #38, #70,#88,#88,#70,#88,#88,#70,#00	; 8
	.db #39, #70,#88,#88,#78,#08,#10,#60,#00	; 9
	.db #41, #70,#88,#88,#F8,#88,#88,#88,#00	; A
	.db #42, #F0,#88,#88,#F0,#88,#88,#F0,#00	; B
	.db #43, #70,#88,#80,#80,#80,#88,#70,#00	; C
	.db #44, #F0,#88,#88,#88,#88,#88,#F0,#00	; D
	.db #45, #F8,#80,#80,#F0,#80,#80,#F8,#00	; E
	.db #46, #F8,#80,#80,#F0,#80,#80,#80,#00	; F
	.db #47, #70,#88,#80,#B8,#88,#88,#70,#00	; G
	.db #48, #88,#88,#88,#F8,#88,#88,#88,#00	; H
	.db #49, #F8,#20,#20,#20,#20,#20,#F8,#00	; I
	.db #4A, #18,#08,#08,#08,#88,#88,#70,#00	; J
	.db #4B, #88,#90,#A0,#C0,#A0,#90,#88,#00	; K
	.db #4C, #80,#80,#80,#80,#80,#80,#F8,#00	; L
	.db #4D, #88,#D8,#A8,#88,#88,#88,#88,#00	; M
	.db #4E, #88,#C8,#A8,#98,#88,#88,#88,#00	; N
	.db #4F, #70,#88,#88,#88,#88,#88,#70,#00	; O
	.db #50, #F0,#88,#88,#F0,#80,#80,#80,#00	; P
	.db #51, #70,#88,#88,#88,#A8,#90,#68,#00	; Q
	.db #52, #F0,#88,#88,#F0,#A0,#90,#88,#00	; R
	.db #53, #70,#88,#80,#70,#08,#88,#70,#00	; S
	.db #54, #F8,#20,#20,#20,#20,#20,#20,#00	; T
	.db #55, #88,#88,#88,#88,#88,#88,#70,#00	; U
	.db #56, #88,#88,#88,#88,#88,#50,#20,#00	; V
	.db #57, #88,#88,#88,#A8,#A8,#D8,#88,#00	; W
	.db #58, #88,#88,#50,#20,#50,#88,#88,#00	; X
	.db #59, #88,#88,#50,#20,#20,#20,#20,#00	; Y
	.db #5A, #F8,#08,#10,#20,#40,#80,#F8,#00	; Z
font_count equ 39
