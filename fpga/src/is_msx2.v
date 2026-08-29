//-----------------------------------------------------------------------------
// is_msx2 - detecta si el MSX anfitrion lleva una BIOS MSX2 o superior
//-----------------------------------------------------------------------------
// Vigila el espejo de escrituras al VDP del anfitrion (puertos 98-9Bh) y busca
// una escritura completa al REGISTRO 16 del VDP, el puntero de paleta. Ese
// registro no existe en el TMS9918, asi que solo una BIOS MSX2 o posterior lo
// escribe: un anfitrion MSX1 nunca hace saltar esta salida.
//
// PARA QUE SIRVE. El espejo del VDP del anfitrion se corta en cuanto esto se
// activa. Las BIOS MSX2 y MSX2+ dibujan su logo de arranque con COMANDOS del
// VDP y sincronizandose con sus interrupciones, y ninguna de las dos cosas
// sobrevive al espejo: los dos VDP no van sincronizados, asi que el logo sale
// deformado, y el motor de comandos puede quedar a medias cuando el MSX2+ toma
// el mando. Cortando antes de que empiece esa rutina no hay nada que arreglar
// despues.
//
// El anfitrion escribe R#16 en su inicializacion del VDP, antes del barrido de
// slots. Asi que en una maquina MSX2 el corte llega ANTES de que se ejecute el
// proxy, y su mensaje tampoco se refleja en el HDMI. Es el precio aceptado: en
// esas maquinas el espejo aportaba poco y estropeaba mas. En un anfitrion MSX1
// no se dispara nada y se sigue reflejando todo el arranque, mensaje incluido.
//
// POR QUE R#16 Y NO CUALQUIER PUERTO "de MSX2". Bastaria con ver una escritura
// a 9Ah o 9Bh, que tampoco existen en el TMS9918, y saldria mas corto porque no
// haria falta seguir la fase del puerto 99h. Pero R#16 tiene una propiedad que
// esos no dan: al completarse su escritura sabemos que el latch de primer/
// segundo byte esta en "espera primer byte". El corte cae en un punto de fase
// limpio y el MSX2+ no puede heredar media pareja de bytes.
//
// El seguimiento de la fase reproduce el del VDP real:
//   - escritura a 99h: primer byte -> segundo byte -> vuelta a primer byte
//   - segundo byte con patron 10rrrrrr = escritura al registro rrrrrr
//   - cualquier acceso al puerto de datos 98h resetea el latch
//   - la lectura del registro de estado 99h resetea el latch (es justo lo que
//     hace la rom del esclavo antes de programar el VDP del anfitrion)
//-----------------------------------------------------------------------------

module is_msx2 (
    input  wire       clk,
    input  wire       reset_n,

    // espejo del bus de VDP del anfitrion, tal cual lo entrega slave_bus
    input  wire [2:0] vdp_host_mode,     // bus_addr[2:0] : 0=98h 1=99h 2=9Ah 3=9Bh
    input  wire       vdp_host_csw_n,
    input  wire       vdp_host_csr_n,
    input  wire [7:0] vdp_host_din,

    output wire       detected           // 1 = anfitrion MSX2 o superior (se queda a 1)
);

    localparam [5:0] REG_PALETTE_PTR = 6'd16;   // R#16, puntero de paleta

    localparam [1:0] PORT_DATA = 2'b00,         // 98h
                     PORT_CTRL = 2'b01;         // 99h

    reg       csw_n_d;
    reg       csr_n_d;
    reg [7:0] din_hold;
    reg [1:0] port_hold;
    reg       phase;            // 0 = espera primer byte, 1 = espera segundo
    reg       detected_ff;

    // Se actua al SOLTAR la senal, no al activarla: durante todo el acceso el
    // dato y el puerto han estado estables y ya se han capturado.
    wire write_end = (csw_n_d == 1'b0) && (vdp_host_csw_n == 1'b1);
    wire read_end  = (csr_n_d == 1'b0) && (vdp_host_csr_n == 1'b1);

    always @ (posedge clk) begin
        if (reset_n == 1'b0) begin
            csw_n_d     <= 1'b1;
            csr_n_d     <= 1'b1;
            din_hold    <= 8'h00;
            port_hold   <= 2'b00;
            phase       <= 1'b0;
            detected_ff <= 1'b0;
        end
        else begin
            csw_n_d <= vdp_host_csw_n;
            csr_n_d <= vdp_host_csr_n;

            if (vdp_host_csw_n == 1'b0) begin
                din_hold  <= vdp_host_din;
                port_hold <= vdp_host_mode[1:0];
            end
            else if (vdp_host_csr_n == 1'b0) begin
                port_hold <= vdp_host_mode[1:0];
            end

            if (write_end == 1'b1) begin
                if (port_hold == PORT_DATA) begin
                    phase <= 1'b0;                      // 98h resetea el latch
                end
                else if (port_hold == PORT_CTRL) begin
                    if (phase == 1'b0) begin
                        phase <= 1'b1;                  // primer byte guardado
                    end
                    else begin
                        phase <= 1'b0;
                        // segundo byte 10rrrrrr: escritura de registro
                        if (din_hold[7:6] == 2'b10 &&
                            din_hold[5:0] == REG_PALETTE_PTR)
                            detected_ff <= 1'b1;
                    end
                end
                // 9Ah y 9Bh no tocan el latch de 99h
            end
            else if (read_end == 1'b1) begin
                // lectura de datos (98h) o de estado (99h): ambas lo resetean
                if (port_hold == PORT_DATA || port_hold == PORT_CTRL)
                    phase <= 1'b0;
            end
        end
    end

    assign detected = detected_ff;

endmodule
