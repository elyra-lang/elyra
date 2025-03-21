const std = @import("std");

const ParseTree = @import("types.zig").ParseTree;
const ParseNode = @import("types.zig").ParseNode;
const TokenType = @import("../tokenizer/types.zig").TokenType;
const TokenBuffer = @import("../tokenizer/types.zig").TokenBuffer;

/// Represents the state of the parser.
const ParserState = enum(u8) {};

/// Context shared between parser states.
const ParserContext = struct {
    nodes: std.ArrayList(ParseNode),
    stack: std.ArrayList(ParserState),
    tokenize_buffer: *TokenBuffer,
    curr_idx: usize,
};

pub fn parse(allocator: std.mem.Allocator, token_buffer: *TokenBuffer) !ParseTree {
    var state = ParserContext{
        .nodes = std.ArrayList(ParseNode).initCapacity(allocator, token_buffer.tokens.len) catch @panic("Parser: OOM!"),
        .stack = std.ArrayList(ParserState).initCapacity(allocator, 4096) catch @panic("Parser: OOM!"),
        .tokenize_buffer = token_buffer,
        .curr_idx = 0,
    };

    while (true) : (state.curr_idx += 1) {
        if (state.curr_idx >= state.tokenize_buffer.tokens.len) {
            @branchHint(.unlikely);
            break;
        }
        @prefetch(state.tokenize_buffer.tokens, .{});

        state.nodes.append(ParseNode{
            .kind = state.tokenize_buffer.tokens[state.curr_idx].kind,
            .index = @intCast(state.curr_idx),
        }) catch unreachable;
    }

    return ParseTree{
        .backing_allocator = allocator,
        .token_buffer = token_buffer,
        .nodes = state.nodes.toOwnedSlice() catch @panic("Parser: OOM!"),
    };
}
