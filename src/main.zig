const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const process = std.process;

const DEFAULT_LINES = 10;

const CommandLineArgs = struct { number_of_lines: u32, files: ArrayList([]const u8), follow: bool, help: bool };

const CommandParsingError = error{
    NoNumLinesProvided,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const command_line_args = try get_command_line_args(allocator);

    if (command_line_args.help) {
        print_usage();
    } else if (command_line_args.files.items.len > 0) {
        for (command_line_args.files.items) |path| {
            if (command_line_args.files.items.len > 1) {
                std.debug.print("==> {s} <==\n\n", .{path});
            }
            try dumb_tail(path, command_line_args.number_of_lines, allocator);
        }
    } else if (command_line_args.follow) {
        todo_dumb_tail_follow();
    }

    for (command_line_args.files.items) |path| {
        allocator.free(path);
    }
    command_line_args.files.deinit();
}

fn get_command_line_args(allocator: Allocator) !CommandLineArgs {
    var args = process.args();
    _ = args.skip();

    var command_line_args = CommandLineArgs{ .number_of_lines = DEFAULT_LINES, .files = ArrayList([]const u8).init(allocator), .follow = false, .help = false };
    errdefer {
        for (command_line_args.files.items) |path| {
            allocator.free(path);
        }
        command_line_args.files.deinit();
        print_usage();
    }

    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "-n")) {
            if (args.next()) |num_lines| {
                command_line_args.number_of_lines = try std.fmt.parseInt(u32, num_lines, 10);
            } else {
                return CommandParsingError.NoNumLinesProvided;
            }
        } else if (std.mem.eql(u8, path, "-f")) {
            command_line_args.follow = true;
        } else if (std.mem.eql(u8, path, "--help")) {
            command_line_args.help = true;
        } else {
            const next_path: []u8 = try allocator.alloc(u8, path.len);
            std.mem.copyForwards(u8, next_path, path);
            try command_line_args.files.append(next_path);
        }
    }

    return command_line_args;
}

fn print_usage() void {
    const usage =
        \\Usage: lizard-tail [OPTION]... [FILE]...
        \\Print the last 10 lines of each FILE to standard output.
        \\With more than one FILE, precede each with a header giving the file name.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -c, --bytes=[+]NUM       output the last NUM bytes; or use -c +NUM to
        \\                             output starting with byte NUM of each file
        \\  -f, --follow[={name|descriptor}]
        \\                           output appended data as the file grows;
        \\                             an absent option argument means 'descriptor'
        \\  -F                       same as --follow=name --retry
        \\  -n, --lines=[+]NUM       output the last NUM lines, instead of the last 10;
        \\                             or use -n +NUM to output starting with line NUM
        \\      --max-unchanged-stats=N
        \\                           with --follow=name, reopen a FILE which has not
        \\                             changed size after N (default 5) iterations
        \\                             to see if it has been unlinked or renamed
        \\                             (this is the usual case of rotated log files);
        \\                             with inotify, this option is rarely useful
        \\      --pid=PID            with -f, terminate after process ID, PID dies
        \\  -q, --quiet, --silent    never output headers giving file names
        \\      --retry              keep trying to open a file if it is inaccessible
        \\  -s, --sleep-interval=N   with -f, sleep for approximately N seconds
        \\                             (default 1.0) between iterations;
        \\                             with inotify and --pid=P, check process P at
        \\                             least once every N seconds
        \\  -v, --verbose            always output headers giving file names
        \\  -z, --zero-terminated    line delimiter is NUL, not newline
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\NUM may have a multiplier suffix:
        \\b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,
        \\GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E, Z, Y.
        \\Binary prefixes can be used, too: KiB=K, MiB=M, and so on.
        \\
        \\With --follow (-f), tail defaults to following the file descriptor, which
        \\means that even if a tail'ed file is renamed, tail will continue to track
        \\its end.  This default behavior is not desirable when you really want to
        \\track the actual name of the file, not the file descriptor (e.g., log
        \\rotation).  Use --follow=name in that case.  That causes tail to track the
        \\named file in a way that accommodates renaming, removal and creation.
        \\
        \\GNU coreutils online help: <https://www.gnu.org/software/coreutils/>
        \\Report any translation bugs to <https://translationproject.org/team/>
        \\Full documentation <https://www.gnu.org/software/coreutils/tail>
        \\or available locally via: info '(coreutils) tail invocation'
    ;

    std.debug.print("{s}", .{usage});
}

fn dumb_tail(path: []const u8, num_of_lines: u32, allocator: Allocator) !void {
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
    const start = if (end > num_of_lines) end - num_of_lines else 0;

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

fn todo_dumb_tail_follow() void {}
