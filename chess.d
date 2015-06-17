import std.stdio;
import std.string;

import utils;

enum H_SHIFT = 1;
enum V_SHIFT = 8;
enum AFILE = 0x101010101010101UL;
enum BFILE = 0x202020202020202UL;
enum CFILE = 0x404040404040404UL;
enum DFILE = 0x808080808080808UL;
enum EFILE = 0x1010101010101010UL;
enum FFILE = 0x2020202020202020UL;
enum GFILE = 0x4040404040404040UL;
enum HFILE = 0x8080808080808080UL;
enum RANK8 = 0xFFUL;
enum RANK7 = 0xFF00UL;
enum RANK6 = 0xFF0000UL;
enum RANK5 = 0xFF000000UL;
enum RANK4 = 0xFF00000000UL;
enum RANK3 = 0xFF0000000000UL;
enum RANK2 = 0xFF000000000000UL;
enum RANK1 = 0xFF00000000000000UL;
enum CHECKERBOARD = 0X55AA55AA55AA55AAUL;
enum FULL = 0xFFFFFFFFFFFFFFFFUL;


ulong north(ulong pieces) pure nothrow @nogc @safe
{
    return pieces >> V_SHIFT;
}

ulong south(ulong pieces) pure nothrow @nogc @safe
{
    return pieces << V_SHIFT;
}

ulong east(ulong pieces) pure nothrow @nogc @safe
{
    return (pieces & ~HFILE) << H_SHIFT;
}

ulong west(ulong pieces) pure nothrow @nogc @safe
{
    return (pieces & ~AFILE) >> H_SHIFT;
}

ulong north2(ulong pieces) pure nothrow @nogc @safe
{
    return pieces >> (2 * V_SHIFT);
}

ulong south2(ulong pieces) pure nothrow @nogc @safe
{
    return pieces << (2 * V_SHIFT);
}

ulong d_one(ulong pieces) pure nothrow @nogc @safe
{
    return ((pieces & ~HFILE) >> (V_SHIFT - H_SHIFT)) | ((pieces & ~AFILE) << (V_SHIFT - H_SHIFT));
}

ulong z_one(ulong pieces) pure nothrow @nogc @safe
{
    return ((pieces & ~AFILE) >> (V_SHIFT + H_SHIFT)) | ((pieces & ~HFILE) << (V_SHIFT + H_SHIFT));
}

ulong mirror_v(ulong x) pure nothrow @nogc @trusted
{
    version (profile){
        enum profile = true;
    }
    else {
        enum profile = false;
    }
    if (__ctfe || profile){
       enum k1 = 0x00FF00FF00FF00FFUL;
       enum k2 = 0x0000FFFF0000FFFFUL;
       x = ((x >>  8) & k1) | ((x & k1) <<  8);
       x = ((x >> 16) & k2) | ((x & k2) << 16);
       x = ( x >> 32)       | ( x       << 32);
       return x;
    }
    else {
        asm pure nothrow @nogc @trusted
        {
            mov RAX, x;
            bswap RAX;
        }
    }
}

ulong mirror_h (ulong x) pure nothrow @nogc @safe
{
   enum k1 = 0x5555555555555555UL;
   enum k2 = 0x3333333333333333UL;
   enum k4 = 0x0F0F0F0F0F0F0F0FUL;
   x = ((x >> 1) & k1) | ((x & k1) << 1);
   x = ((x >> 2) & k2) | ((x & k2) << 2);
   x = ((x >> 4) & k4) | ((x & k4) << 4);
   return x;
}

ulong mirror_d(ulong x) pure nothrow @nogc @safe
{
   ulong t;
   enum k1 = 0x5500550055005500UL;
   enum k2 = 0x3333000033330000UL;
   enum k4 = 0x0f0f0f0f00000000UL;
   t  = k4 & (x ^ (x << 28));
   x ^=       t ^ (t >> 28) ;
   t  = k2 & (x ^ (x << 14));
   x ^=       t ^ (t >> 14) ;
   t  = k1 & (x ^ (x <<  7));
   x ^=       t ^ (t >>  7) ;
   return x;
}


ulong[] separate(ulong pieces) pure nothrow @safe
{
    ulong[] result;
    while (pieces){
        auto index = bitScanForward(pieces);
        auto piece = (1UL << index);
        result ~= piece;
        pieces ^= piece;
    }
    return result;
}

/*
ulong[] separate(ulong pieces)
{
    ulong[] result;
    foreach (i; 0..64){
        auto piece = 1UL << i;
        if (piece & pieces){
            result ~= piece;
        }
    }
    return result;
}
*/

string on_board(ulong pieces, ulong other_pieces=0)
{
        string r;
        foreach (j; 0..8){
            foreach (i; 0..8){
                auto s = 1UL << (i * H_SHIFT + j * V_SHIFT);
                r ~= "\x1b[0;30;";
                if ((i + j) & 1){
                    r ~= "44m";
                }
                else {
                    r ~= "43m";
                }
                if (s & pieces){
                    if (s & other_pieces){
                        r ~= "\x1b[31m";
                    }
                    else{
                        r ~= "\x1b[37m";
                    }
                }
                else if (s & other_pieces){
                    r ~= "\x1b[30m";
                }
                if (s & (pieces | other_pieces)){
                    r ~= "◆ ";
                }
                else {
                    r ~= "  ";
                }
            }
            r ~= "\x1b[0m";
            r ~= "\n";
        }
        r ~= format("popcount=%s", pieces.popcount);
        if (other_pieces){
            r ~= format(", %s", other_pieces.popcount);
        }
        return r;
}

