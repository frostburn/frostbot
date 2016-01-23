module board8;

import std.stdio;
import std.string;
import std.stream;

import utils;
import board_common;

version(polyomino){
    import polyomino;
}

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
    enum INVALID = 0xFFFFFFFFFFFFFFFFUL;

    static immutable ulong[WIDTH * HEIGHT / 2] FORAGE_TABLE = mixin(get_forage_table);

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
        bits = 1UL << (x * H_SHIFT + y * V_SHIFT);
    }

    void to_stream(OutputStream stream)
    {
        stream.write(bits);
    }

    static Board8 from_stream(InputStream stream)
    {
        ulong bits;
        stream.read(bits);
        return Board8(bits);
    }

    static Board8 full()
    {
        return Board8(FULL);
    }

    static Board8 empty()
    {
        return Board8(EMPTY);
    }

    static Board8 invalid()
    {
        return Board8(INVALID);
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

    int popcount() const pure nothrow @nogc @safe
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

    Board8 cross_unsafe() const pure nothrow @nogc @safe
    {
        return Board8(bits | (bits << H_SHIFT) | (bits >> H_SHIFT) | (bits << V_SHIFT) | (bits >> V_SHIFT));
    }

    Board8 cross(in Board8 playing_area) const pure nothrow @nogc @safe
    {
        return Board8((bits | (bits << H_SHIFT) | (bits >> H_SHIFT) | (bits << V_SHIFT) | (bits >> V_SHIFT)) & playing_area.bits);
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

    Board8 inner_border() const pure nothrow @nogc @safe
    {
        auto temp = ~bits;
        return Board8(
            (
                (temp << H_SHIFT) |
                (temp >> H_SHIFT) |
                (temp << V_SHIFT) |
                (temp >> V_SHIFT) |
                NORTH_WALL | WEST_WALL | SOUTH_WALL | EAST_WALL
            ) & bits
        );
    }

    Board8 east() const
    {
        return Board8((bits << H_SHIFT) & FULL);
    }

    Board8 west() const
    {
        return Board8((bits >> H_SHIFT) & FULL);
    }

    Board8 east(in int n=1) const
    {
        uint new_bits = cast(uint)bits;
        for (int i = 0; i < n; i++){
            new_bits = (new_bits << H_SHIFT) & FULL;
        }
        return Board8(new_bits);
    }

    Board8 west(in int n=1) const
    {
        uint new_bits = cast(uint)bits;
        for (int i = 0; i < n; i++){
            new_bits = (new_bits >> H_SHIFT) & FULL;
        }
        return Board8(new_bits);
    }

    Board8 south(in int n=1) const
    {
        return Board8((bits << (V_SHIFT * n)) & FULL);
    }

    Board8 north(in int n=1) const
    {
        return Board8(bits >> (V_SHIFT * n));
    }

    ubyte pattern3_player_at(in int x, in int y) const
    in
    {
        assert((0 <= x) && (x < WIDTH) && (0 <= y) && (y < HEIGHT));
        assert(valid);
    }
    body
    {
        int shift = H_SHIFT * (x - 1) + V_SHIFT * (y - 1);
        return cast(ubyte) (
            (right_shift(bits, shift) & 7) |
            (right_shift(bits, shift + V_SHIFT - 3) & 8) |
            (right_shift(bits, shift + V_SHIFT - 2) & 16) |
            (right_shift(bits, shift + 2 * V_SHIFT - 5) & 224)
        );
    }

    ubyte pattern3_border_at(in int x, in int y) const
    {
        return ~pattern3_player_at(x, y);
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
        ulong temp;
        ulong target_bits = target.bits;

        bits &= target_bits;
        if (!bits){
            return this;
        }

        // TODO: Figure out why the "+" hack didn't work.
        do{
            temp = bits;
            bits |= (
                (bits << H_SHIFT) |
                (bits >> H_SHIFT) |
                (bits << V_SHIFT) |
                (bits >> V_SHIFT)
            ) & target_bits;
        } while(bits != temp);

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
        assert(HEIGHT == WIDTH - 1);
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < HEIGHT; x++){
                result |= (
                    (1UL & ( bits >> (x * H_SHIFT + y * V_SHIFT))) <<
                    (y * H_SHIFT + (WIDTH - 2 - x) * V_SHIFT)
                );
            }
        }
        return result;
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
        bits = (
            (bits & 0x40UL) << (6 * D_SHIFT) |
            (bits & 0x8020UL) << (5 * D_SHIFT) |
            (bits & 0x1004010UL) << (4 * D_SHIFT) |
            (bits & 0x200802008UL) << (3 * D_SHIFT) |
            (bits & 0x40100401004UL) << (2 * D_SHIFT) |
            (bits & 0x8020080200802UL) << D_SHIFT |
            (bits & 0x1004010040100401UL) |
            (bits & 0x802008020080200UL) >> D_SHIFT |
            (bits & 0x401004010040000UL) >> (2 * D_SHIFT) |
            (bits & 0x200802008000000UL) >> (3 * D_SHIFT) |
            (bits & 0x100401000000000UL) >> (4 * D_SHIFT) |
            (bits & 0x80200000000000UL) >> (5 * D_SHIFT) |
            (bits & 0x40000000000000UL) >> (6 * D_SHIFT)
        );
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

        enum WEST_BLOCK = WEST_WALL | (WEST_WALL << H_SHIFT) | (WEST_WALL << (2 * H_SHIFT)) | (WEST_WALL << (3 * H_SHIFT));
        enum WEST_STRIP = WEST_WALL | (WEST_WALL << H_SHIFT) | (WEST_WALL << (4 * H_SHIFT)) | (WEST_WALL << (5 * H_SHIFT));
        enum WEST_GRID = WEST_WALL | (WEST_WALL << (2 * H_SHIFT)) | (WEST_WALL << (4 * H_SHIFT)) | (WEST_WALL << (6 * H_SHIFT));

        bits = ((bits & WEST_BLOCK) << (4 * H_SHIFT)) | ((bits >> (4 * H_SHIFT)) & WEST_BLOCK);
        bits = ((bits & WEST_STRIP) << (2 * H_SHIFT)) | ((bits >> (2 * H_SHIFT)) & WEST_STRIP);
        bits = ((bits & WEST_GRID) << H_SHIFT) | ((bits >> H_SHIFT) & WEST_GRID);

        version(assert){
            assert(old_bits.popcount == bits.popcount);
        }
    }

    void mirror_h_alt()
    {
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

        enum NORTH_BLOCK = NORTH_WALL | (NORTH_WALL << V_SHIFT) | (NORTH_WALL << (2 * V_SHIFT));
        enum CENTER = NORTH_WALL << (3 * V_SHIFT);
        enum NORTH_GRID = NORTH_WALL | (NORTH_WALL << (4 * V_SHIFT));
        enum GRID_CENTERS = (NORTH_WALL << V_SHIFT) | CENTER | (NORTH_WALL << (5 * V_SHIFT));

        auto center = bits & CENTER;
        bits = ((bits & NORTH_BLOCK) << (4 * V_SHIFT)) | (bits >> (4 * V_SHIFT)) | (bits & CENTER);
        bits = ((bits & NORTH_GRID) << (2 * V_SHIFT)) | ((bits >> (2 * V_SHIFT)) & NORTH_GRID) | (bits & GRID_CENTERS);

        version(assert){
            assert(old_bits.popcount == bits.popcount);
        }
    }

    void mirror_v_alt()
    {
        bits = (
            (bits & (NORTH_WALL << (0 * V_SHIFT))) << ((HEIGHT - 1) * V_SHIFT) |
            (bits & (NORTH_WALL << (1 * V_SHIFT))) << ((HEIGHT - 3) * V_SHIFT) |
            (bits & (NORTH_WALL << (2 * V_SHIFT))) << ((HEIGHT - 5) * V_SHIFT) |
            (bits & (NORTH_WALL << (3 * V_SHIFT))) |
            (bits & (NORTH_WALL << (4 * V_SHIFT))) >> (2 * V_SHIFT) |
            (bits & (NORTH_WALL << (5 * V_SHIFT))) >> (4 * V_SHIFT) |
            (bits & (NORTH_WALL << (6 * V_SHIFT))) >> (6 * V_SHIFT)
        );
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
            if (bits & (EAST_WALL >> ((WIDTH - extent) * H_SHIFT))){
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
        while (extent > 0){
            if (bits & (SOUTH_WALL >> ((HEIGHT - extent) * V_SHIFT))){
                return extent;
            }
            extent--;
        }
        return extent;
    }

    /// Euler characteristic of the board treating each stone as a square. (Connects vertically, horicontally and *diagonally*)
    int euler()
    in
    {
        assert(valid);
    }
    body
    {
        ulong temp = bits | (bits << H_SHIFT);
        int characteristic = -utils.popcount(temp);  // vertical edges
        characteristic += utils.popcount(temp & NORTH_WALL);  // northern vertices
        characteristic += utils.popcount(temp | (temp >> V_SHIFT));  // rest of the vertices
        characteristic -= utils.popcount(bits & NORTH_WALL);  // northern horizontal edges
        characteristic -= utils.popcount(bits | (bits >> V_SHIFT));  // rest of the horizontal edges
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

    /// Euler characteristic of the board treating each stone as a diamond. (Connects only vertically and horicontally)
    int diamond_euler()
    in
    {
        assert(valid);
    }
    body
    {
        int characteristic = utils.popcount(bits & NORTH_WALL);  // northern vertices
        characteristic += utils.popcount(bits | (bits >> V_SHIFT));  // rest of the vertical vertices
        characteristic += utils.popcount(bits | (bits << H_SHIFT));  // horizontal vertices
        return characteristic - 3 * utils.popcount(bits);  // edges and pixels
    }

    /// Euler characteristic of the board treating each stone as a diamond and filling up sigle diamond shaped holes.
    int true_euler()
    in
    {
        assert(valid);
    }
    body
    {
        ulong temp = bits & (bits >> H_SHIFT);
        return diamond_euler + utils.popcount(temp & (temp >> V_SHIFT));
    }

    Board8[] pieces() const
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
        Board8[] result;
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < WIDTH; x++){
                auto piece = Board8(x, y);
                if (piece & this){
                    result ~= piece;
                }
            }
        }
        return result;
    }

    // TODO: Optimize forage tables based on the extent of the playing area.
    Board8[] unoptimized_chains()
    in
    {
        assert(valid);
    }
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

    Board8[] chains() const
    in
    {
        assert(valid);
    }
    out(result)
    {
        assert(result.length <= WIDTH * HEIGHT / 2 + 1);
    }
    body
    {
        ulong foragee = bits;
        ulong temp, temp2;
        Board8[] result;
        foreach (block; FORAGE_TABLE){
            if (!foragee){
                break;
            }
            temp = foragee & block;
            if (temp){
                temp |= (~(temp + foragee)) & foragee;
                do{
                    temp2 = temp;
                    temp |= (
                        (temp >> H_SHIFT) |
                        (temp << V_SHIFT) |
                        (temp >> V_SHIFT)
                    ) & foragee;
                    temp |= (~(temp + foragee)) & foragee;
                } while(temp2 != temp);
                foragee ^= temp;
                result ~= Board8(temp);
            }
        }
        return result;
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
            Board8 temp = this & block;
            if (temp){
                temp.flood_into(this);
                return this == temp;
            }
        }
        assert(false);
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

