//`define ENABLE_V9968 //here for cosmetic reasons, real `define ENABLE_V9968 located in vdp_config.vh
`define ENABLE_SOUND
`define ENABLE_SCAN_LINES
`define ENABLE_SDCARD
`define ENABLE_CONFIG
//`define ENABLE_WIFI //fase 1.1: fuera en la version cartucho (pines 77/79 ocupados por el bus)
//`define ENABLE_CUSTOM_ROM //16kb slot 0-3, bank 1

module asgard
#(
    parameter SD_SLOT = 3
)(
    input wire reset_n,
    input wire clk_27m,
    input wire clk_54m,
    input wire clk_108m,
    input wire clk_108m_n,
    input wire s1,
    input wire s2,

    // --- ventana de intercambio, lado anfitrion --------------------------
    // La conduce slave_bus desde top.v. Es el UNICO camino por el que entra
    // algo del anfitrion: teclado, joysticks y heartbeat.
    input  wire        xchg_host_we,
    input  wire [7:0]  xchg_host_addr,
    input  wire [7:0]  xchg_host_din,
    output wire [7:0]  xchg_host_dout,

    // --- acceso del anfitrion al V9958 (espejo de escritura) --------------
    // Solo se usan mientras el MSX2+ esta retenido en reset. No hay camino de
    // vuelta: el anfitrion nunca lee de este VDP.
    input  wire [2:0]  vdp_host_mode,
    input  wire        vdp_host_csw_n,
    input  wire        vdp_host_csr_n,
    input  wire [7:0]  vdp_host_din,

   //hdmi out
    output wire [2:0] data_p,
    output wire [2:0] data_n,
    output wire clk_p,
    output wire clk_n,

    // flash
    output wire mspi_cs,
    output wire mspi_sclk,
    inout wire mspi_miso,
    inout wire mspi_mosi,

    // MicroSD
    output wire sd_sclk,
    inout wire sd_cmd,      // MOSI
    inout  wire sd_dat0,     // MISO
    output wire sd_dat3,     // 1

`ifdef ENABLE_WIFI
    //uart
    output wire uart_tx,
    input wire uart_rx,
`endif 

    //usb uart
    output wire usb_uart_tx,

    // Magic ports for SDRAM to be inferred
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n, // chip select
    output wire O_sdram_cas_n, // columns address select
    output wire O_sdram_ras_n, // row address select
    output wire O_sdram_wen_n, // write enable
    inout wire [31:0] IO_sdram_dq, // 32 bit bidirectional data bus
    output wire [10:0] O_sdram_addr, // 11 bit multiplexed address bus
    output wire [1:0] O_sdram_ba, // two banks
    output wire [3:0] O_sdram_dqm // 32/4

    //output wire SLTSL3

);

initial begin

