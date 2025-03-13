//! A `SourceObject` represents a source file or buffer that is to be processed
//! by the Elyra compiler.
//!
//! The `SourceObject` struct is used to store the contents of a source file or
//! buffer, along with the filename of the source. It owns the memory for the
//! source text, and will free it when it is deinited.

const std = @import("std");
const builtin = @import("builtin");
const Self = @This();

text: []const u8,
filename: []const u8,
backing_buffer: []const u8,
backing_allocator: std.mem.Allocator,

/// Initializes a `SourceObject` from a file on disk.
/// The `allocator` parameter is used to allocate memory for the `SourceObject`.
/// The `path` parameter is the path to the file to read.
pub fn init_from_file(allocator: std.mem.Allocator, path: []const u8) !Self {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const size = try file.getEndPos();

    // We allocate an extra 4 bytes to store null terminators, allowing us to
    // safely "overread" the buffer in lookahead operations.
    var text = try allocator.alloc(u8, size + 4);
    const backing = text;
    @memset(text, 0);
    text.len = size;

    errdefer allocator.free(text);

    const read = try file.read(text[0..size]);

    if (read != size) {
        return error.SizeMismatch;
    }

    return .{
        .backing_allocator = allocator,
        .filename = try allocator.dupe(u8, path),
        .text = text,
        .backing_buffer = backing,
    };
}

/// Initializes a `SourceObject` from a buffer in memory.
/// The `allocator` parameter is used to allocate memory for the `SourceObject`.
/// The `filename` parameter is the name of the file that the buffer represents.
/// The `text` parameter is the buffer containing the source text.
pub fn init_from_buffer(allocator: std.mem.Allocator, filename: []const u8, text: []const u8) !Self {
    var dup_text = try allocator.alloc(u8, text.len + 4);
    const backing = dup_text;

    @memset(dup_text, 0);
    dup_text.len = text.len;

    @memcpy(dup_text, text);

    const source_object = Self{
        .backing_allocator = allocator,
        .filename = try allocator.dupe(u8, filename),
        .backing_buffer = backing,
        .text = dup_text,
    };

    return source_object;
}

/// Deinitializes a `SourceObject`, freeing the memory used by the source text.
pub fn deinit(self: *Self) void {
    self.backing_allocator.free(self.backing_buffer);
    self.backing_allocator.free(self.filename);
}

/// Returns the number of lines in the source text.
pub fn get_line_count(self: *Self) u32 {
    var line_count: u32 = 1;

    for (self.text) |c| {
        if (c == '\n') {
            line_count += 1;
        }
    }

    return line_count;
}

test "deinit" {
    var source_object = try Self.init_from_buffer(std.testing.allocator, "test.ely", "Hello, world!");
    source_object.deinit();
}
