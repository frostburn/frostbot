module board8;

import std.stdio;
import std.string;

import utils;
import polyomino;


struct Board8
{
    enum WIDTH = 8;
    enum HEIGHT = 7;
    enum H_SHIFT = 1;
    enum V_SHIFT = 9;
    enum EMPTY = 0UL;
    enum FULL = 0x3FDFEFF7FBFDFEFFUL;
    enum WEST_WALL = 0x40201008040201UL;
    enum EAST_WALL = 0x2010080402010080UL;
    enum NORTH_WALL = 0xFFUL;
    enum SOUTH_WALL = 0x3FC0000000000000UL;
    enum OUTSIDE = 0xC020100804020100UL;

    static immutable Board8[WIDTH * HEIGHT / 2] FORAGE_TABLE = mixin(get_forage_table);

    static immutable ulong[1 << HEIGHT] ROTATION_TABLE = mixin(get_rotation_table);

    ulong bits = EMPTY;

    bool valid() const pure nothrow @nogc @safe
    {
        return !(bits & OUTSIDE);
    }

    //Invariant disabled because optimizations depend on creating invalid temporary objects.
    //invariant()
    //{
    //    assert(valid);
    //}

    this(in ulong bits) pure nothrow @nogc @safe
    {
        this.bits = bits;
    }

