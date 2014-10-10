module polyomino;

import std.stdio;
import std.array;


struct Piece
{
    int x;
    int y;

    bool opEquals(in Piece rhs) const pure nothrow @nogc @safe
    {
        return x == rhs.x && y == rhs.y;
    }

    int opCmp(in Piece rhs) const pure nothrow @nogc @safe
    {
        if (x != rhs.x){
            return x - rhs.x;
        }
        return y - rhs.y;
    }

    hash_t toHash() const nothrow @safe
    {
        hash_t y_hash = typeid(y).getHash(&y);
        return (
            typeid(x).getHash(&x) ^
            (y_hash << (hash_t.sizeof * 4)) ^
            (y_hash >> (hash_t.sizeof * 4))
        );
    }
}


struct Shape
{
    Piece[] pieces;

    this(Piece[] pieces)
    {
        this.pieces = pieces.dup;
        this.pieces.sort;
    }

    /*
    invariant
    {
        for (int index = 0; index < pieces.length - 1; index++){
            assert(pieces[index] < pieces[index + 1]);
        }
    }
    */

    bool opEquals(in Shape rhs) const pure nothrow @nogc @safe
    {
        if (pieces.length != rhs.pieces.length){
            return false;
        }
        foreach (index, piece; pieces){
            if (piece != rhs.pieces[index]){
                return false;
            }
        }
        return true;
    }

    int opCmp(in Shape rhs) const pure nothrow @nogc @safe
    {
        if (pieces.length < rhs.pieces.length){
            return -1;
        }
        if (pieces.length > rhs.pieces.length){
            return 1;
        }
        foreach(index, piece; pieces){
            auto rhs_piece = rhs.pieces[index];
            if (piece < rhs_piece){
                return -1;
            }
            if (piece > rhs_piece){
                return 1;
            }
        }
        return 0;
    }

    hash_t toHash() const nothrow @safe
    {
        hash_t result;
        foreach (piece; pieces){
            result ^= piece.toHash;
        }
        return result;
    }

    int extent(string member, string op)()
    {
        if (!pieces.length){
            return 0;
        }
        mixin("int result = pieces[0]." ~ member ~ ";");
        foreach (piece; pieces){
            mixin("
                if (piece." ~ member ~ " " ~ op ~ " result){
                    result = piece." ~ member ~ ";
                }
            ");
        }

        return result;
    }

    alias west_extent = extent!("x", "<");
    alias east_extent = extent!("x", ">");
    alias north_extent = extent!("y", "<");
    alias south_extent = extent!("y", ">");

    void snap()
    {
        auto west_shift = west_extent;
        auto north_shift = north_extent;
        foreach (ref piece; pieces){
            piece.x -= west_shift;
            piece.y -= north_shift;
        }
    }

    void rotate()
    {
        foreach(ref piece; pieces){
            int temp = piece.x;
            piece.x = piece.y;
            piece.y = -temp;
        }
        snap;
        pieces.sort;
    }

    void mirror_h()
    {
        foreach(ref piece; pieces){
            piece.x = -piece.x;
        }
        snap;
        pieces.sort;
    }

    void canonize()
    {
        snap;
        auto temp = Shape(this.pieces);
        enum compare_and_replace = "
            if (temp < this){
                this = temp;
                temp = Shape(this.pieces);
            }
        ";
        for (int i = 0; i < 3; i++){
            temp.rotate;
            mixin(compare_and_replace);
        }
        temp.mirror_h;
        mixin(compare_and_replace);
        for (int i = 0; i < 3; i++){
            temp.rotate;
            mixin(compare_and_replace);
        }
    }

    bool[Shape] shapes_plus_one()
    {
        bool[Piece] piece_set;
        foreach (piece; pieces){
            piece_set[piece] = true;
        }

        bool[Shape] result;
        enum add_new_shape = "
            if (new_piece !in piece_set){
                auto new_pieces = pieces.dup;
                new_pieces ~= new_piece;
                auto new_shape = Shape(new_pieces);
                new_shape.canonize;
                result[new_shape] = true;
            }
        ";
        foreach (piece; pieces){
            auto new_piece = piece;
            new_piece.x += 1;
            mixin(add_new_shape);
            new_piece.x -= 2;
            mixin(add_new_shape);
            new_piece.x += 1;
            new_piece.y += 1;
            mixin(add_new_shape);
            new_piece.y -= 2;
            mixin(add_new_shape);
        }
        return result;
    }
}

bool[Shape] polyominoes(int max_size)
{
    bool[Shape] result;
    Shape[] queue;
    auto shape = Shape([Piece(0, 0)]);
    result[shape] = true;
    queue ~= shape;
    while (queue.length){
        shape = queue.front;
        queue.popFront;
        result[shape] = true;
        if (shape.pieces.length < max_size){
            foreach (new_shape; shape.shapes_plus_one.byKey){
                if (new_shape !in result){
                    queue ~= new_shape;
                }
            }
        }
    }
    return result;
}

unittest
{
    assert(polyominoes(1).length == 1);
    assert(polyominoes(2).length == 2);
    assert(polyominoes(3).length == 4);
    assert(polyominoes(4).length == 9);
    assert(polyominoes(5).length == 21);
    assert(polyominoes(6).length == 56);
    assert(polyominoes(7).length == 164);
}
