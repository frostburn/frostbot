module local;

import std.string;
import std.stdio;
import std.math;
import std.algorithm;

import board8;
import state;
import game_node;


struct LocalState(T)
{
    CanonicalState!T state;
    int extra_turns = 0;

    this(T playing_area)
    {
        this(State!T(playing_area));
    }

    this(State!T state, int extra_turns=0)
    {
        this.state = CanonicalState!T(state);
        this.extra_turns = extra_turns;
    }

    this(CanonicalState!T state, int extra_turns=0)
    {
        this.state = state;
        this.extra_turns = extra_turns;
    }

    bool opEquals(in LocalState!T rhs) const pure nothrow
    {
        return state == rhs.state && extra_turns == rhs.extra_turns;
    }

    int opCmp(in LocalState!T rhs) const pure nothrow
    {
        if (state != rhs.state){
            return state.opCmp(rhs.state);
        }
        return extra_turns - rhs.extra_turns;
    }

    hash_t toHash() const nothrow @safe
    {
        return state.toHash ^ typeid(extra_turns).getHash(&extra_turns);
    }

    bool black_to_play() const @property
    {
        return state.black_to_play;
    }

    int passes() const @property
    {
        return state.passes;
    }

    bool is_leaf()
    {
        return state.is_leaf;
    }

    float value_shift() const @property
    {
        return state.value_shift;
    }

    float value_shift(float shift) @property
    {
        return state.value_shift = shift;
    }

    float liberty_score()
    {
        return state.liberty_score;
    }

    LocalState!T[] children()
    {
        LocalState!T[] result;
        // Negamax requires a pass in between free moves.
        if (extra_turns < 0){
            auto child = state;
            //child.pass;
            //child.passes = 0;
            child.swap_turns;
            result ~= LocalState!T(child, -extra_turns - 1);
        }
        else{
            foreach (child; state.children(true)){
                result ~= LocalState!T(child, -extra_turns);
            }
        }
        return result;
    }

    string toString()
    {
        return state.toString() ~ format(", extra_turns=%s", extra_turns);
    }
}


alias LocalState8 = LocalState!Board8;


struct LocalResult(T)
{
    T moves;
    T threats;
    float pass_low;
    float pass_high;
    float low;
    float high;
    float score;

    bool opEquals(in LocalResult!T rhs) const
    {
        return (
            moves == rhs.moves &&
            threats == rhs.threats &&
            pass_low == rhs.pass_low &&
            pass_high == rhs.pass_high &&
            low == rhs.low &&
            high == rhs.high &&
            score == rhs.score
        );
    }

    // Used for sorting best sente first.
    int opCmp(in LocalResult!T rhs) const
    {
        float sente = low - pass_low;
        float rhs_sente = rhs.low - rhs.pass_low;
        if (sente > rhs_sente){
            return -1;
        }
        else if (sente < rhs_sente){
            return 1;
        }
        return 0;
    }

    string toString()
    {
        return format("Moves\n%s\nThreats\n%s\n%s <= gote <= %s\n%s <= sente <= %s\nscore = %s", moves, threats, pass_low, pass_high, low, high, score);
    }
}


