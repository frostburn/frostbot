module board11;

import std.stdio;
import std.string;
import core.simd;

import utils;
import polyomino;


struct Board11
{
    enum WIDTH = 11;
    enum HEIGHT = 10;
    enum CORNER = 0x10UL;
    enum H_SHIFT = 1;
    enum V_SHIFT = 12;
    enum EMPTY = 0UL;
    enum FULL = 0x7FF7FF7FF7FF7FFUL;
    enum OUTSIDE = 0xF800800800800800UL;
    enum FLOOD_LINE = 0x7FF000000000000UL;

    ulong north_bits;
    ulong south_bits;

    bool valid() const pure nothrow @nogc @safe
    {
        return !(north_bits & OUTSIDE) && !(south_bits & OUTSIDE);
    }

    this(ulong north_bits, ulong south_bits, bool dummy) pure nothrow @nogc @safe
    {
        this.north_bits = north_bits;
        this.south_bits = south_bits;
    }

    this(in ulong x, in ulong y) pure nothrow @nogc @safe
    in
    {
        assert((0 <= x) && (x < WIDTH) && (0 <= y) && (y < HEIGHT));
    }
    out
    {
        assert(valid);
    }
    body
    {
        if (y < 5){
            north_bits = 1UL << (x * H_SHIFT + y * V_SHIFT);
        }
        else{
            south_bits = 1UL << (x * H_SHIFT + (9 - y) * V_SHIFT);
        }
    }

    Board11 opUnary(string op)() const pure nothrow @nogc @safe
    {
        mixin("return Board11(" ~ op ~ "north_bits, " ~ op ~ "south_bits, true);");
    }

    Board11 opBinary(string op)(in Board11 rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board11(north_bits " ~ op ~ " rhs.north_bits, south_bits " ~ op ~ "rhs.south_bits, true);");
    }

    Board11 opBinary(string op)(in int rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board11(north_bits " ~ op ~ " rhs, south_bits " ~ op ~ " rhs, true);");
    }

    Board11 opBinary(string op)(in ulong rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board11(north_bits " ~ op ~ " rhs, south_bits " ~ op ~ " rhs, true);");
    }

