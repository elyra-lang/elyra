const std = @import("std");
const testing = std.testing;

const SourceObject = @import("../source/SourceObject.zig");
const tokenize = @import("../tokenizer/tokenize.zig").tokenize;
const parse = @import("parse.zig").parse;

const ParseNode = @import("types.zig").ParseNode;
const NodeKind = @import("types.zig").NodeKind;

test "parse let declaration" {
    const source = "let PI = 3.14159;";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);

    var parse_tree = try parse(testing.allocator, &token_buffer);
    defer parse_tree.deinit();

    try testing.expectEqualSlices(ParseNode, &[_]ParseNode{
        .{ .kind = @intFromEnum(NodeKind.LetMutability), .tag = 0 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 1 },
        .{ .kind = @intFromEnum(NodeKind.Literal), .tag = 3 },
        .{ .kind = @intFromEnum(NodeKind.Declaration), .tag = 0 },
    }, parse_tree.nodes);
}

test "parse variable declaration" {
    const source = "pub var counter = 0;";

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);

    var parse_tree = try parse(testing.allocator, &token_buffer);
    defer parse_tree.deinit();

    try testing.expectEqualSlices(ParseNode, &[_]ParseNode{
        .{ .kind = @intFromEnum(NodeKind.VarMutability), .tag = 1 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 2 },
        .{ .kind = @intFromEnum(NodeKind.Literal), .tag = 4 },
        .{ .kind = @intFromEnum(NodeKind.Declaration), .tag = 0 },
    }, parse_tree.nodes);
}

test "parse multiple declarations" {
    const source =
        \\ let success : str = "Success!";
        \\ let failure = 'F';
        \\ pub var status = success;
    ;

    var source_object = try SourceObject.init_from_buffer(testing.allocator, "test.ely", source);
    var token_buffer = try tokenize(testing.allocator, &source_object);

    var parse_tree = try parse(testing.allocator, &token_buffer);
    defer parse_tree.deinit();

    try testing.expectEqualSlices(ParseNode, &[_]ParseNode{
        .{ .kind = @intFromEnum(NodeKind.LetMutability), .tag = 0 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 1 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 3 },
        .{ .kind = @intFromEnum(NodeKind.SpecifiedIdentifier), .tag = 1 },
        .{ .kind = @intFromEnum(NodeKind.Literal), .tag = 5 },
        .{ .kind = @intFromEnum(NodeKind.Declaration), .tag = 0 },
        .{ .kind = @intFromEnum(NodeKind.LetMutability), .tag = 0 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 8 },
        .{ .kind = @intFromEnum(NodeKind.Literal), .tag = 10 },
        .{ .kind = @intFromEnum(NodeKind.Declaration), .tag = 6 },
        .{ .kind = @intFromEnum(NodeKind.VarMutability), .tag = 1 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 14 },
        .{ .kind = @intFromEnum(NodeKind.Identifier), .tag = 16 },
        .{ .kind = @intFromEnum(NodeKind.Declaration), .tag = 10 },
    }, parse_tree.nodes);
}