end

    //`default_nettype none

    wire clk_enable_27m;
    wire clk_enable_54m;
    reg [1:0] cnt_clk_enable_27m;
    always @ (posedge clk_108m) begin
        cnt_clk_enable_27m <= cnt_clk_enable_27m + 1;
    end
    assign clk_enable_27m = ( cnt_clk_enable_27m == 2'b00 ) ? 1: 0;
    assign clk_enable_54m = ( cnt_clk_enable_27m[0] == 1 ) ? 1: 0;

    wire bus_clk_3m6;
    CLOCK_DIV #(
        .CLK_SRC(54.0),
        .CLK_DIV(3.58),
        .PRECISION_BITS(16)
    ) cpuclkd (
        .clk_src(clk_54m),
        .clk_div(bus_clk_3m6)
    );

    reg bus_clk_3m6_27;
    reg bus_clk_3m6_27_0;
    reg bus_clk_3m6_27_1;
    reg bus_clk_3m6_27_2;
    reg bus_clk_3m6_27_3;
    reg bus_clk_3m6_27_4;
    reg bus_clk_3m6_27_5;
    reg bus_clk_3m6_27_6;

    always @ (posedge clk_27m) begin
        bus_clk_3m6_27_6 <= bus_clk_3m6;
        bus_clk_3m6_27_5 <= bus_clk_3m6_27_6;
        bus_clk_3m6_27_4 <= bus_clk_3m6_27_5;
        bus_clk_3m6_27_3 <= bus_clk_3m6_27_4;
        bus_clk_3m6_27_2 <= bus_clk_3m6_27_3;
        bus_clk_3m6_27_1 <= bus_clk_3m6_27_2;
        bus_clk_3m6_27_0 <= bus_clk_3m6_27_1;
        bus_clk_3m6_27 <= bus_clk_3m6_27_0;
    end

    wire clk_enable_3m6_27;
    wire clk_falling_3m6_27;
    reg bus_clk_3m6_prev_27;
    always @ (posedge clk_27m) begin
        bus_clk_3m6_prev_27 <= bus_clk_3m6_27;
    end
    assign clk_enable_3m6_27 = (bus_clk_3m6_prev_27 == 0 && bus_clk_3m6_27 == 1);
    assign clk_falling_3m6_27 = (bus_clk_3m6_prev_27 == 1 && bus_clk_3m6_27 == 0);



    wire clk_enable_3m6_54;
    wire clk_falling_3m6_54;
    reg bus_clk_3m6_54;
    reg bus_clk_3m6_prev_54;
    always @ (posedge clk_54m) begin
        bus_clk_3m6_54 <= bus_clk_3m6;
        bus_clk_3m6_prev_54 <= bus_clk_3m6_54;
    end
    assign clk_enable_3m6_54 = (bus_clk_3m6_54 == 0 && bus_clk_3m6 == 1);
    assign clk_falling_3m6_54 = (bus_clk_3m6_54 == 1 && bus_clk_3m6 == 0);

    wire clk_enable_6m75_54_pre;
    wire clk_falling_6m75_54_pre;
    wire clk_enable_13m5_54_pre;
    wire clk_falling_13m5_54_pre;
    reg  video_dhclk_prev_54_pre;

    always @ (posedge clk_54m) begin
        video_dhclk_prev_54_pre <= VideoDHClk;
    end

    assign clk_enable_6m75_54_pre  = (video_dhclk_prev_54_pre == 0 && VideoDHClk == 1 && VideoDLClk == 0);
    assign clk_falling_6m75_54_pre = (video_dhclk_prev_54_pre == 0 && VideoDHClk == 1 && VideoDLClk == 1);
    assign clk_enable_13m5_54_pre = (video_dhclk_prev_54_pre == 0 && VideoDHClk == 1 && VideoDLClk == 0 || video_dhclk_prev_54_pre == 0 && VideoDHClk == 1 && VideoDLClk == 1);
    assign clk_falling_13m5_54_pre = (video_dhclk_prev_54_pre == 1 && VideoDHClk == 0 && VideoDLClk == 0 || video_dhclk_prev_54_pre == 1 && VideoDHClk == 0 && VideoDLClk == 1);

    reg clk_6m75_ff;
    wire clk_6m75_54;
    always @ (posedge clk_54m) begin
        if (clk_enable_6m75_54_pre) clk_6m75_ff <= 1;
        else if (clk_falling_6m75_54_pre ) clk_6m75_ff <= 0;
    end
    assign clk_6m75_54 = clk_6m75_ff;

    wire clk_enable_6m75_54;
    wire clk_falling_6m75_54;
    reg bus_clk_6m75_54;
    reg bus_clk_6m75_prev_54;
    always @ (posedge clk_54m) begin
        bus_clk_6m75_54 <= clk_6m75_54;
        bus_clk_6m75_prev_54 <= bus_clk_6m75_54;
    end
    assign clk_enable_6m75_54 = (bus_clk_6m75_54 == 0 && clk_6m75_54 == 1);
    assign clk_falling_6m75_54 = (bus_clk_6m75_54 == 1 && clk_6m75_54 == 0);

    wire bus_reset_n;
    assign bus_reset_n = reset_n & ~config_reset;

    //startup logic
    reg reset1_n_ff;
    reg reset2_n_ff;
    reg reset3_n_ff;
    //wire reset1_n;
    //wire reset2_n;
    wire reset3_n;

    reg [20:0] counter_reset = 0;
    reg [1:0] rst_seq;
    reg rst_step;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
            rst_step <= 0;
            counter_reset <= 0;
        end
        else begin
            rst_step <= 0;
            if ( counter_reset <= 21'b100000000000000000000 ) 
                counter_reset <= counter_reset + 1;
            else begin
                rst_step <= 1;
                counter_reset <= 0;
            end
        end
    end

    always @ (posedge clk_27m or negedge bus_reset_n ) begin
        if (bus_reset_n == 0 ) begin
            rst_seq <= 2'b00;
            reset1_n_ff <= 0;
            reset2_n_ff <= 0;
            reset3_n_ff <= 0;
        end
        else begin
            case ( rst_seq )
                2'b00: 
                    if (rst_step == 1 ) begin
                        reset1_n_ff <= 1;
                        rst_seq <= 2'b01;
                    end
                2'b01: 
                    if (rst_step == 1) begin
                        reset2_n_ff <= 1;
                        rst_seq <= 2'b10;
                    end
                2'b10:
                    if (rst_step == 1) begin
                        reset3_n_ff <= 1;
                        rst_seq <= 2'b11;
                    end
            endcase
        end
    end
    assign reset1_n = reset1_n_ff;
    assign reset2_n = reset2_n_ff;
    assign reset3_n = reset3_n_ff;

    wire [15:0] bus_addr;
    wire bus_m1_n;
    wire bus_mreq_n;
    wire bus_iorq_n;
    wire bus_rd_n;
    wire bus_wr_n;
    wire bus_rfsh_n;
    reg [7:0] cpu_din;
    wire [7:0] cpu_dout;


    always @ (posedge clk_54m) begin
        cpu_din <= 
                     ( vdp_int_csr_n == 0) ? vdp_dout :
                     ( mapper_read == 1) ? ram_dout :
                     ( mapper_reg_read == 1 ) ? mapper_reg_dout :
                     ( sram_req_r == 1 ) ? sram_dout :
                     ( exp_slot0_req_r == 1) ? ~exp_slot0  :
                     ( exp_slotx_req_r == 1) ? ~exp_slotx  :
                     ( bios_req == 1 ) ? ram_dout :
                     ( bios_missing_req == 1 ) ? bios_missing_dout :
                     ( subrom_logo_req == 1 ) ? ram_dout :
                `ifdef ENABLE_SDCARD
                     ( sd_busreq_w == 1) ? sd_cd_w :
                     ( sram_busreq_w == 1) ? sram_cd_w :
                     ( megarom_req == 1) ? ram_dout :
                     //( slot3_req_r == 1) ? 8'hff :
                 `endif
                `ifdef ENABLE_SOUND
                     //( scc_req3_r == 1 ) ? scc_dout:
                     ( megaram_req == 1 ) ? ram_dout:
                `endif
                `ifdef ENABLE_CONFIG
                     ( config_req == 1 && config_ok == 1) ? config_dout :
                     ( config_req == 1 && config_ok == 0) ? swio_dout :
                `endif
                     ( kanji_driver_req == 1 ) ? ram_dout :
                     ( kanji_data_req_r == 1 ) ? ram_dout :
                `ifdef ENABLE_WIFI
                     ( wifi_req == 1 ) ? ram_dout :
                     ( f2_req_r == 1 ) ? f2_port :
                     ( uart_req == 1 ) ? uart_dout :
                `endif
                `ifdef ENABLE_CUSTOM_ROM
                     ( custom_rom_req == 1 ) ? ram_dout :
                `endif
                     ( rtc_req_r == 1 ) ? rtc_dout :
                     ( ppi_req_r == 1 ) ? ppi_port_a :
                     ( ppi_b_req_r == 1 ) ? xchg_key_data :
                     ( ppi_c_req_r == 1 ) ? ppi_port_c :
                  `ifdef ENABLE_SOUND
                     ( psg_req_r == 1 ) ? psg_dout :
                  `endif
                     ( slot0_req_r == 1 ) ? 8'hff :
                     ( slotx_req_r == 1 ) ? 8'hff :
                      8'hff;   // sin bus externo: lo no decodificado lee 0xFF
    end


    wire cpu_clk_54;
    wire main_clk_enable;
    wire main_clk_falling;
    wire cpu_clk_enable;
    wire cpu_clk_falling;
    wire cpu_wait_n;
    wire cpu_int_n;

    // Glitch-free clock selection: switch only when both sources are stable-low.
    wire   safe_to_switch_clk = (bus_clk_3m6    == 0 && bus_clk_3m6_54    == 0) &&
                                 (clk_6m75_54    == 0 && bus_clk_6m75_54   == 0);
    reg    turbo_safe;
    reg    switch_clk_pending;
    always @ (posedge clk_54m) begin
        if (bus_reset_n == 0) begin
            turbo_safe            <= config_enable_turbo;
            switch_clk_pending <= 0;
        end else begin
            if (config_enable_turbo != turbo_safe)
                switch_clk_pending <= 1;
            if (switch_clk_pending && safe_to_switch_clk) begin
                turbo_safe            <= config_enable_turbo;
                switch_clk_pending <= 0;
            end
        end
    end

    assign cpu_clk_54     = (turbo_safe == 1) ? clk_6m75_54 : bus_clk_3m6_54;
    assign main_clk_enable  = (turbo_safe == 1) ? clk_enable_6m75_54 : clk_enable_3m6_54;
    assign main_clk_falling = (turbo_safe == 1) ? clk_falling_6m75_54 : clk_falling_3m6_54;

    assign cpu_clk_enable  = main_clk_enable;
    assign cpu_clk_falling = main_clk_falling;

    // ---- Un estado de espera por ciclo M1 (estandar MSX) ----------------
    reg m1_n_d;
    reg m1_wait_n;
    always @ (posedge clk_54m) begin
        if (bus_reset_n == 0) begin
            m1_n_d    <= 1'b1;
            m1_wait_n <= 1'b1;
        end
        else if (cpu_clk_enable == 1) begin
            m1_n_d    <= bus_m1_n;
            m1_wait_n <= ~(m1_n_d & ~bus_m1_n);   // solo el flanco de entrada en M1
        end
    end

    `ifdef ENABLE_WIFI
        assign cpu_wait_n = m1_wait_n & wait_uart;
    `else
        assign cpu_wait_n = m1_wait_n;
    `endif

    // Sin bus externo, la unica fuente de interrupcion es el V9958.
    assign cpu_int_n = vdp_int;

    G80a  #(
        .Mode    (0),     // 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
        //.T2Write (0),     //0 => WR_n active in T3, /=0 => WR_n active in T2
        .IOWait   (1)      // 0 => Single I/O cycle, 1 => Std I/O cycle
    ) cpu1 (
        // host_ready retiene la CPU hasta que el proxy del anfitrion ha hecho
        // una pasada completa, para que el menu de arranque tenga teclado.
        .RESET_n   (bus_reset_n & reset3_n & flash_idle & host_ready),
        .CLK_n     (clk_54m),
        .clk_enable (cpu_clk_enable),
        .clk_falling (cpu_clk_falling),
        .WAIT_n    (cpu_wait_n),
        .INT_n     (cpu_int_n),
        .NMI_n     (1),
        .BUSRQ_n   (1),
        .M1_n      (bus_m1_n),
        .MREQ_n    (bus_mreq_n),
        .IORQ_n    (bus_iorq_n),
        .RD_n      (bus_rd_n),
        .WR_n      (bus_wr_n),
        .RFSH_n    (bus_rfsh_n),
        .HALT_n    ( ),
        .BUSAK_n   ( ),
        .A         (bus_addr),
        .update_addr( ),
        .DI         (cpu_din),
        .DO         (cpu_dout),
        .Data_Reverse ( )
    );

    //slots decoding
    reg [7:0] ppi_port_a = 8'h00;
    wire ppi_req_r;
    wire ppi_req_w;
    wire [1:0] pri_slot;
    wire [3:0] pri_slot_num;
    wire [3:0] page_num;

    //----------------------------------------------------------------
    //-- PPI(8255) / primary-slot
    //----------------------------------------------------------------
    assign ppi_req_r = (bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign ppi_req_w = (bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0)
            ppi_port_a <= 8'h00;
        else begin
            if (ppi_req_w == 1 ) begin
                ppi_port_a <= cpu_dout;
            end
        end
    end

    //----------------------------------------------------------------
    //-- PPI(8255) / puerto B (teclado), puerto C y palabra de control
    //----------------------------------------------------------------
    wire ppi_b_req_r;
    wire ppi_c_req_r;
    wire ppi_c_req_w;
    wire ppi_ctrl_req_w;
    reg [7:0] ppi_port_c;

    assign ppi_b_req_r    = (bus_addr[7:0] == 8'ha9 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign ppi_c_req_r    = (bus_addr[7:0] == 8'haa && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign ppi_c_req_w    = (bus_addr[7:0] == 8'haa && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign ppi_ctrl_req_w = (bus_addr[7:0] == 8'hab && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

    // Puerto C: b3-b0 fila de teclado, b4 motor de cassette (1 = parado),
    // b5 escritura de cassette (1 = alto), b6 LED de CAPS (1 = apagado),
    // b7 click de teclas (1 = alto).
    // OJO: la BIOS del MSX NO escribe el puerto C directamente para el LED de
    // CAPS ni para el click, usa el comando bit set/reset por el puerto de
    // control ABh. Sin el, el LED de mayusculas no responderia.
    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0)
            ppi_port_c <= 8'hf0;   // fila 0, motor parado, CAPS apagado, click alto
        else begin
            if (ppi_c_req_w == 1) begin
                ppi_port_c <= cpu_dout;
            end
            else if (ppi_ctrl_req_w == 1) begin
                if (cpu_dout[7] == 0)
                    ppi_port_c[cpu_dout[3:1]] <= cpu_dout[0];  // bit set/reset
                else
                    ppi_port_c <= 8'h00;   // mode set: el 8255 limpia los latches
            end
        end
    end

    //----------------------------------------------------------------
    //-- Registros de intercambio con el anfitrion
    //----------------------------------------------------------------
    wire [7:0] xchg_key_data;
    wire [7:0] xchg_joy1;
    wire [7:0] xchg_joy2;
    wire [7:0] xchg_beat;
    wire       host_ready;
    // Puerto B del PSG (registro 15): b6 = seleccion de puerto de joystick,
    // b7 = LED KANA
    wire [7:0] psg_port_b;

    // El MSX2+ esta ejecutando: misma condicion que libera el RESET_n de la CPU.
    // Declarada aqui, antes de la instancia, porque se usa en su lista de puertos.
    // No hay lazo combinacional: host_ready sale de un registro de xchg_regs y
    // los LEDs solo alimentan host_dout, que no realimenta a host_ready.
    wire msx2p_running;
    assign msx2p_running = bus_reset_n & reset3_n & flash_idle & host_ready;

    // El registro 15 del PSG queda a 0x00 al resetear el nucleo, y su bit 7 es
    // el LED KANA con logica invertida: pide "encendido" desde que la CPU
    // arranca hasta que la BIOS inicializa el PSG, que es una ventana que
    // msx2p_running ya no cubre.
    //
    // 0x00 NO es un valor de operacion legitimo en ese registro: los bits 0-3
    // tienen que estar a 1 para poder leer los gatillos de los joysticks, asi
    // que ninguna BIOS lo deja a cero. Sirve como test de "aun sin inicializar".
    wire psg_initialized;
    assign psg_initialized = (psg_port_b != 8'h00);

    xchg_regs xchg1 (
        .clk        (clk_54m),
        .reset_n    (bus_reset_n),
        .key_row    (ppi_port_c[3:0]),
        .key_data   (xchg_key_data),
        .joy1       (xchg_joy1),
        .joy2       (xchg_joy2),
        .led_caps   (~ppi_port_c[6]),
        .led_kana   (psg_initialized & ~psg_port_b[7]),
        .host_ready (host_ready),
        .host_beat  (xchg_beat),

        // Lado anfitrion: lo conduce slave_bus. Va en clk_54m igual que el lado
        // del MSX2+, asi que ambos comparten dominio de reloj.
        .host_clk   (clk_54m),
        .host_we    (xchg_host_we),
        .host_addr  (xchg_host_addr),
        .host_din   (xchg_host_din),
        .host_dout  (xchg_host_dout)
    );

    //expanded slots 0 & 3
    reg [7:0] exp_slot0;
    wire [1:0] exp_slot0_page;
    wire [3:0] exp_slot0_num;
    reg exp_slot0_req_r;
    reg exp_slot0_req_w;
    wire exp_slot0_req;
    reg [7:0] exp_slotx;
    wire [1:0] exp_slotx_page;
    wire [3:0] exp_slotx_num;
    reg exp_slotx_req_r;
    reg exp_slotx_req_w;
    wire exp_slotx_req;
    wire xffff;
    reg xffh;
    reg xffl;
    always @ (posedge clk_54m) begin
        xffh <= bus_addr[15:8] == 8'hff;
        xffl <= bus_addr[7:0] == 8'hff;
        exp_slot0_req_w <= ( bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slot0_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slotx_req_w <= ( bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
        exp_slotx_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
    end
    assign exp_slot0_req = exp_slot0_req_r | exp_slot0_req_w;
    assign exp_slotx_req = exp_slotx_req_r | exp_slotx_req_w;
    assign xffff = xffh & xffl;


    // slot #0
    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0 )
            exp_slot0 <= 8'h00;
        else begin
            if (exp_slot0_req_w == 1 ) begin
                exp_slot0 <= cpu_dout;
            end
        end
    end

    // slot #3
    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0 )
            exp_slotx <= 8'h00;
        else begin
            if (exp_slotx_req_w == 1 ) begin
                exp_slotx <= cpu_dout;
            end
        end
    end

    // slots decoding
    assign pri_slot = ( bus_addr[15:14] == 2'b00) ? ppi_port_a[1:0] :
                      ( bus_addr[15:14] == 2'b01) ? ppi_port_a[3:2] :
                      ( bus_addr[15:14] == 2'b10) ? ppi_port_a[5:4] :
                                             ppi_port_a[7:6];

    assign pri_slot_num = ( pri_slot == 2'b00 ) ? 4'b0001 :
                          ( pri_slot == 2'b01 ) ? 4'b0010 :
                          ( pri_slot == 2'b10 ) ? 4'b0100 :
                                                  4'b1000;

    assign page_num = ( bus_addr[15:14] == 2'b00) ? 4'b0001 :
                      ( bus_addr[15:14] == 2'b01) ? 4'b0010 :
                      ( bus_addr[15:14] == 2'b10) ? 4'b0100 :
                                                    4'b1000;
    assign exp_slot0_page = ( bus_addr[15:14] == 2'b00) ? exp_slot0[1:0] :
                            ( bus_addr[15:14] == 2'b01) ? exp_slot0[3:2] :
                            ( bus_addr[15:14] == 2'b10) ? exp_slot0[5:4] :
                                                          exp_slot0[7:6];

    assign exp_slot0_num = ( exp_slot0_page == 2'b00 ) ? 4'b0001 :
                           ( exp_slot0_page == 2'b01 ) ? 4'b0010 :
                           ( exp_slot0_page == 2'b10 ) ? 4'b0100 :
                                                         4'b1000;

    assign exp_slotx_page = ( bus_addr[15:14] == 2'b00) ? exp_slotx[1:0] :
                            ( bus_addr[15:14] == 2'b01) ? exp_slotx[3:2] :
                            ( bus_addr[15:14] == 2'b10) ? exp_slotx[5:4] :
                                                          exp_slotx[7:6];

    assign exp_slotx_num = ( exp_slotx_page == 2'b00 ) ? 4'b0001 :
                           ( exp_slotx_page == 2'b01 ) ? 4'b0010 :
                           ( exp_slotx_page == 2'b10 ) ? 4'b0100 :
                                                         4'b1000;

    reg slot0_req_r;
    reg slotx_req_r;
    always @ (posedge clk_54m) begin
        slot0_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
        slotx_req_r <= ( ( config_enable_mapper3 == 1 || config_enable_megaram3 == 1 || config_enable_sdcard == 1 ) && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 ) ? 1 : 0;
    end

    //bios
    reg bios_req;
    //wire [7:0] bios_dout;
    always @ (posedge clk_54m) begin
        bios_req <= ( bios_missing == 0 && bus_mreq_n == 0 && bus_rd_n == 0 && bus_addr[15] == 0 && pri_slot_num[0] == 1 && exp_slot0_num[0] == 1) ? 1 : 0;
    end

    //subrom + logo
    reg subrom_logo_req;
    always @ (posedge clk_54m) begin
        subrom_logo_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[0] == 1 || page_num[1] == 1) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //kanji driver
    reg kanji_driver_req;
    always @ (posedge clk_54m) begin
        kanji_driver_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[1] == 1 || page_num[2] == 1) && pri_slot_num[0] == 1 && exp_slot0_num[1] == 1 ) ? 1 : 0;
    end

    //ram
    reg sram_req_r;
    reg sram_req_w;
    wire sram_req;
    wire [7:0] sram_dout;
    always @ (posedge clk_54m) begin
        sram_req_r <= ( config_enable_mapper12 == 0 && config_enable_mapper3 == 0 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && bus_addr[15] == 1 && exp_slotx_num[0] == 1 && xffff == 0 ) ? 1 : 0;
        sram_req_w <= ( config_enable_mapper12 == 0 && config_enable_mapper3 == 0 && bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot_num[SD_SLOT] == 1 && bus_addr[15] == 1 && exp_slotx_num[0] == 1 && xffff == 0 ) ? 1 : 0;
    end
    assign sram_req = sram_req_r | sram_req_w;

    ram8k ram1 (
        .clk (clk_54m),
        .we (sram_req_w),
        .addr (bus_addr[12:0]),
        .din (cpu_dout),
        .dout (sram_dout)
    );

    //bios_missing
    reg bios_missing_req;
    wire [7:0] bios_missing_dout;
    always @ (posedge clk_54m) begin
        bios_missing_req <= ( bios_missing == 1 && bus_mreq_n == 0 && bus_rd_n == 0 && bus_addr[15] == 0 && pri_slot_num[0] == 1 && exp_slot0_num[0] == 1) ? 1 : 0;
    end
    bios_missing bm1 (
        .clk (clk_54m),
        .addr (bus_addr[7:0]),
        .dout (bios_missing_dout)
    );


`ifdef ENABLE_WIFI

    //wifi driver
    reg wifi_req;
    always @ (posedge clk_54m) begin
        wifi_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[2] == 1 ) ? 1 : 0;
    end

    //uart
    wire uart_req;
    wire wait_uart;
    wire [7:0] uart_dout;

    assign uart_req = (bus_addr[7:1] == 7'b0000011 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // ESP ports 06-07h

    wifi uwifi (
        .clk_i      (clk_27m),
        .wait_o     (wait_uart),
        .reset_i    (bus_reset_n),
        .iorq_i     (bus_iorq_n),
        .wrt_i      (bus_wr_n),
        .rd_i       (bus_rd_n),
        .rx_i       (uart_rx),
        .tx_o       (uart_tx),
        .adr_i      (bus_addr),
        .db_i       (cpu_dout),
        .db_o       (uart_dout)
    );

`endif 

`ifdef ENABLE_CUSTOM_ROM
    reg custom_rom_req;
    always @ (posedge clk_54m) begin
        custom_rom_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[3] == 1 ) ? 1 : 0;
    end