ulong d_rays(ulong pieces, ulong empty) pure nothrow @nogc @safe
{
    ulong temp;
    empty &= ~AFILE & ~HFILE & ~RANK1 & ~RANK8;
    do {
        temp = pieces;
        pieces |= ((pieces >> (V_SHIFT - H_SHIFT)) | (pieces << (V_SHIFT - H_SHIFT))) & empty;
    } while (pieces != temp);
    return pieces | pieces.d_one;
}

ulong z_rays(ulong pieces, ulong empty) pure nothrow @nogc @safe
{
    ulong temp;
    empty &= ~AFILE & ~HFILE & ~RANK1 & ~RANK8;
    do {
        temp = pieces;
        pieces |= ((pieces >> (V_SHIFT + H_SHIFT)) | (pieces << (V_SHIFT + H_SHIFT))) & empty;
    } while (pieces != temp);
    return pieces | pieces.z_one;
}

/*
ulong h_rays(ulong pieces, ulong empty) pure nothrow @nogc @safe
{
    ulong temp;
    empty &= ~AFILE & ~HFILE;
    pieces |= (pieces.east & empty);
    do {
        temp = pieces;
        pieces |= (pieces.west | ~(pieces + empty)) & empty;
    } while (pieces != temp);
    return pieces | pieces.east | pieces.west;
}
*/

ulong h_rays(ulong pieces, ulong empty) pure nothrow @nogc @safe
{
    ulong temp;
    empty &= ~AFILE & ~HFILE;
    do {
        temp = pieces;
        pieces |= ((pieces >> H_SHIFT) | (pieces << H_SHIFT)) & empty;
    } while (pieces != temp);
    return pieces | pieces.east | pieces.west;
}

ulong v_rays(ulong pieces, ulong empty) pure nothrow @nogc @safe
{
    ulong temp;
    empty &= ~RANK1 & ~RANK8;
    do {
        temp = pieces;
        pieces |= (pieces.north | pieces.south) & empty;
    } while (pieces != temp);
    return pieces | pieces.north | pieces.south;
}

ulong knights_moves(ulong knights) pure nothrow @nogc @safe
{
    auto e = knights.east;
    auto w = knights.west;
    auto moves = (e | w).south2;
    moves |= (e | w).north2;
    e = e.east;
    w = w.west;
    moves |= (e | w).south;
    moves |= (e | w).north;
    return moves;
}

bool bpawn_attacks(ulong pawns, ulong target) pure nothrow @nogc @safe
{
    pawns = pawns.south;
    return cast(bool)((pawns.east | pawns.west) & target);
}

bool wpawn_attacks(ulong pawns, ulong target) pure nothrow @nogc @safe
{
    pawns = pawns.north;
    return cast(bool)((pawns.east | pawns.west) & target);
}

bool knight_attacks(ulong knights, ulong target) pure nothrow @nogc @safe
{
    auto e = knights.east;
    auto w = knights.west;
    auto attacks = (e | w).south2;
    attacks |= (e | w).north2;
    if (attacks & target){
        return true;
    }
    e = e.east;
    w = w.west;
    attacks |= (e | w).south;
    attacks |= (e | w).north;
    return cast(bool)(attacks & target);
}

bool bishop_attacks(ulong bishops, ulong target, ulong empty) pure nothrow @nogc @safe
{
    return (d_rays(bishops, empty) & target) || (z_rays(bishops, empty) & target);
}

bool rook_attacks(ulong rooks, ulong target, ulong empty) pure nothrow @nogc @safe
{
    return (h_rays(rooks, empty) & target) || (v_rays(rooks, empty) & target);
}

bool queen_attacks(ulong queens, ulong target, ulong empty) pure nothrow @nogc @safe
{
    return bishop_attacks(queens, target, empty) || rook_attacks(queens, target, empty);
}

bool king_attacks(ulong kings, ulong target) pure nothrow @nogc @safe
{
    kings |= kings.east | kings.west;
    kings |= kings.north | kings.south;
    return cast(bool)(kings & target);
}

bool king_can_reach(ulong king, ulong target, ulong space)
{
    ulong temp;
    do {
        temp = king;
        king |= king.east | king.west;
        king |= king.south | king.north;
        king &= space;
    } while (king != temp);
    return cast(bool)(king & target);
}

struct PawnPush
{
    ulong move;
    ulong enpassant;
}

struct PawnPromotion
{
    ulong move;
    ulong mask;
    ulong knight;
    ulong bishop;
    ulong rook;
    ulong queen;
}

struct Move
{
    ulong move;
    ulong mask;
}

struct Castling
{
    ulong king_move;
    ulong rook_move;
}

struct EndgameType
{
    int p_pawns;
    int o_pawns;
    int p_knights;
    int o_knights;
    int p_bishops;
    int o_bishops;
    int p_rooks;
    int o_rooks;
    int p_queens;
    int o_queens;

    enum MEMBERS = "[p_pawns, o_pawns, p_knights, o_knights, p_bishops, o_bishops, p_rooks, o_rooks, p_queens, o_queens]";

    this(int p_pawns, int o_pawns, int p_knights, int o_knights, int p_bishops, int o_bishops, int p_rooks, int o_rooks, int p_queens, int o_queens)
    {
        this.p_pawns = p_pawns;
        this.o_pawns = o_pawns;
        this.p_knights = p_knights;
        this.o_knights = o_knights;
        this.p_bishops = p_bishops;
        this.o_bishops = o_bishops;
        this.p_rooks = p_rooks;
        this.o_rooks = o_rooks;
        this.p_queens = p_queens;
        this.o_queens = o_queens;
    }

