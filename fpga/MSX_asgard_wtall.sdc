//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//
// Version B del proyecto, placa WonderTANG 101c. Derivado de MSX_asgard.sdc:
// toda la parte jerarquica (asgard1/...) es identica porque el diseno interno
// no cambia; solo difieren los nombres de los puertos del bus del anfitrion.

// ============================== RELOJES =====================================
create_clock -name clock_27m -period 37.037 -waveform {0 18.518} [get_nets {asgard1/clk_27m}] -add
create_generated_clock -name clock_54m        -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -multiply_by 2 [get_nets {asgard1/clk_54m}] -add
create_generated_clock -name clock_108m       -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -multiply_by 4 [get_ports {O_sdram_clk}] -add
create_generated_clock -name clock_VideoDHClk -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -divide_by 2 [get_nets {asgard1/VideoDHClk}] -add
create_generated_clock -name clock_VideoDLClk -source [get_nets {asgard1/clk_27m}] -master_clock clock_27m -divide_by 4 [get_nets {asgard1/VideoDLClk}] -add

// Relojes ficticios: no son relojes reales, sacan del analisis logica que
// avanza a ritmo de enable y no de flanco.
create_clock -name clock_reset     -period 277.778 -waveform {0 138.889} [get_nets {asgard1/bus_reset_n}] -add
create_clock -name clock_audio     -period 277.778 -waveform {0 138.889} [get_nets {asgard1/vdp4/clk_audio}] -add
create_clock -name clock_env_reset -period 277.778 -waveform {0 138.889} [get_nets {asgard1/psg1/env_reset}] -add

set_clock_groups -asynchronous -group [get_clocks {clock_108m clock_54m clock_VideoDHClk clock_VideoDLClk clock_27m}] -group [get_clocks {clock_reset}] -group [get_clocks {clock_env_reset}] -group [get_clocks {clock_audio}]

// ==================== CDC de reset hacia los serializadores =================
// bus_reset_n cruza al dominio de 135 MHz de los serializadores HDMI sin
// sincronizar. Es asincrono por naturaleza, asi que el analisis no aplica.
set_false_path -to [get_pins {asgard1/vdp4/serializer/gwSer?/RESET}]

// ============================== RTC =========================================
// Solo captura con clk_enable_3m6_27: uno de cada ~7.5 ciclos de 27 MHz.
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/rtc1/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/rtc1/?*?/CE}] -hold  -end 1

// ======================== switched_io_ports (OCM) ===========================
// Configuracion de maquina: se captura en clk_27m y solo con el decodificado de
// I/O activo, o sea durante un ciclo completo del Z80.
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/D}]  -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/D}]  -hold  -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {asgard1/ocm_ports/?*?/CE}] -hold  -end 1

// ========================= nucleo del Z80 ===================================
// El T80 tiene CLK_n = clk_54m pero solo avanza con clk_enable: una vez cada
// ~15 ciclos a 3.58 MHz, cada 8 en turbo. -end 2 es muy conservador.
// El -from exige que el origen tambien este DENTRO de cpu1, para que los
// caminos que entran desde la red de clock enables (que si conmuta a 54 MHz)
// se sigan comprobando.
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/?*?/?*}]         -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -setup -end 2
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -setup -end 2

set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/DO?*}] -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/?*?/Q}]       -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/?*?/?*}]         -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/u0/?*?/?*}]      -hold -end 1
set_multicycle_path -from [get_pins {asgard1/cpu1/u0/?*?/Q}]    -to [get_pins {asgard1/cpu1/u0/Regs/?*?/?*}] -hold -end 1

// ======================= captura de cpu_din =================================
// Cota deliberadamente apretada, muy por debajo del presupuesto real (la CPU no
// mira cpu_din hasta ~15 periodos despues del estrobo). Suele aparecer un
// negativo de decimas: es un AVISO de que la ruta esta al limite, no una
// violacion fisica, y mantiene al router trabajandola. NO subirla para "cerrar
// el timing": se perderia esa señal.
set_max_delay -to [get_pins {asgard1/cpu_din_*/D}] 18.1

// ================= estrobos del Z80 -> controlador de memoria ===============
// Clase F->R: RD/WR/MREQ del G80a son registros de flanco de bajada y mem1
// captura en subida, asi que el STA aplica media ventana cuando la señal es
// estable varios estados T. Un periodo completo es la cota honesta.
set_max_delay -from [get_pins {asgard1/cpu1/?*?/Q}] -to [get_pins {asgard1/mem1/?*?/D}]  18.5
set_max_delay -from [get_pins {asgard1/cpu1/?*?/Q}] -to [get_pins {asgard1/mem1/?*?/CE}] 18.5

// ==================== entradas del slot del anfitrion =======================
// Asincronas y sin reloj de referencia. En esta placa la direccion y el control
// lento llegan multiplexados por mp[7:0]; el mp_debouncer los registra en el
// dominio de 108 MHz y de ahi pasan a 54, que es un cruce SINCRONO (54 sale de
// dividir 108) y queda cubierto por el grupo de relojes de arriba.
set_false_path -from [get_ports {mp[*] cd[*] rd_n_in wr_n_in sltsl_n_in}]

// ==================== salidas del demux: 108 MHz -> 54 MHz ==================
// No hace falta ninguna excepcion. El unico camino que daba problemas era el
// reset (latched[20] = MP_RESET_IN_N), por alimentar una red de fanout enorme
// cruzando de 108 a 54 con solo 9.26 ns de ventana; se ha resuelto en el RTL
// reregistrandolo en 54 dentro de top_wt101c.v.
//
// La direccion y MREQ/IORQ tambien cruzan, pero van a los registros de entrada
// de slave_bus, con fanout pequeño, y cierran sin ayuda.

// ========================= SONDAS DE DIAGNOSTICO ============================
report_timing -setup -to [get_pins {asgard1/cpu_din_*/D}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/mem1/sdram_addr_*/D}] -max_paths 16
report_timing -setup -from [get_clocks {clock_54m}] -to [get_pins {asgard1/cpu1/?*?/D}] -max_paths 24
report_timing -setup -to [get_pins {asgard1/cpu1/?*?/CE}] -max_paths 24
report_timing -hold  -to [get_pins {asgard1/cpu1/?*?/CE}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/ff_sd_cd_*/D}] -max_paths 8
report_timing -setup -to [get_pins {slave1/?*?/D}] -max_paths 12
report_timing -setup -to [get_pins {asgard1/xchg1/?*?/D}] -max_paths 12
// especifico de esta placa: el paso del demux (108 MHz) al esclavo (54 MHz)
report_timing -setup -from [get_pins {mp_deb/?*?/Q}] -to [get_pins {slave1/?*?/D}] -max_paths 16

report_timing -setup -max_paths 400 -max_common_paths 1
