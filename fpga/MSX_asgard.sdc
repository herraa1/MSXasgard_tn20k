//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//
// Reescrito desde cero sobre Gowin 1.9.11.03, que cierra sin necesidad de las
// relajaciones que hacian falta con la version anterior. Ver al final la lista
// de las que NO hay que reponer y por que.

// ============================== RELOJES =====================================
create_clock -name clock_27m -period 37.037 -waveform {0 18.518} [get_nets {asgard1/clk_27m}] -add
create_generated_clock -name clock_54m        -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -multiply_by 2 [get_nets {asgard1/clk_54m}] -add
create_generated_clock -name clock_108m       -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -multiply_by 4 [get_ports {O_sdram_clk}] -add
create_generated_clock -name clock_VideoDHClk -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -divide_by 2 [get_nets {asgard1/VideoDHClk}] -add
create_generated_clock -name clock_VideoDLClk -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -divide_by 4 [get_nets {asgard1/VideoDLClk}] -add

// Relojes ficticios: no son relojes reales, existen para sacar del analisis
// logica que avanza a ritmo de enable y no de flanco.
create_clock -name clock_reset     -period 277.778 -waveform {0 138.889} [get_nets {asgard1/bus_reset_n}] -add
create_clock -name clock_audio     -period 277.778 -waveform {0 138.889} [get_nets {asgard1/vdp4/clk_audio}] -add
create_clock -name clock_env_reset -period 277.778 -waveform {0 138.889} [get_nets {asgard1/psg1/env_reset}] -add

set_clock_groups -asynchronous -group [get_clocks {clock_108m clock_54m clock_VideoDHClk clock_VideoDLClk clock_27m}] -group [get_clocks {clock_reset}] -group [get_clocks {clock_env_reset}] -group [get_clocks {clock_audio}]

// ==================== CDC de reset hacia los serializadores =================
// bus_reset_n cruza al dominio de 135 MHz de los serializadores HDMI sin
// sincronizar. Es la peor ruta del diseno (-3.5 ns) y nunca estuvo constreñida.
// Es asincrona por naturaleza, asi que el analisis no aplica.
//
// OJO: esto le dice la verdad al STA pero NO elimina el peligro fisico. Si al
// soltar el reset unos biestables arrancan un ciclo antes que otros, se puede
// corromper una secuencia en marcha. La solucion de fondo es un sincronizador
// de reset por dominio (asertar asincrono, liberar sincrono).
set_false_path -to [get_pins {asgard1/vdp4/serializer/gwSer?/RESET}]

// ============================== RTC =========================================
// Dispositivo de baja prioridad que solo captura con clk_enable_3m6_27, o sea
// uno de cada ~7.5 ciclos de 27 MHz. Antes estaba con set_false_path; el
// multicycle mantiene una comprobacion real en vez de anular la ruta.
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/rtc1/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/rtc1/?*?/CE}] -hold  -end 1

// ======================== switched_io_ports (OCM) ===========================
// Configuracion de maquina: se captura en clk_27m y solo cuando el decodificado
// de I/O esta activo, o sea durante un ciclo completo del Z80. Mismo caso que
// el RTC, y como el estaba antes con set_false_path.
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/D}]  -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/D}]  -hold  -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/CE}] -hold  -end 1

// ========================= nucleo del Z80 ===================================
// El T80 tiene CLK_n = clk_54m pero solo avanza cuando clk_enable esta alto:
// una vez cada ~15 ciclos a 3.58 MHz, cada 8 en turbo a 6.75. Todo camino cuya
// CAPTURA esta gateada por clk_enable dispone de ese presupuesto, no de uno,
// asi que -end 2 es muy conservador.
//
// La diferencia con el blanket anterior esta en el -from: al exigir que el
// origen tambien este DENTRO de cpu1, los caminos que entran desde la red de
// clock enables (que vive en asgard1 y si conmuta a 54 MHz, con requisito real
// de un ciclo) quedan fuera y se siguen comprobando.
//
// Origen real de 58 de las 60 rutas negativas: IStatus_*, que es la ROM en la
// que Gowin empaqueta t80_mcode, el decodificador de microcodigo.
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2

set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1

// Los biestables del nivel u0 (BusB, IStatus...) no los cubrian los patrones de
// arriba: cpu1/?*?/Q solo casa un nivel de jerarquia y u0/?*?/DO?* solo casa
// salidas de memoria. Mismo razonamiento, misma cota.
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -hold -end 1