    this(int[] members)
    {
        p_pawns = members[0];
        o_pawns = members[1];
        p_knights = members[2];
        o_knights = members[3];
        p_bishops = members[4];
        o_bishops = members[5];
        p_rooks = members[6];
        o_rooks = members[7];
        p_queens = members[8];
        o_queens = members[9];
    }

    hash_t toHash() const nothrow @safe
    {
        static assert(hash_t.sizeof > 4);
        hash_t result = 0;
        foreach (member; mixin(MEMBERS)){
            result = 16 * result + member;
        }
        return result;
    }

    bool opEquals(in EndgameType rhs) const nothrow @safe
    {
        return toHash == rhs.toHash;
    }

    size_t size()
    {
        size_t result = 64 * 64;
        foreach (member; mixin(MEMBERS)){
            foreach (i; 0..member){
                result *= 64;
            }
        }
        return result;
    }

    EndgameType pair()
    {
        return EndgameType(o_pawns, p_pawns, o_knights, p_knights, o_bishops, p_bishops, o_rooks, p_rooks, o_queens, p_queens);
    }

    bool[EndgameType] _subtypes()
    {
        bool[EndgameType] result;
        int[] members = mixin(MEMBERS);
        foreach (i, member; members){
            if (member > 0){
                if (i == 0 || i == 1){
                    //TODO: Pawn promotions.
                    assert(false);
                }
                int[] submembers;
                foreach (j, submember; members){
                    if (i == j){
                        submembers ~= submember - 1;
                    }
                    else {
                        submembers ~= submember;
                    }
                }
                auto subtype = EndgameType(submembers);
                result[subtype] = true;
                foreach (st; subtype._subtypes.byKey){
                    result[st] = true;
                }
            }
        }
        result[this] = true;
        result[pair] = true;
        return result;
    }

    EndgameType[] subtypes()
    {
        EndgameType[] result;
        foreach (subtype; _subtypes.byKey){
            result ~= subtype;
        }
        return result;
    }

    string toString()
    {
        string r = "k";
        foreach (i; 0..p_pawns){
            r ~= "p";
        }
        foreach (i; 0..p_knights){
            r ~= "n";
        }
        foreach (i; 0..p_bishops){
            r ~= "b";
        }
        foreach (i; 0..p_rooks){
            r ~= "r";
        }
        foreach (i; 0..p_queens){
            r ~= "q";
        }
        r ~= "_k";
        foreach (i; 0..o_pawns){
            r ~= "p";
        }
        foreach (i; 0..o_knights){
            r ~= "n";
        }
        foreach (i; 0..o_bishops){
            r ~= "b";
        }
        foreach (i; 0..o_rooks){
            r ~= "r";
        }
        foreach (i; 0..o_queens){
            r ~= "q";
        }
        return r;
    }
}

struct PseudoChessState
{
    ulong player;
    ulong pawns;
    ulong knights;
    ulong bishops;
    ulong rooks;
    ulong queens;
    ulong kings;
    ulong unmoved;
    ulong enpassant;
    ulong empty;

    this(ulong player, ulong pawns, ulong knights, ulong bishops, ulong rooks, ulong queens, ulong kings, ulong unmoved, ulong enpassant=0)
    {
        this.player = player;
        this.pawns = pawns;
        this.knights = knights;
        this.bishops = bishops;
        this.rooks = rooks;
        this.queens = queens;
        this.kings = kings;
        this.unmoved = unmoved;
        this.enpassant = enpassant;

        empty = ~(pawns | knights | bishops | rooks | queens | kings);

        /*
        if (popcount(player & kings) != 1 || popcount(~player & kings) != 1){
            writeln("not again...");
            writeln(this);
            print_boards;
            writeln(repr);
        }
        */
    }

    /*
    invariant
    {
        assert(!(player & empty));
        assert(popcount(player & pawns) <= 8);
        assert(popcount(~player & pawns) <= 8);
        assert(!(pawns & (RANK1 | RANK8)));
        assert(!(pawns & (knights | bishops | rooks | queens | kings)));
        assert(popcount(pawns ^ knights ^ bishops ^ rooks ^ queens ^ kings) == popcount(~empty));
        assert(popcount(player & kings) == 1);
        assert(popcount(~player & kings) == 1);
        assert(!(unmoved & ~(RANK1 | RANK8)));
        assert(!(enpassant & ~(RANK3 | RANK6)));
        assert(!(unmoved & ~(rooks | kings)));
    }
    */

    bool valid_before()
    {
        if (player & empty){
            return false;
        }
        if (popcount(player & kings) != 1 || popcount(~player & kings) != 1){
            return false;
        }
        if (pawns + knights + bishops + rooks + queens + kings != ~empty){
            return false;
        }
        if (pawns.mirror_v + knights.mirror_v + bishops.mirror_v + rooks.mirror_v + queens.mirror_v + kings.mirror_v != ~empty.mirror_v){
            return false;
        }
        // This actually checks that the opposing king cannot be taken
        // because valid_before is called prior to canonical conversion.
        return !king_in_check;
    }

