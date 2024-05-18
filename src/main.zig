const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var file = try std.fs.cwd().openFile("foo.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // this line messed up i bet
        try stdout.print("{s}\n", .{line});
    }

    try stdout.print("Hello World\n", .{});

    // clean up
    try bw.flush();
}

// TODO create function for opening a file and reading the whole file.
// then count the newlines and split across em