    ref Board11 opOpAssign(string op)(in Board11 rhs) nothrow @nogc @safe
    {
        mixin ("
            north_bits " ~ op ~ "= rhs.north_bits;
            south_bits " ~ op ~ "= rhs.south_bits;
        ");
        return this;
    }

    bool opEquals(in Board11 rhs) const pure nothrow @nogc @safe
    {
        return north_bits == rhs.north_bits && south_bits == rhs.south_bits;
    }

    int opCmp(in Board11 rhs) const pure nothrow @nogc @safe
    {
        if (north_bits < rhs.north_bits){
            return -1;
        }
        if (north_bits > rhs.north_bits){
            return 1;
        }
        return compare(south_bits, rhs.south_bits);
    }

    hash_t toHash() const nothrow @safe
    {
        hash_t south_hash = typeid(south_bits).getHash(&south_bits);
        return (
            typeid(north_bits).getHash(&north_bits) ^
            (south_hash << (4 * hash_t.sizeof)) ^
            (south_hash >> (4 * hash_t.sizeof))
        );
    }

    int popcount() const pure nothrow @nogc @safe
    {
        return north_bits.popcount + south_bits.popcount;
    }

    Board11 east() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.valid);
    }
    body
    {
        return Board11((north_bits << H_SHIFT) & FULL, (south_bits << H_SHIFT) & FULL, true);
    }

    Board11 west() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.valid);
    }
    body
    {
        return Board11((north_bits >> H_SHIFT) & FULL, (south_bits >> H_SHIFT) & FULL, true);
    }

    Board11 north() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.valid);
    }
    body
    {
        return Board11((north_bits >> V_SHIFT) | (south_bits & FLOOD_LINE), (south_bits << V_SHIFT) & FULL, true);
    }

    Board11 south() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.valid);
    }
    body
    {
        return Board11((north_bits << V_SHIFT) & FULL, (south_bits >> V_SHIFT) | (north_bits & FLOOD_LINE), true);
    }

    /**
     * Floods (expands) the board into target board along vertical and horizontal lines.
     */
    ref Board11 flood_into(in Board11 target) pure nothrow @nogc @safe
    in
    {
        assert(target.valid);
    }
    out
    {
        assert(valid);
    }
    body
    {
        static if (is(ulong2) && false){  // Disabled because this is actually slower thatn the non-vectorized version
            ulong2 bits, target_bits;
            bits.array[0] = north_bits;
            bits.array[1] = south_bits;
            target_bits.array[0] = target.north_bits;
            target_bits.array[1] = target.south_bits;

            bits &= target_bits;
            if (!bits.array[0] && !bits.array[1]){
                north_bits = EMPTY;
                south_bits = EMPTY;
                return this;
            }

            // The "+" operation can be thought as an infinite inverting horizontal flood with a garbage bit at each end.
            // Here we invert it back and clear the garbage bits by "&":ing with the target.
            bits |= (~(bits + target_bits)) & target_bits;

            do{
                north_bits = bits.array[0];
                south_bits = bits.array[1];
                bits.array[0] |= (
                    (north_bits >> H_SHIFT) |
                    (north_bits << V_SHIFT) |
                    (north_bits >> V_SHIFT) |
                    (south_bits & FLOOD_LINE)
                );
                bits.array[1] |= (
                    (south_bits >> H_SHIFT) |
                    (south_bits << V_SHIFT) |
                    (south_bits >> V_SHIFT) |
                    (north_bits & FLOOD_LINE)
                );
                bits &= target_bits;
                bits |= (~(bits + target_bits)) & target_bits;
            } while(bits.array[0] != north_bits || bits.array[1] != south_bits);

            return this;
        }
        else {
            ulong north_temp;
            ulong south_temp;
            ulong target_north_bits = target.north_bits;
            ulong target_south_bits = target.south_bits;

            north_bits &= target_north_bits;
            south_bits &= target_south_bits;
            if (!north_bits && !south_bits){
                return this;
            }

            string east_flood(string direction)
            {
                // The "+" operation can be thought as an infinite inverting horizontal flood with a garbage bit at each end.
                // Here we invert it back and clear the garbage bits by "&":ing with the target.
                return direction ~ "_bits |= (~(" ~ direction ~ "_bits + target_" ~ direction ~ "_bits)) & target_" ~ direction ~ "_bits;";
            }

            string rest_of_the_flood(string direction, string other)
            {
                return "
                    " ~ direction ~ "_bits |= (
                        (" ~ direction ~ "_bits >> H_SHIFT) |
                        (" ~ direction ~ "_bits << V_SHIFT) |
                        (" ~ direction ~ "_bits >> V_SHIFT) |
                        (" ~ other ~ "_temp & FLOOD_LINE)
                    ) & target_" ~ direction ~ "_bits;
                ";
            }

            mixin(east_flood("north"));
            mixin(east_flood("south"));
            do{
                north_temp = north_bits;
                south_temp = south_bits;
                mixin(rest_of_the_flood("north", "south"));
                mixin(rest_of_the_flood("south", "north"));
                mixin(east_flood("north"));
                mixin(east_flood("south"));
            } while(north_bits != north_temp || south_bits != south_temp);

            return this;
        }
    }

    string toString()
    {
        string r;
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < WIDTH; x++){
                if (this & Board11(x, y)){
                    r ~= "@ ";
                }
                else{
                    r ~= ". ";
                }
            }
            if (y != HEIGHT - 1){
                r ~= "\n";
            }
        }
        return r;
    }

    string raw_string()
    {
        string r;
        string get_part(string part){
            return "
                foreach (y; 0..HEIGHT / 2 + 1){
                    foreach (x; 0..WIDTH + 1){
                        if (" ~ part ~ " & (1UL << (x * H_SHIFT + y * V_SHIFT))){
                            r ~= \"@ \";
                        }
                        else{
                            r ~= \". \";
                        }
                        if (y == HEIGHT / 2 && x == 3){
                            break;
                        }
                    }
                    if (y == HEIGHT / 2){
                        break;
                    }
                    r ~= \"\\n\";
                }
            ";
        }
        mixin(get_part("north_bits"));
        r ~= "\n";
        mixin(get_part("south_bits"));
        return r;
    }

    string repr()
    {
        return format("Board11(0x%sUL, 0x%sUL, true)", format("%x", north_bits).toUpper, format("%x", south_bits).toUpper);
    }

    @property bool toBool() const pure nothrow @nogc @safe
    {
        return cast(bool)north_bits || cast(bool)south_bits;
    }

    alias toBool this;
}


immutable Board11 full11 = Board11(Board11.FULL, Board11.FULL, true);
immutable Board11 empty11 = Board11(Board11.EMPTY, Board11.EMPTY, true);

void print_constants()
{
    Board11 full;
    Board11 flood_line;
    foreach (y; 0..Board11.HEIGHT){
        foreach (x; 0..Board11.WIDTH){
            auto p = Board11(x, y);
            full |= p;
            if (y == 4 || y == 5){
                flood_line |= p;
            }
        }
    }

    writeln(full.repr);
    writeln((~full).repr);
    writeln(flood_line.repr);
}

unittest
{
    auto b = Board11(0, 0);
    assert(!b.west);
    assert(b.east);
    assert(!b.north);
    assert(b.south);

    b = Board11(0, Board11.HEIGHT / 2 - 1);
    assert(b.south);
    assert(b.south.popcount == 1);
    b = Board11(0, Board11.HEIGHT / 2);
    assert(b.north);
    assert(b.north.popcount == 1);

    b = Board11(Board11.WIDTH - 1, Board11.HEIGHT - 1);
    assert(b.west);
    assert(!b.east);
    assert(b.north);
    assert(!b.south);

    assert(Board11(0, 5));

    assert(!Board11(Board11.WIDTH - 1, 0).north);
}

unittest
{
    auto b = Board11(0, 4) | Board11(0, 5) | Board11(0, 6) | Board11(1, 5) | Board11(2, 5) | Board11(2, 6) | Board11(2, 7) | Board11(2, 8) | Board11(1, 8) | Board11(0, 8);
    auto c = b | Board11(3, 9);
    auto d = Board11(0, 4);
    d.flood_into(c);

    assert(d == b);
}