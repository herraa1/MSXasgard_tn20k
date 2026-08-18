// ===========================================================================
// slave_rom.v
// ROM de 4096 x 8 bits con el programa proxy que ejecuta el Z80 del MSX
// ANFITRION: barre teclado y joysticks y los deja en los registros de
// intercambio del cartucho.
//
// Se mapea en 0x4000-0x4FFF del slot del cartucho, por debajo de la ventana de
// intercambio (0x5000-0x50FF), asi que ROM y registros no se solapan.
//
// El contenido se carga via $readmemh desde slave_rom.hex (un byte por linea,
// generado por el Makefile de src/slave_rom a partir del .bin de 4096 bytes).
// $readmemh necesita texto hex; el .bin raw no se puede leer directamente, por
// eso se usa el .hex (misma convencion que bios_missing.v / logo.v).
//
// NOTA: la ruta del $readmemh es relativa al directorio de trabajo de la
// sintesis (Gowin), igual que en bios_missing.v. El Makefile deja una copia en
// src/ junto a bios_missing.hex por ese motivo.
// ===========================================================================
module slave_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output wire [7:0]  dout
);

    reg [7:0] mem_r [0:4095];
    reg [7:0] q_r;

    initial begin
        $readmemh("slave_rom.hex", mem_r);
    end

    always @(posedge clk) begin
        q_r <= mem_r[addr];
    end

    assign dout = q_r;

endmodule
