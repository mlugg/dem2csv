const std = @import("std");

fn convertPacket(r: anytype, w: anytype, tick: i32) !void {
    var slot: u8 = 0;
    while (slot < 2) : (slot += 1) {
        try r.skipBytes(4, .{});
        const x = @bitCast(f32, try r.readIntLittle(u32));
        const y = @bitCast(f32, try r.readIntLittle(u32));
        const z = @bitCast(f32, try r.readIntLittle(u32));
        const pitch = @bitCast(f32, try r.readIntLittle(u32));
        const yaw = @bitCast(f32, try r.readIntLittle(u32));
        const roll = @bitCast(f32, try r.readIntLittle(u32));
        try r.skipBytes(12 * 4, .{});

        if (tick > 0 and slot == 0) {
            try w.print("{},{},{d},{d},{d},{d},{d},{d}\n", .{
                slot,
                tick,
                x,
                y,
                z,
                pitch,
                yaw,
                roll,
            });
        }
    }
    try r.skipBytes(8, .{});
    try r.skipBytes(try r.readIntLittle(u32), .{});
}

fn convert(r: anytype, w: anytype) !void {
    if (!try r.isBytes("HL2DEMO\x00")) return error.BadDemo;
    try r.skipBytes(24 + 4 * 260, .{});
    try w.writeAll("slot,tick,x,y,z,pitch,yaw,roll\n");
    while (true) {
        const ty = try r.readByte();
        const tick = try r.readIntLittle(i32);
        const slot = try r.readByte();

        _ = slot;

        switch (ty) {
            1, 2 => { // SignOn / Packet
                try convertPacket(r, w, tick);
            },
            3 => {}, // SyncTick
            4 => { // Consolecmd
                try r.skipBytes(try r.readIntLittle(u32), .{});
            },
            5 => { // Usercmd
                try r.skipBytes(4, .{});
                try r.skipBytes(try r.readIntLittle(u32), .{});
            },
            6 => { // DataTables
                try r.skipBytes(try r.readIntLittle(u32), .{});
            },
            7 => break, // Stop
            8 => { // CustomData
                try r.skipBytes(4, .{});
                try r.skipBytes(try r.readIntLittle(u32), .{});
            },
            9 => { // StringTables
                try r.skipBytes(try r.readIntLittle(u32), .{});
            },
            else => return error.BadDemo,
        }
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    _ = args.skip();
    const demo_path = args.next() orelse return error.BadUsage;

    var demo = try std.fs.cwd().openFile(demo_path, .{});
    defer demo.close();

    var csv = try std.fs.cwd().createFile("demo.csv", .{});
    defer csv.close();

    var br = std.io.bufferedReader(demo.reader());
    var bw = std.io.bufferedWriter(csv.writer());
    defer bw.flush() catch {};

    try convert(br.reader(), bw.writer());
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
