const std = @import("std");
const zdb = @import("zdb");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();


    const allocator = &gpa.allocator;

    var connection = try zdb.DBConnection.initWithConnectionString("DRIVER={Oracle 21 ODBC driver};DBQ=oracle0.ugr.es:1521/practbd.oracle0.ugr.es;UID=x7034014;PWD=x7034014;");
    defer connection.deinit();

    std.log.info("Connected!\n", .{});

    var cursor = try connection.getCursor(allocator);
    defer cursor.deinit() catch unreachable;

    // const value = maybe_foo().?;
   // try cursor.executeDirect()
}