    this(in int x, in int y) pure nothrow @nogc @safe
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
        bits = (1UL << (x * H_SHIFT)) << (y * V_SHIFT);
    }

    Board8 opUnary(string op)() const pure nothrow @nogc @safe
    {
        mixin("return Board8(" ~ op ~ "bits);");
    }

    Board8 opBinary(string op)(in Board8 rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board8(bits " ~ op ~ " rhs.bits);");
    }

    Board8 opBinary(string op)(in int rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    Board8 opBinary(string op)(in ulong rhs) const pure nothrow @nogc @safe
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    ref Board8 opOpAssign(string op)(in Board8 rhs) nothrow @nogc @safe
    {
        mixin ("bits " ~ op ~ "= rhs.bits;");
        return this;
    }

    bool opEquals(in Board8 rhs) const pure nothrow @nogc @safe
    {
        return bits == rhs.bits;
    }

    int opCmp(in Board8 rhs) const pure nothrow @nogc @safe
    {
        return compare(bits, rhs.bits);
    }

    hash_t toHash() const nothrow @safe
    {
        return typeid(bits).getHash(&bits);
    }

    uint popcount() const pure nothrow @nogc @safe
    {
        return bits.popcount;
    }

    Board8 blob(in Board8 playing_area) const pure nothrow @nogc @safe
    {
        auto temp = bits | (bits << H_SHIFT) | (bits >> H_SHIFT);
        return Board8(
            (temp | (temp << V_SHIFT) | (temp >> V_SHIFT)) & playing_area.bits
        );
    }

    Board8 liberties(in Board8 playing_area) const pure nothrow @nogc @safe
    {
        return Board8(
            (
                (bits << H_SHIFT) |
                (bits >> H_SHIFT) |
                (bits << V_SHIFT) |
                (bits >> V_SHIFT)
            ) & (~bits) & playing_area.bits
        );
    }

    Board8 east(in int n=1) const
    {
        return (this << (H_SHIFT * n)) & FULL;
    }

    Board8 west(in int n=1) const
    {
        return (this >> (H_SHIFT * n)) & FULL;
    }

    Board8 south(in int n=1) const
    {
        return (this << (V_SHIFT* n)) & FULL;
    }

    Board8 north(in int n=1) const
    {
        return (this >> (V_SHIFT * n)) & FULL;
    }

    /**
     * Floods (expands) the board into target board along vertical and horizontal lines.
     */
    ref Board8 flood_into(in Board8 target) pure nothrow @nogc @safe
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
        Board8 temp;

        this &= target;
        if (!this){
            return this;
        }

        // The "+" operation can be thought as an infinite inverting horizontal flood with a garbage bit at each end.
        // Here we invert it back and clear the garbage bits by "&":ing with the target.
        this |= (~(this + target)) & target;
        do{
            temp = this;
            this |= (
                (this >> H_SHIFT) |
                (this << V_SHIFT) |
                (this >> V_SHIFT)
            ) & target;
            this |= (~(this + target)) & target;
        } while(this != temp);

        return this;
    }

    void clear()
    {
        bits = EMPTY;
    }

    void fill(){
        bits = FULL;
    }

    void snap(out int westwards, out int northwards) pure nothrow @nogc @safe
    out
    {
        assert(westwards < WIDTH);
        assert(northwards < HEIGHT);
        assert(valid);
    }
    body
    {
        westwards = 0;
        northwards = 0;
        if (!this){
            return;
        }
        while (!(bits & WEST_WALL)){
            bits >>= H_SHIFT;
            westwards++;
        }
        while (!(bits & NORTH_WALL)){
            bits >>= V_SHIFT;
            northwards++;
        }
    }

    void fix(in int westwards, in int northwards) pure nothrow @nogc @safe
    in
    {
        assert(westwards < WIDTH);
        assert(northwards < HEIGHT);
    }
    out
    {
        assert(valid);
    }
    body
    {
        version(assert){
            auto old_bits = bits;
        }
        bits >>= H_SHIFT * westwards + V_SHIFT * northwards;
        version(assert){
            assert(old_bits.popcount == bits.popcount);
        }
    }

    bool can_rotate() pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    body
    {
        return !(bits & EAST_WALL);
    }

    void rotate() nothrow @nogc @safe
    in
    {
        assert(valid);
        assert(can_rotate);
    }
    out
    {
        assert(valid);
        assert(can_rotate);
    }
    body
    {
        version(assert){
            auto rotated_bits = naive_rotate;
        }
        auto old_bits = bits;
        bits = EMPTY;
        assert(HEIGHT <= WIDTH);
        for (int y = 0; y < HEIGHT; y++){
            auto north_line = (old_bits >> (y * V_SHIFT)) & NORTH_WALL;
            bits |= ROTATION_TABLE[north_line] >> (y * H_SHIFT);
        }
        assert(old_bits.popcount == bits.popcount);
        version(assert){
            assert(bits == rotated_bits);
        }
    }

    private ulong naive_rotate() pure nothrow @nogc @safe
    in
    {
        assert(valid);
        assert(can_rotate);
    }
    out(result)
    {
        assert(Board8(result).valid);
        assert(result.popcount == bits.popcount);
    }
    body
    {
        auto result = EMPTY;
        assert(HEIGHT <= WIDTH);
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < HEIGHT; x++){
                result |= (
                    (1UL & ( bits >> (x * H_SHIFT + y * V_SHIFT))) <<
                    ((HEIGHT - 1 - y) * H_SHIFT + x * V_SHIFT)
                );
            }
        }
        return result;
    }

    void mirror_h() pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out
    {
        assert(valid);
    }
    body
    {
        version(assert){
            auto old_bits = bits;
        }
        bits = (
            (bits & (WEST_WALL << (0 * H_SHIFT))) << ((WIDTH - 1) * H_SHIFT) |
            (bits & (WEST_WALL << (1 * H_SHIFT))) << ((WIDTH - 3) * H_SHIFT) |
            (bits & (WEST_WALL << (2 * H_SHIFT))) << ((WIDTH - 5) * H_SHIFT) |
            (bits & (WEST_WALL << (3 * H_SHIFT))) << ((WIDTH - 7) * H_SHIFT) |
            (bits & (WEST_WALL << (4 * H_SHIFT))) >> (1 * H_SHIFT) |
            (bits & (WEST_WALL << (5 * H_SHIFT))) >> (3 * H_SHIFT) |
            (bits & (WEST_WALL << (6 * H_SHIFT))) >> (5 * H_SHIFT) |
            (bits & (WEST_WALL << (7 * H_SHIFT))) >> (7 * H_SHIFT)
        );
        version(assert){
            assert(old_bits.popcount == bits.popcount);
        }
    }

    void mirror_v() pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    out
    {
        assert(valid);
    }
    body
    {
        version(assert){
            auto old_bits = bits;
        }
        bits = (
            (bits & (NORTH_WALL << (0 * V_SHIFT))) << ((HEIGHT - 1) * V_SHIFT) |
            (bits & (NORTH_WALL << (1 * V_SHIFT))) << ((HEIGHT - 3) * V_SHIFT) |
            (bits & (NORTH_WALL << (2 * V_SHIFT))) << ((HEIGHT - 5) * V_SHIFT) |
            (bits & (NORTH_WALL << (3 * V_SHIFT))) |
            (bits & (NORTH_WALL << (4 * V_SHIFT))) >> (2 * V_SHIFT) |
            (bits & (NORTH_WALL << (5 * V_SHIFT))) >> (4 * V_SHIFT) |
            (bits & (NORTH_WALL << (6 * V_SHIFT))) >> (6 * V_SHIFT)
        );
        version(assert){
            assert(old_bits.popcount == bits.popcount);
        }
    }

    int horizontal_extent()
    {
        int extent = WIDTH;
        while (extent > 0){
            if (bits & (EAST_WALL >> ((WIDTH - extent) * H_SHIFT))){
                return extent;
            }
            extent--;
        }
        return extent;
    }

    int vertical_extent()
    {
        int extent = HEIGHT;
        while (extent > 0){
            if (bits & (SOUTH_WALL >> ((HEIGHT - extent) * V_SHIFT))){
                return extent;
            }
            extent--;
        }
        return extent;
    }

    /// Euler charasteristic of the board
    int euler()
    {
        ulong temp = bits | (bits << H_SHIFT);
        int characteristic = -utils.popcount(temp);  // vertical edges
        characteristic += utils.popcount(temp & NORTH_WALL);  // northern vertices
        characteristic += utils.popcount(temp | (temp >> H_SHIFT));  // rest of the vertices
        characteristic -= utils.popcount(bits & NORTH_WALL);  // northern horizontal edges
        characteristic -= utils.popcount(bits | (bits << H_SHIFT));  // rest of the horizontal edges
        characteristic += utils.popcount(bits);  // pixels

        return characteristic;
    }

    /// Euler charasterisric of the board surrounded by a ring of stones
    //TODO:
    /*
    int surrounded_euler()
    {
        ulong temp = (bits & ~WEST_WALL);
        temp |= temp << H_SHIFT;
        int characteristic = -(utils.popcount(temp) + 50);  // vertical edges
    }
    */

    // TODO: Optimize forage tables based on the extent of the playing area.
    Board8[] chains() const
    out(result){
        assert(result.length <= WIDTH * HEIGHT / 2 + 1);
    }
    body
    {
        Board8 foragee = this;
        Board8[] result;
        foreach (block; FORAGE_TABLE){
            Board8 temp = foragee & block;
            if (temp){
                foragee ^= temp.flood_into(foragee);
                result ~= temp;
            }
            if (!foragee){
                break;
            }
        }
        return result;
    }

    string toString()
    {
        string r;
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < WIDTH; x++){
                if (this & Board8(x, y)){
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
        for (int y = 0; y < HEIGHT + 1; y++){
            for (int x = 0; x < WIDTH + 1; x++){
                if (bits & ((1UL << (x * H_SHIFT)) << (y * V_SHIFT))){
                    r ~= "@ ";
                }
                else{
                    r ~= ". ";
                }
                if (y == HEIGHT){
                    return r;
                }
            }
            r ~= "\n";
        }
        assert(false);
    }

    string repr()
    {
        return format("Board8(0x%xUL)", bits);
    }

    @property bool toBool() const pure nothrow @nogc @safe
    {
        return cast(bool)bits;
    }

    alias toBool this;
}