version(polyomino){
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

    alias from_piece8 = from_piece!Board8;
    alias from_shape8 = from_shape!Board8;
}

alias rectangle8 = rectangle!Board8;


immutable Board8 full8 = Board8(Board8.FULL);
immutable Board8 empty8 = Board8(Board8.EMPTY);
immutable Board8 square8 = Board8(Board8.FULL & ~Board8.EAST_WALL);


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

    // Optimize for small boards
    Board8 small_board = rectangle8(4, 4);
    bool[Board8] used;
    Board8[] temp;
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
        r ~= format("%sUL", block.bits);
        if (index < forage.length - 1){
            r ~= ", ";
        }
    }
    r ~= "]";
    return r;

    /*
    r ~= "[";
    foreach (index, block; forage){
        r ~= block.repr;
        if (index < forage.length - 1){
            r ~= ", ";
        }
    }
    r ~= "]";
    return r;
    */
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

unittest
{
    assert((Board8(0, 0) | Board8(5, 0)).east(3) == Board8(3, 0));
}

unittest
{
    auto b = Board8(0, 0) | Board8(1, 0);
    assert(b.euler == 1);
    assert(b.diamond_euler == 1);
    assert(b.true_euler == 1);

    b |= Board8(5, 5);
    assert(b.euler == 2);
    assert(b.diamond_euler == 2);
    assert(b.true_euler == 2);

    b = Board8(0, 0) | Board8(1, 1) | Board8(2, 0);
    assert(b.euler == 1);
    assert(b.diamond_euler == 3);
    assert(b.true_euler == 3);

    b = Board8(1, 0) | Board8(0, 1) | Board8(1, 2) | Board8(2, 1);
    assert(b.euler == 0);
    assert(b.diamond_euler == 4);
    assert(b.true_euler == 4);

    b = rectangle8(2, 2);
    assert(b.euler == 1);
    assert(b.diamond_euler == 0);
    assert(b.true_euler == 1);

    b = rectangle8(3, 3) & ~Board8(1, 1);
    assert(b.euler == 0);
    assert(b.diamond_euler == 0);
    assert(b.true_euler == 0);
}

