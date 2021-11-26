const std = @import("std");

pub fn readNumber(comptime T: type, in: std.fs.File.Reader) !T {
    var stdout = std.io.getStdOut().writer();
    var buf: [10]u8 = undefined;

    while (true) {
        // Leer entrada
        try stdout.print("> ", .{});
        const input_str = (try in.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.EndOfFile;

        // Parsear la entrada como un entero de tipo `T`
        const input = std.fmt.parseInt(T, input_str, 10) catch {
            try stdout.print("Debes introducir un número\n\n", .{});
            continue;
        };
        return input;
    }
}

pub const DateTime = struct {
    day: u8,
    month: u8,
    year: u16,
    hour: u8,
    minute: u8,
    second: u8,

    pub fn fromTimestamp(timestamp: i64) DateTime {
        // aus https://de.wikipedia.org/wiki/Unixzeit
        const unixtime = @intCast(u64, timestamp);
        const SEKUNDEN_PRO_TAG = 86400; //*  24* 60 * 60 */
        const TAGE_IM_GEMEINJAHR = 365; //* kein Schaltjahr */
        const TAGE_IN_4_JAHREN = 1461; //*   4*365 +   1 */
        const TAGE_IN_100_JAHREN = 36524; //* 100*365 +  25 - 1 */
        const TAGE_IN_400_JAHREN = 146097; //* 400*365 + 100 - 4 + 1 */
        const TAGN_AD_1970_01_01 = 719468; //* Tagnummer bezogen auf den 1. Maerz des Jahres "Null" */

        var tagN: u64 = TAGN_AD_1970_01_01 + unixtime / SEKUNDEN_PRO_TAG;
        var sekunden_seit_Mitternacht: u64 = unixtime % SEKUNDEN_PRO_TAG;
        var temp: u64 = 0;

        // Schaltjahrregel des Gregorianischen Kalenders:
        // Jedes durch 100 teilbare Jahr ist kein Schaltjahr, es sei denn, es ist durch 400 teilbar.
        temp = 4 * (tagN + TAGE_IN_100_JAHREN + 1) / TAGE_IN_400_JAHREN - 1;
        var jahr = @intCast(u16, 100 * temp);
        tagN -= TAGE_IN_100_JAHREN * temp + temp / 4;

        // Schaltjahrregel des Julianischen Kalenders:
        // Jedes durch 4 teilbare Jahr ist ein Schaltjahr.
        temp = 4 * (tagN + TAGE_IM_GEMEINJAHR + 1) / TAGE_IN_4_JAHREN - 1;
        jahr += @intCast(u16, temp);
        tagN -= TAGE_IM_GEMEINJAHR * temp + temp / 4;

        // TagN enthaelt jetzt nur noch die Tage des errechneten Jahres bezogen auf den 1. Maerz.
        var monat = @intCast(u8, (5 * tagN + 2) / 153);
        var tag = @intCast(u8, tagN - (@intCast(u64, monat) * 153 + 2) / 5 + 1);
        //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von Maerz bis Juli
        //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von August bis Dezember
        //        31+28          Tage fuer Januar und Februar (siehe unten)
        //  +2: Justierung der Rundung
        //  +1: Der erste Tag im Monat ist 1 (und nicht 0).

        monat += 3; // vom Jahr, das am 1. Maerz beginnt auf unser normales Jahr umrechnen: */
        if (monat > 12) { // Monate 13 und 14 entsprechen 1 (Januar) und 2 (Februar) des naechsten Jahres
            monat -= 12;
            jahr += 1;
        }

        var stunde = @intCast(u8, sekunden_seit_Mitternacht / 3600);
        var minute = @intCast(u8, sekunden_seit_Mitternacht % 3600 / 60);
        var sekunde = @intCast(u8, sekunden_seit_Mitternacht % 60);

        return DateTime{ .day = tag, .month = monat, .year = jahr, .hour = stunde, .minute = minute, .second = sekunde };
    }
};
