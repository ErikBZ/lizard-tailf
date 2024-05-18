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
    const usage =
        \\ Usage: lizard-tail [OPTION]... [FILE]...
        \\ Print the last 10 lines of each FILE to standard output.
        \\ With more than one FILE, precede each with a header giving the file name.
        \\ 
        \\ With no FILE, or when FILE is -, read standard input.
        \\ 
        \\ Mandatory arguments to long options are mandatory for short options too.
        \\   -c, --bytes=[+]NUM       output the last NUM bytes; or use -c +NUM to
        \\                              output starting with byte NUM of each file
        \\   -f, --follow[={name|descriptor}]
        \\                            output appended data as the file grows;
        \\                              an absent option argument means 'descriptor'
        \\   -F                       same as --follow=name --retry
        \\   -n, --lines=[+]NUM       output the last NUM lines, instead of the last 10;
        \\                              or use -n +NUM to output starting with line NUM
        \\       --max-unchanged-stats=N
        \\                            with --follow=name, reopen a FILE which has not
        \\                              changed size after N (default 5) iterations
        \\                              to see if it has been unlinked or renamed
        \\                              (this is the usual case of rotated log files);
        \\                              with inotify, this option is rarely useful
        \\       --pid=PID            with -f, terminate after process ID, PID dies
        \\   -q, --quiet, --silent    never output headers giving file names
        \\       --retry              keep trying to open a file if it is inaccessible
        \\   -s, --sleep-interval=N   with -f, sleep for approximately N seconds
        \\                              (default 1.0) between iterations;
        \\                              with inotify and --pid=P, check process P at
        \\                              least once every N seconds
        \\   -v, --verbose            always output headers giving file names
        \\   -z, --zero-terminated    line delimiter is NUL, not newline
        \\       --help     display this help and exit
        \\       --version  output version information and exit
        \\ 
        \\ NUM may have a multiplier suffix:
        \\ b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,
        \\ GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E, Z, Y.
        \\ Binary prefixes can be used, too: KiB=K, MiB=M, and so on.
        \\ 
        \\ With --follow (-f), tail defaults to following the file descriptor, which
        \\ means that even if a tail'ed file is renamed, tail will continue to track
        \\ its end.  This default behavior is not desirable when you really want to
        \\ track the actual name of the file, not the file descriptor (e.g., log
        \\ rotation).  Use --follow=name in that case.  That causes tail to track the
        \\ named file in a way that accommodates renaming, removal and creation.
        \\ 
        \\ GNU coreutils online help: <https://www.gnu.org/software/coreutils/>
        \\ Report any translation bugs to <https://translationproject.org/team/>
        \\ Full documentation <https://www.gnu.org/software/coreutils/tail>
        \\ or available locally via: info '(coreutils) tail invocation'
    ;

    std.debug.print("{s}", .{usage});
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
