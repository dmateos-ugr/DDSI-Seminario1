const std = @import("std");
const zdb = @import("zdb");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
const SqlDate = zdb.odbc.Types.CType.SqlDate;

// DAVID MATEOS: función utils.readNumber
// DAVID CANTÓN: capturar datos del pedido e insertarlo; menú que viene justo despues
// DANIEL ZUFRÍ: opciones 1 y 2 del menú de dar de alta nuevo pedido

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
    fecha_pedido: SqlDate,
};

const DetallePedido = struct {
    cpedido: u32,
    cproducto: u32,
    cantidad: u32,
};

fn restablecerTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    _ = cursor.statement.executeDirect("DROP TABLE detalle_pedido") catch {};
    _ = cursor.statement.executeDirect("DROP TABLE stock") catch {};
    _ = cursor.statement.executeDirect("DROP TABLE pedido") catch {};

    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE stock (
        \\  Cproducto INTEGER PRIMARY KEY,
        \\  cantidad INTEGER
        \\)
    );

    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE pedido (
        \\  Cpedido INTEGER PRIMARY KEY,
        \\  Ccliente INTEGER,
        \\  fecha_pedido DATE
        \\)
    );

    _ = try cursor.statement.executeDirect(
        \\CREATE TABLE detalle_pedido (
        \\  Cpedido INTEGER REFERENCES pedido(Cpedido),
        \\  Cproducto INTEGER REFERENCES stock(Cproducto),
        \\  cantidad INTEGER,
        \\  CHECK(cantidad >= 0),
        \\  CONSTRAINT detalle_pedido_clave_primaria PRIMARY KEY (Cpedido, Cproducto)
        \\)
    );

    var stocks: [10]Stock = undefined;
    for (stocks) |*stock, i| {
        stock.cproducto = @intCast(u32, i + 1);
        stock.cantidad = @intCast(u32, i + 1);
    }

    const result = try cursor.insert(Stock, "stock", &stocks);
    if (result != stocks.len) {
        std.log.warn("it inserted {} instead of {}\n", .{ result, stocks.len });
    }
}

fn readPedido(allocator: *Allocator, connection: *zdb.DBConnection, in: std.fs.File.Reader) !Pedido {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    var stdout = std.io.getStdOut().writer();

    // Obtener el cpedido, leyendo el máximo cpedido de la base de datos
    const cpedido = bloque: {
        const MaxStruct = struct {
            max: u32,
        };
        var result_set = try cursor.executeDirect(MaxStruct, .{},
            \\ SELECT MAX(cpedido)
            \\ FROM pedido;
        );
        defer result_set.deinit();

        // Obtener el resultado del query. Si no hay ninguno, asignamos 1.
        const max_struct = (try result_set.next()) orelse break :bloque 1;
        break :bloque max_struct.max + 1;
    };

    // Obtener la fecha en formato SQL
    const sql_date = bloque: {
        const date = utils.DateTime.fromTimestamp(std.time.timestamp());
        break :bloque SqlDate{
            .year = @intCast(c_short, date.year),
            .month = date.month,
            .day = date.day,
        };
    };

    // Leer el código de cliente
    try stdout.print("Introduzca su codigo de cliente ", .{});
    const ccliente = try utils.readNumber(u32, in);

    return Pedido{
        .cpedido = cpedido,
        .ccliente = ccliente,
        .fecha_pedido = sql_date,
    };
}

fn darDeAltaPedido(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    // Capturamos pedido
    const pedido = try readPedido(allocator, connection, stdin);

    // Insertamos en la tabla
    _ = try cursor.insert(Pedido, "pedido", &.{pedido});

    while (true) {
        try printAltaPedido(stdout);
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => {},
            2 => {},
            3 => {},
            4 => {},
            else => {
                try stdout.print("El número debe ser del 1 al 4\n", .{});
                continue;
            }
        }
    }
}

fn mostrarContenidoTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    var result_set = try cursor.executeDirect(Stock, .{}, "SELECT * FROM STOCK;");
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
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => try restablecerTablas(allocator, &connection),
            2 => try darDeAltaPedido(allocator, &connection),
            3 => try mostrarContenidoTablas(allocator, &connection),
            4 => break,
            else => {
                try stdout.print("El número debe ser del 1 al 4\n", .{});
                continue;
            },
        }
    }

    try stdout.print("\nHasta luego\n", .{});
}
