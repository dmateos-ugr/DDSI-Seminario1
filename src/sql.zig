const std = @import("std");
const zdb = @import("zdb");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

var allocator: *Allocator = undefined;
var connection: zdb.DBConnection = undefined;

pub fn init(sql_allocator: *Allocator, connection_string: []const u8) !void {
    allocator = sql_allocator;

    connection = try zdb.DBConnection.initWithConnectionString("DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;");
    try connection.setCommitMode(.manual);
}

pub fn deinit() void {
    connection.deinit();
}

pub fn getAllocator() *Allocator {
    return allocator;
}

pub fn execute(comptime statement: []const u8, params: anytype) !void {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    const sql_query = if (params.len > 0) try std.fmt.allocPrint(allocator, statement, params) else statement;
    defer if (params.len > 0) allocator.free(sql_query);

    _ = try cursor.statement.executeDirect(sql_query);
}

pub fn query(comptime StructType: type, comptime statement: []const u8, params: anytype) ![]StructType {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    const sql_query = if (params.len > 0) try std.fmt.allocPrint(allocator, statement, params) else statement;
    defer if (params.len > 0) allocator.free(sql_query);

    var tuplas = try cursor.executeDirect(StructType, .{}, sql_query);
    defer tuplas.deinit();

    // TODO para liberar esto tienes que usar el allocator del cursor..
    return tuplas.getAllRows();
}

pub fn querySingle(comptime StructType: type, comptime statement: []const u8, params: anytype) !?StructType {
    if (@typeInfo(StructType) != .Struct) {
        @compileError("querySingle: StructType must be a struct, you may want to use querySingleValue instead");
    }

    const tuplas = try query(StructType, statement, params);
    defer allocator.free(tuplas);

    if (tuplas.len > 1) {
        @panic("querySingle returned more than one tuple\n");
    }

    return if (tuplas.len > 0) tuplas[0] else null;
}

pub fn querySingleValue(comptime Type: type, comptime statement: []const u8, params: anytype) !?Type {
    if (@typeInfo(Type) == .Struct) {
        @compileError("querySingleValue with struct type: use querySingle instead");
    }

    const StructType = struct {
        value: Type,
    };

    const value_struct = (try querySingle(StructType, statement, params)) orelse return null;
    return value_struct.value;
}

pub fn insert(comptime StructType: type, comptime table_name: []const u8, values: []const StructType) !usize {
    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;
    return try cursor.insert(StructType, table_name, values);
}

pub fn createSavePoint(comptime nombre: []const u8) !void {
    try execute("SAVEPOINT " ++ nombre, .{});
}

pub fn rollbackToSavePoint(comptime nombre: ?[]const u8) !void {
    if (nombre) |s| {
        try execute("ROLLBACK TO " ++ s, .{});
    } else {
        try execute("ROLLBACK", .{});
    }
}
