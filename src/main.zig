const std = @import("std");
const sql = @import("sql.zig");
const utils = @import("utils.zig");
const SqlDate = @import("zdb").odbc.Types.CType.SqlDate;

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

fn restablecerTablas() !void {
    sql.execute("DROP TABLE detalle_pedido", .{}) catch {};
    sql.execute("DROP TABLE stock", .{}) catch {};
    sql.execute("DROP TABLE pedido", .{}) catch {};

    try sql.execute(
        \\CREATE TABLE stock (
        \\  Cproducto INTEGER PRIMARY KEY,
        \\  cantidad INTEGER
        \\)
    , .{});

    try sql.execute(
        \\CREATE TABLE pedido (
        \\  Cpedido INTEGER PRIMARY KEY,
        \\  Ccliente INTEGER,
        \\  fecha_pedido DATE
        \\)
    , .{});

    try sql.execute(
        \\CREATE TABLE detalle_pedido (
        \\  Cpedido INTEGER REFERENCES pedido(Cpedido),
        \\  Cproducto INTEGER REFERENCES stock(Cproducto),
        \\  cantidad INTEGER,
        \\  CHECK(cantidad >= 0),
        \\  CONSTRAINT detalle_pedido_clave_primaria PRIMARY KEY (Cpedido, Cproducto)
        \\)
    , .{});

    var stocks: [10]Stock = undefined;
    for (stocks) |*stock, i| {
        stock.cproducto = @intCast(u32, i + 1);
        stock.cantidad = @intCast(u32, i + 1);
    }

    const result = try sql.insert(Stock, "stock", &stocks);
    if (result != stocks.len) {
        std.log.warn("it inserted {} instead of {}\n", .{ result, stocks.len });
    }

    _ = try sql.execute("COMMIT", .{});
}

fn readPedido() !Pedido {
    // Obtener el cpedido, leyendo el máximo cpedido de la base de datos
    const cpedido = bloque: {
        const max_cpedido = (try sql.querySingleValue(u32,
            \\ SELECT MAX(cpedido)
            \\ FROM pedido;
        , .{})) orelse 0;
        break :bloque max_cpedido + 1;
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

fn darAltaDetalle(pedido: Pedido) !void {
    // Leer cproducto
    print("Introduzca el código del producto que quiere comprar.\n", .{});
    const cproducto = try utils.readNumber(u32, stdin);

    // Obtener el stock asociado al cproducto de la base de datos comprobando que existe
    const stock = (try sql.querySingle(Stock, "SELECT * FROM stock WHERE cproducto = {};", .{cproducto})) orelse {
        print("No existe el producto de código {}\n", .{cproducto});
        return;
    };

    // Comprobar que no hay ningún detalle asociado al pedido con ese código de producto
    const count = (try sql.querySingleValue(u32,
        \\SELECT COUNT(*)
        \\FROM detalle_pedido
        \\WHERE cpedido = {} AND cproducto = {};
    , .{ pedido.cpedido, cproducto })).?;
    if (count != 0) {
        print("Ya existe un detalle del producto {} asociado al pedido\n", .{cproducto});
        return;
    }

    // Leer cantidad
    print("Introduzca la cantidad del producto {}\n", .{cproducto});
    const cantidad = try utils.readNumber(u32, stdin);
    if (cantidad == 0) {
        print("La cantidad debe ser positiva!\n", .{});
        return;
    }

    const detalle = DetallePedido{
        .cpedido = pedido.cpedido,
        .cproducto = cproducto,
        .cantidad = cantidad,
    };

    // Comprobar que hay suficiente cantidad
    if (stock.cantidad < detalle.cantidad) {
        print("Sólo hay {} items del producto {}\n", .{ stock.cantidad, stock.cproducto });
        return;
    }

    // Insertar el detalle
    _ = try sql.insert(DetallePedido, "detalle_pedido", &.{detalle});

    // Actualizar la cantidad del stock
    const nueva_cantidad = stock.cantidad - detalle.cantidad;
    try sql.execute(
        \\UPDATE stock
        \\SET cantidad = {}
        \\WHERE cproducto = {};
    , .{ nueva_cantidad, stock.cproducto });
}

fn darDeAltaPedido() !void {
    // Capturamos pedido
    const pedido = try readPedido();

    // Insertamos en la tabla
    _ = try sql.insert(Pedido, "pedido", &.{pedido});
    _ = try sql.createSavePoint("pedido_creado");

    while (true) {
        printAltaPedido();
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => {
                try darAltaDetalle(pedido);
                try mostrarContenidoTablas();
            },
            2 => {
                try sql.rollbackToSavePoint("pedido_creado");
                try mostrarContenidoTablas();
            },
            3 => {
                try sql.rollbackToSavePoint(null);
                try mostrarContenidoTablas();
                break;
            },
            4 => {
                try sql.execute("COMMIT", .{});
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
) !void {
    var tuplas = try sql.query(StructType, "SELECT * FROM " ++ nombre_tabla, .{});
    defer sql.getAllocator().free(tuplas);

    print("\n[" ++ nombre_tabla ++ "]\n", .{});
    for (tuplas) |tupla| {
        // Comptime magic: por cada campo de StructType, imprimir el nombre del
        // campo y su valor. Recorremos los campos de StructType. Dado el nombre
        // del campo como string, podemos acceder al valor en una instancia del
        // struct (tupla) usando @field. Ej: @field(stock, "cproducto") es lo
        // mismo que stock.cproducto. Si el tipo es SqlDate hacemos un formateo
        // especial.
        inline for (comptime std.meta.fields(StructType)) |field| {
            const value = @field(tupla, field.name);
            if (field.field_type == SqlDate) {
                print("{s}: [{}/{}/{}]; ", .{ field.name, value.day, value.month, value.year });
            } else {
                print("{s}: {}; ", .{ field.name, value });
            }
        }
        print("\n", .{});
    }
}

fn mostrarContenidoTablas() !void {
    try mostrarContenidoTabla(Stock, "STOCK");
    try mostrarContenidoTabla(Pedido, "PEDIDO");
    try mostrarContenidoTabla(DetallePedido, "DETALLE_PEDIDO");
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // Conectarnos a la base de datos
    try sql.init(allocator, "DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;");
    defer sql.deinit();
    print("Conectado!\n", .{});

    while (true) {
        printMenu();

        // Leer número
        const input = try utils.readNumber(usize, stdin);

        switch (input) {
            1 => try restablecerTablas(),
            2 => try darDeAltaPedido(),
            3 => try mostrarContenidoTablas(),
            4 => break,
            else => {
                print("El número debe ser del 1 al 4\n", .{});
                continue;
            },
        }
    }

    print("\nHasta luego\n", .{});
}
