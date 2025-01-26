const std = @import("std");
const testing = std.testing;

pub inline fn isA(comptime T: type, comptime F: anytype) bool {
    switch (@typeInfo(@TypeOf(F))) {
        .@"fn" => |f| {
            if (f.return_type != type)
                @compileError("F is not a type constructor\n");

            switch (@typeInfo(T)) {
                .@"struct" => |s| {
                    if (f.params.len > s.decls.len)
                        return false;

                    comptime var fields: [f.params.len]std.builtin.Type.StructField = undefined;
                    inline for (f.params, s.decls[0..f.params.len], 0..) |param, decl, i| {
                        const decl_type = @TypeOf(@field(T, decl.name));
                        if (!param.is_generic and decl_type != param.type)
                            return false;

                        comptime var buf: [16]u8 = undefined;
                        fields[i] = .{ .name = comptime std.fmt.bufPrintZ(&buf, "{}", .{i}) catch unreachable, .type = decl_type, .default_value_ptr = @ptrCast(&@field(T, decl.name)), .is_comptime = true, .alignment = @alignOf(decl_type) };
                    }

                    const params = std.builtin.Type.Struct{ .is_tuple = true, .decls = &.{}, .fields = &fields, .layout = .auto };

                    const S = @Type(std.builtin.Type{ .@"struct" = params });
                    return @call(.compile_time, F, S{}) == T;
                },
                else => @compileError("T is not a struct\n"),
            }
        },
        else => @compileError("F is not a function\n"),
    }
}

fn Type1(comptime T: type) type {
    return struct {
        pub const Type = T;
        a: T,
    };
}

fn Type1Copy(comptime T: type) type {
    return struct {
        pub const Type = T;
        a: T,
    };
}

fn Type2(comptime T: type, D: anytype) type {
    return struct {
        pub const Type = T;
        pub const Data = D;
    };
}

test "basic" {
    try testing.expect(isA(Type1(u8), Type1));
    try testing.expect(isA(Type1(Type1Copy(?[]const u8)), Type1));
}

test "incorrect type" {
    try testing.expect(!isA(Type1Copy(u8), Type1));
}

test "anytype" {
    try testing.expect(isA(Type2(u8, "Hello"), Type2));
}
