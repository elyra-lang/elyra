const std = @import("std");
const TokenBuffer = @import("../tokenizer/types.zig").TokenBuffer;

/// The parse node represents a single node in the parse tree.
/// The `kind` is used to identify the type of node, and is of type NodeType.
/// The `index` is used to identify the corresponding token in the TokenBuffer.
pub const ParseNode = packed struct(u32) {
    kind: u8,
    index: u24,
};

/// The node types
pub const NodeType = enum(u8) {};

/// The parse tree represents a collection of parse nodes.
/// The `backing_allocator` is used to allocate memory for the nodes.
/// The `nodes` is an array of parse nodes.
/// The `token_buffer` is used to store the tokens associated with the parse tree.
pub const ParseTree = struct {
    backing_allocator: std.mem.Allocator,
    nodes: []ParseNode,
    token_buffer: *TokenBuffer,

    pub fn deinit(self: *ParseTree) void {
        self.backing_allocator.free(self.nodes);
        self.token_buffer.deinit();
        self.* = undefined;
    }
};
