module direct_mc;

import std.stdio;
import std.string;
import std.random;
import std.conv;
import std.math;
import std.array;
import std.algorithm;
import std.range;
import std.parallelism;

import utils;
import board8;
import state;
import defense_state;
import defense_search_state;
import defense;
static import monte_carlo;
import wdl_node;


ulong next_tag = 1;


class DirectMCNode(T, S, C)
{
    C state;
    T player_secure;
    T opponent_secure;
    Statistics statistics;
    bool is_final = false;
    float lower_value = float.nan;
    float upper_value = float.nan;
    ulong tag = 0;

    DirectMCNode!(T, S, C)[] children;
    DirectMCNode!(T, S, C)[C] parents;
    DirectMCNode!(T, S, C)[C] *node_pool;

    private
    {
        T[] moves;
        float lower_loop;
        float upper_loop;
    }

    double value() const @property
    {
        return 0.5 * (lower_value + upper_value);
    }

    this (T playing_area, DirectMCNode!(T, S, C)[C] *node_pool=null)
    {
        this(S(playing_area), node_pool);
    }

    this (S state, DirectMCNode!(T, S, C)[C] *node_pool=null)
    {
        this(C(state), node_pool);
    }

    this (C state, DirectMCNode!(T, S, C)[C] *node_pool=null)
    {
        state.analyze_unconditional(player_secure, opponent_secure);
        auto result = analyze_state_light!(T, C)(state, player_secure, opponent_secure);
        player_secure = result.player_secure;
        opponent_secure = result.opponent_secure;
        this.state = state;
        if (state.is_leaf){
            this.is_final = true;
            //this.statistics = Statistics(result.score, result.score);
            this.lower_value = this.upper_value = result.score;
        }
        else{
            calculate_available_moves(result);
            this.node_pool = node_pool;
            this.statistics = Statistics(result.lower_bound, result.upper_bound);
        }
    }

    int opCmp(in DirectMCNode!(T, S, C) rhs) const
    {
        float v = lower_value + upper_value;
        float rv = rhs.lower_value + rhs.upper_value;
        if (v < rv){
            return -1;
        }
        else if (v == rv){
            return 0;
        }
        else {
            return 1;
        }
    }

    void invalidate(ulong tag)
    {
        if (is_final){
            return;
        }
        if (this.tag == tag){
            return;
        }
        this.tag = tag;

        lower_value = float.nan;
        upper_value = float.nan;

        foreach (parent; parents.byValue){
            parent.invalidate(tag);
        }
    }

    void playout()
    {
        enum rounds = 200;
        Statistics[] sub_statisticss;
        foreach (i; 0..totalCPUs){
            sub_statisticss ~= Statistics(statistics.lower_bound, statistics.upper_bound);
        }
        foreach (ref sub_statistics; parallel(sub_statisticss)){
            foreach (i; 0..rounds){
                auto default_node = monte_carlo.DefaultNode!(T, S)(state.state, player_secure, opponent_secure, moves);
                default_node.playout;
                sub_statistics.add_value(default_node.value);
            }
        }
        foreach (ref sub_statistics; sub_statisticss){
            foreach (i; 0..statistics.bins.length){
                statistics.bins[i] += sub_statistics.bins[i];
            }
        }
    }

    void get_value(){
        float lower_dummy, upper_dummy;
        return get_value(next_tag++, statistics.lower_bound, statistics.upper_bound, lower_dummy, upper_dummy);
    }

    void get_value(ulong tag, float alpha, float beta, out float lower_value, out float upper_value)
    {
        if (!this.lower_value.isNaN && !this.upper_value.isNaN){
            lower_value = this.lower_value;
            upper_value = this.upper_value;
            return;
        }
        if (this.tag == tag){
            lower_value = lower_loop;
            upper_value = upper_loop;
            return;
        }
        this.tag = tag;
        if (children.length == 0){
            playout;
            lower_value = this.lower_value = upper_value = this.upper_value = statistics.mean;
        }
        else {
            lower_loop = -float.infinity;
            upper_loop = float.infinity;
            lower_value = -float.infinity;
            upper_value = -float.infinity;
            foreach (child; children){
                float child_lower_value, child_upper_value;
                child.get_value(tag, -beta, -alpha, child_upper_value, child_lower_value);
                child_lower_value = -child_lower_value;
                child_upper_value = -child_upper_value;
                if (child_lower_value > lower_value){
                    lower_value = child_lower_value;
                    alpha = max(alpha, lower_value);
                }
                if (child_upper_value > upper_value){
                    upper_value = child_upper_value;
                }
                /*
                if (lower_value >= beta){
                    assert(upper_value >= beta);
                    if (alpha <= statistics.lower_bound && beta >= statistics.upper_bound){
                        this.lower_value = lower_loop = lower_value;
                        this.upper_value = upper_loop = upper_value;
                    }
                    return;
                }
                */
            }
            //if (alpha <= statistics.lower_bound && beta >= statistics.upper_bound){
            this.lower_value = lower_loop = lower_value;
            this.upper_value = upper_loop = upper_value;
            //}
        }
    }