    bool king_in_check()
    {
        auto opponent = ~player;
        auto king = player & kings;
        return (
            bpawn_attacks(opponent & pawns, king) ||
            knight_attacks(opponent & knights, king) ||
            rook_attacks(opponent & (rooks | queens), king, empty) ||
            bishop_attacks(opponent & (bishops | queens), king, empty) ||
            king_attacks(opponent & kings, king)
        );
    }

    bool opponent_king_in_check()
    {
        auto king = ~player & kings;
        return !(
            wpawn_attacks(player & pawns, king) ||
            knight_attacks(player & knights, king) ||
            rook_attacks(player & (rooks | queens), king, empty) ||
            bishop_attacks(player & (bishops | queens), king, empty) ||
            king_attacks(player & kings, king)
        );
    }

    PawnPush[] pawn_pushes()
    {
        PawnPush[] actions;
        auto pushable_pawns = player & pawns & ~RANK7 & empty.south;
        foreach (pawn; pushable_pawns.separate){
            actions ~= PawnPush(pawn | pawn.north, 0);
        }
        pushable_pawns &= RANK2 & empty.south2;
        auto temp = (~player & pawns).south;
        auto valid_enpassant = RANK3 & (temp.east | temp.west);
        foreach (pawn; pushable_pawns.separate){
            actions ~= PawnPush(pawn | pawn.north2, pawn.north & valid_enpassant);
        }
        return actions;
    }

    Move[] pawn_captures()
    {
        Move[] actions;
        auto player_pawns = (player & pawns & ~RANK7);
        auto opponent_material = (~player & ~empty) | enpassant;
        auto temp = opponent_material.south;
        player_pawns &= (temp.east | temp.west);
        foreach (pawn; player_pawns.separate){
            auto n = pawn.north;
            auto attack = n.east;
            auto mask = attack;
            enum add_action = "
                if (attack & opponent_material){
                    if (attack & enpassant){
                        mask = mask.south;
                    }
                    actions ~= Move(pawn | attack, ~mask);
                }
            ";
            mixin(add_action);
            attack = n.west;
            mask = attack;
            mixin(add_action);
        }
        return actions;
    }

    PawnPromotion[] pawn_promotions()
    {
        PawnPromotion[] actions;
        auto promotable_pawns = player & pawns & RANK7;
        auto pushable_pawns = promotable_pawns & empty.south;
        foreach (pawn; pushable_pawns.separate){
            auto promoted = pawn.north;
            auto move = pawn | promoted;
            actions ~= PawnPromotion(move, FULL, promoted, 0, 0, 0);
            actions ~= PawnPromotion(move, FULL, 0, promoted, 0, 0);
            actions ~= PawnPromotion(move, FULL, 0, 0, promoted, 0);
            actions ~= PawnPromotion(move, FULL, 0, 0, 0, promoted);
        }
        auto opponent_material = ~player & ~empty;
        auto temp = opponent_material.south;
        auto capturing_pawns = promotable_pawns & (temp.east | temp.west);
        foreach (pawn; capturing_pawns.separate){
            auto n = pawn.north;
            auto attack = n.east;
            auto move = pawn | attack;
            auto mask = ~attack;
            enum add_action = "
                if (attack & opponent_material){
                    actions ~= PawnPromotion(move, mask, attack, 0, 0, 0);
                    actions ~= PawnPromotion(move, mask, 0, attack, 0, 0);
                    actions ~= PawnPromotion(move, mask, 0, 0, attack, 0);
                    actions ~= PawnPromotion(move, mask, 0, 0, 0, attack);
                }
            ";
            mixin(add_action);
            attack = n.west;
            move = pawn | attack;
            mask = ~attack;
            mixin(add_action);
        }
        return actions;
    }

    Move[] knight_moves()
    {
        Move[] actions;
        foreach (knight; (player & knights).separate){
            foreach (move; separate(knights_moves(knight) & ~player)){
                actions ~= Move(knight | move, ~move);
            }
        }
        return actions;
    }

    Move[] bishop_moves()
    {
        Move[] actions;
        foreach (bishop; separate(player & bishops)){
            auto d_moves = d_rays(bishop, empty);
            auto z_moves = z_rays(bishop, empty);
            foreach (move; separate((d_moves | z_moves) & ~player)){
                actions ~= Move(bishop | move, ~move);
            }
        }
        return actions;
    }

    Move[] rook_moves()
    {
        Move[] actions;
        foreach (rook; separate(player & rooks)){
            auto h_moves = h_rays(rook, empty);
            auto v_moves = v_rays(rook, empty);
            foreach (move; separate((h_moves | v_moves) & ~player)){
                actions ~= Move(rook | move, ~move);
            }
        }
        return actions;
    }

    Move[] queen_moves()
    {
        Move[] actions;
        foreach (queen; separate(player & queens)){
            auto d_moves = d_rays(queen, empty);
            auto z_moves = z_rays(queen, empty);
            auto h_moves = h_rays(queen, empty);
            auto v_moves = v_rays(queen, empty);
            foreach (move; separate((d_moves | z_moves | h_moves | v_moves) & ~player)){
                actions ~= Move(queen | move, ~move);
            }
        }
        return actions;
    }

    Move[] king_moves()
    {
        Move[] actions;
        auto king = player & kings;
        auto blob = king | king.east | king.west;
        blob |= blob.north | blob.south;
        foreach (move; separate(blob & ~player)){
            actions ~= Move(king | move, ~move);
        }
        return actions;
    }

