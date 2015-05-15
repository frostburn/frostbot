module wdl_node;

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
import board11;
import state;
import defense_state;
import defense_search_state;
import defense;
import monte_carlo;



struct Statistics
{
    uint[] bins;

    private
    {
        float shift;
    }

    float lower_bound() const @property
    {
        return -shift;
    }

    float upper_bound() const @property
    {
        return (cast(float)bins.length) - shift - 1;
    }

    ulong confidence() const @property
    {
        ulong total = 0;
        foreach (bin; bins){
            total += bin;
        }
        return total;
    }

    this(float lower_bound, float upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        bins.length = to!size_t(round(upper_bound - lower_bound)) + 1;
        bins[] = 0;
        shift = -lower_bound;
        if (lower_bound == upper_bound){
            bins[0] = uint.max;
        }
    }

    void clear()
    {
        bins[] = 0;
    }

    void set_bounds(float lower_bound, float upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        uint[] new_bins;
        new_bins.length = to!size_t(round(upper_bound - lower_bound)) + 1;
        new_bins[] = 0;
        float new_shift = -lower_bound;
        for (float v = lower_bound; v <= upper_bound; v++){
            new_bins[to!size_t(round(v + new_shift))] = get_bin(v);
        }
        bins = new_bins;
        shift = new_shift;
    }

    float add_value(float value)
    {
        float index = round(value + shift);
        if (index < 0){
            index = 0;
        }
        else if (index >= bins.length){
            index = bins.length - 1;
        }
        bins[to!size_t(index)] += 1;

        return index - shift;
    }

    uint get_bin(float value)
    {
        float index = round(value + shift);
        if (index < 0){
            return 0;
        }
        else if (index >= bins.length){
            return 0;
        }
        return bins[to!size_t(index)];
    }

    double mean() const
    {
        double e = 0.0;
        double total = 0.0;
        foreach (index, bin; bins){
            e += (to!double(index) - shift) * bin;
            total += bin;
        }
        if (total == 0.0){
            return -shift;
        }
        else{
            return e / total;
        }
    }

    string toString()
    {
        double max = 0.0;
        foreach (bin; bins){
            if (bin > max){
                max = bin;
            }
        }

        if (max == 0.0){
            return "";
        }

        enum height = 20;

        string r;
        foreach (y; 0..height){
            foreach (x; 0..bins.length){
                double bin_height = (8 * height * to!double(bins[x])) / max;
                auto target_height = 8 * (height - y);
                if (bin_height >= target_height){
                    r ~= "█";
                }
                else if (bin_height >= target_height - 1){
                    r ~= "▇";
                }
                else if (bin_height >= target_height - 2){
                    r ~= "▆";
                }
                else if (bin_height >= target_height - 3){
                    r ~= "▅";
                }
                else if (bin_height >= target_height - 4){
                    r ~= "▄";
                }
                else if (bin_height >= target_height - 5){
                    r ~= "▃";
                }
                else if (bin_height >= target_height - 6){
                    r ~= "▂";
                }
                else if (bin_height >= target_height - 7){
                    r ~= "▁";
                }
                else{
                    r ~= " ";
                }
            }
            r ~= "\n";
        }
        return format("%sMean=%s", r, mean);
    }
}


ulong next_tag = 1;


class WDLNode(T, S, C)
{
    C state;
    T player_secure;
    T opponent_secure;
    Statistics lower_statistics;
    Statistics upper_statistics;
    bool is_final = false;
    ulong tag = 0;

    WDLNode!(T, S, C)[] children;
    WDLNode!(T, S, C)[C] parents;
    WDLNode!(T, S, C)[C] *node_pool;

    private
    {
        T[] moves;
        float lower_value;
        float upper_value;
        bool broken = false;
    }

    invariant
    {
        if (is_final){
            assert(lower_statistics.lower_bound == lower_statistics.upper_bound);
            assert(upper_statistics.lower_bound == upper_statistics.upper_bound);
        }
    }

    double value() const @property
    {
        return 0.5 * (lower_statistics.mean + upper_statistics.mean);
    }

    this (T playing_area, WDLNode!(T, S, C)[C] *node_pool=null)
    {
        this(S(playing_area), node_pool);
    }

