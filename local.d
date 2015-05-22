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
    float score = float.nan;

    string toString()
    {
        return format("Moves\n%s\nThreats\n%s\nscore=%s", moves, threats, score);
    }
}


LocalResult!T get_local_result(T)(T player, T opponent, T region, T player_unconditional, T opponent_unconditional)
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
    auto pass_node = new GameNode!(T, LocalState!T)(pass_state);
    pass_node.calculate_minimax_values;
    auto pass_score = -pass_node.high_value;

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
    auto pessimistic_node = new GameNode!(T, LocalState!T)(pessimistic_state);
    pessimistic_node.calculate_minimax_values;
    mixin(update_member("pessimistic_node", "high", "pass_score", "moves"));
    mixin(update_member("pessimistic_node", "low", "pass_score", "moves"));

    // TODO: Prune threats.
    auto best_score = region.popcount - opponent_unconditional.popcount;
    auto eyespace = region & ~(player | player_unconditional | opponent_unconditional);
    foreach (extra_turns; 1..(eyespace.popcount - 2)){
        auto optimistic_state = LocalState!T(state, extra_turns);
        auto optimistic_node = new GameNode!(T, LocalState!T)(optimistic_state);
        optimistic_node.calculate_minimax_values;
        mixin(update_member("optimistic_node", "high", "pessimistic_node.low_value", "threats"));
        mixin(update_member("optimistic_node", "low", "pessimistic_node.low_value", "threats"));
        if (optimistic_node.low_value >= best_score){
            break;
        }
    }

    if (
        pessimistic_node.low_value == pessimistic_node.high_value &&
        pessimistic_node.high_value == -pass_node.low_value &&
        pass_node.low_value == pass_node.high_value
    ){
        result.score = pessimistic_node.low_value - player_unconditional.popcount + opponent_unconditional.popcount;
    }

    return result;
}


alias LocalResult8 = LocalResult!Board8;
alias get_local_result8 = get_local_result!Board8;


unittest
{
    auto s = State8(rectangle8(3, 3));
    s.player = rectangle8(3, 1);
    s.opponent = rectangle8(3, 1).south;
    s.player_unconditional = s.player;

    auto r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.player_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves == Board8(1, 2));
    assert(!r.threats);
    assert(r.score.isNaN);

    s.swap_turns;
    r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.opponent_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves == Board8(1, 2));
    assert(!r.threats);
    assert(r.score.isNaN);

    s.opponent_unconditional = Board8();
    s.playing_area = rectangle8(4, 3);
    s.player = rectangle8(4, 1);
    s.opponent = rectangle8(4, 1).south;
    s.player_unconditional = s.player;

    r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.player_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert((Board8(1,2) | Board8(2, 2)) & r.threats);
    assert(r.score == -8);

    s.swap_turns;
    r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.opponent_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert(!r.threats);
    assert(r.score == 8);
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

    auto r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.player_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(r.moves);
    assert(r.score.isNaN);


    s.swap_turns;
    r = get_local_result8(s.player, s.opponent, s.playing_area & ~s.opponent_unconditional, s.player_unconditional, s.opponent_unconditional);
    assert(!r.moves);
    assert(!r.threats);
    assert(r.score.isNaN);
}