    Castling[] castlings()
    {
        // Depends on 'unmoved' being set to 0 if the board is transformed out of the standard orientation.
        Castling[] actions;
        enum king = EFILE & RANK1;
        if (king & unmoved){
            assert(player & kings & king);
            auto opponent = ~player;
            enum west_rook = AFILE & RANK1;
            enum west_space = RANK1 & (BFILE | CFILE | DFILE);
            enum west_check = RANK1 & (CFILE | DFILE | EFILE);
            if ((west_rook & unmoved) && !(west_space & ~empty)){
                assert(player & rooks & west_rook);
                bool west_attacked = (
                    bpawn_attacks(opponent & pawns, west_check) ||
                    knight_attacks(opponent & knights, west_check) ||
                    rook_attacks(opponent & (rooks | queens), west_check, empty) ||
                    bishop_attacks(opponent & (bishops | queens), west_check, empty) ||
                    king_attacks(opponent & kings, west_check)
                );
                if (!west_attacked){
                    actions ~= Castling(king | (CFILE & RANK1), west_rook | (DFILE & RANK1));
                }
            }
            enum east_rook = HFILE & RANK1;
            enum east_space = RANK1 & (FFILE | GFILE);
            enum east_check = RANK1 & (EFILE | FFILE | GFILE);
            if ((east_rook & unmoved) && !(east_space & ~empty)){
                assert(player & rooks & east_rook);
                bool east_attacked = (
                    bpawn_attacks(opponent & pawns, east_check) ||
                    knight_attacks(opponent & knights, east_check) ||
                    rook_attacks(opponent & (rooks | queens), east_check, empty) ||
                    bishop_attacks(opponent & (bishops | queens), east_check, empty) ||
                    king_attacks(opponent & kings, east_check)
                );
                if (!east_attacked){
                    actions ~= Castling(king | (GFILE & RANK1), east_rook | (FFILE & RANK1));
                }
            }
        }
        return actions;
    }

    bool insufficient_material()
    {
        auto piece_count = (~empty).popcount;
        assert(piece_count >= 2);
        if (piece_count == 2){
            // King against king
            return true;
        }
        /*
        // If we give non-zero score for stalemates we
        // cannot automatically draw kn_k or kb_k,
        // because of forceable stalemates.
        else if (piece_count == 3){
            if (knights){
                // King against king and knigth
                return true;
            }
            else if (bishops){
                // King agains king and bishop
                return true;
            }
        }
        else if ((bishops | kings) == ~empty){
            auto w_bishops = bishops & CHECKERBOARD;
            auto b_bishops = bishops & ~CHECKERBOARD;
            // King and bishops against king and bishops with all bishops of the same color
            return (!w_bishops) ^ (!b_bishops);
        }
        */
        return false;
    }

    bool book_win()
    {
        auto piece_count = (~empty).popcount;
        assert(piece_count >= 2);
        if (piece_count == 3){
            if (player & (rooks | queens)){
                return true;
            }
        }
        return false;
    }

    bool book_draw()
    {
        auto piece_count = (~empty).popcount;
        assert(piece_count >= 2);
        if (piece_count == 4){
            if (knights.popcount == 2){
                if (!(player & knights)){
                    return true;
                }
            }
        }
        return false;
    }