    this (S state, WDLNode!(T, S, C)[C] *node_pool=null)
    {
        this(C(state), node_pool);
    }

    this (C state, WDLNode!(T, S, C)[C] *node_pool=null)
    {
        state.analyze_unconditional(player_secure, opponent_secure);
        auto result = analyze_state_light!(T, C)(state, player_secure, opponent_secure);
        player_secure = result.player_secure;
        opponent_secure = result.opponent_secure;
        this.state = state;
        if (state.is_leaf){
            this.is_final = true;
            this.lower_statistics = this.upper_statistics = Statistics(result.score, result.score);
        }
        else{
            calculate_available_moves(result);
            this.node_pool = node_pool;
            /*
            if (state.value_shift - floor(state.value_shift) > 0.25){
                this.lower_statistics = Statistics(-3.5, 3.5);
                this.upper_statistics = Statistics(-3.5, 3.5);
            }
            else {
                this.lower_statistics = Statistics(-3, 3);
                this.upper_statistics = Statistics(-3, 3);
            }
            */
            this.lower_statistics = Statistics(-81, 81);
            this.upper_statistics = Statistics(-81, 81);
        }
    }

    int opCmp(in WDLNode!(T, S, C) rhs) const
    {
        float v = value;
        float rv = rhs.value;
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

    void sample()
    {
        float dummy_lower_value, dummy_upper_value;
        sample(dummy_lower_value, dummy_upper_value);
    }

    void sample(out float lower_value, out float upper_value)
    {
        sample(next_tag++, lower_value, upper_value, lower_statistics.lower_bound, lower_statistics.upper_bound);
    }

    void sample(ulong tag, out float lower_value, out float upper_value, float alpha, float beta)
    {
        if (this.tag == tag && !broken){
            lower_value = this.lower_value;
            upper_value = this.upper_value;
            return;
        }
        this.tag = tag;
        if (tag % 100 == 99){
            sort(children);
        }
        if (this.is_final){
            this.lower_value = lower_value = lower_statistics.lower_bound;
            this.upper_value = upper_value = upper_statistics.lower_bound;
            return;
        }
        if (!children.length){
            auto default_node = DefaultNode!(T, S)(state.state, player_secure, opponent_secure, moves);
            default_node.playout;
            this.lower_value = this.upper_value = lower_value = upper_value = default_node.value;
        }
        else {
            // Turning this stuff off for now.
            alpha = lower_statistics.lower_bound;
            beta = lower_statistics.upper_bound;
            // Don't store samples that are not fully explored.
            broken = alpha > lower_statistics.lower_bound || beta < lower_statistics.upper_bound;
            assert(!broken);
            // Set up absolute loss and win for loops.
            this.lower_value = -float.infinity;
            this.upper_value = float.infinity;
            // Negamaximize score.
            lower_value = -float.infinity;
            upper_value = -float.infinity;
            foreach (child; children){
                float child_lower_value, child_upper_value;
                child.sample(tag, child_lower_value, child_upper_value, -beta, -alpha);
                child_lower_value = -child_lower_value;
                child_upper_value = -child_upper_value;
                if (child_upper_value > lower_value){
                    lower_value = child_upper_value;
                    alpha = max(alpha, lower_value);
                }
                if (child_lower_value > upper_value){
                    upper_value = child_lower_value;
                }
                if (lower_value >= beta){
                    assert(upper_value >= beta);
                    break;
                }
            }
            // Set up values for re-entry
            this.lower_value = lower_value;
            this.upper_value = upper_value;
        }
        if (!broken){
            lower_statistics.add_value(lower_value);
            upper_statistics.add_value(upper_value);
        }
    }

    void sample_to(long count)
    {
        while (lower_statistics.confidence < count){
            sample;
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

        this.lower_statistics.clear;
        this.upper_statistics.clear;

        foreach (parent; parents.byValue){
            parent.invalidate(tag);
        }
    }

    /*
    void playout()
    {
        enum rounds = 40;
        Likelyhood[] sub_priors;
        foreach (i; 0..totalCPUs){
            sub_priors ~= Likelyhood(prior.lower_bound, prior.upper_bound, prior.delta);
        }
        foreach (ref sub_prior; parallel(sub_priors)){
            foreach (i; 0..rounds){
                auto default_node = DefaultNode!(T, S)(state.state, player_secure, opponent_secure, moves);
                default_node.playout;
                sub_prior.add_value(default_node.value);
            }
        }
        foreach (ref sub_prior; sub_priors){
            foreach (i; 0..prior.bins.length){
                prior.bins[i] += sub_prior.bins[i];
            }
            prior.confidence += sub_prior.confidence;
        }
    }

    void refine(){
        HistoryNode!C history = null;
        return refine(history);
    }

    void refine(ref HistoryNode!C history)
    {
        if (is_final){
            return;
        }
        else{
            assert(visits < ulong.max);
            if (visits < 1 || (history !is null && state in history)){
                playout;
            }
            else{
                auto my_history = new HistoryNode!C(state, history);
                auto child = choose_child;
                if (child is null){
                    return;
                }
                child.refine(my_history);
                recalculate_prior;
            }
            visits++;
        }
    }

    void recalculate_prior()
    {
        Likelyhood[] child_priors;

        foreach (child; children){
            child_priors ~= child.prior;
        }

        //this.prior = negamax(child_priors, 0.4 + 0.5 / (1.0 + log(0.1 * visits + 1)));
        this.prior = negamax(child_priors, 0.9);
    }

    bool update_bounds()
    {
        if (is_final){
            // There should be nothing left to do here.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;

        if (children.length){
            float new_lower_bound = -float.infinity;
            float new_upper_bound = -float.infinity;

            foreach (child; children){
                if (-child.upper_bound > new_lower_bound){
                    new_lower_bound = -child.upper_bound;
                }
                if (-child.lower_bound > new_upper_bound){
                    new_upper_bound = -child.lower_bound;
                }
            }

            debug (update_bounds){
                foreach (child; children){
                    writeln("c: ", child.lower_bound, ", ", child.upper_bound);
                }
                writeln(to!int(new_lower_bound));
                writeln(to!int(new_upper_bound));
            }
            statistics.set_bounds(to!int(new_lower_bound), to!int(new_upper_bound));
        }

        return old_lower_bound != lower_bound || old_upper_bound != upper_bound;
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        WDLNode!(T, S, C)[] queue;
        foreach (parent; parents.byValue){
            queue ~= parent;
        }

        while (queue.length){
            auto tree_node = queue.front;
            queue.popFront;
            debug(update_parents) {
                writeln("Updating parents for:");
                writeln(tree_node);
            }
            bool changed = tree_node.update_bounds;
            if (changed){
                foreach (parent; tree_node.parents){
                    queue ~= parent;
                }
            }
        }
    }
    */

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
        WDLNode!(T, S, C) best_child;
        foreach (child; children){
            debug(expand) {
                writeln("expand:child");
                writeln(child);
            }
            double child_value = child.value; //+ exploration_constant * sqrt(log(visits + 1) / (child.visits + 1));
            if (child_value < best_value){
                best_child = child;
                best_value = child_value;
            }
        }
        best_child.expand;
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
                auto child = new WDLNode!(T, S, C)(child_state, node_pool);
                child.parents[state] = this;
                children ~= child;
                if (node_pool !is null){
                    (*node_pool)[child_state] = child;
                }
            }
        }
        invalidate(next_tag++);
        //check_finality(next_tag++);
    }

    void check_finality(ulong tag)
    {
        if (this.tag == tag){
            return;
        }
        this.tag = tag;
        //TODO
    }

    /*
    WDLNode!(T, S, C) best_child()
    {
        if (!children.length){
            make_children;
        }

        WDLNode!(T, S, C) best_child;
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

    override string toString()
    {
        return format(
            "%s\nlower=%s, %s\nupper=%s, %s\nfinal=%s, number of children=%s",
            state._toString(T(), T(), player_secure, opponent_secure),
            lower_statistics.mean, lower_statistics.confidence,
            upper_statistics.mean, upper_statistics.confidence,
            is_final, children.length
        );
    }
}

alias WDLNode8 = WDLNode!(Board8, State8, CanonicalState8);
alias WDLNode11 = WDLNode!(Board11, State11, CanonicalState11);
