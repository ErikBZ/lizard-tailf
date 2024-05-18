const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const process = std.process;

const DEFAULT_LINES = 10;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = process.args();
    _ = args.skip();

    const path = args.next();

    if (path) |good_path| {
        try dumb_tail(good_path, allocator);
    } else {
        print_usage();
    }
}

fn print_usage() void {
    std.debug.print("Usage: lizard-tail [OPTION]... [FILE]...\n", .{});
    std.debug.print("Print the last 10 lines of each FILE to standard output\n", .{});
}

fn dumb_tail(path: []const u8, allocator: Allocator) !void {
    const file = try std.fs.cwd().openFile(path, .{});

    var lines = ArrayList([]const u8).init(allocator);
    defer {
        file.close();
        lines.deinit();
    }

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;

    // need to copy line into a new []const u8
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const stuff = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, stuff, line);
        try lines.append(stuff);
    }

    const end = lines.items.len;
    const start = if (end > DEFAULT_LINES) end - DEFAULT_LINES else 0;

    for (lines.items[start..end]) |line| {
        std.debug.print("{s}\n", .{line});
    }

    // just 2 dots for the index stuff
    for (lines.items) |line| {
        allocator.free(line);
    }
}

test "Test for memory leaks in dumb_tail" {
    const test_allocator = std.testing.allocator;
    try dumb_tail("foo.txt", test_allocator);
}
