const std = @import("std");

const ParseTree = @import("types.zig").ParseTree;
const ParseNode = @import("types.zig").ParseNode;
const NodeKind = @import("types.zig").NodeKind;
const TokenKind = @import("../tokenizer/types.zig").TokenKind;
const TokenBuffer = @import("../tokenizer/types.zig").TokenBuffer;

/// Respesents some encoded stack information
/// In most cases, data is a pointer to the starting node of a subtree
const ParserState = struct {
    kind: ParserKind,
    data: u24,
};

/// Represents the state of the parser.
const ParserKind = enum(u8) {
    /// The base state the parser starts in.
    /// This is essentially finding all bindings and variable declarations to
    /// pull out of the token buffer.
    ScopeDeclLoop,
    Let,
    LetAfterSpecifier,
    LetFinish,
    Var,
    VarAfterSpecifier,
    VarFinish,
    Specifier,
    Expression,
};

const IS_DEBUGGING = false;
fn debug_print(comptime format: []const u8, args: anytype) void {
    if (IS_DEBUGGING) {
        std.debug.print(format, args);
    }
}

/// Context shared between parser states.
const ParserContext = struct {
    nodes: std.ArrayList(ParseNode),
    stack: std.ArrayList(ParserState),
    tokenize_buffer: *TokenBuffer,
    curr_idx: usize,

    pub inline fn add_leaf_node(self: *ParserContext, kind: NodeKind) void {
        self.nodes.append(ParseNode{
            .kind = @intFromEnum(kind),
            .tag = @intCast(self.curr_idx),
        }) catch @panic("Parser: OOM!");
    }

    pub inline fn add_leaf_node_expect(self: *ParserContext, kind: TokenKind, node: NodeKind) void {
        self.add_leaf_node(node);

        // This is technically the wrong order, but it's okay because we're only
        // consuming one token... Correct error handling just goes -1 token.
        self.consume(kind);
    }

    pub inline fn add_node(self: *ParserContext, kind: NodeKind, tag: u24) void {
        self.nodes.append(ParseNode{
            .kind = @intFromEnum(kind),
            .tag = tag,
        }) catch @panic("Parser: OOM!");
    }

    pub inline fn consume(self: *ParserContext, kind: TokenKind) void {
        if (self.get_curr_token() != kind) {
            if (IS_DEBUGGING) {
                debug_print("Unexpected token: {}, expected: {}\n", .{ self.get_curr_token(), kind });
                debug_print("State: {}\n", .{self.peek_stack()});
                debug_print("Curr_Idx: {}\n", .{self.curr_idx});
                debug_print("Tokens: {any}\n", .{self.tokenize_buffer.tokens});
                debug_print("Nodes: {any}\n", .{self.nodes.items});
            }
            @panic("Unexpected Token");
        }
        self.curr_idx += 1;
        debug_print("Consumed token: {} idx: {}\n", .{ kind, self.curr_idx });
    }

    pub inline fn consume_if(self: *ParserContext, kind: TokenKind) bool {
        // TODO: Heuristics on token consumption
        if (self.get_curr_token() == kind) {
            self.curr_idx += 1;
            debug_print("Consumed token: {} idx: {}\n", .{ kind, self.curr_idx });
            return true;
        }
        return false;
    }

    pub inline fn push_state(self: *ParserContext, kind: ParserKind) void {
        self.stack.append(ParserState{
            .kind = kind,
            .data = @intCast(self.nodes.items.len),
        }) catch @panic("Parser: OOM!");
    }

    pub inline fn push_state_subtree(self: *ParserContext, kind: ParserKind, subtree: u24) void {
        self.stack.append(ParserState{
            .kind = kind,
            .data = @intCast(subtree),
        }) catch @panic("Parser: OOM!");
    }

    pub inline fn pop_state(self: *ParserContext) ParserState {
        return self.stack.pop() orelse @panic("Parser: Stack underflow!");
    }

    pub inline fn peek_stack(self: *ParserContext) ParserState {
        return self.stack.items[self.stack.items.len - 1];
    }

    pub inline fn get_curr_token(self: *ParserContext) TokenKind {
        return @enumFromInt(self.tokenize_buffer.tokens[self.curr_idx].kind);
    }

    pub inline fn get_next_token(self: *ParserContext) TokenKind {
        return @enumFromInt(self.tokenize_buffer.tokens[self.curr_idx + 1].kind);
    }

    pub inline fn get_node_index(self: *ParserContext) u24 {
        return @intCast(self.nodes.items.len);
    }
};

