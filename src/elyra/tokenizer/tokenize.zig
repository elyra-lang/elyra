const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const ztracy = @import("ztracy");

const SourceObject = @import("../source/SourceObject.zig");
const Token = types.Token;
const TokenKind = types.TokenKind;
const TokenBuffer = types.TokenBuffer;

/// Convenience object to hold the state of the tokenizer.
const TokenizerState = struct {
    source: *SourceObject,
    tokens: std.ArrayList(Token),
};

/// Keyword Map
const KeywordMap = std.StaticStringMap(TokenKind);
const KeywordPairs = .{
    .{ "true", .True },
    .{ "false", .False },
    .{ "null", .Null },
    .{ "and", .BooleanAnd },
    .{ "or", .BooleanOr },
    .{ "let", .Let },
    .{ "var", .Var },
    .{ "func", .Func },
    .{ "return", .Return },
    .{ "match", .Match },
    .{ "if", .If },
    .{ "else", .Else },
    .{ "struct", .Struct },
    .{ "trait", .Trait },
    .{ "import", .Import },
    .{ "while", .While },
    .{ "for", .For },
    .{ "break", .Break },
    .{ "continue", .Continue },
    .{ "temp", .Temp },
    .{ "pub", .Pub },
};

/// Tokenizes a source object.
/// This function tokenizes the source object and returns a token buffer.
/// The token buffer contains a list of tokens and a reference to the source object.
/// The source object is not modified by this function, but becomes owned by the TokenBuffer.
/// The token buffer is allocated using the provided allocator.
/// The source object is deallocated when the token buffer is deallocated.
/// The token buffer is deallocated when the token buffer is deallocated.
///
/// The tokenization process is a highly-optimized loop that reads each character in the source text.
/// The loop appends a token to the token list for each character.
/// The token list is then converted to an owned slice.
///
/// The tokenization process is optimized for speed and memory usage.
/// The tokenization process is not guaranteed to be thread-safe, but is parallelizable.
pub noinline fn tokenize(allocator: std.mem.Allocator, source: *SourceObject) !TokenBuffer {
    // Start the Tracy frame for the tokenizer
    ztracy.FrameMarkStart("Tokenize");
    defer ztracy.FrameMarkEnd("Tokenize");

    var tokens = try std.ArrayList(Token).initCapacity(allocator, source.text.len / 4);
    var mapping_table = try std.ArrayList(types.Mapping).initCapacity(allocator, source.text.len / 4);
    var value_table = try std.ArrayList(u64).initCapacity(allocator, source.text.len / 4);

    const text_ptr = source.text.ptr;
    var i: u24 = 0;

    const kmap = KeywordMap.initComptime(KeywordPairs);

    // While true with unlikely branch hint
    while (true) : (i += 1) {
        if (i >= source.text.len) {
            @branchHint(.unlikely);
            break;
        }

        @prefetch(text_ptr, .{});
        const c = text_ptr[i];
        if (is_space_table[c]) {
            continue;
        } else if (is_alpha_table[c]) {
            const pos = i;

            i += 1;
            while (is_alphanum_table[text_ptr[i]]) : (i += 1) {}
            const slice = text_ptr[pos..i];

            // It can be a keyword
            if (kmap.get(slice)) |kw| {
                tokens.append(.{
                    .kind = @intFromEnum(kw),
                    .position = pos,
                }) catch unreachable;
            } else {
                tokens.append(.{
                    .kind = @intFromEnum(TokenKind.Identifier),
                    .position = pos,
                }) catch unreachable;
            }

            continue;
        } else if (is_num_table[c]) {
            // TODO: Add to value table
            const pos = i;

            var kind = TokenKind.IntLiteral;
            while (is_num_table[text_ptr[i]] or is_dot_table[text_ptr[i]]) : (i += 1) {
                if (is_dot_table[text_ptr[i]]) {
                    i += 1;
                    while (is_num_table[text_ptr[i]]) : (i += 1) {}
                    kind = TokenKind.FloatLiteral;
                    break;
                }
            }

            // Yay, we don't have to parse it ourselves!
            value_table.append(if (kind == .IntLiteral)
                @bitCast(std.fmt.parseInt(u64, text_ptr[pos..i], 0) catch unreachable)
            else
                @bitCast(std.fmt.parseFloat(f64, text_ptr[pos..i]) catch unreachable)) catch unreachable;

            tokens.append(.{
                .kind = @intFromEnum(kind),
                .position = pos,
            }) catch unreachable;

            mapping_table.append(.{
                .token = @bitCast(tokens.items[tokens.items.len - 1]),
                .index = @intCast(value_table.items.len - 1),
            }) catch unreachable;

            continue;
        } else if (is_comment_table[c]) {
            // Find newline
            while (!is_newline_table[text_ptr[i]]) : (i += 1) {}
            i += 1;
            continue;
        } else if (is_string_table[c]) {
            const pos = i;

            i += 1;
            while (!is_string_table[text_ptr[i]]) : (i += 1) {}
            i += 1;

            tokens.append(.{
                .kind = @intFromEnum(TokenKind.StringLiteral),
                .position = pos,
            }) catch unreachable;

            continue;
        } else if (is_identity_map_table[c]) {
            tokens.append(.{
                .kind = c,
                .position = i,
            }) catch unreachable;
            continue;
        } else if (is_normal_op_table[c]) {
            var base = normal_op_map_table[c];
            const pos = i;

            if (text_ptr[i + 1] == '=') {
                base += 1;
                i += 1;
            }

            tokens.append(.{
                .kind = base,
                .position = pos,
            }) catch unreachable;
            continue;
        } else if (is_complex_op_table[c]) {
            var base = complex_op_map_table[c];
            const pos = i;

            switch (text_ptr[i + 1]) {
                '=' => {
                    base += 1;
                    i += 1;
                },
                '|' => {
                    if (text_ptr[i + 2] == '=') {
                        base += 4;
                        i += 2;
                    } else {
                        base += 2;
                        i += 1;
                    }
                },
                '%' => {
                    if (text_ptr[i + 2] == '=') {
                        base += 5;
                        i += 2;
                    } else {
                        base += 3;
                        i += 1;
                    }
                },
                '>' => {
                    if (base == 136) {
                        base += 38;
                        i += 1;
                    }
                },
                ' ' => {},
                else => {
                    if (base == @intFromEnum(TokenKind.Add)) {
                        base = @intFromEnum(TokenKind.AddUnary);
                    } else if (base == @intFromEnum(TokenKind.Sub)) {
                        base = @intFromEnum(TokenKind.SubUnary);
                    }
                },
            }

            tokens.append(.{
                .kind = base,
                .position = pos,
            }) catch unreachable;
            continue;
        } else if (is_right_angle_table[c]) {
            if (text_ptr[i + 1] == '>') {
                if (text_ptr[i + 2] == '=') {
                    tokens.append(.{
                        .kind = @intFromEnum(TokenKind.ShiftRightEq),
                        .position = i,
                    }) catch unreachable;
                    i += 2;
                } else {
                    tokens.append(.{
                        .kind = @intFromEnum(TokenKind.ShiftRight),
                        .position = i,
                    }) catch unreachable;
                    i += 1;
                }
            } else if (text_ptr[i + 1] == '=') {
                tokens.append(.{
                    .kind = @intFromEnum(TokenKind.GreaterEq),
                    .position = i,
                }) catch unreachable;
                i += 1;
            } else {
                tokens.append(.{
                    .kind = @intFromEnum(TokenKind.Greater),
                    .position = i,
                }) catch unreachable;
            }
            continue;
        } else if (is_left_angle_table[c]) {
            if (text_ptr[i + 1] == '<') {
                if (text_ptr[i + 2] == '|') {
                    if (text_ptr[i + 3] == '=') {
                        tokens.append(.{
                            .kind = @intFromEnum(TokenKind.ShiftLeftSatEq),
                            .position = i,
                        }) catch unreachable;
                        i += 3;
                    } else {
                        tokens.append(.{
                            .kind = @intFromEnum(TokenKind.ShiftLeftSat),
                            .position = i,
                        }) catch unreachable;
                        i += 2;
                    }
                } else if (text_ptr[i + 2] == '=') {
                    tokens.append(.{
                        .kind = @intFromEnum(TokenKind.ShiftLeftEq),
                        .position = i,
                    }) catch unreachable;
                    i += 2;
                } else {
                    tokens.append(.{
                        .kind = @intFromEnum(TokenKind.ShiftLeft),
                        .position = i,
                    }) catch unreachable;
                    i += 1;
                }
            } else if (text_ptr[i + 1] == '=') {
                tokens.append(.{
                    .kind = @intFromEnum(TokenKind.LessEq),
                    .position = i,
                }) catch unreachable;
                i += 1;
            } else {
                tokens.append(.{
                    .kind = @intFromEnum(TokenKind
                        .Less),
                    .position = i,
                }) catch unreachable;
            }
            continue;
        } else if (is_char_table[c]) {
            tokens.append(.{
                .kind = @intFromEnum(TokenKind.CharLiteral),
                .position = i,
            }) catch unreachable;

            i += 2;
            continue;
        }

        if (c != 0) {
            @branchHint(.unlikely);
            std.debug.print("Unexpected character: '{}'\n", .{c});
            unreachable;
        }
    }

    // Reclaim memory from the tokens array if overallocated
    tokens.shrinkAndFree(tokens.items.len);
    value_table.shrinkAndFree(value_table.items.len);

    return .{
        .backing_allocator = allocator,
        .source = source,
        .tokens = try tokens.toOwnedSlice(),
        .mapping_table = try mapping_table.toOwnedSlice(),
        .value_table = try value_table.toOwnedSlice(),
    };
}

