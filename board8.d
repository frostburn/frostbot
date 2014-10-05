module board8;

import std.stdio;
import std.string;

// TODO: Move to utils
int popcount(ulong b)
{
     b = (b & 0x5555555555555555UL) + (b >> 1 & 0x5555555555555555UL);
     b = (b & 0x3333333333333333UL) + (b >> 2 & 0x3333333333333333UL);
     b = b + (b >> 4) & 0x0F0F0F0F0F0F0F0FUL;
     b = b + (b >> 8);
     b = b + (b >> 16);
     b = b + (b >> 32) & 0x0000007FUL;

     return cast(int)b;
}

struct Board8
{
    enum WIDTH = 8;
    enum HEIGHT = 7;
    enum H_SHIFT = 1;
    enum V_SHIFT = 9;
    enum EMPTY = 0UL;
    enum FULL = 4602661192559623935UL;
    enum WEST_WALL = 18049651735527937UL;
    enum EAST_WALL = 2310355422147575936UL;
    enum NORTH_WALL = 255UL;
    enum OUTSIDE = 13844082881149927680UL;

    static immutable Board8[28] FORAGE = [
        Board8(513UL),
        Board8(1026UL),
        Board8(2052UL),
        Board8(4104UL),
        Board8(8208UL),
        Board8(16416UL),
        Board8(32832UL),
        Board8(65664UL),
        Board8(134479872UL),
        Board8(268959744UL),
        Board8(537919488UL),
        Board8(1075838976UL),
        Board8(2151677952UL),
        Board8(4303355904UL),
        Board8(8606711808UL),
        Board8(17213423616UL),
        Board8(35253091565568UL),
        Board8(70506183131136UL),
        Board8(141012366262272UL),
        Board8(282024732524544UL),
        Board8(564049465049088UL),
        Board8(1128098930098176UL),
        Board8(2256197860196352UL),
        Board8(4512395720392704UL),
        Board8(54043195528445952UL),
        Board8(216172782113783808UL),
        Board8(864691128455135232UL),
        Board8(3458764513820540928UL),
    ];

    ulong bits = EMPTY;

    bool valid() const
    {
        return !(bits & OUTSIDE);
    }

    //Invariant disabled because optimizations depend on creating invalid temporary objects.
    //invariant()
    //{
    //    assert(valid);
    //}

    this(in ulong bits)
    {
        this.bits = bits;
    }

    this(in int x, in int y)
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

    Board8 opUnary(string op)() const
    {
        mixin("return Board8(" ~ op ~ "bits);");
    }

    Board8 opBinary(string op)(in Board8 rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs.bits);");
    }

    Board8 opBinary(string op)(in int rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    Board8 opBinary(string op)(in ulong rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    ref Board8 opOpAssign(string op)(in Board8 rhs)
    {
        mixin ("bits " ~ op ~ "= rhs.bits;");
        return this;
    }

    bool opEquals(in Board8 rhs) const
    {
        return bits == rhs.bits;
    }

    hash_t toHash() const nothrow @safe
    {
        return typeid(bits).getHash(&bits);
    }

    Board8 liberties(in Board8 playing_area) const
    {
        return (
            (this << H_SHIFT) |
            (this >> H_SHIFT) |
            (this << V_SHIFT) |
            (this >> V_SHIFT)
        ) & (~this) & playing_area;
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
    ref Board8 flood_into(in Board8 target)
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

    void snap(out int westwards, out int northwards)
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

    void fix(in int westwards, in int northwards)
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

    private ulong naive_rotate()
    in
    {
        assert(valid);
        assert(!(bits & EAST_WALL));
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
        return format("Board8(%sUL)", bits);
    }

    @property bool toBool() const
    {
        return cast(bool)bits;
    }

    alias toBool this;
}

T rectangle(T)(int width, int height){
    T result;
    for (int y = 0; y < height; y++){
        for (int x = 0; x < width; x++){
            result |= T(x, y);
        }
    }
    return result;
}

immutable Board8 full8 = Board8(Board8.FULL);
immutable Board8 empty8 = Board8(Board8.EMPTY);

int popcount(Board8 b)
{
    return popcount(b.bits);
}


void print_forage_pattern()
{
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
    writeln("[");
    foreach (block; forage){
        writeln("    " ~ block.repr() ~ ",");
    }
    writeln("];");
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

    b0.flood_into(b2);

    assert(b0 == b1);
}

unittest
{
    Board8 b = Board8(Board8.FULL);
    assert(b.popcount() == Board8.WIDTH * Board8.HEIGHT);
}


void main()
{
    auto b = Board8(12398724987489237345UL & ~Board8.EAST_WALL & Board8.FULL);
    writeln(b);
    writeln;
    auto r = Board8(b.naive_rotate);
    writeln(r);
}
