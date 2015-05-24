module local;

import std.string;
import std.stdio;
import std.math;

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

    bool opEquals(in LocalResult!T rhs) const
    {
        return (
            moves == rhs.moves &&
            threats == rhs.threats &&
            pass_low == rhs.pass_low &&
            pass_high == rhs.pass_high &&
            low == rhs.low &&
            high == rhs.high
        );
    }

    string toString()
    {
        return format("Moves\n%s\nThreats\n%s\n%s <= pass <= %s, %s <= score <= %s", moves, threats, pass_low, pass_high, low, high);
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
    pass_node.calculate_minimax_values;
    auto pass_score = -pass_node.high_value;
    debug (local) {
        writeln("Pass node");
        writeln(pass_node);
    }

    string update_member(string node, string type, string worse_result, string member)
    {
        return "
            if (" ~ node ~ "." ~ type ~ "_value > " ~ worse_result ~"){
                foreach (child; " ~ node ~ "." ~ type ~ "_children){
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
    pessimistic_node.calculate_minimax_values;
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
        optimistic_node.calculate_minimax_values;
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

    debug (local){
        writeln(result);
    }
    return result;
}


alias LocalResult8 = LocalResult!Board8;
alias get_local_result8 = get_local_result!Board8;


void analyze_state(T, S)(S state, out T moves, out float lower_bound, out float upper_bound, Transposition[LocalState!T] *transpositions=null){
    enum check_passes = "
        if (state.passes == 1){
            auto score = state.liberty_score;
            if (score > lower_bound){
                lower_bound = score;
            }
            if (score > upper_bound){
                upper_bound = score;
            }
        }
    ";
    assert(state.black_to_play);
    float size = state.playing_area.popcount;
    lower_bound = -size;
    upper_bound = size;

    T space = state.playing_area & ~(state.player | state.opponent);
    moves = space;
    T undecided_space = state.playing_area & ~(state.player_unconditional | state.opponent_unconditional);
    foreach (region; undecided_space.chains){
        if (region.popcount <= 10 && !(region & state.ko)){
            auto result = get_local_result(
                region,
                state.player, state.opponent,
                state.player_unconditional, state.opponent_unconditional,
                transpositions
            );
            // TODO: Investigate why this breaks.
            /*
            if (region == undecided_space){
                moves = result.moves;
                float base_score = state.player_unconditional.popcount - state.opponent_unconditional.popcount;
                lower_bound = result.low + base_score;
                upper_bound = result.high + base_score;
                assert(lower_bound >= -size);
                assert(lower_bound <= size);
                assert(upper_bound >= -size);
                assert(upper_bound <= size);
                lower_bound += state.value_shift;
                upper_bound += state.value_shift;
                mixin(check_passes);
                assert(lower_bound <= upper_bound);
                return;
            }
            */
            moves &= ~region;
            moves |= result.moves;
            if (state.ko){
                moves |= result.threats;
            }
            // TODO: Check if this condition is necessary.
            if (result.pass_low == result.high){
                space &= ~region;
                float assumed_score = region.popcount;
                lower_bound += result.pass_low + assumed_score;
                upper_bound += result.high - assumed_score;
            }
        }
    }
    // The minimal strategy is to fill half of sure dames.
    int player_crawl = state.player_unconditional.liberties(space).popcount;
    int opponent_crawl = state.opponent_unconditional.liberties(space).popcount;

    // TODO: Check if this is right.
    lower_bound += (player_crawl / 2) + (player_crawl & 1);
    upper_bound -= (opponent_crawl / 2); //- (opponent_crawl & 1);

    lower_bound += 2 * state.player_unconditional.popcount;
    upper_bound -= 2 * state.opponent_unconditional.popcount;

    assert(lower_bound >= -size);
    assert(lower_bound <= size);
    assert(upper_bound >= -size);
    assert(upper_bound <= size);
    lower_bound += state.value_shift;
    upper_bound += state.value_shift;
    mixin(check_passes);
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