// ======================= captura de cpu_din =================================
// cpu_din captura en clk_54m sin enable, pero el dato que recoge no lo mira la
// CPU hasta varios T-states despues del estrobo: con clock enables a 3.58 MHz
// son ~15 periodos de clk_54m, 8 en turbo. Ese es el presupuesto REAL.
//
// Se deja a 18.1 ns A PROPOSITO, muy por debajo de ese presupuesto. El retardo
// medido ronda los 18.26, asi que suele aparecer un negativo de decimas: es un
// AVISO de que la ruta esta al limite, no una violacion fisica. Mantener la cota
// apretada hace ademas que el router siga trabajandola en vez de darla por buena
// y parar. No subirla para "cerrar el timing": se perderia esa senal.
//
// Sin -from: el microcodigo tambien alimenta este mux, y el patron cpu1/?*/Q
// dejaba esas rutas fuera.
set_max_delay -to [get_pins {asgard1/cpu_din_*/D}] 18.1

// ================= estrobos del Z80 -> controlador de memoria ===============
// Misma clase F->R que cpu_din: RD/WR/MREQ del G80a son registros de flanco de
// bajada y mem1 captura en subida, asi que el STA aplica media ventana (9.26 ns)
// cuando bus_rd_n es estable varios estados T. Si el controlador ve la peticion
// un ciclo mas tarde, el acceso a SDRAM se retrasa 18.5 ns, muy dentro del ciclo
// de CPU. Aqui basta con un periodo completo: hay ~8 ns de holgura.
set_max_delay -from [get_pins {asgard1/cpu1/?*?/Q}] -to [get_pins {asgard1/mem1/?*?/D}]  18.5
set_max_delay -from [get_pins {asgard1/cpu1/?*?/Q}] -to [get_pins {asgard1/mem1/?*?/CE}] 18.5

// ==================== entradas del slot del anfitrion =======================
// Asincronas y sin reloj de referencia. slave_bus las registra de inmediato en
// clk_54m y son estables durante todo el ciclo del Z80 (~500 ns).
set_false_path -from [get_ports {ex_bus_*}]

// ==================== LO QUE NO HAY QUE REPONER =============================
// Estas restricciones existian en la version anterior del SDC. Con el
// compilador actual sus familias cierran solas: NINGUNA aparece entre las rutas
// negativas. Ademas dos de ellas eran activamente nocivas.
//
// 1) set_max_delay mem1/vram_dout_* -> vdp4/u_v9958/U_SPRITE 18.0
//    Sustituia a un multicycle -end 2 que era INSOUND: relajaba a ~46 ns cuando
//    el presupuesto real desde el primer commit son 18.5, y producia sprites
//    fantasma deterministas (confirmado en HW 2026-07).
//
// 2) set_multicycle_path sobre ff_sd_cd_*/D y ff_sd_sector_*/CE
//    Enmascaraba una posible violacion en la transicion busy->done del
//    controlador SD -> estado mal leido -> cuelgues aleatorios de la SD.
//
// 3) set_max_delay -to mem1/sdram_addr_*/D 16.6  ("molienda forzada")
//    Cota inalcanzable a proposito para que el router no parase pronto, porque
//    se observo que el diseno arrancaba SOLO cuando el timing no cerraba. La
//    sospecha escrita entonces era skew de liberacion del reset asincrono, y
//    encaja con lo que se ve ahora: bus_reset_n va por red LW (secundaria,
//    saturada al 100%) mientras PRIMARY tiene huecos libres, y la peor ruta del
//    diseno es de reset. Si vuelve la pantalla negra, atacar el reset antes que
//    reponer esta cota.
//
// 4) set_multicycle_path blanket sobre cpu1/?*?/D, /CE y cpu1/u0/*
//    Relajaba TODO el nucleo Z80 a 2 ciclos, incluidos los CE, cuya red de
//    clock-enables conmuta a 54 MHz y tiene requisito real de 1 ciclo.

// ========================= SONDAS DE DIAGNOSTICO ============================
// Solo informan, no restringen: vuelcan el retardo real de las familias que las
// constraints relajan y que por eso no aparecen en el listado general.
report_timing -setup -to [get_pins {asgard1/cpu_din_*/D}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/mem1/sdram_addr_*/D}] -max_paths 16
report_timing -setup -from [get_clocks {clock_54m}] -to [get_pins {asgard1/cpu1/?*?/D}] -max_paths 24
report_timing -setup -to [get_pins {asgard1/cpu1/?*?/CE}] -max_paths 24
report_timing -hold  -to [get_pins {asgard1/cpu1/?*?/CE}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/mem1/vram_dout_*/Q}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/ff_sd_cd_*/D}] -max_paths 8
// nuevos: esclavo del bus del anfitrion y ventana de intercambio
report_timing -setup -to [get_pins {slave1/?*?/D}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/xchg1/?*?/D}] -max_paths 12

report_timing -setup -max_paths 400 -max_common_paths 1