    PseudoChessState[] children(out float score)
    {
        if (insufficient_material){
            score = 0;
            return [];
        }
        /*
        if (book_win){
            score = 1;
            return [];
        }
        if (book_draw){
            score = 0;
            return [];
        }
        */
        enum king_lives = "
            version (assert){
                if (!(~player & kings & action.mask)){
                    writeln(this);
                }
            }
            assert(~player & kings & action.mask);
        ";
        PseudoChessState[] candidates;
        bool has_pawn_move = false;
        foreach (action; pawn_pushes){
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns ^ action.move,
                knights,
                bishops,
                rooks,
                queens,
                kings,
                unmoved,
                action.enpassant
            );
            has_pawn_move = true;
        }
        foreach (action; pawn_captures){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                (pawns & action.mask) ^ action.move,
                knights & action.mask,
                bishops & action.mask,
                rooks & action.mask,
                queens & action.mask,
                kings,
                unmoved & action.mask
            );
            assert(popcount(candidates[$ - 1].empty) == popcount(empty) + 1);
            has_pawn_move = true;
        }
        foreach (action; pawn_promotions){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask & (~action.move),
                (knights & action.mask) | action.knight,
                (bishops & action.mask) | action.bishop,
                (rooks & action.mask) | action.rook,
                (queens & action.mask) | action.queen,
                kings,
                unmoved & action.mask
            );
            has_pawn_move = true;
        }

        foreach (action; knight_moves){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask,
                (knights & action.mask) ^ action.move,
                bishops & action.mask,
                rooks & action.mask,
                queens & action.mask,
                kings,
                unmoved & action.mask
            );
        }

        foreach (action; bishop_moves){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask,
                knights & action.mask,
                (bishops & action.mask) ^ action.move,
                rooks & action.mask,
                queens & action.mask,
                kings,
                unmoved & action.mask
            );
        }

        foreach (action; rook_moves){
            mixin(king_lives);
            auto new_unmoved = unmoved & ~action.move;
            if (!(new_unmoved & RANK1 & rooks)){
                new_unmoved &= RANK8;
            }
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask,
                knights & action.mask,
                bishops & action.mask,
                (rooks & action.mask) ^ action.move,
                queens & action.mask,
                kings,
                new_unmoved & action.mask
            );
        }

        foreach (action; queen_moves){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask,
                knights & action.mask,
                bishops & action.mask,
                rooks & action.mask,
                (queens & action.mask) ^ action.move,
                kings,
                unmoved & action.mask
            );
        }

        foreach (action; king_moves){
            mixin(king_lives);
            candidates ~= PseudoChessState(
                player ^ action.move,
                pawns & action.mask,
                knights & action.mask,
                bishops & action.mask,
                rooks & action.mask,
                queens & action.mask,
                kings ^ action.move,
                unmoved & RANK8 & action.mask
            );
        }

        foreach (action; castlings){
            candidates ~= PseudoChessState(
                player ^ action.king_move ^ action.rook_move,
                pawns,
                knights,
                bishops,
                rooks ^ action.rook_move,
                queens,
                kings ^ action.king_move,
                unmoved & RANK8
            );
        }

        PseudoChessState[] result;
        foreach (ref child; candidates){
            if (!child.king_in_check){
                assert(popcount(child.empty) >= popcount(empty));
                assert(popcount(child.player & ~child.empty) == popcount(player & ~empty));
                result ~= child;
            }
        }

        if (result.length == 0){
            if (king_in_check){
                score = -2;
            }
            else {
                // We give score for stalemating to differentiate it from other draws.
                score = -1;
            }
            return result;
        }

        // This would be required to prevent non-finishable games.
        /*
        if ((kings | pawns) == ~empty){
            if ((player & pawns) && !has_pawn_move && !kings_can_capture_pawns){
                score = 0;
                return [];
            }
        }
        */

        return result;
    }

    bool kings_can_capture_pawns()
    {
        auto pawns = ~player & this.pawns;
        auto temp = pawns.south;
        auto space = empty & ~(temp.east | temp.west);
        bool player_can_capture = king_can_reach(player & kings, pawns, space);
        pawns = player & this.pawns;
        temp = pawns.north;
        space = empty & ~(temp.east | temp.west);
        return player_can_capture || king_can_reach(~player & kings, pawns, space);
    }

    // TODO: For pawns canonize player king to the east and mark enpassant as pawn on the first rank.
    size_t endgame_state(out EndgameType type)
    {
        auto opponent = ~player;
        auto p_pawns = player & pawns;
        auto o_pawns = opponent & pawns;
        auto p_knights = player & knights;
        auto o_knights = opponent & knights;
        auto p_bishops = player & bishops;
        auto o_bishops = opponent & bishops;
        auto p_rooks = player & rooks;
        auto o_rooks = opponent & rooks;
        auto p_queens = player & queens;
        auto o_queens = opponent & queens;
        type = EndgameType(
            popcount(p_pawns),
            popcount(o_pawns),
            popcount(p_knights),
            popcount(o_knights),
            popcount(p_bishops),
            popcount(o_bishops),
            popcount(p_rooks),
            popcount(o_rooks),
            popcount(p_queens),
            popcount(o_queens)
        );
        size_t endgame = 0;
        string serialize_member(string member){
            return "
                while (" ~ member ~ "){
                    size_t index = bitScanForward(" ~ member ~ ");
                    endgame = index + 64 * endgame;
                    " ~ member ~ " ^= (1UL << index);
                }
            ";
        }
        mixin(serialize_member("p_pawns"));
        mixin(serialize_member("o_pawns"));
        mixin(serialize_member("p_knights"));
        mixin(serialize_member("o_knights"));
        mixin(serialize_member("p_bishops"));
        mixin(serialize_member("o_bishops"));
        mixin(serialize_member("p_rooks"));
        mixin(serialize_member("o_rooks"));
        mixin(serialize_member("p_queens"));
        mixin(serialize_member("o_queens"));
        endgame = bitScanForward(player & kings) + 64 * endgame;
        endgame = bitScanForward(opponent & kings) + 64 * endgame;
        return endgame;
    }

    static bool from_endgame_state(size_t endgame, EndgameType type, out PseudoChessState state)
    {
        ulong player;
        ulong pawns;
        ulong knights;
        ulong bishops;
        ulong rooks;
        ulong queens;
        ulong kings = 1UL << (endgame % 64);
        endgame /= 64;
        player |= kings;
        kings |= 1UL << (endgame % 64);
        endgame /= 64;
        if (kings.popcount != 2){
            return false;
        }
        string unravel_member(string member){
            return "
                foreach (i; 0..type.o_" ~ member ~ "){
                    " ~ member ~ " |= (1UL << (endgame % 64));
                    endgame /= 64;
                }
                if (" ~ member ~ ".popcount != type.o_" ~ member ~ "){
                    return false;
                }
                player |= " ~ member ~ ";
                foreach (i; 0..type.p_" ~ member ~ "){
                    " ~ member ~ " |= (1UL << (endgame % 64));
                    endgame /= 64;
                }
                if (" ~ member ~ ".popcount != type.p_" ~ member ~ " + type.o_" ~ member ~ "){
                    return false;
                }
            ";
        }

        mixin(unravel_member("queens"));
        mixin(unravel_member("rooks"));
        mixin(unravel_member("bishops"));
        mixin(unravel_member("knights"));
        mixin(unravel_member("pawns"));

        state = PseudoChessState(player, pawns, knights, bishops, rooks, queens, kings, 0);
        return state.valid_before;
    }

    void pseudo_decanonize()
    {
        // This is just a visual trick
        player = ~player & ~empty;
        player = player.mirror_v;
        pawns = pawns.mirror_v;
        knights = knights.mirror_v;
        bishops = bishops.mirror_v;
        rooks = rooks.mirror_v;
        queens = queens.mirror_v;
        kings = kings.mirror_v;
        unmoved = unmoved.mirror_v;
        enpassant = enpassant.mirror_v;
        empty = empty.mirror_v;
    }

    string toString()
    {
        string r;
        foreach (j; 0..8){
            foreach (i; 0..8){
                auto s = 1UL << (i * H_SHIFT + j * V_SHIFT);
                r ~= "\x1b[0;30;";
                if (s & unmoved){
                    r ~= "42m";
                }
                else if (s & enpassant){
                    r ~= "41m";
                }
                else if ((i + j) & 1){
                    r ~= "44m";
                }
                else {
                    r ~= "43m";
                }
                if (s & player){
                    r ~= "\x1b[37m";
                }
                else {
                    r ~= "\x1b[30m";
                }
                if (s & pawns){
                    r ~= "♟ ";
                }
                else if (s & knights){
                    r ~= "♞ ";
                }
                else if (s & bishops){
                    r ~= "♝ ";
                }
                else if (s & rooks){
                    r ~= "♜ ";
                }
                else if (s & queens){
                    r ~= "♛ ";
                }
                else if (s & kings){
                    r ~= "♚ ";
                }
                else {
                    r ~= "  ";
                }
            }
            r ~= "\x1b[0m";
            r ~= "\n";
        }
        r ~= "White to play";
        return r;
    }

    string repr()
    {
        return format("PseudoChessState(0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL)", player, pawns, knights, bishops, rooks, queens, kings, unmoved, enpassant);
    }

    void print_boards()
    {
        foreach (i, member; [player, pawns, knights, bishops, rooks, queens, kings, unmoved, enpassant, empty]){
            writeln(i);
            writeln(member.on_board);
        }
    }
}


