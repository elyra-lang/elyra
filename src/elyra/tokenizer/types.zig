//! Types for the tokenizer
const std = @import("std");
const SourceObject = @import("../source/SourceObject.zig");

/// A token is a single unit of the source code that the tokenizer produces.
/// It is a packed struct that contains the kind of token and the position of
/// the token in the source code.
pub const Token = packed struct(u32) {
    kind: u8, // Token Kind; Done this way to be easier in the tokenizer
    position: u24,
};

/// The kind of token that the tokenizer has produced.
/// This is an enum that represents all of the different kinds of tokens that
/// the tokenizer can produce.
///
/// It uses identity values for the single-character tokens, and enum values
/// for the multi-character tokens.
pub const TokenKind = enum(u8) {
    Invalid = 0,
    LParen = '(',
    RParen = ')',
    LBrace = '{',
    RBrace = '}',
    LBracket = '[',
    RBracket = ']',
    Comma = ',',
    Dot = '.',
    Semicolon = ';',
    Colon = ':',
    Nullable = '?',

    Add = 129, // + (binary)
    AddEq = 130, // +=
    AddSat = 131, // +|
    AddWrap = 132, // +%
    AddSatEq = 133, // +|=
    AddWrapEq = 134, // +%=
    Sub = 136, // - (binary)
    SubEq = 137, // -=
    SubSat = 138, // -|
    SubWrap = 139, // -%
    SubSatEq = 140, // -|=
    SubWrapEq = 141, // -%=
    Mul = 142, // *
    MulEq = 143, // *=
    MulSat = 144, // *|
    MulWrap = 145, // *%
    MulSatEq = 146, // *|=
    MulWrapEq = 147, // *%=
    Div = 148, // /
    DivEq = 149, // /=
    Rem = 150, // %,
    RemEq = 151, // %=
    BitAnd = 152, // &
    BitAndEq = 153, // &=
    BitOr = 154, // |
    BitOrEq = 155, // |=
    BitXor = 156, // ^
    BitXorEq = 157, // ^=
    BitNot = 158, // ~
    BitNotEq = 159, // ~=
    ErrUnion = 160, // !
    NotEq = 161, // !=
    Assign = 162, // =
    Eq = 163, // ==

    Less = 164, // <
    Greater = 165, // >
    LessEq = 166, // <=
    GreaterEq = 167, // >=
    ShiftRight = 168, // >>
    ShiftRightEq = 169, // >>=
    ShiftLeft = 170, // <<
    ShiftLeftEq = 171, // <<=
    ShiftLeftSat = 172, // <<|
    ShiftLeftSatEq = 173, // <<|=
    CurryArrow = 174, // ->
    AddUnary = 175, // + (unary)
    SubUnary = 176, // - (unary)

    // Non-operators
    Identifier,
    IntLiteral,
    FloatLiteral,
    StringLiteral,
    CharLiteral,

    // Keywords
    True,
    False,
    Null,
    BooleanAnd,
    BooleanOr,
    Let,
    Var,
    Func,
    Return,
    Match,
    If,
    Else,
    Struct,
    Trait,
    Import,
    While,
    For,
    Break,
    Continue,
    Temp,
    Pub,
};

pub const Mapping = struct {
    token: u32,
    index: u32,
};

/// The token buffer is a struct that contains a backing allocator and a list
/// of tokens.
///
/// TODO: Add methods to the token buffer to make it easier to work with.
pub const TokenBuffer = struct {
    backing_allocator: std.mem.Allocator,
    source: *SourceObject,
    tokens: []Token,

    // Data tables
    mapping_table: []Mapping,
    value_table: []u64, // Generic 64-bit value

    pub fn deinit(self: *TokenBuffer) void {
        self.source.deinit();
        self.backing_allocator.free(self.tokens);
        self.backing_allocator.free(self.mapping_table);
        self.backing_allocator.free(self.value_table);

        self.* = undefined;
    }
};
