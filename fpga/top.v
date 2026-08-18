//`define ENABLE_WIFI //fase 1.1: fuera en la version cartucho (pines 77/79 ocupados por el bus)

module top
(
    input wire ex_clk_27m,
    input wire s1,
    input wire s2,

    input wire ex_bus_reset_n,
    input wire ex_bus_clk_3m6,

    input wire [15:0] ex_bus_addr,
    inout wire [7:0] ex_bus_data,

    input wire ex_bus_mreq_n,
    input wire ex_bus_iorq_n,
    input wire ex_bus_rd_n,
    input wire ex_bus_wr_n,
    input wire ex_bus_sltsl_n,

    output wire ex_bus_data_reverse_n,

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

    //clocks
    wire clk_108m;
    wire clk_108m_n;
    CLK_108P clk_main (
        .clkout(clk_108m), //output clkout
        .lock(), //output lock
        .clkoutp(clk_108m_n), //output clkoutp
        .reset(0), //input reset
        .clkin(ex_clk_27m) //input clkin
    );

    wire clk_54m;
    Gowin_CLKDIV2 div2(
        .clkout(clk_54m), //output clkout
        .hclkin(clk_108m), //input hclkin
        .resetn(1) //input resetn
    );

    wire clk_27m;
    Gowin_CLKDIV div4(
        .clkout(clk_27m), //output clkout
        .hclkin(clk_108m), //input hclkin
        .resetn(1) //input resetn
    );

    wire bus_reset_n;
    PINFILTER dn3(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_reset_n),
        .dout(bus_reset_n)
    );

    // --- lado esclavo del bus del anfitrion ---------------------------------
    // Unica parte del diseno que habla con el anfitrion. Es independiente del
    // MSX2+: funciona aunque asgard siga retenido en reset por host_ready.
    wire [7:0] slave_dout;
    wire       slave_dir;

    // Ventana de intercambio: el puente entre las dos maquinas.
    wire       xchg_we;
    wire [7:0] xchg_addr;
    wire [7:0] xchg_din;
    wire [7:0] xchg_dout;

    // Espionaje del VDP del anfitrion: alimenta al V9958 mientras el MSX2+
    // esta retenido en reset, para que el HDMI no este en negro al arrancar.
    wire [2:0] vdp_host_mode;
    wire       vdp_host_csw_n;
    wire       vdp_host_csr_n;
    wire [7:0] vdp_host_din;

    slave_bus #(
        .DIR_DELAY (4'd6)   // ~110 ns antes de girar el 245, como la 55_
    ) slave1 (
        .clk         (clk_54m),
        .reset_n     (bus_reset_n),

        .bus_addr    (ex_bus_addr),
        .bus_sltsl_n (ex_bus_sltsl_n),
        .bus_mreq_n  (ex_bus_mreq_n),
        .bus_iorq_n  (ex_bus_iorq_n),
        .bus_rd_n    (ex_bus_rd_n),
        .bus_wr_n    (ex_bus_wr_n),
        .bus_din     (ex_bus_data),
        .bus_dout    (slave_dout),
        .bus_dir     (slave_dir),

        .xchg_we     (xchg_we),
        .xchg_addr   (xchg_addr),
        .xchg_din    (xchg_din),
        .xchg_dout   (xchg_dout),

        .vdp_mode    (vdp_host_mode),
        .vdp_csw_n   (vdp_host_csw_n),
        .vdp_csr_n   (vdp_host_csr_n),
        .vdp_din     (vdp_host_din)
    );

    assign ex_bus_data = (slave_dir == 1) ? slave_dout : 8'hzz;
    assign ex_bus_data_reverse_n = ~slave_dir;

asgard
#(
    .SD_SLOT (3)
) asgard1 (
    .reset_n (bus_reset_n),
    .clk_27m (clk_27m),
    .clk_54m (clk_54m),
    .clk_108m (clk_108m),
    .clk_108m_n (clk_108m_n),
    .s1 (s1),
    .s2 (s2),

    // ventana de intercambio, lado anfitrion
    .xchg_host_we   (xchg_we),
    .xchg_host_addr (xchg_addr),
    .xchg_host_din  (xchg_din),
    .xchg_host_dout (xchg_dout),

    // acceso del anfitrion al V9958
    .vdp_host_mode  (vdp_host_mode),
    .vdp_host_csw_n (vdp_host_csw_n),
    .vdp_host_csr_n (vdp_host_csr_n),
    .vdp_host_din   (vdp_host_din),

   //hdmi out
    .data_p (data_p),
    .data_n (data_n),
    .clk_p (clk_p),
    .clk_n (clk_n),

    // flash
    .mspi_cs (mspi_cs),
    .mspi_sclk (mspi_sclk),
    .mspi_miso (mspi_miso),
    .mspi_mosi (mspi_mosi),

    // MicroSD
    .sd_sclk (sd_sclk),
    .sd_cmd (sd_cmd),      // MOSI
    .sd_dat0 (sd_dat0),     // MISO
    .sd_dat3 (sd_dat3),     // 1

`ifdef ENABLE_WIFI
    //uart
    .uart_tx (uart_tx),
    .uart_rx (uart_rx),
`endif 

    //usb uart
    .usb_uart_tx (usb_uart_tx),

    // Magic ports for SDRAM to be inferred
    .O_sdram_clk (O_sdram_clk),
    .O_sdram_cke (O_sdram_cke),
    .O_sdram_cs_n (O_sdram_cs_n), // chip select
    .O_sdram_cas_n (O_sdram_cas_n), // columns address select
    .O_sdram_ras_n (O_sdram_ras_n), // row address select
    .O_sdram_wen_n (O_sdram_wen_n), // write enable
    .IO_sdram_dq (IO_sdram_dq), // 32 bit bidirectional data bus
    .O_sdram_addr (O_sdram_addr), // 11 bit multiplexed address bus
    .O_sdram_ba (O_sdram_ba), // two banks
    .O_sdram_dqm (O_sdram_dqm) // 32/4

    //output wire SLTSL3

);


endmodule