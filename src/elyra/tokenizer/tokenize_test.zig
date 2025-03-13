const std = @import("std");
const testing = std.testing;

const tokenize = @import("tokenize.zig").tokenize;

const SourceObject = @import("../source/SourceObject.zig");
const Token = @import("types.zig").Token;
const TokenKind = @import("types.zig").TokenKind;
const TokenBuffer = @import("types.zig").TokenBuffer;

test "basic identity tokens" {
    const source = "(){}[],.;:?";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.LParen), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.RParen), .position = 1 },
        .{ .kind = @intFromEnum(TokenKind.LBrace), .position = 2 },
        .{ .kind = @intFromEnum(TokenKind.RBrace), .position = 3 },
        .{ .kind = @intFromEnum(TokenKind.LBracket), .position = 4 },
        .{ .kind = @intFromEnum(TokenKind.RBracket), .position = 5 },
        .{ .kind = @intFromEnum(TokenKind.Comma), .position = 6 },
        .{ .kind = @intFromEnum(TokenKind.Dot), .position = 7 },
        .{ .kind = @intFromEnum(TokenKind.Semicolon), .position = 8 },
        .{ .kind = @intFromEnum(TokenKind.Colon), .position = 9 },
        .{ .kind = @intFromEnum(TokenKind.Nullable), .position = 10 },
    }, token_buffer.tokens);
}

test "whitespace skipping" {
    const source = " \t\n\r";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{}, token_buffer.tokens);
}

test "whitespace skipping characters" {
    const source = "; \t\n\r;";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.Semicolon), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.Semicolon), .position = 5 },
    }, token_buffer.tokens);
}

test "add sub mul operator suite" {
    const source = "++ += +% +| +%= +|= -- -= -% -| -%= -|= * *= *| *% *%= *|=";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.AddUnary), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.Add), .position = 1 },
        .{ .kind = @intFromEnum(TokenKind.AddEq), .position = 3 },
        .{ .kind = @intFromEnum(TokenKind.AddWrap), .position = 6 },
        .{ .kind = @intFromEnum(TokenKind.AddSat), .position = 9 },
        .{ .kind = @intFromEnum(TokenKind.AddWrapEq), .position = 12 },
        .{ .kind = @intFromEnum(TokenKind.AddSatEq), .position = 16 },
        .{ .kind = @intFromEnum(TokenKind.SubUnary), .position = 20 },
        .{ .kind = @intFromEnum(TokenKind.Sub), .position = 21 },
        .{ .kind = @intFromEnum(TokenKind.SubEq), .position = 23 },
        .{ .kind = @intFromEnum(TokenKind.SubWrap), .position = 26 },
        .{ .kind = @intFromEnum(TokenKind.SubSat), .position = 29 },
        .{ .kind = @intFromEnum(TokenKind.SubWrapEq), .position = 32 },
        .{ .kind = @intFromEnum(TokenKind.SubSatEq), .position = 36 },
        .{ .kind = @intFromEnum(TokenKind.Mul), .position = 40 },
        .{ .kind = @intFromEnum(TokenKind.MulEq), .position = 42 },
        .{ .kind = @intFromEnum(TokenKind.MulSat), .position = 45 },
        .{ .kind = @intFromEnum(TokenKind.MulWrap), .position = 48 },
        .{ .kind = @intFromEnum(TokenKind.MulWrapEq), .position = 51 },
        .{ .kind = @intFromEnum(TokenKind.MulSatEq), .position = 55 },
    }, token_buffer.tokens);
}

test "curry operator" {
    const source = "->";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.CurryArrow), .position = 0 },
    }, token_buffer.tokens);
}

test "normal operator" {
    const source = "/ /= % %= & &= | |= ^ ^=";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.Div), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.DivEq), .position = 2 },
        .{ .kind = @intFromEnum(TokenKind.Rem), .position = 5 },
        .{ .kind = @intFromEnum(TokenKind.RemEq), .position = 7 },
        .{ .kind = @intFromEnum(TokenKind.BitAnd), .position = 10 },
        .{ .kind = @intFromEnum(TokenKind.BitAndEq), .position = 12 },
        .{ .kind = @intFromEnum(TokenKind.BitOr), .position = 15 },
        .{ .kind = @intFromEnum(TokenKind.BitOrEq), .position = 17 },
        .{ .kind = @intFromEnum(TokenKind.BitXor), .position = 20 },
        .{ .kind = @intFromEnum(TokenKind.BitXorEq), .position = 22 },
    }, token_buffer.tokens);
}