// Lookup tables for ASCII characters
// I tried making these bits only, but it was slower
// TODO: Revisit this and see if it can be optimized further

/// Creates a lookup table for ASCII characters.
fn create_ascii_bool_table(comptime string: []const u8) [256]bool {
    var table: [256]bool = @splat(false);
    for (string) |byte| {
        table[byte] = true;
    }
    return table;
}

const is_space_table = create_ascii_bool_table(&.{ ' ', '\t', '\n', '\r' });
const is_identity_map_table = create_ascii_bool_table(&.{ '(', ')', '{', '}', '[', ']', ',', '.', ';', ':', '?' });
const is_normal_op_table = create_ascii_bool_table(&.{ '/', '%', '&', '|', '^', '~', '!', '=' });
const is_complex_op_table = create_ascii_bool_table(&.{ '+', '-', '*' });
const is_left_angle_table = create_ascii_bool_table(&.{'<'});
const is_right_angle_table = create_ascii_bool_table(&.{'>'});
const is_string_table = create_ascii_bool_table(&.{ 0, '"' }); // Null is for end of file
const is_char_table = create_ascii_bool_table(&.{'\''});
const is_num_table = create_ascii_bool_table(&.{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' });
const is_alpha_table = create_ascii_bool_table(&.{ '_', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' });
const is_comment_table = create_ascii_bool_table(&.{'#'});
const is_alphanum_table = create_ascii_bool_table(&.{ '_', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' });
const is_newline_table = create_ascii_bool_table(&.{ '\n', '\r' });
const is_dot_table = create_ascii_bool_table(&.{'.'});

/// Creates a lookup table for ASCII characters to map to values.
fn create_ascii_val_table(comptime string: []const u8, comptime vals: []const u8) [256]u8 {
    var table: [256]u8 = @splat(0);
    for (string, vals) |k, v| {
        table[k] = v;
    }
    return table;
}

const normal_op_map_table = create_ascii_val_table(&.{ '/', '%', '&', '|', '^', '~', '!', '=' }, &.{
    @intFromEnum(TokenKind.Div),
    @intFromEnum(TokenKind.Rem),
    @intFromEnum(TokenKind.BitAnd),
    @intFromEnum(TokenKind.BitOr),
    @intFromEnum(TokenKind.BitXor),
    @intFromEnum(TokenKind.BitNot),
    @intFromEnum(TokenKind.ErrUnion),
    @intFromEnum(TokenKind.Assign),
});

const complex_op_map_table = create_ascii_val_table(&.{ '+', '-', '*' }, &.{
    @intFromEnum(TokenKind.Add),
    @intFromEnum(TokenKind.Sub),
    @intFromEnum(TokenKind.Mul),
});