LocalResult!T get_local_result(T)(T region, T player, T opponent, T player_unconditional, T opponent_unconditional, Transposition[LocalState!T] *transpositions=null)
{
    assert(region.is_contiguous);
    assert(~(region & (player_unconditional | opponent_unconditional)));
    auto playing_area = region.cross(region | player_unconditional | opponent_unconditional);
    player &= playing_area;
    opponent &= playing_area;
    player_unconditional &= playing_area;
    opponent_unconditional &= playing_area;
    auto state = State!T(playing_area);
    state.player = player;
    state.opponent = opponent;
    state.player_unconditional = player_unconditional;
    state.opponent_unconditional = opponent_unconditional;

    debug (local){
        writeln("Local analysis");
        writeln(state);
    }

    auto moves = state.moves;
    auto children = state.children(moves, true);
    assert(children.length == moves.length);
    CanonicalState!T[] canonical_children;
    foreach (child; children){
        canonical_children ~= CanonicalState!T(child);
    }

    LocalResult!T result;

    auto pass_state = LocalState!T(state);
    pass_state.state.swap_turns;
    auto pass_node = new GameNode!(T, LocalState!T)(pass_state, transpositions);
    pass_node.calculate_minimax_values(transpositions);
    auto pass_score = -pass_node.high_value;
    debug (local) {
        writeln("Pass node");
        writeln(pass_node);
    }

    string update_member(string node, string other_type, string worse_result, string member)
    {
        return "
            foreach (child; " ~ node ~ ".children){
                if (-child." ~ other_type ~ "_value > " ~ worse_result ~"){
                    foreach (i, canonical_child; canonical_children){
                        if (canonical_child == child.state.state){
                            result." ~ member ~ " |= moves[i];
                        }
                    }
                }
            }
        ";
    }

    auto pessimistic_state = LocalState!T(state);
    auto pessimistic_node = new GameNode!(T, LocalState!T)(pessimistic_state, transpositions);
    pessimistic_node.calculate_minimax_values(transpositions);
    if (!pessimistic_node.children.length){
        pessimistic_node.make_children(transpositions);
    }
    mixin(update_member("pessimistic_node", "high", "pass_score", "moves"));
    mixin(update_member("pessimistic_node", "low", "pass_score", "moves"));
    debug (local){
        writeln("Pessimistic node");
        writeln(pessimistic_node);
    }

    // TODO: Prune threats.
    auto best_score = region.popcount - opponent_unconditional.popcount;
    auto eyespace = region & ~(player | player_unconditional | opponent_unconditional);
    foreach (extra_turns; 1..eyespace.popcount){
        auto optimistic_state = LocalState!T(state, extra_turns);
        auto optimistic_node = new GameNode!(T, LocalState!T)(optimistic_state, transpositions);
        optimistic_node.calculate_minimax_values(transpositions);
        if (!optimistic_node.children.length){
            optimistic_node.make_children(transpositions);
        }
        mixin(update_member("optimistic_node", "high", "pessimistic_node.low_value", "threats"));
        mixin(update_member("optimistic_node", "low", "pessimistic_node.low_value", "threats"));
        debug (local){
            writeln("Optimistic node");
            writeln(optimistic_node);
        }

        if (optimistic_node.low_value >= best_score){
            break;
        }
    }

    /*
    if (
        pessimistic_node.low_value == pessimistic_node.high_value &&
        pessimistic_node.high_value == -pass_node.low_value &&
        pass_node.low_value == pass_node.high_value
    ){
        result.score = pessimistic_node.low_value - player_unconditional.popcount + opponent_unconditional.popcount;
    }
    */

    float adjustment = opponent_unconditional.popcount - player_unconditional.popcount;
    result.pass_low = adjustment - pass_node.high_value;
    result.pass_high = adjustment - pass_node.low_value;
    result.low = adjustment + pessimistic_node.low_value;
    result.high = adjustment + pessimistic_node.high_value;
    result.score = result.pass_high;

    debug (local){
        writeln(result);
    }
    return result;
}


alias LocalResult8 = LocalResult!Board8;
alias get_local_result8 = get_local_result!Board8;

LocalResult!T get_static_result(T)(T region, T player, T opponent, T player_unconditional, T opponent_unconditional)
{
    //assert(region.is_contiguous);
    assert(~(region & (player_unconditional | opponent_unconditional)));
    /*
    auto playing_area = region.cross(region | player_unconditional | opponent_unconditional);
    player &= playing_area;
    opponent &= playing_area;
    player_unconditional &= playing_area;
    opponent_unconditional &= playing_area;
    */

    LocalResult!T result;
    T space = region & ~(player | opponent);
    result.moves = space;
    result.threats = result.moves;

    int region_size = region.popcount;
    T player_dames = player_unconditional.liberties(space);
    T opponent_dames = opponent_unconditional.liberties(space);
    int player_dame_count = player_dames.popcount;
    int opponent_dame_count = opponent_dames.popcount;
    int player_pass_sure = player_dame_count / 2;
    int player_sure = player_pass_sure + (player_dame_count & 1);
    int opponent_pass_sure = opponent_dame_count / 2;
    result.pass_low = 2 * player_pass_sure - region_size;
    result.pass_high = result.pass_low;  // Luckily not used to do any relevant analysis.
    result.low = 2 * player_sure - region_size;
    result.high = region_size - 2 * opponent_pass_sure;

    result.score = player.cross(region & ~opponent).popcount - opponent.cross(region & ~player).popcount;

    debug (local){
        writeln("Static result:");
        writeln(result);
    }

    return result;
}


