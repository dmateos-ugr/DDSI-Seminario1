const std = @import("std");
const zdb = @import("zdb");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
const SqlDate = zdb.odbc.Types.CType.SqlDate;

// DAVID MATEOS: función utils.readNumber
// DAVID CANTÓN: capturar datos del pedido e insertarlo; menú que viene justo despues
// DANIEL ZUFRÍ: opciones 1 y 2 del menú de dar de alta nuevo pedido

const stdin = std.io.getStdIn().reader();

fn print(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(format, args) catch unreachable;
}

fn printMenu() void {
    print("\n1. Restablecer tablas e inserción de 10 tuplas predefinidas en la tabla Stock\n", .{});
    print("2. Dar de alta nuevo pedido\n", .{});
    print("3. Mostrar contenido de las tablas\n", .{});
    print("4. Salir y cerrar conexión\n", .{});
}

fn printAltaPedido() void {
    print("\n1. Añadir detalle de pedido\n", .{});
    print("2. Eliminar todos los detalles de pedido\n", .{});
    print("3. Cancelar pedido\n", .{});
    print("4. Finalizar pedido\n", .{});
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

    _ = try cursor.statement.executeDirect("COMMIT");
}

fn readPedido(allocator: *Allocator, connection: *zdb.DBConnection) !Pedido {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

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
    print("Introduzca su codigo de cliente ", .{});
    const ccliente = try utils.readNumber(u32, stdin);

    return Pedido{
        .cpedido = cpedido,
        .ccliente = ccliente,
        .fecha_pedido = sql_date,
    };
}

fn readDetallePedido(pedido: Pedido) !DetallePedido {
    // Leer cproducto
    print("Introduzca el código del producto que quiere comprar.\n", .{});
    const cproducto = try utils.readNumber(u32, stdin);

    // Leer cantidad
    print("Introduzca la cantidad del producto {}\n", .{cproducto});
    const cantidad = try utils.readNumber(u32, stdin);

    return DetallePedido{
        .cpedido = pedido.cpedido,
        .cproducto = cproducto,
        .cantidad = cantidad,
    };
}

fn createSavePoint(comptime nombre: []const u8, allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    _ = try cursor.statement.executeDirect("SAVEPOINT " ++ nombre);
}

fn rollback(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    _ = try cursor.statement.executeDirect("ROLLBACK");
}

fn rollbackToSavepoint(comptime nombre: []const u8, allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    _ = try cursor.statement.executeDirect("ROLLBACK TO " ++ nombre);
}

fn sqlQuery(
    allocator: *Allocator,
    connection: *zdb.DBConnection,
    comptime format: []const u8,
    parameters: anytype,
    ReturnType: type,
) !zdb.ResultSet(ReturnType) {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    const sql_query = try std.fmt.allocPrint(allocator, format, parameters);
    defer allocator.free(sql_query);

    return try cursor.executeDirect(ReturnType, .{}, format);
}

fn darAltaDetalle(pedido: Pedido, allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    // Leer cproducto
    print("Introduzca el código del producto que quiere comprar.\n", .{});
    const cproducto = try utils.readNumber(u32, stdin);

    // Comprobar que existe el producto y obtener el stock
    var result_set = try sqlQuery(
        allocator,
        connection,
        "SELECT * FROM stock WHERE cproducto = {};",
        .{cproducto},
        Stock,
    );
    defer result_set.deinit();
    const stock = (try result_set.next()) orelse {
        print("No existe el producto de código {}\n", .{cproducto});
        return;
    };

    // Leer cantidad
    print("Introduzca la cantidad del producto {}\n", .{cproducto});
    const cantidad = try utils.readNumber(u32, stdin);

    const detalle = DetallePedido{
        .cpedido = pedido.cpedido,
        .cproducto = cproducto,
        .cantidad = cantidad,
    };

    // Leemos el DetallePedido
    // const detalle = try readDetallePedido(pedido);
    if (stock.cantidad < detalle.cantidad) {
        print("Sólo hay {} items del producto {}\n", .{ stock.cantidad, stock.cproducto });
        return;
    }

    _ = try cursor.insert(DetallePedido, "detalle_pedido", &.{detalle});

    const nueva_cantidad = stock.cantidad - detalle.cantidad;
    const sql_query = try std.fmt.allocPrint(allocator,
        \\UPDATE stock
        \\SET cantidad = {}
        \\WHERE cproducto = {};
    , .{ nueva_cantidad, stock.cproducto });
    defer allocator.free(sql_query);
    _ = try cursor.statement.executeDirect(sql_query);
}

fn darDeAltaPedido(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    // Capturamos pedido
    const pedido = try readPedido(allocator, connection);

    // Insertamos en la tabla
    _ = try cursor.insert(Pedido, "pedido", &.{pedido});
    _ = try createSavePoint("pedido_creado", allocator, connection);

    while (true) {
        printAltaPedido();
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => {
                try darAltaDetalle(pedido, allocator, connection);
                try mostrarContenidoTablas(allocator, connection);
            },
            2 => {
                try rollbackToSavepoint("pedido_creado", allocator, connection);
                try mostrarContenidoTablas(allocator, connection);
            },
            3 => {
                try rollback(allocator, connection);
                try mostrarContenidoTablas(allocator, connection);
                break;
            },
            4 => {
                _ = try cursor.statement.executeDirect("COMMIT");
                break;
            },
            else => {
                print("El número debe ser del 1 al 4\n", .{});
                continue;
            },
        }
    }
}

fn mostrarContenidoTabla(
    comptime StructType: type,
    comptime nombre_tabla: []const u8,
    cursor: *zdb.Cursor,
) !void {
    var result_set = try cursor.executeDirect(StructType, .{}, "SELECT * FROM " ++ nombre_tabla);
    defer result_set.deinit();

    print("\n[" ++ nombre_tabla ++ "]\n", .{});
    while (try result_set.next()) |result| {
        // Comptime magic: por cada campo de StructType, imprimir el nombre del
        // campo y su valor. Recorremos los campos de StructType. Dado el nombre
        // del campo como string, podemos acceder al valor en una instancia del
        // struct (result) usando @field. Si el tipo es SqlDate hacemos un
        // formateo especial.
        inline for (comptime std.meta.fields(StructType)) |field| {
            const value = @field(result, field.name);
            if (field.field_type == SqlDate) {
                print("{s}: [{}/{}/{}]; ", .{ field.name, value.day, value.month, value.year });
            } else {
                print("{s}: {}; ", .{ field.name, value });
            }
        }
        print("\n", .{});
    }
}

fn mostrarContenidoTablas(allocator: *Allocator, connection: *zdb.DBConnection) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;
    try mostrarContenidoTabla(Stock, "STOCK", &cursor);
    try mostrarContenidoTabla(Pedido, "PEDIDO", &cursor);
    try mostrarContenidoTabla(DetallePedido, "DETALLE_PEDIDO", &cursor);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // Conectarnos a la base de datos
    var connection = try zdb.DBConnection.initWithConnectionString("DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;");
    defer connection.deinit();
    print("Conectado!\n", .{});

    // Desactivar autocommit
    try connection.setCommitMode(.manual);

    while (true) {
        printMenu();

        // Leer número
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => try restablecerTablas(allocator, &connection),
            2 => try darDeAltaPedido(allocator, &connection),
            3 => try mostrarContenidoTablas(allocator, &connection),
            4 => break,
            else => {
                print("El número debe ser del 1 al 4\n", .{});
                continue;
            },
        }
    }

    print("\nHasta luego\n", .{});
}