struct CanonicalChessState
{
    // 1. pawn
    // 2. knight
    // 3. bishop
    // 4. unmoved rook
    // 5. moved rook
    // 6. queen
    // 7. unmoved king
    // 8. moved king
    // 9-16. same as above but for the opponent
    // 17. empty square
    // 18. enpassant square
    // Clumping unmoved pieces together regardless of player gives us 15
    // so we can fit everything into 4 bits per square.

    ulong player;
    ulong straight;
    ulong diagonal;
    ulong special;

    this(ulong player, ulong straight, ulong diagonal, ulong special)
    {
        this.player = player;
        this.straight = straight;
        this.diagonal = diagonal;
        this.special = special;
    }

    this(PseudoChessState state)
    {
        auto unmoved = state.unmoved;
        auto moved_kings = state.kings & ~unmoved;
        auto moved_rooks = state.rooks & ~unmoved;

        player = state.player;
        straight = moved_rooks | state.queens | moved_kings;
        diagonal = state.bishops | state.queens | moved_kings;
        special = state.pawns | state.knights | moved_kings;

        straight |= state.pawns;
        diagonal |= state.knights;

        // PseudoChessState doesn't swap turns.
        // Do part of it here.
        player = ~player & (straight | diagonal | special);

        // Enpassant is special empty square.
        special |= state.enpassant;

        // Unmoved piece is empty player square.
        player |= (state.kings | state.rooks) & unmoved;


        if (!unmoved){
            if (state.pawns){
                // Finish swapping turns by flipping the board;
                mirror_v;
                mirror_canonize;
            }
            else {
                // No need to flip here.
                full_canonize;
            }
        }
        else{
            // Finish swapping turns by flipping the board;
            mirror_v;
        }
    }

    bool is_leaf()
    {
        return false;
    }

    float value_shift() const @property
    {
        return 0;
    }

    float value_shift(float shift) @property
    {
        assert(shift == 0);
        return 0;
    }

    void mirror_v()
    {
        player = player.mirror_v;
        straight = straight.mirror_v;
        diagonal = diagonal.mirror_v;
        special = special.mirror_v;
    }

    void mirror_h()
    {
        player = player.mirror_h;
        straight = straight.mirror_h;
        diagonal = diagonal.mirror_h;
        special = special.mirror_h;
    }

    void mirror_d()
    {
        player = player.mirror_d;
        straight = straight.mirror_d;
        diagonal = diagonal.mirror_d;
        special = special.mirror_d;
    }

    bool opEquals(in CanonicalChessState rhs) const
    {
        return (
            player == rhs.player &&
            straight == rhs.straight &&
            diagonal == rhs.diagonal &&
            special == rhs.special
        );
    }

    hash_t toHash() const nothrow @safe
    {
        return (
            typeid(player).getHash(&player) ^
            typeid(straight).getHash(&straight) ^
            typeid(diagonal).getHash(&diagonal) ^
            typeid(special).getHash(&special)
        );
    }

    int opCmp(in CanonicalChessState rhs) const
    {
        string compare(string member){
            return "
                if (" ~ member ~ " < rhs." ~ member ~ "){
                    return -1;
                }
                if (" ~ member ~ " > rhs." ~ member ~ ")
                {
                    return 1;
                }
            ";
        }
        mixin(compare("player"));
        mixin(compare("straight"));
        mixin(compare("diagonal"));
        mixin(compare("special"));
        return 0;
    }

    void mirror_canonize()
    {
        auto temp = this;
        temp.mirror_h;
        if (temp < this){
            this = temp;
        }
    }