// TODO: Move to board_common
T rectangle(T)(int width, int height){
    T result;
    for (int y = 0; y < height; y++){
        for (int x = 0; x < width; x++){
            result |= T(x, y);
        }
    }
    return result;
}


Board8 from_piece(T)(Piece piece)
in
{
    assert(piece.x >= 0);
    assert(piece.y >= 0);
    assert(piece.x < T.WIDTH);
    assert(piece.y < T.HEIGHT);
}
out(result)
{
    assert(result.valid);
}
body
{
    return T(piece.x, piece.y);
}


Board8 from_shape(T)(Shape shape)
in
{
    assert(shape.west_extent >= 0);
    assert(shape.north_extent >= 0);
    assert(shape.east_extent < T.WIDTH);
    assert(shape.south_extent < T.HEIGHT);
}
out(result)
{
    assert(result.valid);
}
body
{
    auto result = T();
    foreach (piece; shape.piece_set.byKey){
        result |= from_piece!T(piece);
    }
    return result;
}


alias rectangle8 = rectangle!Board8;
alias from_piece8 = from_piece!Board8;
alias from_shape8 = from_shape!Board8;


immutable Board8 full8 = Board8(Board8.FULL);
immutable Board8 empty8 = Board8(Board8.EMPTY);


string get_forage_table()
{
    string r;
    Board8 forage[];
    for (int y = 0; y < Board8.HEIGHT - 1; y += 2){
        for (int x = 0; x < Board8.WIDTH; x++){
            Board8 block = Board8(x, y);
            block |= Board8(x, y + 1);
            forage ~= block;
        }
    }
    int y = Board8.HEIGHT - 1;
    for (int x = 0; x < Board8.WIDTH; x += 2){
        Board8 block = Board8(x, y);
        block |= Board8(x + 1, y);
        forage ~= block;
    }
    r ~= "[";
    foreach (index, block; forage){
        r ~= block.repr;
        if (index < forage.length - 1){
            r ~= ", ";
        }
    }
    r ~= "]";
    return r;
}