pub fn parse(allocator: std.mem.Allocator, token_buffer: *TokenBuffer) !ParseTree {
    var state = ParserContext{
        .nodes = std.ArrayList(ParseNode).initCapacity(allocator, token_buffer.tokens.len) catch @panic("Parser: OOM!"),
        .stack = std.ArrayList(ParserState).initCapacity(allocator, 4096) catch @panic("Parser: OOM!"),
        .tokenize_buffer = token_buffer,
        .curr_idx = 0,
    };
    defer state.stack.deinit();

    // Set initial state
    state.push_state(.ScopeDeclLoop);

    while (true) {
        if (state.stack.items.len == 0) {
            @branchHint(.unlikely);
            break;
        }

        // TODO: Prefetch optimization

        // Peek last state
        const stack_state = state.peek_stack();
        debug_print("Current state: {}\n", .{stack_state.kind});
        switch (stack_state.kind) {
            .ScopeDeclLoop => {
                // Handle RootScopeDeclLoop state

                // First there could be a `pub` visibility modifier before any statement
                // TODO: Other modifiers in future?
                var is_pub = false;
                if (state.consume_if(.Pub)) {
                    is_pub = true;
                }

                // Then it will be invariably a 'let' or 'var' mutability modifier
                // Because the only valid container level statements are binding or variable declaration
                if (state.consume_if(.Let)) {
                    state.push_state(.Let);

                    // The tag data here is modifier flags
                    // In this case, it's 1 (pub) or 0 (no pub)
                    // Could be changed later, but we remove pub from the tree
                    state.add_node(.LetMutability, @intFromBool(is_pub));
                } else if (state.consume_if(.Var)) {
                    state.push_state(.Var);

                    // The tag data here is modifier flags
                    // In this case, it's 1 (pub) or 0 (no pub)
                    // Could be changed later, but we remove pub from the tree
                    state.add_node(.VarMutability, @intFromBool(is_pub));
                } else if (state.consume_if(.RBrace) or state.consume_if(.EndOfFile)) {
                    _ = state.pop_state();
                } else {
                    @branchHint(.unlikely);
                    @panic("Invalid token!");
                }
            },
            .Let => {
                // Handle let statement
                const curr_state = state.pop_state();

                // From here, we have a few things to do
                // First it's possible there's a type specifier at n + 1
                // If there is, we add type specifier to the tree
                // Otherwise, we just add the name.
                // Then there will be an equal and an expression
                // Finally, we add the declaration to the tree at the semicolon

                // Prep the states in reverse order
                state.push_state_subtree(.LetFinish, curr_state.data);
                state.push_state(.LetAfterSpecifier);
                state.push_state(.Specifier);
            },
            .Var => {
                // Handle var statement
                const curr_state = state.pop_state();

                // Prep the states in reverse order, see comment in let handler
                state.push_state_subtree(.VarFinish, curr_state.data);
                state.push_state(.VarAfterSpecifier);
                state.push_state(.Specifier);
            },
            .LetAfterSpecifier => {
                _ = state.pop_state();

                state.consume(.Assign);
                state.push_state(.Expression);
            },
            .VarAfterSpecifier => {
                _ = state.pop_state();

                state.consume(.Assign);
                state.push_state(.Expression);
            },
            .LetFinish, .VarFinish => {
                // Cleanup and add declaration in post-order
                const curr_state = state.pop_state();

                state.consume(.Semicolon);
                state.add_node(.Declaration, curr_state.data);
            },
            .Expression => {
                // Cleanup and add expression in post-order
                const curr_state = state.pop_state();
                _ = curr_state;

                // TODO: Complete
                // TODO: Scan binops
                // TODO: Operator precedence

                if (state.get_curr_token() == .FloatLiteral) {
                    state.add_leaf_node(.Literal);
                    state.consume(.FloatLiteral);
                } else if (state.get_curr_token() == .IntLiteral) {
                    state.add_leaf_node(.Literal);
                    state.consume(.IntLiteral);
                } else if (state.get_curr_token() == .StringLiteral) {
                    state.add_leaf_node(.Literal);
                    state.consume(.StringLiteral);
                } else if (state.get_curr_token() == .Identifier) {
                    state.add_leaf_node(.Identifier);
                    state.consume(.Identifier);
                } else if (state.get_curr_token() == .CharLiteral) {
                    state.add_leaf_node(.Literal);
                    state.consume(.CharLiteral);
                } else unreachable;
            },
            .Specifier => {
                // Handles the type specifier for let declarations or parameters

                _ = state.pop_state();

                // Not the same as state.data -- which is the index of the subtree before let/var
                const curr_node = state.get_node_index();

                // We need the identifier, which is always a leaf, either of the let tree, or the specifier tree
                state.add_leaf_node_expect(.Identifier, .Identifier);

                if (state.consume_if(.Colon)) {
                    // This now encodes the type itself.
                    state.add_leaf_node_expect(.Identifier, .Identifier);

                    // Finally for the postorder, we add the specifier to the tree
                    // The tag stores the beginning of the tree
                    // This is for future use in Generics / Comptime
                    state.add_node(.SpecifiedIdentifier, @intCast(curr_node));
                }
            },
        }
    }

    return ParseTree{
        .backing_allocator = allocator,
        .token_buffer = token_buffer,
        .nodes = state.nodes.toOwnedSlice() catch @panic("Parser: OOM!"),
    };
}
