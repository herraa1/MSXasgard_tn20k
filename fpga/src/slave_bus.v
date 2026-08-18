// ===========================================================================
// slave_bus.v
// Esclavo del slot de cartucho del MSX ANFITRION.
//
// Es la unica parte del diseno que habla con el bus del anfitrion. El MSX2+
// (asgard) es completamente independiente y no aparece por aqui.
//
// Mapa dentro del slot:
//   0x4000-0x4FFF   ROM del proxy, 4 KB en BSRAM (slave_rom)
//   0x5000-0x50FF   ventana de registros de intercambio
//   resto           sin decodificar, no se responde
//
// TEMPORIZACION
// Todo el bus se muestrea a clk_54m en vez de al reloj del anfitrion. La
// direccion y el control estan estables durante todo el ciclo del Z80, asi que
// registrarlos no tiene riesgo real de metaestabilidad, y a cambio la lectura
// de BSRAM baja a ~37 ns frente a los ~280 ns que costaria un ciclo completo de
// 3.58 MHz. La ventana del Z80 entre RD y el muestreo del dato es de ~400 ns.
//
// REFRESCO
// El decodificado se cualifica SIEMPRE con RD o WR, nunca solo con SLTSL:
// durante los ciclos de refresco del Z80, MREQ baja con la direccion de
// refresco en A0-A7, y hay maquinas cuyo SLTSL no esta gateado con RFSH (senal
// que en esta placa ni siquiera esta cableada).
// ===========================================================================
module slave_bus #(
    // Cuentas de clk_54m que se esperan desde que se detecta la lectura hasta
    // girar el 74LVC245 de datos, para no solaparse con el buffer del anfitrion.
    // Portado de la 55_, que espera >2 cuentas a 27 MHz (~110 ns).
    parameter [3:0] DIR_DELAY = 4'd6
)(
    input  wire        clk,          // clk_54m
    input  wire        reset_n,

    // --- pines del slot de cartucho ---
    input  wire [15:0] bus_addr,
    input  wire        bus_sltsl_n,
    input  wire        bus_mreq_n,
    input  wire        bus_iorq_n,
    input  wire        bus_rd_n,
    input  wire        bus_wr_n,
    input  wire [7:0]  bus_din,      // lo que pone el anfitrion
    output wire [7:0]  bus_dout,     // lo que devolvemos
    output wire        bus_dir,      // 1 = conducimos el bus del anfitrion

    // --- ventana de intercambio (0x5000-0x50FF) ---
    output wire        xchg_we,
    output wire [7:0]  xchg_addr,
    output wire [7:0]  xchg_din,
    input  wire [7:0]  xchg_dout,

    // --- espionaje del VDP del anfitrion (98-9Bh) ---------------------------
    // Durante el arranque del anfitrion el V9958 interno sigue ESTE bus, de modo
    // que el HDMI muestra lo mismo que la salida analogica desde el primer
    // momento. Es un espejo de ESCRITURA: no devolvemos dato nunca, el VDP real
    // del anfitrion sigue sirviendo las lecturas y no hay contencion.
    //
    // csr_n tambien se expone, y es imprescindible: el puntero de VRAM del
    // V9958 avanza tanto en lectura como en escritura, y leer el registro de
    // estado limpia el flag de interrupcion. Sin espiar las lecturas, el espejo
    // se desincronizaria del original al primer acceso de lectura a VRAM.
    output wire [2:0]  vdp_mode,
    output wire        vdp_csw_n,
    output wire        vdp_csr_n,
    output wire [7:0]  vdp_din
);

    // --- muestreo del bus ---------------------------------------------------
    reg [15:0] addr_r;
    reg        sltsl_n_r;
    reg        mreq_n_r;
    reg        iorq_n_r;
    reg        rd_n_r;
    reg        wr_n_r;
    reg [7:0]  din_r;

    always @ (posedge clk) begin
        addr_r    <= bus_addr;
        sltsl_n_r <= bus_sltsl_n;
        mreq_n_r  <= bus_mreq_n;
        iorq_n_r  <= bus_iorq_n;
        rd_n_r    <= bus_rd_n;
        wr_n_r    <= bus_wr_n;
        din_r     <= bus_din;
    end

    // --- decodificado -------------------------------------------------------
    wire sel_page1;
    wire rom_sel;
    wire xchg_sel;

    assign sel_page1 = (reset_n == 1) && (sltsl_n_r == 0) && (mreq_n_r == 0) &&
                       (addr_r[15:14] == 2'b01);
    assign rom_sel   = sel_page1 && (addr_r[13:12] == 2'b00);      // 0x4000-0x4FFF
    assign xchg_sel  = sel_page1 && (addr_r[13:8] == 6'b010000);   // 0x5000-0x50FF

    // --- ROM del proxy ------------------------------------------------------
    // Se le da la direccion SIN registrar: la BSRAM la registra por dentro, asi
    // que su salida y addr_r corresponden al mismo flanco y van sincronizadas.
    wire [7:0] rom_dout;

    slave_rom rom1 (
        .clk  (clk),
        .addr (bus_addr[11:0]),
        .dout (rom_dout)
    );

    // --- ventana de intercambio ---------------------------------------------
    // Un unico pulso por escritura del anfitrion, no un nivel: asi el heartbeat
    // y la firma no se reescriben decenas de veces por ciclo del Z80.
    reg  xchg_wr_d;
    wire xchg_wr_now;

    assign xchg_wr_now = xchg_sel && (wr_n_r == 0);

    always @ (posedge clk) begin
        if (reset_n == 0) xchg_wr_d <= 1'b0;
        else              xchg_wr_d <= xchg_wr_now;
    end

    assign xchg_we   = xchg_wr_now & ~xchg_wr_d;
    assign xchg_addr = addr_r[7:0];
    assign xchg_din  = din_r;

    // --- dato hacia el anfitrion --------------------------------------------
    assign bus_dout = (rom_sel == 1) ? rom_dout : xchg_dout;

    // --- direccion del 74LVC245 ---------------------------------------------
    wire read_req;
    reg [3:0] dir_cnt;
    reg       dir_ff;

    assign read_req = (rom_sel || xchg_sel) && (rd_n_r == 0);

    always @ (posedge clk) begin
        if (reset_n == 0) begin
            dir_cnt <= 4'd0;
            dir_ff   <= 1'b0;
        end
        else if (read_req == 1) begin
            if (dir_cnt == DIR_DELAY) dir_ff   <= 1'b1;
            else                      dir_cnt <= dir_cnt + 4'd1;
        end
        else begin
            dir_cnt <= 4'd0;
            dir_ff   <= 1'b0;
        end
    end

    assign bus_dir = dir_ff;

    // --- espionaje del VDP del anfitrion ------------------------------------
    // Rango 98-9Bh, el que documenta la tabla de puertos. NO se usa el 98-9Fh
    // del decodificado interno: sus 9Ch son flags del V9968, una extension
    // nuestra, y en el anfitrion esos puertos no son suyos.
    //
    // No hace falta cualificar con M1 (que ademas no esta cableado en esta
    // placa): el unico ciclo con IORQ bajo y M1 bajo es el reconocimiento de
    // interrupcion, y ahi el Z80 deja RD y WR en alto. Al exigir RD o WR, los
    // ciclos de INTACK quedan excluidos solos.
    wire vdp_io;
    assign vdp_io = (reset_n == 1) && (iorq_n_r == 0) && (addr_r[7:2] == 6'b100110);

    assign vdp_csw_n = ~(vdp_io && (wr_n_r == 0));
    assign vdp_csr_n = ~(vdp_io && (rd_n_r == 0));
    assign vdp_mode  = addr_r[2:0];
    assign vdp_din   = din_r;

endmodule