void analyze_state(T, S)(S state, out T[] moves, out float lower_bound, out float upper_bound, Transposition[LocalState!T] *transpositions=null){
    assert(state.black_to_play);
    float size = state.playing_area.popcount;

    bool has_good_moves = false;
    T undecided_space = state.playing_area & ~(state.player_unconditional | state.opponent_unconditional);
    LocalResult!T[] local_results;
    foreach (region; undecided_space.chains){
        version (high_memory){
            int limit = 12;
        }
        else {
            int limit = 10;
        }

        if (region.popcount <= limit && !(region & state.ko)){
            auto result = get_local_result(
                region,
                state.player, state.opponent,
                state.player_unconditional, state.opponent_unconditional,
                transpositions
            );
            if (result.moves || (state.ko && result.threats)){
                has_good_moves = true;
            }
            local_results ~= result;
        }
        else {
            local_results ~= get_static_result(
                region,
                state.player, state.opponent,
                state.player_unconditional, state.opponent_unconditional,
            );
            auto space = region & ~(state.player | state.opponent | state.ko);
            if (3 * space.popcount > region.popcount || state.player_unconditional.liberties(space)){
                has_good_moves = true;
            }
        }
    }
    sort(local_results);

    // The minimal low strategy is to lose sente in the first region and take gote in the rest.
    // The high strategy is to keep sente all the way.
    lower_bound = state.player_unconditional.popcount - state.opponent_unconditional.popcount;
    upper_bound = lower_bound;
    float score = lower_bound;
    T flat_moves;
    bool first_move = true;
    foreach (result; local_results){
        flat_moves |= result.moves;
        if (state.ko){
            flat_moves |= result.threats;
        }
        if (first_move){
            lower_bound += result.low;
            first_move = false;
        }
        else {
            lower_bound += result.pass_low;
        }
        upper_bound += result.high;
        score += result.score;
    }

    moves = flat_moves.pieces();
    if (!has_good_moves || state.passes){
        moves ~= T();
    }

    assert(lower_bound >= -size);
    assert(lower_bound <= size);
    assert(upper_bound >= -size);
    assert(upper_bound <= size);
    lower_bound += state.value_shift;
    upper_bound += state.value_shift;
    score += state.value_shift;
    if (state.passes >= 2){
        moves = moves.init;
        upper_bound = lower_bound = score;
    }
    assert(lower_bound <= upper_bound);
}