test "unary operators" {
    const source = "+ - +-.";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.Add), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.Sub), .position = 2 },
        .{ .kind = @intFromEnum(TokenKind.AddUnary), .position = 4 },
        .{ .kind = @intFromEnum(TokenKind.SubUnary), .position = 5 },
        .{ .kind = @intFromEnum(TokenKind.Dot), .position = 6 },
    }, token_buffer.tokens);
}

test "comparison operators" {
    const source = "< > <= >=";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.Less), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.Greater), .position = 2 },
        .{ .kind = @intFromEnum(TokenKind.LessEq), .position = 4 },
        .{ .kind = @intFromEnum(TokenKind.GreaterEq), .position = 7 },
    }, token_buffer.tokens);
}

test "shift operators" {
    const source = "<< <<= >> >>= <<| <<|=";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.ShiftLeft), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.ShiftLeftEq), .position = 3 },
        .{ .kind = @intFromEnum(TokenKind.ShiftRight), .position = 7 },
        .{ .kind = @intFromEnum(TokenKind.ShiftRightEq), .position = 10 },
        .{ .kind = @intFromEnum(TokenKind.ShiftLeftSat), .position = 14 },
        .{ .kind = @intFromEnum(TokenKind.ShiftLeftSatEq), .position = 18 },
    }, token_buffer.tokens);
}

test "literals" {
    const source = "'a' \"String\" 123456 3.14159";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.CharLiteral), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.StringLiteral), .position = 4 },
        .{ .kind = @intFromEnum(TokenKind.IntLiteral), .position = 13 },
        .{ .kind = @intFromEnum(TokenKind.FloatLiteral), .position = 20 },
    }, token_buffer.tokens);
}

test "identifier" {
    const source = "hello world";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.Identifier), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.Identifier), .position = 6 },
    }, token_buffer.tokens);
}

test "comment" {
    const source = "# This is a comment\n";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{}, token_buffer.tokens);
}

test "keywords" {
    const source = "true false null and or let var func return match if else struct trait import while for break continue temp pub";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);
    defer token_buffer.deinit();

    try testing.expectEqualSlices(Token, &.{
        .{ .kind = @intFromEnum(TokenKind.True), .position = 0 },
        .{ .kind = @intFromEnum(TokenKind.False), .position = 5 },
        .{ .kind = @intFromEnum(TokenKind.Null), .position = 11 },
        .{ .kind = @intFromEnum(TokenKind.BooleanAnd), .position = 16 },
        .{ .kind = @intFromEnum(TokenKind.BooleanOr), .position = 20 },
        .{ .kind = @intFromEnum(TokenKind.Let), .position = 23 },
        .{ .kind = @intFromEnum(TokenKind.Var), .position = 27 },
        .{ .kind = @intFromEnum(TokenKind.Func), .position = 31 },
        .{ .kind = @intFromEnum(TokenKind.Return), .position = 36 },
        .{ .kind = @intFromEnum(TokenKind.Match), .position = 43 },
        .{ .kind = @intFromEnum(TokenKind.If), .position = 49 },
        .{ .kind = @intFromEnum(TokenKind.Else), .position = 52 },
        .{ .kind = @intFromEnum(TokenKind.Struct), .position = 57 },
        .{ .kind = @intFromEnum(TokenKind.Trait), .position = 64 },
        .{ .kind = @intFromEnum(TokenKind.Import), .position = 70 },
        .{ .kind = @intFromEnum(TokenKind.While), .position = 77 },
        .{ .kind = @intFromEnum(TokenKind.For), .position = 83 },
        .{ .kind = @intFromEnum(TokenKind.Break), .position = 87 },
        .{ .kind = @intFromEnum(TokenKind.Continue), .position = 93 },
        .{ .kind = @intFromEnum(TokenKind.Temp), .position = 102 },
        .{ .kind = @intFromEnum(TokenKind.Pub), .position = 107 },
    }, token_buffer.tokens);
}
