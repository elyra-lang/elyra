const std = @import("std");
const TokenBuffer = @import("../tokenizer/types.zig").TokenBuffer;

/// The parse node represents a single node in the parse tree.
/// The `kind` is used to identify the type of node, and is of type NodeType.
/// The `tag` is used for various purposes, such as identifying the corresponding token in the TokenBuffer or any other relevant information.
/// In the case `kind` is `NodeKind.Error`, the `tag` is set to `0`.
/// In the case `kind` is Let or Var declarations, the `tag` is the first node of the tree.
pub const ParseNode = packed struct(u32) {
    kind: u8,
    tag: u24,
};

/// The node types
pub const NodeKind = enum(u8) {
    LetMutability,
    VarMutability,
    PubModifier,
    Identifier,
    SpecifiedIdentifier,
    Literal,
    Declaration,
};

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