    void full_canonize()
    {
        auto temp = this;
        enum compare_and_replace = "
            if (temp < this){
            this = temp;
            }
        ";
        temp.mirror_v;
        mixin(compare_and_replace);
        temp.mirror_h;
        mixin(compare_and_replace);
        temp.mirror_v;
        mixin(compare_and_replace);
        temp.mirror_d;
        mixin(compare_and_replace);
        temp.mirror_v;
        mixin(compare_and_replace);
        temp.mirror_h;
        mixin(compare_and_replace);
        temp.mirror_v;
        mixin(compare_and_replace);
    }

    PseudoChessState state() const
    {
        auto unmoved = player & ~straight & ~diagonal & ~special;
        auto unmoved_rooks = unmoved & (AFILE | HFILE);
        auto unmoved_kings = unmoved & EFILE;

        auto true_player = player & ~(unmoved & RANK8);

        auto pawns = straight & ~diagonal & special;
        auto knights = ~straight & diagonal & special;
        auto bishops = ~straight & diagonal & ~special;
        auto rooks = (straight & ~diagonal & ~special) | unmoved_rooks;
        auto queens = straight & diagonal & ~special;
        auto kings = (straight & diagonal & special) | unmoved_kings;
        auto enpassant = ~straight & ~diagonal & special;

        return PseudoChessState(true_player, pawns, knights, bishops, rooks, queens, kings, unmoved, enpassant);
    }

    CanonicalChessState[] children(out float score) const
    {
        CanonicalChessState[] result;
        bool[CanonicalChessState] seen;
        foreach (child; state.children(score)){
            auto canonical_child = CanonicalChessState(child);
            if (canonical_child !in seen){
                seen[canonical_child] = true;
                result ~= canonical_child;
            }
        }
        return result;
    }

    size_t endgame_state(out EndgameType type) const
    {
        return state.endgame_state(type);
    }

    static bool from_endgame_state(size_t endgame, EndgameType type, out CanonicalChessState result)
    {
        PseudoChessState s;
        if (PseudoChessState.from_endgame_state(endgame, type, s)){
            result = CanonicalChessState(s);
            return true;
        }
        return false;
    }

    string toString()
    {
        return state.toString;
    }

    string repr()
    {
        return format("CanonicalChessState(0x%xUL, 0x%xUL, 0x%xUL, 0x%xUL)", player, straight, diagonal, special);
    }
}

immutable CanonicalChessState chess_initial = CanonicalChessState(
    PseudoChessState(
        RANK1 | RANK2,
        RANK2 | RANK7,
        (RANK1 | RANK8) & (BFILE | GFILE),
        (RANK1 | RANK8) & (CFILE | FFILE),
        (RANK1 | RANK8) & (AFILE | HFILE),
        (RANK1 | RANK8) & DFILE,
        (RANK1 | RANK8) & EFILE,
        (RANK1 | RANK8) & (AFILE | EFILE | HFILE)
    )
);

// TODO: Replace with a real thing that can represent arbitrary moves.
alias ChessMove = Move;

void examine_chess_playout(CanonicalChessState s, bool decanonize=true)
{
    import std.random;
    import core.thread;

    Mt19937 gen;
    auto seed = uniform!uint;
    //seed = 2880884799;
    //seed = 3403945820;
    writeln("Seed=", seed);
    gen.seed(seed);

    int j = 0;
    while (true){
        float score;
        auto children = s.children(score);
        if (children.length == 0){
            writeln(s);
            writeln("Score=", score);
            return;
        }
        auto n = gen.front;
        gen.popFront;
        s = children[n % children.length];
        if (decanonize){
            if (j & 1){
                writeln(s);
            }
            else {
                auto d = s.state;
                d.pseudo_decanonize;
                string r = d.toString;
                r = r[0..$ - "White to play".length] ~ "Black to play";
                writeln(r);
            }
        }
        else {
            writeln(s);
            EndgameType t;
            size_t e = s.endgame_state(t);
            CanonicalChessState r;
            if (CanonicalChessState.from_endgame_state(e, t, r)){
                writeln(r);
            }
            else {
                writeln(e);
            }
        }
        writeln(s.repr);
        Thread.sleep(dur!("msecs")(10));
        j++;
    }
}


unittest
{
    assert(h_rays(RANK4 & AFILE, FULL) == RANK4);
    assert(h_rays(RANK5 & HFILE, FULL) == RANK5);
    assert(h_rays(RANK5 & (BFILE | HFILE), FULL) == RANK5);
    assert(h_rays((RANK2 | RANK7) & CFILE, FULL) == (RANK2 | RANK7));
    assert(h_rays(RANK6 | RANK7, FULL) == (RANK6 | RANK7));
    assert(h_rays(CFILE, FULL) == FULL);

    assert(v_rays(RANK1 & AFILE, FULL) == AFILE);

    assert(d_rays(RANK1 & AFILE, FULL).popcount == 8);
    assert(d_rays(RANK4 & EFILE, FULL).popcount == 7);

    assert(z_rays(RANK1 & AFILE, FULL).popcount == 1);
    assert(z_rays(RANK4 & EFILE, FULL).popcount == 8);
}

unittest
{
    auto s = PseudoChessState(BFILE & (RANK1 | RANK7), 0, HFILE & RANK6, 0, BFILE & (RANK1 | RANK3), 0, (BFILE & RANK7) | (EFILE & RANK8), 0);
    assert(s.king_in_check);
}

unittest
{
    auto c = CanonicalChessState(0x8402900000000UL, 0x8406929100000UL, 0x8000000100000UL, 0x8406929100000UL);
    assert(!c.state.kings_can_capture_pawns);
}
