module pattern3;

import std.stdio;
import std.string;

struct Pattern3
{
    ubyte player;
    ubyte opponent;

    static immutable ubyte[256] ROTATION_TABLE = mixin(get_rotation_table);

    this(in ubyte player, in ubyte opponent) pure nothrow @nogc @safe
    {
        this.player = player;
        this.opponent = opponent;
    }

    this(in int player, in int opponent) pure nothrow @nogc @safe
    {
        this(cast(ubyte)player, cast(ubyte)opponent);
    }

    this(in ubyte player, in ubyte opponent, in ubyte border) pure nothrow @nogc @safe
    {
        this(player | border, opponent | border);
    }

    int opCmp(in Pattern3 rhs) const pure nothrow @nogc @safe
    {
        if (player < rhs.player){
            return -1;
        }
        if (player > rhs.player){
            return 1;
        }
        if (opponent < rhs.opponent){
            return -1;
        }
        if (opponent > rhs.opponent){
            return 1;
        }
        return 0;
    }

    hash_t toHash() const nothrow @safe
    {
        return cast(hash_t)player | (cast(hash_t)opponent << 8);
    }



    void rotate() pure nothrow @nogc @safe
    {
        player = ROTATION_TABLE[player];
        opponent = ROTATION_TABLE[opponent];
    }

    void mirror_v() pure nothrow @nogc @safe
    {
        player = cast(ubyte)((player << 5) | (player & 24) | (player >> 5));
        opponent = cast(ubyte)((opponent << 5) | (opponent & 24) | (opponent >> 5));
    }

    void canonize()
    {
        Pattern3 temp = this;
        temp.rotate;
        if (temp < this){
            this = temp;
        }
        temp.rotate;
        if (temp < this){
            this = temp;
        }
        temp.rotate;
        if (temp < this){
            this = temp;
        }
        temp.mirror_v;
        if (temp < this){
            this = temp;
        }
        temp.rotate;
        if (temp < this){
            this = temp;
        }
        temp.rotate;
        if (temp < this){
            this = temp;
        }
        temp.rotate;
        if (temp < this){
            this = temp;
        }
    }

    string toString()
    {
        string r;
        foreach (j; 0..3){
            foreach (i; 0..3){
                ubyte p = 0;
                if (j == 0 || (j == 1 && i == 0)){
                    p = cast(ubyte)(1 << (i + 3 * j));
                }
                if (j == 2 || (j == 1 && i == 2)){
                    p = cast(ubyte)(1 << (i - 1 + 3 * j));
                }
                if (p & player){
                    if (p & opponent){
                        r ~= "# ";
                    }
                    else {
                        r ~= "@ ";
                    }
                }
                else {
                    if (p & opponent){
                        r ~= "O ";
                    }
                    else {
                        r ~= ". ";
                    }
                }
            }
            if (j < 2){
                r ~= "\n";
            }
        }
        return r;
    }
}


Pattern3 from_hash(hash_t h)
{
    return Pattern3(h & 255, (h >> 8) & 255);
}


// Clockwise rotation
// 1  2  4
// 8     16
// 32 64 128
ubyte naive_rotate(ubyte stones)
{
    ubyte result = 0;
    if (stones & 1){
        result |= 4;
    }
    if (stones & 2){
        result |= 16;
    }
    if (stones & 4){
        result |= 128;
    }
    if (stones & 8){
        result |= 2;
    }
    if (stones & 16){
        result |= 64;
    }
    if (stones & 32){
        result |= 1;
    }
    if (stones & 64){
        result |= 8;
    }
    if (stones & 128){
        result |= 32;
    }
    return result;
}


string get_rotation_table()
{
    string r;
    r ~= "[";
    foreach (stones; 0..256){
        r ~= format("0x%x", naive_rotate(cast(ubyte)stones));
        if (stones < 255){
            r ~= ", ";
        }
    }
    r ~= "]";
    return r;
}


unittest
{
    foreach (player; 0..256){
        foreach (opponent; 0..256){
            auto p = Pattern3(player, opponent);
            assert(p == from_hash(p.toHash));
        }
    }
}