    void expand()
    {
        debug(expand) {
            writeln("expand");
            writeln(this);
        }
        if (!children.length){
            make_children;
            return;
        }
        enum exploration_constant = 2.0;

        double best_value = double.infinity;
        DirectMCNode!(T, S, C) best_child = null;
        foreach (child; children){
            if (child.is_final){
                continue;
            }
            debug(expand) {
                writeln("expand:child");
                writeln(child);
            }
            child.get_value;
            double child_value = child.value; //+ exploration_constant * sqrt(log(visits + 1) / (child.visits + 1));
            if (child_value < best_value){
                best_child = child;
                best_value = child_value;
            }
        }
        if (best_child !is null){
            best_child.expand;
        }
    }

    void calculate_available_moves(DefenseAnalysisResult!T result)
    {
        int y_max = state.playing_area.vertical_extent;
        int x_max = state.playing_area.horizontal_extent;

        for (int y = 0; y < y_max; y++){
            for (int x = 0; x < x_max; x++){
                T move = T(x, y);
                if (move & state.playing_area & ~player_secure & ~opponent_secure & ~result.player_useless){
                    moves ~= move;
                }
            }
        }
        // Only allow passing when the board is at least half full.
        if ((state.player | player_secure | state.opponent | opponent_secure).popcount * 2 > state.playing_area.popcount){
            moves ~= T();
        }
    }

    void make_children()
    {
        if (is_final){
            return;
        }
        if (children.length){
            return;
        }
        auto child_states = state.children(moves);
        foreach (move, child_state; zip(moves, child_states)){
            if (node_pool !is null && child_state in *node_pool){
                auto child = (*node_pool)[child_state];
                child.parents[state] = this;
                children ~= child;
            }
            else{
                auto child = new DirectMCNode!(T, S, C)(child_state, node_pool);
                child.parents[state] = this;
                children ~= child;
                if (node_pool !is null){
                    (*node_pool)[child_state] = child;
                }
            }
        }
        invalidate(next_tag++);
        check_finality(next_tag++);
    }

    void check_finality(ulong tag)
    {
        if (this.tag == tag){
            return;
        }
        this.tag = tag;
        is_final = true;
        foreach (child; children){
            is_final = is_final && child.is_final;
        }
        if (is_final){
            lower_value = -float.infinity;
            upper_value = -float.infinity;
            foreach (child; children){
                if (-child.upper_value > lower_value){
                    lower_value = -child.upper_value;
                }
                if (-child.lower_value > upper_value){
                    upper_value = -child.lower_value;
                }
            }
        }
    }

    /*
    DirectMCNode!(T, S, C) best_child()
    {
        if (!children.length){
            make_children;
        }

        DirectMCNode!(T, S, C) best_child;
        float best_value = -float.infinity;

        // TODO: Factor in confidence.
        foreach (child; children){
            if (-child.value >= best_value){
                best_value = -child.value;
                best_child = child;
            }
        }
        return best_child;
    }
    */

    DirectMCNode!(T, S, C) bottom()
    {
        return bottom(next_tag++);
    }

    DirectMCNode!(T, S, C) bottom(ulong tag){
        if (this.tag == tag){
            return this;
        }
        this.tag = tag;
        if (!children.length){
            return this;
        }
        foreach (child; children){
            child.get_value;
        }
        sort(children);
        return children[0].bottom;
    }

    override string toString()
    {
        return format(
            "%s\nlower=%s, upper=%s\nfinal=%s, number of children=%s",
            state._toString(T(), T(), player_secure, opponent_secure),
            lower_value, upper_value,
            is_final, children.length
        );
    }
}

alias DirectMCNode8 = DirectMCNode!(Board8, State8, CanonicalState8);
