//`define ENABLE_WIFI //pines 75 y 86 reservados en el .cst

module top
(
    input wire clkin,
    input wire s1,
    input wire s2,

    // bus del slot: direccion y control lento, multiplexados
    input  wire [7:0] mp,
    output wire [2:0] msel_n,

    // bus del slot: datos y control rapido, directos
    inout  wire [7:0] cd,
    input  wire rd_n_in,
    input  wire wr_n_in,
    input  wire sltsl_n_in,
    input wire cpu_clkin,
    output wire datadir,

    // salidas de la placa que no usamos pero hay que aparcar
    output wire wait_out,
    output  wire int_out,
    output wire busdir_n,
    output wire sound,
    output wire audio,

    // hdmi
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire tmds_clk_p,
    output wire tmds_clk_n,

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
    output wire uart_tx,
    input wire uart_rx,
`endif

    output wire usb_uart_tx,

    // Magic ports for SDRAM to be inferred
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n,
    output wire O_sdram_cas_n,
    output wire O_sdram_ras_n,
    output wire O_sdram_wen_n,
    inout wire [31:0] IO_sdram_dq,
    output wire [10:0] O_sdram_addr,
    output wire [1:0] O_sdram_ba,
    output wire [3:0] O_sdram_dqm
);

    assign wait_out = 1'b0;
    if(CONFIG_BOARD::BOARD_ID == BOARD_ID::WonderTANG_101c) begin
        assign int_out = 1'b1;
    end
    else begin
        assign int_out = 1'b0;
    end
    assign busdir_n = 1'b1;
    assign sound    = 1'b0;
    assign audio    = 1'b0;

    //clocks
    wire clk_108m;
    wire clk_108m_n;
    CLK_108P clk_main (
        .clkout(clk_108m),
        .lock(),
        .clkoutp(clk_108m_n),
        .reset(0),
        .clkin(clkin)
    );

    wire clk_54m;
    Gowin_CLKDIV2 div2(
        .clkout(clk_54m),
        .hclkin(clk_108m),
        .resetn(1)
    );

    wire clk_27m;
    Gowin_CLKDIV div4(
        .clkout(clk_27m),
        .hclkin(clk_108m),
        .resetn(1)
    );

    wire [15:0] bus_addr;
    wire        bus_mreq_n;
    wire        bus_iorq_n;
    wire        reset_in_n;

    mp_debouncer mp_deb (
        .clk(clk_108m),
        .reset_n(1'b1),
        .mp(mp),
        .msel_n(msel_n),
        .a_lo(),
        .a_hi(),
        .addr(bus_addr),
        .merq_n(bus_mreq_n),
        .iorq_n(bus_iorq_n),
        .cs1_n(),
        .cs2_n(),
        .reset_in_n(reset_in_n),
        .rfsh_n(),
        .cs12_n(),
        .m1_n(),
        .inputs_latched()
    );

    localparam [22:0] POR_CYCLES = 23'd54000;   // 1 ms a 54 MHz
    reg [22:0] por_cnt = 23'd0;
    reg        por_n   = 1'b0;

    always @ (posedge clk_54m) begin
        if (por_cnt == POR_CYCLES) por_n   <= 1'b1;
        else                       por_cnt <= por_cnt + 23'd1;
    end

    reg reset_in_n_54 = 1'b1;
    always @ (posedge clk_54m)
        reset_in_n_54 <= reset_in_n;

    wire bus_reset_n;
    assign bus_reset_n = reset_in_n_54 & por_n;

    // --- lado esclavo del bus del anfitrion ---------------------------------
    wire [7:0] slave_dout;
    wire       slave_dir;

    wire       xchg_we;
    wire [7:0] xchg_addr;
    wire [7:0] xchg_din;
    wire [7:0] xchg_dout;

    wire [2:0] vdp_host_mode;
    wire       vdp_host_csw_n;
    wire       vdp_host_csr_n;
    wire [7:0] vdp_host_din;

    slave_bus #(
        .DIR_DELAY (4'd2)
    ) slave1 (
        .clk         (clk_54m),
        .reset_n     (bus_reset_n),

        .bus_addr    (bus_addr),
        .bus_sltsl_n (sltsl_n_in),
        .bus_mreq_n  (bus_mreq_n),
        .bus_iorq_n  (bus_iorq_n),
        .bus_rd_n    (rd_n_in),
        .bus_wr_n    (wr_n_in),
        .bus_din     (cd),
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

    // datadir: 0 = conducimos hacia el MSX, misma convencion que la placa propia
    assign cd      = (slave_dir == 1) ? slave_dout : 8'hzz;
    assign datadir = ~slave_dir;

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
    .data_p (tmds_data_p),
    .data_n (tmds_data_n),
    .clk_p (tmds_clk_p),
    .clk_n (tmds_clk_n),

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
    .uart_tx (uart_tx),
    .uart_rx (uart_rx),
`endif

    .usb_uart_tx (usb_uart_tx),

    // Magic ports for SDRAM to be inferred
    .O_sdram_clk (O_sdram_clk),
    .O_sdram_cke (O_sdram_cke),
    .O_sdram_cs_n (O_sdram_cs_n),
    .O_sdram_cas_n (O_sdram_cas_n),
    .O_sdram_ras_n (O_sdram_ras_n),
    .O_sdram_wen_n (O_sdram_wen_n),
    .IO_sdram_dq (IO_sdram_dq),
    .O_sdram_addr (O_sdram_addr),
    .O_sdram_ba (O_sdram_ba),
    .O_sdram_dqm (O_sdram_dqm)
);


endmodule
