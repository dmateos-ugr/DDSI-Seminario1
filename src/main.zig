const std = @import("std");
const zdb = @import("zdb");
const Allocator = std.mem.Allocator;

// fn printMenu(out: std.fs.File.Writer) void {
fn printMenu(out: std.fs.File.Writer) !void {
    try out.print("\n1. Restablecer tablas e inserción de 10 tuplas predefinidas en la tabla Stock\n", .{});
    try out.print("2. Dar de alta nuevo pedido\n", .{});
    try out.print("3. Mostrar contenido de las tablas\n", .{});
    try out.print("4. Salir y cerrar conexión\n", .{});
}

fn restablecerTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit();

    // cursor.insert()
}

fn darDeAltaPedido(allocator: *Allocator, connection: *zdb.DBConnection) !void {
}

fn mostrarContenidoTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
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

        // Leer de stdin
        var buf: [10]u8 = undefined;
        const input_str = (try stdin.readUntilDelimiterOrEof(&buf, '\n')) orelse break;

        // Parsear la entrada como un `usize`
        const input = std.fmt.parseInt(usize, input_str, 10) catch {
            try stdout.print("Debes introducir un número\n", .{});
            continue;
        };

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