unittest
{
    auto s = State8(rectangle8(3, 3));
    s.player = rectangle8(3, 1);
    s.opponent = rectangle8(3, 1).south;
    s.player_unconditional = s.player;

    auto r = get_local_result8(s.playing_area & ~s.player_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves == Board8(1, 2));
    assert(!r.threats);
    //assert(r.score.isNaN);

    s.swap_turns;
    r = get_local_result8(s.playing_area & ~s.opponent_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves == Board8(1, 2));
    assert(!r.threats);
    //assert(r.score.isNaN);

    s.opponent_unconditional = Board8();
    s.playing_area = rectangle8(4, 3);
    s.player = rectangle8(4, 1);
    s.opponent = rectangle8(4, 1).south;
    s.player_unconditional = s.player;

    r = get_local_result8(s.playing_area & ~s.player_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert((Board8(1,2) | Board8(2, 2)) & r.threats);
    assert(r.pass_low == -8);

    s.swap_turns;
    r = get_local_result8(s.playing_area & ~s.opponent_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert(!r.threats);
    assert(r.pass_low == 8);
}

unittest
{
    // Moonshine life
    auto b = Board8(0, 0);
    b = b.cross(full8);
    auto opponent = b.liberties(full8) | Board8(0, 0);
    b = b.cross(full8);
    auto player = b.liberties(full8);
    b = b.cross(full8);

    auto s = State8(b);
    s.player = player;
    s.opponent = opponent;
    s.player_unconditional = player;

    auto r = get_local_result8(s.playing_area & ~s.player_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves);
    //assert(r.score.isNaN);


    s.swap_turns;
    r = get_local_result8(s.playing_area & ~s.opponent_unconditional, s.player, s.opponent, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert(!r.threats);
    //assert(r.score.isNaN);
}

unittest
{
    Transposition[LocalState8] empty2;
    auto local_transpositions = &empty2;

    auto r = Board8(1, 0);
    auto p = Board8(0, 0) | Board8(1, 1);
    auto o = Board8(2, 0);

    auto result1 = get_local_result(r, p, o, p, o, local_transpositions);
    auto result2 = get_local_result(r, p, o, p, o, local_transpositions);

    assert(result1 == result2);
}

unittest
{
    auto b = Board8(1, 0);
    b = b.cross(full8);
    b |= b.east;
    auto p = Board8(2, 1) | Board8(3, 0);
    auto o = Board8(1, 0).liberties(b);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.player_unconditional = p;
    s.opponent_unconditional = o ^ Board8(2, 0);

    auto n = new GameNode!(Board8, LocalState8)(LocalState8(s));
    n.calculate_minimax_values;
    assert(n.low_value == -2);
    assert(n.high_value == 2);
}

unittest
{
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;

    auto b = Board8(0, 0);
    b = b.cross(full8).cross(full8).cross(full8);
    auto o = b.liberties(full8) ^ Board8(4, 0) ^ Board8(1, 2);
    b = b.cross(full8);
    auto p = rectangle8(3, 2) ^ Board8(2, 0) ^ Board8(3, 0) ^ Board8(0, 1) ^ Board8(0, 2);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.opponent_unconditional = o;

    auto n = new GameNode8(CanonicalState8(s));
    n.calculate_minimax_values;

    bool[CanonicalState8] seen;
    void check(GameNode8 root)
    {
        if (root.state in seen){
            return;
        }
        seen[root.state] = true;
        Board8[] moves;
        float low, high;
        root.state.get_score_bounds(low, high);
        assert(low <= root.low_value);
        assert(root.high_value <= high);
        // Liberty score gives score to dead stones still on the board, ignore.
        if (root.state.passes == 0){
            analyze_state(root.state, moves, low, high, transpositions);
            if (low > root.low_value || root.high_value > high){
                writeln(root);
                writeln(low, ", ", high);
            }
            assert(low <= root.low_value);
            assert(root.high_value <= high);
        }
        foreach (child; root.children){
            check(child);
        }
    }
    check(n);
}

unittest
{
    auto state = State!Board8(Board8(0x406UL), Board8(0x2c1a00UL), Board8(0x3c1e0fUL), Board8(0x0UL), true, 2, Board8(0x0UL), Board8(0x0UL), 0);
    Board8[] moves;
    float low, high;

    analyze_state(state, moves, low, high);

    assert(!moves.length);
    assert(low == -4);
    assert(high == -4);
}

unittest
{
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;
    auto r = get_local_result(
        rectangle8(4, 3),
        empty8, Board8(1, 1),
        empty8, empty8,
        transpositions
    );
    assert(r.moves & Board8(2, 1));
}

unittest
{
    version (high_memory){
        Transposition[LocalState8] loc_trans;
        auto transpositions = &loc_trans;

        auto cs = CanonicalState!Board8(State!Board8(Board8(0x1605UL), Board8(0x180800UL), Board8(0x3c1e0fUL), Board8(0x0UL), true, 1, Board8(0x0UL), Board8(0x0UL), 0));

        Board8[] moves;
        float low, high;

        analyze_state(cs, moves, low, high, transpositions);
        assert(low == 4);
        assert(high == 12);
    }
}