unittest
{
    auto b = Board8(0, 0);
    assert(!b.west);
    assert(b.east);
    assert(!b.north);
    assert(b.south);

    b = Board8(0, Board8.HEIGHT - 1);
    assert(!b.west);
    assert(b.east);
    assert(b.north);
    assert(!b.south);

    b = Board8(Board8.WIDTH - 1, Board8.HEIGHT - 1);
    assert(b.west);
    assert(!b.east);
    assert(b.north);
    assert(!b.south);
}

unittest
{
    auto b = Board8(2349872384947897979UL) & full8;
    int total_popcount = 0;
    foreach (y; 0..Board8.HEIGHT){
        foreach (x; 0..Board8.WIDTH){
            total_popcount += b.pattern3_player_at(x, y).popcount;
        }
    }
    auto corners = Board8(0, 0) | Board8(0, Board8.HEIGHT - 1) | Board8(Board8.WIDTH - 1, 0) | Board8(Board8.WIDTH - 1, Board8.HEIGHT - 1);
    auto edges = full8.inner_border ^ corners;
    auto center = ~(full8.inner_border);
    int calculated_popcount = 3 * (b & corners).popcount + 5 * (b & edges).popcount + 8 * (b & center).popcount;
    assert(calculated_popcount == total_popcount);
}

unittest
{
    auto stream = new MemoryStream;
    auto b = Board8(2, 3);
    b.to_stream(stream);
    stream.position = 0;
    auto c = Board8.from_stream(stream);
    assert(b == c);
}

unittest
{
    auto b = Board8(123881237912738987) & square8;
    auto a = Board8(b.naive_rotate);
    b.rotate;
    assert(a == b);
}

unittest
{
    auto a = Board8(1239892183798712983 & Board8.FULL);
    auto b = a;
    a.mirror_h;
    b.mirror_h_alt;
    assert(a == b);

    auto c = Board8(1297234234123987123 & Board8.FULL);
    auto d = c;
    c.mirror_v;
    d.mirror_v_alt;
    assert(c == d);
}