string get_rotation_table(){
    string r;
    assert(Board8.HEIGHT <= Board8.WIDTH);
    ulong[1 << Board8.HEIGHT] rotation_table;
    for (ulong north_line = 0; north_line < (1 << Board8.HEIGHT); north_line++){
        rotation_table[north_line] = Board8(north_line).naive_rotate;
    }
    r ~= "[";
    foreach (index, rotation; rotation_table){
        r ~= format("0x%xUL", rotation);
        if (index < rotation_table.length - 1){
            r ~= ", ";
        }
    }
    r ~= "]";
    return r;
}

unittest
{
    Board8 b0 = Board8(0, 1);
    Board8 b1 = Board8(0, 0);
    b1 |= b0;
    b1 |= Board8(1, 1);
    b1 |= Board8(2, 1);
    b1 |= Board8(2, 2);
    b1 |= Board8(3, 2);
    b1 |= Board8(3, 3);
    b1 |= Board8(3, 4);
    b1 |= Board8(2, 4);

    Board8 b2 = b1;
    b2 |= Board8(4, 5);
    b2 |= Board8(7, 1);

    assert(b1.horizontal_extent == 4);
    assert(b1.vertical_extent == 5);

    b0.flood_into(b2);

    assert(b0 == b1);

    assert(b2.chains.sort == [b1, Board8(4, 5), Board8(7, 1)].sort);
}

unittest
{
    Board8 b = Board8(Board8.FULL);
    assert(b.popcount == Board8.WIDTH * Board8.HEIGHT);
}

/*
void main()
{
    auto b = Board8(12398724987489237345UL & ~Board8.EAST_WALL & Board8.FULL);
    writeln(b);
    writeln;
    auto r = Board8(b.naive_rotate);
    writeln(r);
}
*/
