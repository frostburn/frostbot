module board11;

import std.stdio;
import std.string;
import std.stream;
import core.simd;

import utils;
import polyomino;
import board_common;


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
    enum WEST_WALL = 0x1001001001001UL;
    enum EAST_WALL = 0x400400400400400UL;
    enum H_WALL = 0x7FFUL;
    enum R_LINE = 0x1FUL;

    static immutable Board11[WIDTH * HEIGHT / 2] FORAGE_TABLE = mixin(get_forage_table);

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

    void to_stream(OutputStream stream)
    {
        stream.write(north_bits);
        stream.write(south_bits);
    }

    static Board11 from_stream(InputStream stream)
    {
        ulong north_bits;
        ulong south_bits;
        stream.read(north_bits);
        stream.read(south_bits);
        return Board11(north_bits, south_bits, true);
    }

    static Board11 full()
    {
        return Board11(FULL, FULL, true);
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

    Board11 blob(in Board11 playing_area) const pure nothrow @nogc @safe
    {
        auto north_temp = north_bits | (north_bits << H_SHIFT) | (north_bits >> H_SHIFT);
        auto south_temp = south_bits | (south_bits << H_SHIFT) | (south_bits >> H_SHIFT);
        return Board11(
            (north_temp | (north_temp << V_SHIFT) | (north_temp >> V_SHIFT) | (south_temp & FLOOD_LINE)) & playing_area.north_bits,
            (south_temp | (south_temp << V_SHIFT) | (south_temp >> V_SHIFT) | (north_temp & FLOOD_LINE)) & playing_area.south_bits,
            true
        );
    }

    Board11 cross(in Board11 playing_area) const pure nothrow @nogc @safe
    {
        return Board11(
            (
                north_bits |
                (north_bits << H_SHIFT) |
                (north_bits >> H_SHIFT) |
                (north_bits << V_SHIFT) |
                (north_bits >> V_SHIFT) |
                (south_bits & FLOOD_LINE)
            ) & playing_area.north_bits,
            (
                south_bits |
                (south_bits << H_SHIFT) |
                (south_bits >> H_SHIFT) |
                (south_bits << V_SHIFT) |
                (south_bits >> V_SHIFT) |
                (north_bits & FLOOD_LINE)
            ) & playing_area.south_bits,
            true
        );
    }

    Board11 liberties(in Board11 playing_area) const pure nothrow @nogc @safe
    {
        return Board11(
            (
                (north_bits << H_SHIFT) |
                (north_bits >> H_SHIFT) |
                (north_bits << V_SHIFT) |
                (north_bits >> V_SHIFT) |
                (south_bits & FLOOD_LINE)
            ) & (~north_bits) & playing_area.north_bits,
            (
                (south_bits << H_SHIFT) |
                (south_bits >> H_SHIFT) |
                (south_bits << V_SHIFT) |
                (south_bits >> V_SHIFT) |
                (north_bits & FLOOD_LINE)
            ) & (~south_bits) & playing_area.south_bits,
            true
        );
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

    Board11 east(in int n) pure nothrow @nogc @safe
    {
        auto result = this;
        foreach (i; 0..n){
            result = result.east;
        }
        return result;
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

    Board11 west(in int n) pure nothrow @nogc @safe
    {
        auto result = this;
        foreach (i; 0..n){
            result = result.west;
        }
        return result;
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

    Board11 north(in int n) pure nothrow @nogc @safe
    {
        auto result = this;
        foreach (i; 0..n){
            result = result.north;
        }
        return result;
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

    Board11 south(in int n) pure nothrow @nogc @safe
    {
        auto result = this;
        foreach (i; 0..n){
            result = result.south;
        }
        return result;
    }

    //TODO:
    ubyte pattern3_player_at(in int x, in int y) const
    {
        assert(false);
        return 0;
    }

    ubyte pattern3_border_at(in int x, in int y) const
    {
        assert(false);
        return 0;
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

    void clear()
    {
        north_bits = EMPTY;
        south_bits = EMPTY;
    }

    void fill(){
        north_bits = FULL;
        south_bits = FULL;
    }

    void snap(out int westwards, out int northwards)// pure nothrow @nogc @safe
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
        while (!((north_bits | south_bits) & WEST_WALL)){
            north_bits >>= H_SHIFT;
            south_bits >>= H_SHIFT;
            westwards++;
        }
        while (!(north_bits & H_WALL)){
            north_bits >>= V_SHIFT;
            north_bits |= south_bits & FLOOD_LINE;
            south_bits = (south_bits << V_SHIFT) & FULL;
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
        north_bits >>= H_SHIFT * westwards;
        south_bits >>= H_SHIFT * westwards;
        foreach (i; 0..northwards){
            north_bits >>= V_SHIFT;
            north_bits |= south_bits & FLOOD_LINE;
            south_bits = (south_bits << V_SHIFT) & FULL;
        }
    }

    bool can_rotate() pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    body
    {
        return !((north_bits | south_bits) & EAST_WALL);
    }

    Board11 naive_rotate() pure nothrow @nogc @safe
    in
    {
        assert(valid);
        assert(can_rotate);
    }
    out(result)
    {
        assert(result.valid);
        assert(result.popcount == this.popcount);
    }
    body
    {
        Board11 result;
        assert(HEIGHT == WIDTH - 1);
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < HEIGHT; x++){
                auto p = Board11(x, y);
                if (this & p){
                    result |= Board11(y, WIDTH - 2 - x);
                }
            }
        }
        return result;
    }

    void rotate() pure nothrow @nogc @safe
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
        mirror_d;
        mirror_v;
    }

    void mirror_d() pure nothrow @nogc @safe
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
        enum D_SHIFT = V_SHIFT - H_SHIFT;
        enum Z_SHIFT = V_SHIFT + H_SHIFT;
        enum WEST_BLOCK = 0x1F01F01F01F01FUL;
        enum EAST_BLOCK = 0x3E03E03E03E03E0UL;
        north_bits = (
            (north_bits & 0x210UL) << (4 * D_SHIFT) |
            (north_bits & 0x210108UL) << (3 * D_SHIFT) |
            (north_bits & 0x210108084UL) << (2 * D_SHIFT) |
            (north_bits & 0x210108084042UL) << D_SHIFT |
            (north_bits & 0x210108084042021UL) |
            (north_bits & 0x108084042021000UL) >> D_SHIFT |
            (north_bits & 0x84042021000000UL) >> (2 * D_SHIFT) |
            (north_bits & 0x42021000000000UL) >> (3 * D_SHIFT) |
            (north_bits & 0x21000000000000UL) >> (4 * D_SHIFT)
        );
        auto temp = north_bits & EAST_BLOCK;

        south_bits = (
            (south_bits & 0x21UL) << (4 * Z_SHIFT) |
            (south_bits & 0x21042UL) << (3 * Z_SHIFT) |
            (south_bits & 0x21042084UL) << (2 * Z_SHIFT) |
            (south_bits & 0x21042084108UL) << Z_SHIFT |
            (south_bits & 0x21042084108210UL) |
            (south_bits & 0x42084108210000UL) >> Z_SHIFT |
            (south_bits & 0x84108210000000UL) >> (2 * Z_SHIFT) |
            (south_bits & 0x108210000000000UL) >> (3 * Z_SHIFT) |
            (south_bits & 0x210000000000000UL) >> (4 * Z_SHIFT)
        );
        temp |= south_bits & WEST_BLOCK;

        temp = (
            (temp & (H_WALL << (0 * V_SHIFT))) << (4 * V_SHIFT) |
            (temp & (H_WALL << (1 * V_SHIFT))) << (2 * V_SHIFT) |
            (temp & (H_WALL << (2 * V_SHIFT))) |
            (temp & (H_WALL << (3 * V_SHIFT))) >> (2 * V_SHIFT) |
            (temp & (H_WALL << (4 * V_SHIFT))) >> (4 * V_SHIFT)
        );

        north_bits = (north_bits & WEST_BLOCK) | (temp & WEST_BLOCK) << (5 * H_SHIFT);
        south_bits = (south_bits & EAST_BLOCK) | (temp & EAST_BLOCK) >> (5 * H_SHIFT);
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
        string do_mirror_h(string part){
            return "
                " ~ part ~ "_bits = (
                    (" ~ part ~ "_bits & (WEST_WALL << (0 * H_SHIFT))) << ((WIDTH - 1) * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (1 * H_SHIFT))) << ((WIDTH - 3) * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (2 * H_SHIFT))) << ((WIDTH - 5) * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (3 * H_SHIFT))) << ((WIDTH - 7) * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (4 * H_SHIFT))) << ((WIDTH - 9) * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (5 * H_SHIFT))) |
                    (" ~ part ~ "_bits & (WEST_WALL << (6 * H_SHIFT))) >> (2 * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (7 * H_SHIFT))) >> (4 * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (8 * H_SHIFT))) >> (6 * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (9 * H_SHIFT))) >> (8 * H_SHIFT) |
                    (" ~ part ~ "_bits & (WEST_WALL << (10 * H_SHIFT))) >> (10 * H_SHIFT)
                );";
        }
        mixin(do_mirror_h("north"));
        mixin(do_mirror_h("south"));
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
        auto temp = north_bits;
        north_bits = south_bits;
        south_bits = temp;
    }

    void transform(Transformation transformation) nothrow @nogc @safe
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
        if (transformation == Transformation.rotate){
            assert(can_rotate);
            rotate;
        }
        else if (transformation == Transformation.flip){
            mirror_v;
            mirror_h;
        }
        else if (transformation == Transformation.rotate_thrice){
            assert(can_rotate);
            rotate;
            rotate;
            rotate;
        }
        else if (transformation == Transformation.mirror_v_rotate){
            assert(can_rotate);
            mirror_v;
            rotate;
        }
        else if (transformation == Transformation.mirror_h){
            mirror_h;
        }
        else if (transformation == Transformation.rotate_mirror_v){
            assert(can_rotate);
            rotate;
            mirror_v;
        }
        else if (transformation == Transformation.mirror_v){
            mirror_v;
        }
    }

    int horizontal_extent() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    body
    {
        int extent = WIDTH;
        while (extent > 0){
            if ((north_bits | south_bits) & (EAST_WALL >> ((WIDTH - extent) * H_SHIFT))){
                return extent;
            }
            extent--;
        }
        return extent;
    }

    int vertical_extent() const pure nothrow @nogc @safe
    in
    {
        assert(valid);
    }
    body
    {
        int extent = HEIGHT;
        while (extent > 5){
            if (south_bits & (H_WALL << ((HEIGHT - extent) * V_SHIFT))){
                return extent;
            }
            extent--;
        }
        while (extent > 0) {
            if (north_bits & (H_WALL << ((extent - 1) * V_SHIFT))){
                return extent;
            }
            extent--;
        }
        return extent;
    }

    // TODO:
    int euler()
    {
        assert(false);
        return 0;
    }

    Board11[] pieces() const
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.length <= WIDTH * HEIGHT);
    }
    body
    {
        Board11[] result;
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < WIDTH; x++){
                auto piece = Board11(x, y);
                if (piece & this){
                    result ~= piece;
                }
            }
        }
        return result;
    }

    Board11[] chains()
    in
    {
        assert(valid);
    }
    out(result){
        assert(result.length <= WIDTH * HEIGHT / 2 + 1);
    }
    body
    {
        Board11 foragee = this;
        Board11[] result;
        foreach (block; FORAGE_TABLE){
            Board11 temp = foragee & block;
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

    bool is_contiguous() const
    in
    {
        assert(valid);
    }
    body
    {
        if (!this){
            return true;
        }
        foreach (block; FORAGE_TABLE){
            Board11 temp = this & block;
            if (temp){
                temp.flood_into(this);
                return this == temp;
            }
        }
        assert(false);
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
immutable Board11 square11 = Board11(0x3FF3FF3FF3FF3FFUL, 0x3FF3FF3FF3FF3FFUL, true);


alias rectangle11 = rectangle!Board11;


string get_forage_table()
{
    string r;
    Board11 forage[];
    for (int y = 0; y < Board11.HEIGHT; y += 2){
        for (int x = 0; x < Board11.WIDTH; x++){
            Board11 block = Board11(x, y);
            block |= Board11(x, y + 1);
            forage ~= block;
        }
    }

    // Optimize for 9x9
    Board11 small_board = rectangle11(9, 9);
    bool[Board11] used;
    Board11[] temp;
    foreach(block; forage){
        if (block & small_board){
            temp ~= block;
            used[block] = true;
        }
    }
    foreach(block; forage){
        if (block !in used){
            temp ~= block;
        }
    }
    forage = temp;

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

void print_constants()
{
    Board11 full;
    Board11 flood_line;
    Board11 east_wall;
    Board11 west_wall;
    foreach (y; 0..Board11.HEIGHT){
        foreach (x; 0..Board11.WIDTH){
            auto p = Board11(x, y);
            full |= p;
            if (y == 4 || y == 5){
                flood_line |= p;
            }
            if (x == Board11.WIDTH -1){
                east_wall |= p;
            }
            if (x == 0){
                west_wall |= p;
            }
        }
    }

    writeln(full.repr);
    writeln((~full).repr);
    writeln(flood_line.repr);
    writeln(east_wall.repr);
    writeln(west_wall.repr);
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

unittest
{
    auto b = Board11(123881237912738987, 9231278367867832, true) & square11;
    auto a = b.naive_rotate;
    b.rotate;
    assert(a == b);
}