`endif

    //rtc
    wire rtc_req_r;
    wire rtc_req_w;
    wire rtc_req;
    wire [7:0] rtc_dout;
    assign rtc_req_w = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC
    assign rtc_req_r = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC
    assign rtc_req = rtc_req_w | rtc_req_r;

    rtc rtc1(
        .clk21m(clk_27m),
        .reset(0),
        .clkena(clk_enable_3m6_27),
        .req(rtc_req_w | rtc_req_r),
        .ack(),
        .wrt(rtc_req_w),
        .adr(bus_addr),
        .dbi(rtc_dout),
        .dbo(cpu_dout)
    );

    //vdp
	wire vdp_csw_n; //VDP write request
	wire vdp_csr_n; //VDP read request	
    wire vdp_req;
    wire [7:0] vdp_dout;
    wire vdp_int;
    wire WeVdp_n;
    wire [17:0] VdpAdr;   // 18 bits (VRAM 256K)
    //wire [15:0] VrmDbi;
    wire [7:0] VrmDbo;
    wire VideoDHClk;
    wire VideoDLClk;
    reg [15:0] VrmDbi2;    // F1 VRAM contigua: par {byte@X+1, byte@X} desde memory.vram_dout
    wire [31:0] VrmDbi2_32; // F1 VRAM contigua: palabra de 32 bits desde memory.vram_dout_32 (sprite/F2)
    wire [31:0] VrmDbo32;   // F3 command cache: palabra de escritura enmascarada
    wire [3:0]  VrmWmask;
    wire        VrmWide;
    reg signed [15:0] audio_sample;   // salida de lpf_butter4_8k (filter2), entra al VDP
    // Acceso del MSX2+ al VDP
    wire vdp_int_csw_n;
    wire vdp_int_csr_n;
    assign vdp_int_csw_n = ( (bus_addr[7:3] == 5'b10011 ) && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 0:1; // I/O:98-9Fh   / VDP (V9938/V9958/V9968: 9Ch = int flags)
    assign vdp_int_csr_n = ( (bus_addr[7:3] == 5'b10011 ) && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 0:1; // I/O:98-9Fh   / VDP (V9938/V9958/V9968: 9Ch = int flags)
    assign vdp_req = ~(vdp_int_csw_n & vdp_int_csr_n);

    //----------------------------------------------------------------
    //-- De quien es el V9958 en cada momento
    //----------------------------------------------------------------
    // Mientras el MSX2+ esta retenido en reset, el V9958 sigue el bus del
    // ANFITRION: asi el HDMI muestra el arranque del anfitrion y el aviso del
    // proxy desde el primer momento, en vez de estar en negro hasta que acaba
    // el volcado de la flash y llega host_ready. Cuando la CPU arranca, el VDP
    // pasa a ser suyo.
    //
    // El anfitrion NUNCA lee de este VDP (cdi solo va al MSX2+), asi que es un
    // espejo de escritura y no hay contencion con su VDP real.
    // msx2p_running se declara arriba, junto a la instancia de xchg_regs.

    // La conmutacion solo se hace con las CUATRO senales en reposo. Si cayera a
    // mitad de un acceso se truncaria o duplicaria un ciclo del VDP y podria
    // corromper un registro. Mismo patron que safe_to_switch_clk para el turbo.
    reg vdp_owner_msx2p;
    always @ (posedge clk_54m) begin
        if (bus_reset_n == 0)
            vdp_owner_msx2p <= 1'b0;
        else if (vdp_int_csw_n == 1 && vdp_int_csr_n == 1 &&
                 vdp_host_csw_n == 1 && vdp_host_csr_n == 1)
            vdp_owner_msx2p <= msx2p_running;
    end

    wire [2:0] vdp_mode_sel;
    wire [7:0] vdp_cdo_sel;
    assign vdp_csw_n   = (vdp_owner_msx2p == 1) ? vdp_int_csw_n : vdp_host_csw_n;
    assign vdp_csr_n   = (vdp_owner_msx2p == 1) ? vdp_int_csr_n : vdp_host_csr_n;
    assign vdp_mode_sel = (vdp_owner_msx2p == 1) ? bus_addr[2:0] : vdp_host_mode;
    assign vdp_cdo_sel  = (vdp_owner_msx2p == 1) ? cpu_dout      : vdp_host_din;

    vdp_top vdp4 (
        .clk (clk_27m),
        .s1 (0),
        .clk_50 (0),
        .clk_125 (0),

        .reset_n (bus_reset_n ),
        .mode    (vdp_mode_sel),
        .csw_n   (vdp_csw_n),
        .csr_n   (vdp_csr_n),

        .int_n   (vdp_int),
        .gromclk (),
        .cpuclk  (),
        .cdi     (vdp_dout),      // solo al MSX2+: el anfitrion nunca lee de aqui
        .cdo     (vdp_cdo_sel),

        .audio_sample   (audio_sample),

        .adc_clk  (),
        .adc_cs   (),
        .adc_mosi (),
        .adc_miso (0),

        .maxspr_n    (1),
    `ifdef ENABLE_SCAN_LINES
        .scanlin_n   (~config_enable_scanlines),
    `else
        .scanlin_n   (1),
    `endif
        .gromclk_ena_n (1),
        .cpuclk_ena_n  (1),

        .WeVdp_n(WeVdp_n),
        .VdpAdr(VdpAdr),
        .VrmDbi(VrmDbi2),
        .VrmDbi32(VrmDbi2_32),   // F1: palabra de 32 bits contigua (sprite/F2)
        .VrmDbo(VrmDbo),
        .VrmDbo32(VrmDbo32),     // F3: palabra de escritura del command cache
        .VrmWmask(VrmWmask),
        .VrmWide(VrmWide),


        .VideoDHClk(VideoDHClk),
        .VideoDLClk(VideoDLClk),

        .tmds_clk_p    (clk_p),
        .tmds_clk_n    (clk_n),
        .tmds_data_p   (data_p),
        .tmds_data_n   (data_n)
    );

    //mapper
    wire mapper_read;
    wire mapper_write;
    wire mapper_req;
    reg mapper_req3;
    reg mapper_req12;
    reg [7:0] mapper_dout;
    wire [21:0] mapper_addr;
    reg [7:0] mapper_reg0;
    reg [7:0] mapper_reg1;
    reg [7:0] mapper_reg2;
    reg [7:0] mapper_reg3;
    wire mapper_reg_read;
    wire mapper_reg_write;
    wire [7:0] mapper_reg_dout;

    assign mapper_addr = (bus_addr [15:14] == 2'b00 ) ? { mapper_reg0, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b01 ) ? { mapper_reg1, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b10 ) ? { mapper_reg2, bus_addr[13:0] } :
                                                        { mapper_reg3, bus_addr[13:0] };

    always @ (posedge clk_54m) begin
        mapper_req3 <= ( bus_rfsh_n == 1 && config_enable_mapper3 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[0] == 1 && xffff == 0) ? 1 : 0;
        mapper_req12 <= ( config_enable_mapper12 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_mapper_slot ) ? 1 : 0;
    end
    assign mapper_req = mapper_req3 | mapper_req12;
    assign mapper_read = mapper_req & ~bus_rd_n;
    assign mapper_write = mapper_req & ~bus_wr_n;
    assign mapper_reg_read = ( bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0 && (bus_addr [7:2] == 6'b111111) )?1:0;
    assign mapper_reg_write = ( (bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) && (bus_addr [7:2] == 6'b111111) )?1:0;

    assign mapper_reg_dout = ( bus_addr [1:0] == 2'b00 ) ? mapper_reg0 :
                             ( bus_addr [1:0] == 2'b01 ) ? mapper_reg1 :
                             ( bus_addr [1:0] == 2'b10 ) ? mapper_reg2 : mapper_reg3;

    always @(posedge clk_54m) begin
        if (bus_reset_n == 0) begin
            mapper_reg0	<= 8'b00000011;
            mapper_reg1	<= 8'b00000010;
            mapper_reg2	<= 8'b00000001;
            mapper_reg3	<= 8'b00000000;
        end
        else if (mapper_reg_write == 1) begin
            case (bus_addr[1:0])
                2'b00: mapper_reg0 <= cpu_dout[7:0];
                2'b01: mapper_reg1 <= cpu_dout[7:0];
                2'b10: mapper_reg2 <= cpu_dout[7:0];
                2'b11: mapper_reg3 <= cpu_dout[7:0];
            endcase
        end
    end


    reg [7:0] megaram_dout;
    wire [22:0] ram_addr;
    wire ram_read;
    wire ram_write;
    wire ram_req;
    wire [7:0] ram_din;
    reg [7:0] ram_dout;
    reg ram_busy;

    //rom map, 512 KB, [18:0]
    //876 54321098 76543210
    //111 11xxxxxx xxxxxxxx free/custom, 16 KB, 0x7c000 - 0x7ffff
    //111 10xxxxxx xxxxxxxx esp8266, 16 KB, 0x78000 - 0x7bfff
    //111 0xxxxxxx xxxxxxxx kanji, 32 KB, 0x70000 - 0x77fff
    //110 11xxxxxx xxxxxxxx fm + logo + boot menu, 16 KB, 0x6c000 - 0x6ffff
    //110 10xxxxxx xxxxxxxx msx2+ subrom, 16 KB, 0x68000 - 0x6bfff
    //110 0xxxxxxx xxxxxxxx msx2+ bios, 32 KB, 0x60000 - 0x67fff
    //10x xxxxxxxx xxxxxxxx wondertang disk, 128 KB, 0x40000 - 0x5ffff
    //01x xxxxxxxx xxxxxxxx jis2, 128 KB, 0x20000 - 0x3ffff
    //00x xxxxxxxx xxxxxxxx jis1, 128 KB, 0x00000 - 0x1ffff

    //sdram map, 8 MB, [22:0]
    //2109876 54321098 76543210
    //11111xx xxxxxxxx xxxxxxxx vram, 256 KB, bank D
    //1110111 11xxxxxx xxxxxxxx custom rom, 16 KB, 0x77c000 - 0x77ffff
    //1110111 10xxxxxx xxxxxxxx esp8266, 16 KB, 0x778000 - 0x77bfff
    //1110111 0xxxxxxx xxxxxxxx kanji driver, 32 KB, 0x770000 - 0x777fff
    //1110110 11xxxxxx xxxxxxxx fm + logo + boot menu, 16 KB, 0x76c000 - 0x76ffff
    //1110110 10xxxxxx xxxxxxxx msx2+ subrom, 16 KB, 0x768000 - 0x76bfff
    //1110110 0xxxxxxx xxxxxxxx msx2+ bios, 32 KB, 0x760000 - 0x767fff
    //111010x xxxxxxxx xxxxxxxx wondertang disk, 128 KB, bank D, 0x740000 - 0x75ffff
    //11100xx xxxxxxxx xxxxxxxx kanji data jis1 + jis2, 256 KB, 0x700000 - 0x73ffff
    //10xxxxx xxxxxxxx xxxxxxxx megaram, 2 MB, bank C
    //0xxxxxx xxxxxxxx xxxxxxxx mapper, 4 MB, banks A+B

    assign ram_addr = (~flash_idle) ? rom_addr :
                        (mapper_req == 1) ? { 1'b0, mapper_addr[21:0] } :  //bank A+B
                        (bios_req == 1 ) ? { 8'b11101100, bus_addr[14:0] } : //bank D
                        (subrom_logo_req == 1 ) ? { 8'b11101101, bus_addr[14:0] } : //bank D
                `ifdef ENABLE_SDCARD
                        (megarom_req == 1 ) ? { 6'b111010, megarom_addr[16:0] } : //bank D
                `endif
                        (megaram_req == 1 ) ? { 2'b10, megaram_addr[20:0] } :  //bank C
                        (kanji_driver_req == 1 ) ? { 8'b11101110, ~bus_addr[14], bus_addr[13:0] } : //bank D
                        (kanji_data_ram_req == 1 ) ? { 5'b11100, kanji_data_ram_addr[17:0] } : //bank D
                `ifdef ENABLE_WIFI
                        (wifi_req == 1 ) ? { 9'b111011110, bus_addr[13:0] } : //bank D
                `endif
                `ifdef ENABLE_CUSTOM_ROM
                        (custom_rom_req == 1 ) ? { 9'b111011111, bus_addr[13:0] } : //bank D
                `endif
                        23'h7fffff; 
    
    assign ram_read = (~flash_idle) ? 0 : 
                      (mapper_read == 1) ? ~bus_rd_n :
                      (bios_req == 1) ? ~bus_rd_n :
                      (subrom_logo_req == 1) ? ~bus_rd_n :
                `ifdef ENABLE_SDCARD
                      (megarom_req == 1) ? ~bus_rd_n :
                `endif
                      (megaram_req == 1) ? ~bus_rd_n :
                      (kanji_driver_req == 1) ? ~bus_rd_n :
                      (kanji_data_ram_req == 1) ? ~bus_rd_n :
                `ifdef ENABLE_WIFI
                      (wifi_req == 1) ? ~bus_rd_n :
                `endif
                `ifdef ENABLE_CUSTOM_ROM
                       (custom_rom_req == 1 ) ? ~bus_rd_n :
                `endif
                      0;
    
    assign ram_write = (~flash_idle) ? rom_write : 
                      (mapper_write == 1 ) ? ~bus_wr_n :
                      (megaram_wrt == 1) ? ~bus_wr_n :
                      0; 

    assign ram_req = (~flash_idle) ? rom_write : 
                     (mapper_req == 1) ? mapper_req:
                     (bios_req == 1) ? bios_req:
                     (subrom_logo_req == 1) ? subrom_logo_req:
                `ifdef ENABLE_SDCARD
                     (megarom_req == 1) ? megarom_req:
                `endif
                     (megaram_req == 1) ? megaram_req:
                     (kanji_driver_req == 1) ? kanji_driver_req:
                     (kanji_data_ram_req == 1) ? kanji_data_ram_req:
                `ifdef ENABLE_WIFI
                     (wifi_req == 1) ? wifi_req:
                `endif
                `ifdef ENABLE_CUSTOM_ROM
                        (custom_rom_req == 1 ) ? custom_rom_req :
                `endif
                      0;

    assign ram_din = (~flash_idle) ? { rom_dout, rom_dout }  : { cpu_dout, cpu_dout };

memory_ctrl mem1 (
    .clk_54m(clk_54m),
    .clk_108m(clk_108m),
    .bus_reset_n(bus_reset_n ),
    .video_dhclk(VideoDHClk),
    .video_dlclk(VideoDLClk),

    .ram_din(ram_din),
    .ram_req(ram_req),
    .ram_write(ram_write),
    .ram_addr(ram_addr),
    .vram_din(VrmDbo),
    .vram_write(~WeVdp_n),
    .vram_addr(VdpAdr),   // 18 bits: bit17 (256K) activo, gateado por modo V9968 dentro del VDP
    // F3 command cache: escritura de palabra enmascarada desde el VDP (solo accesos del
    // cache de comandos, VrmWide=1; en modo V9958 el VDP mantiene VrmWide=0 = clasico).
    .vram_din_32(VrmDbo32),
    .vram_wmask(VrmWmask),
    .vram_wide(VrmWide),
    .bus_rfsh_n(bus_rfsh_n),

    .ram_dout(ram_dout),
    .vram_dout(VrmDbi2),          // F1: par {byte@X+1, byte@X} (16b) al VDP
    .vram_dout_32(VrmDbi2_32),    // F1: palabra de 32b al VDP (sprite/F2)
    .ram_busy(ram_busy),

    .O_sdram_clk(O_sdram_clk),
    .O_sdram_cke(O_sdram_cke),
    .O_sdram_cs_n(O_sdram_cs_n),
    .O_sdram_cas_n(O_sdram_cas_n),
    .O_sdram_ras_n(O_sdram_ras_n),
    .O_sdram_wen_n(O_sdram_wen_n),
    .IO_sdram_dq(IO_sdram_dq),
    .O_sdram_addr(O_sdram_addr),
    .O_sdram_ba(O_sdram_ba),
    .O_sdram_dqm(O_sdram_dqm)
);




`ifdef ENABLE_SOUND

    //YM219 PSG
    wire psgBdir;
    wire psgBc1;
    wire iorq_wr_n;
    wire iorq_rd_n;
    //wire [7:0] psg_dout;
    wire [7:0] psgSound1;
    wire [7:0] psgPA;
    wire [7:0] psgPB;
    reg clk_1m8;
    assign iorq_wr_n = bus_iorq_n | bus_wr_n;
    assign iorq_rd_n = bus_iorq_n | bus_rd_n;
    assign psgBdir = ( bus_addr[7:3]== 5'b10100 && iorq_wr_n == 0 && bus_addr[1]== 0 ) ?  1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bdir = 1 when writing to &HA0-&Ha1
    assign psgBc1 = ( bus_addr[7:3]== 5'b10100 && ((iorq_rd_n==0 && bus_addr[1]== 1) || (bus_addr[1]==0 && iorq_wr_n==0 && bus_addr[0]==0))) ? 1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bc1 = 1 when writing A0 or reading A2

    // Puerto A del PSG (registro 14): entrada de joystick. El proxy muestrea los
    // DOS puertos del anfitrion en cada pasada, asi que el multiplexado lo hace
    // aqui con el bit 6 del registro 15 (0 = puerto 1, 1 = puerto 2) y no hay
    // viaje de ida y vuelta en la ruta de lectura.
    assign psgPA = (psg_port_b[6] == 0) ? xchg_joy1 : xchg_joy2;
    assign psgPB = 8'hff;   // entrada del puerto B: en MSX se usa como salida, aqui en reposo

    wire [7:0] psg_dout;
    wire psg_req_r;
    assign psg_req_r = ( bus_addr[7:0] == 8'ha2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0 ) ? 1 : 0;

    wire clk_enable_1m8;
    reg clk_1m8_prev;
    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27) begin
            clk_1m8 <= ~clk_1m8;
        end
    end
    assign clk_enable_1m8 = (clk_enable_3m6_27 == 1 && clk_1m8 == 1);

    YM2149 psg1 (
        .I_DA(cpu_dout),
        .O_DA(psg_dout),
        .O_DA_OE_L(),
        .I_A9_L(0),
        .I_A8(1),
        .I_BDIR(psgBdir),
        .I_BC2(1),
        .I_BC1(psgBc1),
        .I_SEL_L(1),
        .O_AUDIO(psgSound1),
        .I_IOA(psgPA),
        .O_IOA(),
        .O_IOA_OE_L(),
        .I_IOB(psgPB),
        .O_IOB(psg_port_b),     // reg 15: b6 selecciona puerto de joystick, b7 LED KANA
        .O_IOB_OE_L(),
        
        .ENA(clk_enable_1m8), // clock enable for higher speed operation
        .RESET_L(bus_reset_n),
        .CLK(clk_27m),
        .clkHigh(clk_27m),
        .debug ()
    );


    //opll
    wire opll_req_n; 
    wire [15:0] jt2413_wav;

    assign opll_req_n = ( bus_iorq_n == 1'b0 && bus_addr[7:1] == 7'b0111110  &&  bus_wr_n == 1'b0 )  ? 1'b0 : 1'b1;    // I/O:7C-7Dh   / OPLL (YM2413)
  
    // OPLL (YM2413). Comparacion jt2413 (jtopl) vs IKAOPLL (ciclo-exacto): activa una
    // instancia y comenta la otra. Ambas exponen la misma interfaz y alimentan jt2413_wav
    // (signed 16b), asi que la mezcla de audio de abajo no cambia.
//    jt2413 opll(
//        .rst (~bus_reset_n),        // rst should be at least 6 clk&cen cycles long
//        .clk (clk_27m),        // CPU clock
//        .cen (clk_enable_3m6_27),        // optional clock enable, if not needed leave as 1'b1
//        .din (cpu_dout),
//        .addr (bus_addr[0]),
//        .cs_n (opll_req_n),
//        .wr_n (1'b0),
//        .snd (jt2413_wav),
//        .sample   ( )
//    );

    opll_ikaopll opll(
        .rst (~bus_reset_n),
        .clk (clk_27m),
        .cen (clk_enable_3m6_27),
        .din (cpu_dout),
        .addr (bus_addr[0]),
        .cs_n (opll_req_n),
        .wr_n (1'b0),
        .snd (jt2413_wav),
        .sample ( )
    );

    //scc & ghost scc
    wire [14:0] scc_wav;
    wire [7:0] scc_dout;
    wire scc_req;
    reg scc_req3;
    wire scc_req3_r;
    reg scc_req12;

    wire scc_wrt;
    
    reg x98h;
    always @ (posedge clk_54m) begin
        x98h <= ( bus_addr[15:8] == 8'h98 ) ? 1 : 0;
    end

    reg [7:0] scc_bank2;
    reg scc_enable_req3;
    reg scc_enable_req12;
    wire scc_enable_req;
    always @ (posedge clk_54m) begin
        scc_enable_req3 <= ( bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[3] == 1 ) ? 1 : 0;
        scc_enable_req12 <= ( config_enable_megaram12 == 1 && bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot == config_megaram_slot ) ? 1 : 0;
    end
    assign scc_enable_req = scc_enable_req3 | scc_enable_req12;

    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0)
            scc_bank2 <= 8'h00;
        else begin
            if (scc_enable_req == 1 ) begin
                scc_bank2 <= cpu_dout;
            end
        end
    end

    wire scc_enable;
    assign scc_enable = ( scc_bank2 == 8'h3f ) ? 1 : 0;

    always @ (posedge clk_54m) begin
        scc_req3 <= ( config_enable_megaram3 == 1 && scc_enable == 1 && x98h == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) && pri_slot == config_megaram_slot && exp_slotx_num[3] == 1  ) ? 1 : 0;
        scc_req12 <= ( config_enable_megaram12 == 1 && scc_sound_disable == 0 && scc_enable == 1 && x98h == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) && pri_slot == config_megaram_slot ) ? 1 : 0;
    end
    assign scc_req = scc_req3 | scc_req12;
    assign scc_req3_r = ( scc_req3 == 1 && bus_rd_n == 0 ) ? 1 : 0;
    assign scc_wrt = ( scc_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    scc_wave2 SccCh (
        .clk21m (clk_27m),
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_27),
        .req ( scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav)
    );

    reg scc2_req3;
    reg scc2_req12;
    wire scc2_req;
    wire scc2_wrt;
    wire megaram_req;
    wire megaram_wrt;
    wire [20:0] megaram_addr;

    always @ (posedge clk_54m) begin
        scc2_req3 <= ( config_enable_ghost_scc == 0 && config_enable_megaram3 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot && exp_slotx_num[3] == 1  && xffff == 0) ? 1 : 0;
        scc2_req12 <= ( config_enable_ghost_scc == 0 && config_enable_megaram12 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot ) ? 1 : 0;
    end
    assign scc2_req = scc2_req3 | scc2_req12;
    assign scc2_wrt = ( scc2_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    wire [1:0] map_sel;
    wire map_linear;
    wire scc_sound_disable;
    assign map_sel = Slot2Mode;
    assign map_linear = iSlt2_linear;

    megaram_scc megaram1 (
        .clk_27m (clk_54m),
        .bus_reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_rd_n (bus_rd_n),
        .bus_wr_n (bus_wr_n),
        .scc_req (scc2_req),
        .scc_wrt (scc2_wrt),
        .map_sel (map_sel),
        .map_linear (map_linear),

        .megaram_req (megaram_req),
        .megaram_wrt (megaram_wrt), 
        .megaram_addr (megaram_addr),
        .scc_sound_disable (scc_sound_disable)
    );


    //mixer
    reg signed [15:0] audio_sample_pre;
    // audio_sample se declara arriba, antes de la instancia vdp4.

    // Mezcla de audio. MISMO BALANCE y MISMOS NIVELES que el original (OPLL x1, SCC x2,
    // PSG x64 unipolar con silencio=0). Unico cambio: la suma se hace en 18 bits con signo
    // y se SATURA a signed 16b, en vez de dejar que el desbordamiento diera la vuelta
    // (wraparound = la distorsion fuerte). Ahora que el OPLL suena a buen nivel, OPLL+PSG
    // puede pasar de fondo de escala; sin esto, esos picos se corrompian.
    // (El PSG unipolar es un termino positivo; su DC lo elimina el acoplo AC del HDMI. NO se
    //  le resta offset: en silencio vale 0. Restarlo metia un DC que recortaba el OPLL.)
    wire signed [17:0] mix_opll = {{2{jt2413_wav[15]}}, jt2413_wav};   // x1  (signed)
    wire signed [17:0] mix_scc  = {{2{scc_wav[14]}}, scc_wav, 1'b0};   // x2  (signed)
    wire signed [17:0] mix_psg  = {4'b0, psgSound1, 6'b000000};        // x64 (0..16320, unipolar)
    wire signed [17:0] mix_sum  = (map_sel[0] == 0) ? (mix_opll + mix_scc + mix_psg)
                                                    : (mix_opll + mix_psg);

    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27 == 1 ) begin
            if      (mix_sum >  18'sd32767)  audio_sample_pre <= 16'h7FFF;   // satura a +full
            else if (mix_sum < -18'sd32768)  audio_sample_pre <= 16'h8000;   // satura a -full
            else                             audio_sample_pre <= mix_sum[15:0];
        end
    end

     lpf_butter4_8k #(
        .DW (16)
    ) filter2 (
        .clk (clk_27m),     // 27 MHz
        .rst_n(bus_reset_n),
        .en (1),      // fija en '1' si fs = 27 MHz
        .x_in (audio_sample_pre),
        .y_out (audio_sample)
    );

`else

    wire scc2_req;
    wire [14:0] scc2_wav;
    assign psg_port_b = 8'hff;   // sin PSG: KANA apagado, puerto de joystick 1
    wire megaram_req;
    wire [20:0] megaram_addr;
    //wire megaram_enabled;
    // audio_sample se declara arriba, antes de la instancia vdp4 (queda sin conducir
    // en esta rama, igual que antes).
    wire megaram_wrt;

`endif

    //kanji data
    wire kanji_data_req_r;
    wire kanji_data_req_w;
    wire kanji_data_req;
    wire kanji_data_ram_req;
    //reg [7:0] kanji_data_dout;
    wire [17:0] kanji_data_ram_addr;
    assign kanji_data_req_w = (bus_addr[7:2] == 6'b110110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:B4-B5h   / I/O:D8-DBh / Kanji-data
    assign kanji_data_req_r = (bus_addr[7:2] == 6'b110110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // I/O:B4-B5h   / I/O:D8-DBh / Kanji-data
    assign kanji_data_req = kanji_data_req_w | kanji_data_req_r;

    kanji kanji1(
        .clk21m(clk_27m),
        .reset(0),
        .req(kanji_data_req_w | kanji_data_req_r),
        .wrt(kanji_data_req_w),
        .adr(bus_addr),
        .dbo(cpu_dout),
        .ramreq(kanji_data_ram_req),
        .ramadr(kanji_data_ram_addr)
    );

`ifdef ENABLE_WIFI
    //f2 port
    wire f2_req_r;
    wire f2_req_w;
    wire f2_req;
    reg [7:0] f2_port;

    assign f2_req_r = (bus_addr[7:0] == 8'hf2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign f2_req_w = (bus_addr[7:0] == 8'hf2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign f2_req = f2_req_r | f2_req_w;

    always @ (posedge clk_54m) begin
        if ( bus_reset_n == 0)
            f2_port <= 8'h00;
        else begin
            if (f2_req_w == 1 ) begin
                f2_port <= cpu_dout;
            end
        end
    end
`endif

    localparam CONFIG1_DEFAULT = 8'hfb;
    localparam CONFIG2_DEFAULT = 8'h0f;

`ifdef ENABLE_CONFIG
    //config
    reg [7:0] config0_ff = 8'h00;
    reg [7:0] config1_ff = CONFIG1_DEFAULT;
    reg [7:0] config1_temp_ff;
    reg [7:0] config2_ff = CONFIG2_DEFAULT;
    reg [7:0] config2_temp_ff;
    reg [1:0] config_mapper_slot_ff = 2'b11;
    reg [1:0] config_megaram_slot_ff = 2'b11;
    reg [1:0] config_sdcard_slot_ff = 2'b11;
    reg config_enable_mapper3;
    reg config_enable_mapper12;
    wire config_enable_megaram;
    wire config_enable_megaram3;
    wire config_enable_megaram12;
    wire config_enable_ghost_scc;
    reg config_enable_sdcard;
    wire config_enable_wait;
    reg config_enable_turbo;
    reg config_reset_ff;
    reg config_flash_write_ff;
    reg config1_update;
    reg config2_update;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire config0_req;
    wire config1_req;
    wire config2_req;
    wire config_reset_req;
    wire config_reset;
    wire config_ok;
    wire [7:0] config_dout;
    wire config_req;

    always @ (posedge clk_54m) begin
        config_reset_ff <= 0;
        config_flash_write_ff <= 0;
        config1_update <= 0;
        config2_update <= 0;
        if (cpu_clk_54 == 1 ) begin
            if (config0_req == 1 ) begin
                config0_ff <= ~cpu_dout;
            end

            if (config1_req == 1 ) begin
                config1_update <= 1;
                config1_temp_ff <= cpu_dout;
            end
            if (config2_req == 1 ) begin
                config2_update <= 1;
                config2_temp_ff <= cpu_dout[5:0];
                if ( cpu_dout[6] == 1) begin
                    config_flash_write_ff <= 1;
                end
                if ( cpu_dout[7] == 1) begin
                    config_reset_ff <= 1;
                end
            end
        end
    end

    reg [2:0] ocm_slot2_prev; //bit2 = linear ,bits 1,0 = mode
    reg ocm_update;
    always @ (posedge clk_54m) begin
        ocm_update <= 0;
        if ( { iSlt2_linear, Slot2Mode } != ocm_slot2_prev ) begin
            ocm_update <= 1;
        end
    end

    reg config_init_delay = 0;
    always @ (posedge clk_54m) begin
        config_init_delay <= config_init;
        if (config_init == 1 ) begin
            if (s2 == 1) begin
                config1_ff <= CONFIG1_DEFAULT;
                config2_ff <= CONFIG2_DEFAULT;
            end
            else begin
                config1_ff <= config_sig[2];
                config2_ff <= config_sig[3];
            end
        end
        if (config1_update == 1) begin
            config1_ff <= config1_temp_ff;
        end
        if (config2_update == 1) begin
            config2_ff <= config2_temp_ff;
        end
        if (ocm_update == 1) begin
            config1_ff[7:6] <= 2'b10;
            config1_ff[1] <= 1;
            ocm_slot2_prev <= { iSlt2_linear, Slot2Mode };
        end
    end

    monostable mono (
        .pulse_in(config_reset_ff),
        .clock(clk_27m),
        .pulse_out(config_reset_req)
    );
    assign config_reset = (config_reset_req == 1 && flash_write_busy == 0) ? 1 : 0;

    assign config_ok = (config0_ff == 8'hb7) ? 1 : 0;
    assign config0_req = (bus_addr[7:0] == 8'h40 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config1_req = (config_ok == 1 && bus_addr[7:0] == 8'h41 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config2_req = (config_ok == 1 && bus_addr[7:0] == 8'h42 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config_enable_scanlines = config1_ff[3];
    //assign config_keyboard = config2_ff[4:3];
    assign config_enable_wait = config2_ff[3];
    assign config_req = (bus_addr[7:4] == 4'h4 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign config_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                         ( bus_addr[3:0] == 4'h1 ) ? config1_ff :
                         ( bus_addr[3:0] == 4'h2 ) ? config2_ff : 8'hff;


    always @ (posedge clk_54m) begin
        if (bus_reset_n == 0 || config_init_delay == 1 ) begin
            config_mapper_slot_ff <= config1_ff[5:4];
            config_enable_mapper3 <= (config1_ff[0] == 1 && config1_ff[5:4] == 2'b11);
            config_enable_mapper12 <= (config1_ff[0] == 1 && config1_ff[5:4] != 2'b11);
            //config_megaram_slot_ff <= config1_ff[7:6];
            config_enable_sdcard <= config2_ff[0];
            config_sdcard_slot_ff <= config2_ff[2:1];
            config_enable_turbo <= config2_ff[4];
        end
    end
    assign config_mapper_slot = config_mapper_slot_ff;
    assign config_megaram_slot = config1_ff[7:6];
    assign config_sdcard_slot = config_sdcard_slot_ff;
    assign config_enable_megaram = config1_ff[1];
    assign config_enable_megaram3 = (config1_ff[1] == 1 && config1_ff[7:6] == 2'b11);
    assign config_enable_megaram12 = (config1_ff[1] == 1 && config1_ff[7:6] != 2'b11 );
    assign config_enable_ghost_scc = config1_ff[2];

`else

    wire config_enable_mapper3;
    wire config_enable_mapper12;
    wire config_enable_megaram;
    wire config_enable_megaram3;
    wire config_enable_megaram12;
    wire config_enable_ghost_scc;
    wire config_enable_sdcard;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire config_reset;
    wire config_enable_wait;
    assign config_enable_mapper3 = 1;
    assign config_enable_mapper12 = 0;
    assign config_enable_megaram = 1;
    assign config_enable_megaram3 = 1;
    assign config_enable_megaram12 = 0;
    assign config_enable_ghost_scc = 0;
    assign config_enable_sdcard = 0;
    assign config_enable_scanlines = 1;
    assign config_mapper_slot = 2'b11;
    assign config_megaram_slot = 2'b11;
    assign config_sdcard_slot= 2'b11;
    assign config_reset = 0;
    assign config_enable_wait = 0;
    assign config_enable_turbo = 0;

`endif

    /// FLASH ROM LOADER - BIOS
    localparam FLASH_START_ADDRESS = 24'h200000;
    localparam RAM_START_ADDRESS = 23'h6fffff;
    localparam GOAULD_ROM_SIZE = 512*1024 + 6; //512KB + signature (AB) + config
    reg ff_rom_wr = 0;
    reg [24:0] ff_rom_addr;
    
    wire rom_write;
    wire [7:0] rom_dout;
    wire [24:0] rom_addr;
    assign rom_write = flash_busy;
    assign rom_dout = ff_rom_dout;
    assign rom_addr = ff_rom_addr;
    
    reg [31:0] ff_flash_counter;

//flash
    reg [23:0] ff_flash_addr = 24'd0;
    reg ff_flash_rd = 0;
    reg ff_flash_terminate = 0;
    reg [7:0] ff_rom_dout;
    reg flash_wait_n;
    wire[7:0] flash_dout;
    wire flash_data_ready;
    wire flash_busy;
    wire [7:0] flash_write_din;
    wire flash_write_busy;
    wire [7:0] flash_write_counter;
    wire flash_write_terminate;
    assign flash_write_din = (flash_write_counter == 8'd00) ? 8'h41 :
                             (flash_write_counter == 8'd01) ? 8'h42 :
                        `ifdef ENABLE_CONFIG
                             (flash_write_counter == 8'd02) ? config1_ff :
                             (flash_write_counter == 8'd03) ? config2_ff : 8'hff;
                        `else
                             (flash_write_counter == 8'd02) ? CONFIG1_DEFAULT :
                             (flash_write_counter == 8'd03) ? CONFIG2_DEFAULT : 8'hff;
                        `endif
    assign flash_write_terminate = (flash_write_counter == 8'd6) ? 1 : 0;

    flash # (
        .STARTUP_WAIT(1)
    )
    flash1
    (
        .clk(clk_54m),
        .reset_n(bus_reset_n),
        .SCLK(mspi_sclk),
        .CS(mspi_cs),
        .MISO(mspi_miso),
        .MOSI(mspi_mosi),
        .addr(ff_flash_addr),
        .rd(ff_flash_rd),
        .dout(flash_dout),
        .data_ready(flash_data_ready),
        .busy(flash_busy),
        .terminate(ff_flash_terminate),
        .write_enable(config_flash_write_ff),
        .write_din(flash_write_din),
        .write_busy(flash_write_busy),
        .write_counter(flash_write_counter),
        .write_terminate(flash_write_terminate),
        .write_addr(24'h280000) //24'h278000)
    );

    reg [7:0] ff_flash_state = 8'd0;
    
    localparam STATE_RESET          = 8'd0;
    localparam STATE_READ_START     = 8'd1;
    localparam STATE_READ_LOOP      = 8'd2;
    localparam STATE_IDLE           = 8'd3;
    localparam STATE_INIT1          = 8'd4;
    localparam STATE_INIT2          = 8'd5;
    localparam STATE_INIT3          = 8'd6;
    localparam STATE_INIT4          = 8'd7;
    reg [31:0] nose = 0;
    wire flash_idle;
    assign flash_idle = (ff_flash_state == STATE_IDLE ) ? 1'b1 : 1'b0;
    
    always @(posedge clk_54m) begin
    if (reset3_n == 0) begin
        ff_flash_state = STATE_RESET;
        ff_flash_rd <= 0;
        ff_rom_wr <= 0;
        nose <= 0;
    end else
        case (ff_flash_state)
    
            STATE_RESET: begin   // reset
                ff_flash_state <= STATE_READ_START;
                ff_flash_rd <= 0;
                ff_rom_wr <= 0;
                ff_flash_terminate <= 0;
            end
    
            STATE_INIT1: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= 24'h000000;
                    ff_flash_rd <= 1;
                    ff_flash_state = STATE_INIT2;
                end
            end
    
            STATE_INIT2: begin  // start read
                if (flash_busy == 1) begin
                    ff_flash_rd <= 0;
                    ff_flash_state = STATE_INIT3;
                end
            end
            
            STATE_INIT3: begin  // start read
                if (flash_busy == 0) begin
                    nose <= 0;
                    ff_flash_terminate <= 1;
                    ff_flash_state = STATE_INIT4;
                end
            end
    
            STATE_INIT4: begin  // start read
                nose <= nose + 1;
                if (nose > 10) begin
                    ff_flash_terminate <= 0;
                    ff_flash_state = STATE_READ_START;
                end
            end
    
            STATE_READ_START: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= FLASH_START_ADDRESS;
                    ff_rom_addr <= RAM_START_ADDRESS;
                    ff_flash_rd <= 1;
                    ff_flash_state = STATE_READ_LOOP;
                    ff_flash_counter <= GOAULD_ROM_SIZE;
                end
            end
    
            STATE_READ_LOOP: begin  // loop read
                if (flash_busy == 0) begin
    
                    if (ff_flash_counter > 0) begin
                        
                        if (~ff_flash_rd) begin
    
                            ff_flash_addr <= ff_flash_addr + 1;
                            ff_flash_counter <= ff_flash_counter - 1;
                            ff_flash_rd <= 1;
    
                            ff_rom_wr <= 1;
                            ff_rom_addr <= ff_rom_addr + 1;
                            ff_rom_dout <= flash_dout; 
    
                        end
                    end else begin    
                        ff_rom_wr <= 0;
                        ff_flash_rd <= 0;
                        ff_flash_state <= STATE_IDLE;
                    end
                end else begin
                    ff_rom_wr <= 0;
                    ff_flash_rd <= 0;
                end
            end
    
            STATE_IDLE: begin  // idle
                ff_flash_terminate <= 1;
            end
    
        endcase
    end

    // configuration + signature
    reg [7:0] config_sig [0:5];
    reg [2:0] last_bytes_cnt;
    reg bios_missing;
    wire new_byte;
    wire config_init;
    assign new_byte = (~ff_flash_rd && flash_busy == 0);
    assign config_init = (config_sig[0] == 8'h41 && config_sig[1] == 8'h42 && last_bytes_cnt == 3'd1) ? 1 : 0;

    always @(posedge clk_54m) begin
        if (!reset3_n) begin
            last_bytes_cnt <= 3'd0;
            config_sig[0] <= 8'd0;
            config_sig[1] <= 8'd0;
            config_sig[2] <= 8'd0;
            config_sig[3] <= 8'd0;
            config_sig[4] <= 8'd0;
            config_sig[5] <= 8'd0;
            bios_missing <= 1;
        end else begin
            if (config_init == 1) begin
                bios_missing <= 0;
            end
            if (ff_flash_counter == 32'd6)
                last_bytes_cnt <= 3'd6;
            if (new_byte && last_bytes_cnt != 3'd0) begin
                case (last_bytes_cnt)
                    3'd6: config_sig[0] <= flash_dout;
                    3'd5: config_sig[1] <= flash_dout;
                    3'd4: config_sig[2] <= flash_dout;
                    3'd3: config_sig[3] <= flash_dout;
                    3'd2: config_sig[4] <= flash_dout;
                    3'd1: config_sig[5] <= flash_dout;
                endcase
                last_bytes_cnt <= last_bytes_cnt - 1;
            end
        end
    end


`ifdef ENABLE_SDCARD

    
   
    //megarom
    reg megarom_req;
    wire [16:0] megarom_addr;
    reg [2:0] megarom_page_ff;
    reg megarom_page_req;
    wire [2:0] megarom_page;

    always @ (posedge clk_54m) begin
        megarom_req <=     ( config_enable_sdcard == 1 && bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (page_num[1] == 1 || page_num[2] == 1) ) ? 1 : 0;
        megarom_page_req <= ( bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_wr_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && bus_addr == 16'h6000 ) ? 1 : 0;
    end
    assign megarom_page = megarom_page_ff;
    assign megarom_addr = { megarom_page, bus_addr[13:0] };

    always @(posedge clk_54m) begin
        if (bus_reset_n == 0) begin
           megarom_page_ff <= 3'b0;
        end 
        else begin
            if (megarom_page_req == 1) begin
                megarom_page_ff <= cpu_dout[2:0]; // select page
            end
        end
    end


    //sd card
    localparam int SDC_SDATA		=  16'h7C00;		 	// rw: 7C00h-7Dff - sector transfer area
    localparam int SDC_ENABLE  	    =  16'h7E00;		    // wo: 1: enable SDC register, 0: disable
    localparam int SDC_CMD			=  SDC_ENABLE+1; 		// wo: cmd to SDC fpga: 1=sd read, 2=sd write
    localparam int SDC_STATUS		=  SDC_CMD+1;	 		// ro: SDC status bits
    localparam int SDC_SADDR		=  SDC_STATUS+1;	 	// wo: 4 bytes: sector addr for read/write
    localparam int SDC_C_SIZE  	    =  SDC_SADDR+4;			// ro: 3 bytes: device size blocks
    localparam int SDC_C_SIZE_MULT	=  SDC_C_SIZE+3;		// ro: 3 bits size multiplier
    localparam int SDC_RD_BL_LEN	=  SDC_C_SIZE_MULT+1;	// ro: 4 bits block length
    localparam int SDC_CTYPE		=  SDC_RD_BL_LEN+1;		// ro: SDC Card type: 0=unknown, 1=SDv1, 2=SDv2, 3=SDHCv2 
    localparam int SDC_MID		    =  SDC_CTYPE+1;		    // ro: manufacture ID: 8 bits unsigned
    localparam int SDC_OID		    =  SDC_MID+1;		    // ro: oem id: 2 character
    localparam int SDC_PNM		    =  SDC_OID+2;		    // ro: product name: 5 character
    localparam int SDC_PSN		    =  SDC_PNM+5;		    // ro: serial number: 32 bits unsigned
    localparam int SCC_ENABLE       =  16'h7E80;            // wo: enable disable SCC+
    localparam int SDC_END          =  16'h7EFF; 
    
    wire [8:0] sram_addr_w;
    reg ff_sram_we = 0;
    reg ff_sd_en = 0;
    reg sram_cs_w;
    wire sram_busreq_w;
    wire [7:0] sram_cd_w;
    
    wire [3:0] sd_card_stat_w;
    wire [1:0] sd_card_type_w;
    reg ff_sd_rstart;
    reg ff_sd_init;
    reg [31:0] ff_sd_sector;
    wire sd_busy_w;
    wire sd_done_w;
    wire sd_outen_w;
    wire [8:0] sd_outaddr_w;
    wire [7:0] sd_outbyte_w;
    reg ff_sd_wstart;
    wire [7:0] sd_inbyte_w;
    
    wire [21:0] sd_c_size_w;
    wire [2:0] sd_c_size_mult_w;
    wire [3:0] sd_read_bl_len_w;
    
    wire [7:0] sd_mid_w;
    wire [15:0] sd_oid_w;
    wire [39:0] sd_pnm_w;
    wire [31:0] sd_psn_w;
    wire sd_crc_error_w;
    wire sd_timeout_error_w;
    always @ (posedge clk_54m) begin
        sram_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n == 1 && bus_m1_n == 1 && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && ( bus_addr >= SDC_SDATA && bus_addr < SDC_ENABLE) ? 1 : 0;
    end
    assign sram_busreq_w = sram_cs_w && ~bus_rd_n;

    dpram#(
        .widthad_a(9),
        .width_a(8)
    ) dpram1 (
        .clock_a(clk_54m),
        .wren_a(cpu_clk_54 && sram_cs_w && ~bus_wr_n),
        .rden_a(cpu_clk_54 && sram_cs_w && ~bus_rd_n),
        .address_a(bus_addr[8:0]),
        .data_a(cpu_dout),
        .q_a(sram_cd_w),
    
        .clock_b(clk_54m),
        .wren_b(ff_sd_rstart && sd_outen_w),
        .rden_b(ff_sd_wstart && sd_outen_w),
        .address_b(sd_outaddr_w),
        .data_b(sd_outbyte_w),
        .q_b(sd_inbyte_w)
    );
    
    sd_reader #(
        .CLK_DIV(3'd3),
        .SIMULATE(0)
    ) sd1 (
        .rstn(bus_reset_n),
        .clk(clk_54m),
        .sdclk(sd_sclk),
        .sdcmd(sd_cmd),
        .sddat0(sd_dat0),                  
        .card_stat(sd_card_stat_w),        // show the sdcard initialize status
        .card_type(sd_card_type_w),        // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
        .rstart(ff_sd_rstart), 
        .rsector(ff_sd_sector),
        .rbusy(sd_busy_w),
        .rdone(sd_done_w),
        .outen(sd_outen_w),                // when outen=1, a byte of sector content is read out from outbyte
        .outaddr(sd_outaddr_w),            // outaddr from 0 to 511, because the sector size is 512
        .outbyte(sd_outbyte_w),            // a byte of sector content
        .wstart(ff_sd_wstart), 
        .inbyte(sd_inbyte_w),
        .c_size(sd_c_size_w),
        .c_size_mult(sd_c_size_mult_w),
        .read_bl_len(sd_read_bl_len_w),
        .mid(sd_mid_w),
        .oid(sd_oid_w),
        .pnm(sd_pnm_w),
        .psn(sd_psn_w),
        .crc_error(sd_crc_error_w),
        .timeout_error(sd_timeout_error_w),
        .init(ff_sd_init)
    );
    
    // DAT1 y DAT2 ya no son pines de la FPGA: sus patillas (85 y 80) las ocupa
    // el bus de direcciones del cartucho. En modo SD de 1 bit la tarjeta no las
    // conduce y la placa lleva pullups, asi que basta con eso.
    assign sd_dat3 = 1; // hay que mantener DAT3 a 1 para que la tarjeta no entre en modo SPI
    
    
    always @(posedge clk_54m) begin
        if (~bus_reset_n) begin
            ff_sd_en <= 0;
        end else begin
            if (config_enable_sdcard == 1 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && bus_addr == SDC_ENABLE && ~bus_wr_n && bus_iorq_n && bus_m1_n) 
                ff_sd_en <= cpu_dout[0];
        end
    end
    
    reg sd_cs_w;
    always @ (posedge clk_54m) begin
        sd_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n && bus_m1_n && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (bus_addr >= SDC_ENABLE && bus_addr <= SDC_END) ? 1 : 0;
    end
    wire sd_busreq_w;
    assign sd_busreq_w = sd_cs_w && ~bus_rd_n;
    reg [7:0] ff_sd_cd;
    wire [7:0] sd_cd_w;
    assign sd_cd_w = ff_sd_cd;
    
    always @(posedge clk_54m) begin
        if (~bus_reset_n) begin
            ff_sd_rstart <= '0;
            ff_sd_wstart <= '0;
            ff_sd_init <= '0;
        end else begin
            if (sd_done_w) begin
                ff_sd_rstart <= '0;
                ff_sd_wstart <= '0;
            end
    
            if (sd_cs_w) begin
                if (~bus_wr_n) begin
                    case(bus_addr) 
                        SDC_CMD: begin
                            ff_sd_rstart <= ff_sd_rstart | cpu_dout[0];
                            ff_sd_wstart <= ff_sd_wstart | cpu_dout[1];
                            ff_sd_init   <= ff_sd_init   | cpu_dout[7];
                            //ff_sms_init  <= ff_sms_init  | cdin_w[7];
                        end
                        SDC_SADDR+0:    ff_sd_sector[ 7: 0] <= cpu_dout;
                        SDC_SADDR+1:    ff_sd_sector[15: 8] <= cpu_dout;
                        SDC_SADDR+2:    ff_sd_sector[23:16] <= cpu_dout;
                        SDC_SADDR+3:    ff_sd_sector[31:24] <= cpu_dout;
                    endcase
                end else
                if (~bus_rd_n) begin
                    case(bus_addr) 
                        SDC_ENABLE:     ff_sd_cd <= { 7'b0, ff_sd_en };
                        SDC_STATUS:     ff_sd_cd <= { sd_busy_w, 5'b0, sd_timeout_error_w, sd_crc_error_w };
                        SDC_C_SIZE+0:   ff_sd_cd <= sd_c_size_w[7:0];
                        SDC_C_SIZE+1:   ff_sd_cd <= sd_c_size_w[15:8];
                        SDC_C_SIZE+2:   ff_sd_cd <= { 2'b0, sd_c_size_w[21:16] };
                        SDC_C_SIZE_MULT:ff_sd_cd <= { 5'b0, sd_c_size_mult_w };
                        SDC_RD_BL_LEN:  ff_sd_cd <= { 4'b0, sd_read_bl_len_w };
                        SDC_CTYPE:      ff_sd_cd <= { 6'b0, sd_card_type_w };
                        SDC_MID:        ff_sd_cd <= sd_mid_w;
                        SDC_OID+0:      ff_sd_cd <= sd_oid_w[7:0];
                        SDC_OID+1:      ff_sd_cd <= sd_oid_w[15:8];
                        SDC_PNM+0:      ff_sd_cd <= sd_pnm_w[7:0];
                        SDC_PNM+1:      ff_sd_cd <= sd_pnm_w[15:8];
                        SDC_PNM+2:      ff_sd_cd <= sd_pnm_w[23:16];
                        SDC_PNM+3:      ff_sd_cd <= sd_pnm_w[31:24];
                        SDC_PNM+4:      ff_sd_cd <= sd_pnm_w[39:32];
                        SDC_PSN+0:      ff_sd_cd <= sd_psn_w[7:0];
                        SDC_PSN+1:      ff_sd_cd <= sd_psn_w[15:8];
                        SDC_PSN+2:      ff_sd_cd <= sd_psn_w[23:16];
                        SDC_PSN+3:      ff_sd_cd <= sd_psn_w[31:24];
                        default:        ff_sd_cd <= '1;
                    endcase
                end
            end
        end
    end

`else

    wire sd_busreq_w;
    wire sram_busreq_w;
    wire megarom_req;
    wire megarom_page_req;
    wire sram_cs_w;
    wire sd_cs_w;

`endif

    // Switched I/O ports
    reg [1:0] Slot2Mode;
    //wire  swio_req;
    wire [7:0] io42_id212;
    wire iSlt2_linear;
    wire swio_req;
    wire swio_req_r;
    wire swio_req_w;
    wire [7:0] swio_dout;
    assign swio_req_r = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign swio_req_w = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign swio_req = swio_req_r | swio_req_w;

    switched_io_ports ocm_ports (
            .clk21m        (clk_27m),
            .reset         (~bus_reset_n) ,
            .power_on_reset(1),
            .req           (swio_req   ),
            .ack           (           ),
            .wrt           (~bus_wr_n ),
            .adr           (bus_addr   ),
            .dbi           (swio_dout     ),
            .dbo           (cpu_dout      ),
            .io42_id212    (io42_id212    ),
            .iSlt2_linear  (iSlt2_linear  )
        );

    // virtual DIP-SW assignment (2/2)
    always @ ( posedge clk_27m )  begin
        Slot2Mode[1]    <=  io42_id212[4];
        Slot2Mode[0]    <=  io42_id212[5];
    end

    wire send;
    monostable mono2 (
        .pulse_in(s2),
        .clock(clk_27m),
        .pulse_out(send)
    );

//    msx2p_debug debug1 (
//        .clk_27m(clk_27m),
//        .clk (clk_27m),
//        .reset_n ( bus_reset_n ),
//        .clk_enable (clk_enable_3m6_27),
//        .bus_addr(bus_addr),
//        .bus_data(cpu_din),
//        .bus_iorq_n(bus_iorq_n),
//        .bus_mreq_n(bus_mreq_n),
//        .bus_wr_n(bus_wr_n),
//        .send(send),
//        .uart_tx(usb_uart_tx),
//        .boot_ok( )
//    );

    timing_debug debug1(
        .clk_27m(clk_27m),
        .clk_108m(clk_108m),
        .reset_n(bus_reset_n),
        .bus_iorq_n(bus_iorq_n),
        .bus_mreq_n(bus_mreq_n),
        .bus_rd_n(bus_rd_n),
        .bus_wr_n(bus_wr_n),
        .send(send),
        .uart_tx(usb_uart_tx)
    );


endmodule