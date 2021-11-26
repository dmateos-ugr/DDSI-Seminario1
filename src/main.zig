const std = @import("std");
const zdb = @import("zdb");
const Allocator = std.mem.Allocator;

// DAVID MATEOS: función readNumber
// DAVID CANTÓN: capturar datos del pedido e insertarlo; menú que viene justo despues
// DANIEL ZUFRÍ: opciones 1 y 2 del menú de dar de alta nuevo pedido

fn readNumber(comptime T: type, in: std.fs.File.Reader) !?T {
    var stdout = std.io.getStdOut().writer();
    var buf: [10]u8 = undefined;

    while (true) {
        // Leer entrada
        try stdout.print("> ", .{});
        const input_str = (try in.readUntilDelimiterOrEof(&buf, '\n')) orelse return null;

        // Parsear la entrada como un entero de tipo `T`
        const input = std.fmt.parseInt(T, input_str, 10) catch {
            try stdout.print("Debes introducir un número\n\n", .{});
            continue;
        };
        return input;
    }
}

fn printMenu(out: std.fs.File.Writer) !void {
    try out.print("\n1. Restablecer tablas e inserción de 10 tuplas predefinidas en la tabla Stock\n", .{});
    try out.print("2. Dar de alta nuevo pedido\n", .{});
    try out.print("3. Mostrar contenido de las tablas\n", .{});
    try out.print("4. Salir y cerrar conexión\n", .{});
}

fn printAltaPedido(out: std.fs.File.Writer) !void {
    try out.print("\n1. Añadir detalle de producto\n", .{});
    try out.print("2. Eliminar todos los detalles de producto\n", .{});
    try out.print("3. Cancelar pedido\n", .{});
    try out.print("4. Finalizar pedido\n", .{});
}

const Stock = struct {
    cproducto: u32,
    cantidad: u32,
};

const Pedido = struct {
    cpedido: u32,
    ccliente: u32,
  //  fecha: SqlDate, 
};

const DetallePedido = struct {
    cpedido:    u32,
    cproducto:  u32,
    cantidad:   u32
};

fn readPedido(allocator: *Allocator, connection: *zdb.DBConnection, in: std.fs.File.Reader) !?Pedido {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    var stdout = std.io.getStdOut().writer();
    var pedido: Pedido = undefined;

    const MaxStruct = struct {
        max: u32,
    };

    var result_set = try cursor.executeDirect(MaxStruct,.{},
        \\ SELECT MAX(cpedido)
        \\ FROM Pedido;
    );

    defer result_set.deinit();
    const cpedido = (try result_set.next()).?.max;

    std.debug.print("{}",.{cpedido});
    try stdout.print("Introduzca su codigo de cliente ", .{});
    pedido.ccliente = (try readNumber(u32, in)) orelse return null;

// FALTA FECHA Y CPEDIDO

    return pedido;
}

fn restablecerTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    _ = cursor.statement.executeDirect("DROP TABLE stock") catch {};
    _ = cursor.statement.executeDirect("DROP TABLE detalle-pedido") catch {};
    _ = cursor.statement.executeDirect("DROP TABLE pedido") catch {};

    // _ = try cursor.executeDirect(Stock, .{},
    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE Stock (
        \\  Cproducto INTEGER PRIMARY KEY,
        \\  cantidad INTEGER
        \\ )
    );

    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE Detalle-Pedido (
        \\  Cpedido INTEGER REFERENCES Pedido(Cpedido)
        \\  Cproducto INTEGER REFERENCES Stock(Cproducto),
        \\  cantidad INTEGER,
        \\  CHECK(cantidad GE 0),
        \\ CONSTRAINT detalle_pedido_clave_primaria PRIMARY KEY (Cpedido, Cproducto)
        \\ )
    );

    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE Pedido (
        \\  Cpedido INTEGER PRIMARY KEY,
        \\  Ccliente INTEGER,
        \\  fecha-pedido DATE
        \\ )
    );

    var stocks: [10]Stock = undefined;
    for (stocks) |*stock, i| {
        stock.cproducto = @intCast(u32, i + 1);
        stock.cantidad = @intCast(u32, i + 1);
    }

    const result = try cursor.insert(Stock, "stock", &stocks);
    if (result != stocks.len) {
        std.log.warn("it inserted {} instead of {}\n", .{result, stocks.len});
    }
}

fn darDeAltaPedido(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    // Capturamos pedido
    const pedido = (try readPedido(allocator, connection, stdin)).?;
    // Insertamos en la tabla
    const result = try cursor.insert(Pedido, "pedido", &.{pedido});

    while(true){
        try printAltaPedido(stdout);
        const input = (try readNumber(usize, stdin)) orelse break;

        // switch (input) {
        //     1 => try {},
        //     2 => try {},
        //     3 => try {},
        //     4 => try {},
        //     else => {
        //         try stdout.print("El número debe ser del 1 al 4\n", .{});
        //         continue;
        //     }
        // }
    }
}

fn mostrarContenidoTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    var result_set = try cursor.executeDirect(
        Stock,
        .{ },
        "SELECT * FROM STOCK;"
    );
    defer result_set.deinit();

    while (try result_set.next()) |result| {
        std.debug.print("stock: {}\n", .{result});
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();

    var connection = try zdb.DBConnection.initWithConnectionString("DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;");
    defer connection.deinit();
    try stdout.print("Conectado!\n", .{});

    while (true) {
        try printMenu(stdout);

        // Leer número
        const input = (try readNumber(usize, stdin)) orelse break;

        switch (input) {
            1 => try restablecerTablas(allocator, &connection),
            2 => try darDeAltaPedido(allocator, &connection),
            3 => try mostrarContenidoTablas(allocator, &connection),
            4 => break,
            else => {
                try stdout.print("El número debe ser del 1 al 4\n", .{});
                continue;
            }
        }
    }

    try stdout.print("\nHasta luego\n", .{});
}
