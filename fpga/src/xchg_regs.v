// ===========================================================================
// xchg_regs.v
// Registros de intercambio entre el MSX ANFITRION y el MSX2+.
//
// El anfitrion, secuestrado por la ROM del cartucho (src/slave_rom), barre su
// matriz de teclado y sus dos puertos de joystick y va dejando el resultado
// aqui. El MSX2+ los lee como si fueran su propio PPI y su propio PSG. En
// sentido contrario, el MSX2+ deja aqui el estado de los LEDs (CAPS y KANA)
// para que el proxy los refleje en el hardware del anfitrion.
//
// Ventana del anfitrion (0x5000-0x50FF del slot del cartucho):
//   0x00-0x0F  16 filas crudas de teclado, indice = 0xAA[3:0]   (escribe)
//   0x10       joystick puerto 1                                 (escribe)
//   0x11       joystick puerto 2                                 (escribe)
//   0x12       heartbeat, lo incrementa el proxy en cada pasada  (escribe)
//   0x13       firma del proxy                                   (escribe)
//   0x20       LEDs: b0 = CAPS, b1 = KANA                        (lee)
//
// Son REGISTROS y no BSRAM a proposito: la lectura del puerto B del PPI tiene
// que resolverse dentro del ciclo de lectura de la CPU, y un mux 16:1 sobre
// registros es mas rapido y mas barato que un acceso a bloque.
//
// CRUCE DE DOMINIOS: el anfitrion escribe en su reloj y el MSX2+ lee en
// clk_54m, sin handshake ni sincronizadores. Es seguro porque lo que se
// intercambia es ESTADO IDEMPOTENTE, no eventos: una lectura desgarrada
// devuelve como mucho el valor de una pasada anterior, indistinguible de haber
// muestreado unos microsegundos antes. key_data sale registrada en clk_54m y
// el mux de cpu_din la vuelve a registrar, con lo que hay dos etapas.
// ===========================================================================
module xchg_regs #(
    parameter [7:0]  HOST_SIG     = 8'h5a,        // firma que escribe el proxy
    parameter [26:0] HOST_TIMEOUT = 27'd108000000 // 2 s a 54 MHz
)(
    // --- lado MSX2+ (clk_54m) ---
    input  wire        clk,
    input  wire        reset_n,
    input  wire [3:0]  key_row,      // seleccion de fila del PPI interno
    output reg  [7:0]  key_data,     // fila seleccionada
    output wire [7:0]  joy1,
    output wire [7:0]  joy2,
    input  wire        led_caps,     // 1 = encendido
    input  wire        led_kana,     // 1 = encendido
    output wire        host_ready,
    output wire [7:0]  host_beat,    // para diagnostico

    // --- lado anfitrion (ventana 0x50xx) ---
    input  wire        host_clk,
    input  wire        host_we,
    input  wire [7:0]  host_addr,
    input  wire [7:0]  host_din,
    output wire [7:0]  host_dout
);

    reg [7:0] keys [0:15];
    reg [7:0] joy1_r;
    reg [7:0] joy2_r;
    reg [7:0] beat_r;
    reg [7:0] sig_r;

    integer i;

    // --- escritura desde el anfitrion ---------------------------------------
    // Reset a 0xFF: en la matriz del MSX y en los puertos de joystick la logica
    // es negativa, asi que 0xFF es "nada pulsado". Es el estado en el que arranca
    // el MSX2+ mientras el proxy todavia no ha hecho su primera pasada.
    always @ (posedge host_clk) begin
        if (reset_n == 0) begin
            for (i = 0; i < 16; i = i + 1)
                keys[i] <= 8'hff;
            joy1_r <= 8'hff;
            joy2_r <= 8'hff;
            beat_r <= 8'h00;
            sig_r  <= 8'h00;
        end
        else if (host_we == 1) begin
            casex (host_addr)
                8'b0000_xxxx: keys[host_addr[3:0]] <= host_din;
                8'h10:        joy1_r <= host_din;
                8'h11:        joy2_r <= host_din;
                8'h12:        beat_r <= host_din;
                8'h13:        sig_r  <= host_din;
            endcase
        end
    end

    // --- lectura desde el MSX2+ ---------------------------------------------
    always @ (posedge clk) begin
        key_data <= keys[key_row];
    end

    assign joy1      = joy1_r;
    assign joy2      = joy2_r;
    assign host_beat = beat_r;

    // --- lectura desde el anfitrion (LEDs) ----------------------------------
    assign host_dout = (host_addr == 8'h20) ? { 6'b000000, led_kana, led_caps } :
                                              8'hff;

    // --- host_ready ----------------------------------------------------------
    // Se libera cuando el proxy ha escrito su firma, que solo hace al final de
    // una pasada completa: asi el MSX2+ no arranca hasta que hay un barrido
    // valido en los registros y el menu de arranque tiene teclado.
    //
    // El temporizador de escape cuenta en clk_54m, NO en el reloj del anfitrion:
    // si el anfitrion esta apagado o retenido en reset su reloj puede no estar
    // oscilando, que es justo el caso que el timeout tiene que cubrir.
    reg [26:0] tmo_cnt;
    reg        host_ready_r;

    always @ (posedge clk) begin
        if (reset_n == 0) begin
            tmo_cnt      <= 27'd0;
            host_ready_r <= 1'b0;
        end
        else if (host_ready_r == 0) begin
            if (sig_r == HOST_SIG)
                host_ready_r <= 1'b1;
            else if (tmo_cnt >= HOST_TIMEOUT)
                host_ready_r <= 1'b1;
            else
                tmo_cnt <= tmo_cnt + 1'b1;
        end
    end

    assign host_ready = host_ready_r;

endmodule
