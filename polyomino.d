module polyomino;

import std.stdio;
import std.array;

import utils;


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


class Shape
{
    Piece[] pieces;

    this()
    {
        pieces = pieces.init;
    }

    this(Piece[] pieces)
    {
        this.pieces = pieces.dup;
        this.pieces.sort;
    }

    bool piece_condition(const Piece piece) const
    {
        return true;
    }

    bool is_good()
    {
        return true;
    }

    /*
    invariant
    {
        for (int index = 0; index < pieces.length - 1; index++){
            assert(pieces[index] < pieces[index + 1]);
        }
        foreach (piece; pieces){
            assert(piece_condition(piece));
        }
    }
    */

    /*
    Shape opAssign(in Shape rhs)
    {
        this.pieces = rhs.pieces.dup;

        return this;
    }

    this(this) pure nothrow @safe
    {
        pieces = pieces.dup;
    }
    */

    Shape copy()
    {
        return new Shape(pieces);
    }

    override bool opEquals(Object _rhs) const pure nothrow @nogc @safe
    {
        Shape rhs = cast(Shape) _rhs;
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

    override hash_t toHash() const nothrow @safe
    {
        hash_t result;
        foreach (piece; pieces){
            result ^= piece.toHash;
        }
        return result;
    }

    Shape opBinary(string op)(in Shape rhs)
        if (op == "|")
    {
        auto piece_set = this.piece_set;

        foreach (piece; rhs.pieces){
            piece_set[piece] = true;
        }

        Piece[] new_pieces;
        foreach (piece; piece_set.byKey){
            new_pieces ~= piece;
        }

        return new Shape(new_pieces);
    }

    Shape opBinary(string op)(in Shape rhs)
        if (op == "&")
    {
        auto piece_set = this.piece_set;

        Piece[] new_pieces;
        foreach (piece; rhs.pieces){
            if (piece in piece_set){
                new_pieces ~= piece;
            }
        }

        return new Shape(new_pieces);
    }

    size_t length(){
        return pieces.length;
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

    bool[Piece] piece_set()
    {
        bool[Piece] _piece_set;
        foreach (piece; pieces){
            _piece_set[piece] = true;
        }
        return _piece_set;
    }


    alias west_extent = extent!("x", "<");
    alias east_extent = extent!("x", ">");
    alias north_extent = extent!("y", "<");
    alias south_extent = extent!("y", ">");

    void translate(int x, int y){
        foreach (ref piece; pieces){
            piece.x += x;
            piece.y += y;
        }
    }

    void snap()
    {
        translate(-west_extent, -north_extent);
    }

    void rotate()
    {
        foreach(ref piece; pieces){
            int temp = piece.x;
            piece.x = piece.y;
            piece.y = -temp;
        }
        pieces.sort;
    }

    void mirror_h()
    {
        foreach(ref piece; pieces){
            piece.x = -piece.x;
        }
        pieces.sort;
    }

    void mirror_d()
    {
        foreach(ref piece; pieces){
            int temp = piece.x;
            piece.x = piece.y;
            piece.y = temp;
        }
        pieces.sort;
    }

    void canonize()
    {
        snap;
        auto temp = this.copy;
        enum compare_and_replace = "
            if (temp < this){
                this.pieces = temp.pieces.dup;
            }
        ";
        for (int i = 0; i < 3; i++){
            temp.rotate;
            temp.snap;
            mixin(compare_and_replace);
        }
        temp.mirror_h;
        temp.snap;
        mixin(compare_and_replace);
        for (int i = 0; i < 3; i++){
            temp.rotate;
            temp.snap;
            mixin(compare_and_replace);
        }
    }

    bool[Shape] shapes_plus_one()
    {
        auto piece_set = this.piece_set;

        bool[Shape] result;
        enum add_new_shape = "
            if (new_piece !in piece_set){
                auto new_pieces = pieces.dup;
                new_pieces ~= new_piece;
                auto new_shape = new Shape(new_pieces);
                new_shape.canonize;
                if (new_shape.is_good){
                    result[new_shape] = true;
                }
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

    Shape liberties()
    {
        auto piece_set = this.piece_set;

        bool[Piece] liberty_piece_set;
        enum add_new_piece = "
            if (piece_condition(new_piece) && new_piece !in piece_set){
                liberty_piece_set[new_piece] = true;
            }
        ";

        foreach (piece; pieces){
            auto new_piece = piece;
            new_piece.x += 1;
            mixin(add_new_piece);
            new_piece.x -= 2;
            mixin(add_new_piece);
            new_piece.x += 1;
            new_piece.y += 1;
            mixin(add_new_piece);
            new_piece.y -= 2;
            mixin(add_new_piece);
        }
        Piece[] new_pieces;
        foreach (liberty; liberty_piece_set.byKey){
            new_pieces ~= liberty;
        }
        return new Shape(new_pieces);
    }

    Shape blob_liberties()
    {
        auto piece_set = this.piece_set;

        bool[Piece] liberty_piece_set;
        enum add_new_piece = "
            if (piece_condition(new_piece) && new_piece !in piece_set){
                liberty_piece_set[new_piece] = true;
            }
        ";

        foreach (piece; pieces){
            auto new_piece = piece;
            new_piece.x += 1;
            mixin(add_new_piece);
            new_piece.y += 1;
            mixin(add_new_piece);
            new_piece.x -= 1;
            mixin(add_new_piece);
            new_piece.x -= 1;
            mixin(add_new_piece);
            new_piece.y -= 1;
            mixin(add_new_piece);
            new_piece.y -= 1;
            mixin(add_new_piece);
            new_piece.x += 1;
            mixin(add_new_piece);
            new_piece.x += 1;
            mixin(add_new_piece);
        }
        Piece[] new_pieces;
        foreach (liberty; liberty_piece_set.byKey){
            new_pieces ~= liberty;
        }
        return new Shape(new_pieces);
    }

    Shape corners()
    {
        auto piece_set = this.piece_set;

        foreach (piece; pieces){
            auto new_piece = piece;
            new_piece.x += 1;
            piece_set[new_piece] = true;
            new_piece.x -= 2;
            piece_set[new_piece] = true;
            new_piece.x += 1;
            new_piece.y += 1;
            piece_set[new_piece] = true;
            new_piece.y -= 2;
            piece_set[new_piece] = true;
        }

        bool[Piece] corner_piece_set;
        enum add_new_piece = "
            if (piece_condition(new_piece) && new_piece !in piece_set){
                corner_piece_set[new_piece] = true;
            }
        ";

        foreach (piece; pieces){
            auto new_piece = piece;
            new_piece.x += 1;
            new_piece.y += 1;
            mixin(add_new_piece);
            new_piece.x -= 2;
            mixin(add_new_piece);
            new_piece.y -= 2;
            mixin(add_new_piece);
            new_piece.x += 2;
            mixin(add_new_piece);
        }

        Piece[] new_pieces;
        foreach (corner; corner_piece_set.byKey){
            new_pieces ~= corner;
        }
        return new Shape(new_pieces);
    }

    Shape[] chains()
    {
        bool[Piece] piece_set = this.piece_set;

        Piece[] queue;
        Shape[] result;
        Piece[] chain;

        enum add_to_queue = "
            if (piece in piece_set){
                queue ~= piece;
            }
        ";

        while (piece_set.length){
            chain = [];
            queue ~= piece_set.byKey.front;
            while (queue.length){
                auto piece = queue.front;
                queue.popFront;

                piece_set.remove(piece);
                chain ~= piece;

                piece.x += 1;
                mixin(add_to_queue);
                piece.x -= 2;
                mixin(add_to_queue);
                piece.x += 1;
                piece.y += 1;
                mixin(add_to_queue);
                piece.y -= 2;
                mixin(add_to_queue);
            }
            result ~= new Shape(chain);
        }
        return result;
    }

    bool is_contiguous()
    {
        return chains.length == 1;
    }

    override string toString()
    {
        string r;
        auto piece_set = this.piece_set;
        for (int y = north_extent; y <= south_extent; y++){
            for (int x = west_extent; x <= east_extent; x++){
                auto piece = Piece(x, y);
                if (piece in piece_set){
                    r ~= "# ";
                }
                else{
                    r ~= "  ";
                }
            }
            if (y < south_extent){
                r ~= "\n";
            }
        }
        return r;
    }
}

class CornerShape : Shape
{
    this(Piece[] pieces)
    {
        super(pieces);
    }

    this(Shape s)
    {
        this(s.pieces);
    }

    invariant
    {
        foreach (piece; pieces){
            assert(piece.x >= 0 && piece.y >= 0);
        }
    }

    override bool is_good()
    {
        return blob_liberties.is_contiguous;
    }

    override bool piece_condition(const Piece piece) const
    {
        return piece.x >= 0 && piece.y >= 0;
    }

    override void canonize()
    {
        snap;
        auto temp = this.copy;
        temp.mirror_d;
        if (temp < this){
            this.pieces = temp.pieces.dup;
        }
    }


    bool[CornerShape] shapes_plus_one()
    {
        auto piece_set = this.piece_set;

        bool[CornerShape] result;
        enum add_new_shape = "
            if (new_piece !in piece_set){
                auto new_pieces = pieces.dup;
                new_pieces ~= new_piece;
                auto temp_shape = new Shape(new_pieces);
                temp_shape.snap;
                auto new_shape = new CornerShape(temp_shape);
                new_shape.canonize;
                if (new_shape.is_good){
                    result[new_shape] = true;
                }
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

    // Compilers and their warnings...
    alias shapes_plus_one = Shape.shapes_plus_one;

    override CornerShape liberties()
    {
        return new CornerShape(super.liberties);
    }

    override CornerShape blob_liberties()
    {
        return new CornerShape(super.blob_liberties);
    }

    override string toString()
    {
        return "CornerShape\n" ~ super.toString;
    }
}


class EdgeShape : Shape
{
    this(Piece[] pieces)
    {
        super(pieces);
    }

    this(Shape s)
    {
        this(s.pieces);
    }

    invariant
    {
        foreach (piece; pieces){
            assert(piece.y >= 0);
        }
    }

    override bool is_good()
    {
        return blob_liberties.is_contiguous;
    }

    override bool piece_condition(const Piece piece) const
    {
        return piece.y >= 0;
    }

    override void canonize()
    {
        snap;
        auto temp = this.copy;
        temp.mirror_h;
        if (temp < this){
            this.pieces = temp.pieces.dup;
        }
    }


    bool[EdgeShape] shapes_plus_one()
    {
        auto piece_set = this.piece_set;

        bool[EdgeShape] result;
        enum add_new_shape = "
            if (new_piece !in piece_set){
                auto new_pieces = pieces.dup;
                new_pieces ~= new_piece;
                auto temp_shape = new Shape(new_pieces);
                temp_shape.snap;
                auto new_shape = new EdgeShape(temp_shape);
                new_shape.canonize;
                if (new_shape.is_good){
                    result[new_shape] = true;
                }
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

    // Compilers and their warnings...
    alias shapes_plus_one = Shape.shapes_plus_one;

    override EdgeShape liberties()
    {
        return new EdgeShape(super.liberties);
    }

    override EdgeShape blob_liberties()
    {
        return new EdgeShape(super.blob_liberties);
    }

    override string toString()
    {
        return "EdgeShape\n" ~ super.toString;
    }
}

/*
struct Eyespace
{
    Shape space;
    Shape edge;

    Eyespace opAssign(in Eyespace rhs)
    {
        this.space = rhs.space;
        this.edge = rhs.edge;

        return this;
    }

    this(this)
    {
        space = space;
        edge = edge;
    }

    bool opEquals(in Eyespace rhs) const pure nothrow
    {
        return space == rhs.space && edge == rhs.edge;
    }

    int opCmp(in Eyespace rhs) const pure nothrow
    {
        if (space != rhs.space){
            return space.opCmp(rhs.space);
        }
        return edge.opCmp(rhs.edge);
    }

    hash_t toHash() const nothrow @safe
    {
        return space.toHash ^ edge.toHash;
    }

    bool is_good(){
        foreach (edge_chain; edge.chains){
            if ((edge_chain.liberties & space).length < 2){
                return false;
            }
        }
        return true;
    }

    int extent(string direction, string op)()
    {
        mixin("int space_extent = space." ~ direction ~"_extent;");
        mixin("int edge_extent = edge." ~ direction ~ "_extent;");
        mixin("
            if (space_extent " ~ op ~ " edge_extent){
                return space_extent;
            }
            return edge_extent;
        ");
    }

    alias west_extent = extent!("west", "<");
    alias north_extent = extent!("north", "<");
    alias east_extent = extent!("east", ">");
    alias south_extent = extent!("south", ">");

    void snap(){
        auto west_extent = this.west_extent;
        auto north_extent = this.north_extent;
        space.translate(-west_extent, -north_extent);
        edge.translate(-west_extent, -north_extent);
    }

    void rotate(){
        space.rotate;
        edge.rotate;
    }

    void mirror_h(){
        space.mirror_h;
        edge.mirror_h;
    }

    void canonize()
    {
        snap;
        auto temp = this;
        enum compare_and_replace = "
            if (temp < this){
                this = temp;
            }
        ";
        for (int i = 0; i < 3; i++){
            temp.rotate;
            temp.snap;
            mixin(compare_and_replace);
        }
        temp.mirror_h;
        temp.snap;
        mixin(compare_and_replace);
        for (int i = 0; i < 3; i++){
            temp.rotate;
            temp.snap;
            mixin(compare_and_replace);
        }
    }

    string toString()
    {
        string r;
        auto space_set = space.piece_set;
        auto edge_set = edge.piece_set;
        for (int y = north_extent; y <= south_extent; y++){
            for (int x = west_extent; x <= east_extent; x++){
                auto piece = Piece(x, y);
                if (piece in space_set){
                    r ~= ". ";
                }
                else if (piece in edge_set){
                    r ~= "# ";
                }
                else{
                    r ~= "  ";
                }
            }
            if (y < south_extent){
                r ~= "\n";
            }
        }
        return r;
    }
}
*/

bool[T] polyominoes(T=Shape)(int max_size)
{
    bool[T] result;
    T[] queue;
    auto shape = new T([Piece(0, 0)]);
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

/*
bool[Eyespace] eyespaces(int max_size)
{
    bool[Eyespace] eyespace_set;

    foreach (space; polyominoes(max_size).byKey){
        Shape[] liberty_parts = space.liberties.chains;
        Shape[] corner_parts = space.corners.chains;
        foreach (liberty_subset; PowerSet!Shape(liberty_parts)){
            Shape edge;
            foreach (edge_part; liberty_subset){
                edge = edge | edge_part;
            }
            Shape[] connecting_corner_parts = [];
            foreach (corner_part; corner_parts){
                if ((corner_part.liberties & edge).length >= 2){
                    connecting_corner_parts ~= corner_part;
                }
            }
            foreach (corner_subset; PowerSet!Shape(connecting_corner_parts)){
                auto final_edge = edge;
                foreach (corner_part; corner_subset){
                    final_edge = final_edge | corner_part;
                }
                auto eyespace = Eyespace(space, final_edge);
                if (eyespace.is_good){
                    eyespace.canonize;
                    eyespace_set[eyespace] = true;
                }
            }
        }
    }

    return eyespace_set;
}
*/


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

unittest
{
    auto s = new Shape([Piece(0, 0)]);
    assert(s.liberties == new Shape([Piece(-1, 0), Piece(0, -1), Piece(0, 1), Piece(1, 0)]));
    assert(s.corners == new Shape([Piece(-1, -1), Piece(-1, 1), Piece(1, -1), Piece(1, 1)]));
    assert(s.corners.chains.length == 4);
}

unittest
{
    auto bent_three_in_the_corner = new CornerShape([Piece(0, 0), Piece(0, 1), Piece(1, 0)]);
    bent_three_in_the_corner.canonize;
    auto bent_three_out_of_the_corner = new CornerShape([Piece(0, 0), Piece(0, 1), Piece(1, 1)]);
    bent_three_out_of_the_corner.canonize;
    assert(bent_three_in_the_corner != bent_three_out_of_the_corner);
}

/*
unittest
{
    auto s = Shape([Piece(0, 0), Piece(0, 1)]);
    auto e = Shape([Piece(0, 2)]);
    auto es = Eyespace(s, e);
    assert(!es.is_good);

    es.edge = Shape([Piece(1, 0), Piece(1, 1)]);
    assert(es.is_good);
}

unittest
{
    assert(eyespaces(4).length == 314);
}
*/
