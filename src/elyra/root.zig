pub const SourceObject = @import("source/SourceObject.zig");
pub const Tokenizer = @import("tokenizer/tokenize.zig");

// We can put all tests here
// This is a good way to test the whole project
comptime {
    _ = @import("source/SourceObject.zig"); // This one we just have one test in, no separate file
    _ = @import("tokenizer/tokenize_test.zig"); // Everything else follows this pattern
}
