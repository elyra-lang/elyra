const std = @import("std");
const elyra = @import("elyra");

fn find_n_newline_position(buffer: []const u8, n: usize) usize {
    var i: usize = 0;
    var count: usize = 0;

    while (i < buffer.len) {
        if (buffer[i] == '\n') {
            count += 1;
            if (count == n) {
                return i;
            }
        }
        i += 1;
    }

    return buffer.len;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.time.sleep(std.time.ns_per_s * 4);
    std.debug.print("Lexer/lines\t\tIterations\tTime(us)\tToken/s\tLine/s\tByte/s\n", .{});

    var total_lines: u32 = 256;
    for (0..6) |_| {
        // Total lines
        const its = (1024 * 1024 * 10) / total_lines;

        var source_object = try elyra.SourceObject.init_from_file(gpa.allocator(), "test.ely");
        var time: i128 = 0;
        var tokens: usize = 0;
        var bytes: usize = 0;
        for (0..its) |_| {
            var arena = std.heap.ArenaAllocator.init(gpa.allocator());
            defer arena.deinit();

            const allocator = arena.allocator();
            const real_len = source_object.text.len;
            source_object.text = source_object.text[0..find_n_newline_position(source_object.text, total_lines)];

            const start_time = std.time.nanoTimestamp();
            const token_buffer = try elyra.Tokenizer.tokenize(allocator, &source_object);
            tokens = token_buffer.tokens.len;
            bytes = source_object.text.len;

            const end_time = std.time.nanoTimestamp();

            time += end_time - start_time;
            source_object.text.len = real_len;
        }

        const avg_time = @as(f64, @floatFromInt(time)) / @as(f64, @floatFromInt(its)) / @as(f64, @floatFromInt(std.time.ns_per_s));
        const avg_tokens_per_second = @as(f64, @floatFromInt(tokens)) / avg_time;
        const avg_lines_per_second = @as(f64, @floatFromInt(total_lines)) / avg_time;
        const avg_throughput = @as(f64, @floatFromInt(bytes)) / avg_time;

        const mtoken = avg_tokens_per_second / 1_000_000.0;
        const mlines = avg_lines_per_second / 1_000_000.0;
        const mbps = avg_throughput / 1_000_000.0;

        std.debug.print("Lexer/{}\t\t{}\t\t{}us\t\t{d:.2}M\t{d:.2}M\t{d:.2}M\n", .{ total_lines, its, @divTrunc(time, its * 1000), mtoken, mlines, mbps });

        total_lines *= 4;
    }
}
