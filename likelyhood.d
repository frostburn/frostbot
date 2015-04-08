module likelyhood;

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
import monte_carlo;


struct Likelyhood
{
    double[] bins;
    ulong confidence = 0;
    double delta = 1.0;

    private
    {
        int shift;
    }

    invariant
    {
        foreach (bin; bins){
            assert(!isNaN(bin));
        }
    }

    int lower_bound() @property
    {
        return -shift;
    }

    int upper_bound() @property
    {
        return (cast(int)bins.length) - shift - 1;
    }

    this(int lower_bound, int upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        bins.length = upper_bound - lower_bound + 1;
        bins[] = 0.0;
        shift = -lower_bound;
        if (lower_bound == upper_bound){
            bins[0] = 1.0;
            confidence = ulong.max;
            delta = 0.0;
        }
    }

    this(int lower_bound, int upper_bound, double delta)
    {
        this(lower_bound, upper_bound);
        this.delta = delta;
    }

    void set_bounds(int lower_bound, int upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        double[] new_bins;
        new_bins.length = upper_bound - lower_bound + 1;
        new_bins[] = 0;
        int new_shift = -lower_bound;
        for (int v = lower_bound; v <= upper_bound; v++){
            new_bins[v + new_shift] = get_bin(v);
        }
        bins = new_bins;
        shift = new_shift;
    }

    void adjust(int amount)
    {
        double[] new_bins;
        new_bins.length = bins.length;
        new_bins[] = 0;
        foreach (index, bin; bins){
            new_bins[max(0, min(bins.length - 1, to!int(index) + amount))] += bin;
        }
        bins = new_bins;
    }

    float add_value(float value)
    in
    {
        assert(confidence < ulong.max);
    }
    body
    {
        float index = value + shift;
        if (index < 0){
            index = 0;
        }
        else if (index >= bins.length){
            index = bins.length - 1;
        }
        bins[to!size_t(index)] += delta;
        confidence++;

        return index - shift;
    }

    double get_bin(float value)
    {
        float index = value + shift;
        if (index < 0){
            return 0.0;
        }
        else if (index >= bins.length){
            return 0.0;
        }
        return bins[to!size_t(index)];
    }

    double mean()
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

    void normalize()
    {
        double total = 0.0;
        foreach (bin; bins){
            total += bin;
        }
        if (total == 0){
            foreach (ref bin; bins){
                bin = 1.0 / to!double(bins.length);
            }
            return;
        }
        total = 1.0 / total;
        foreach (ref bin; bins){
            bin *= total;
        }
        delta *= total;
    }

    // Normalizes as a side effect.
    double less_than(double value){
        normalize;
        double mass = 0.0;
        foreach (index, bin; bins){
            if (index < value + shift){
                mass += bin;
            }
        }
        return mass;
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
                double bin_height = (8 * height * bins[x]) / max;
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


// Normalizes as a side effect.
Likelyhood negamax(Likelyhood[] likelyhoods, double codependence=0.0)
{
    int lower_bound = int.max;
    int upper_bound = int.min;
    foreach (likelyhood; likelyhoods){
        lower_bound = min(lower_bound, -likelyhood.upper_bound);
        upper_bound = max(upper_bound, -likelyhood.lower_bound);
    }
    assert(lower_bound <= upper_bound);

    double cdf[];
    cdf.length = upper_bound - lower_bound + 1;
    cdf[] = 1.0;

    foreach (likelyhood; likelyhoods){
        likelyhood.normalize;
        double cumsum = 0.0;
        for (double v = lower_bound; v <= upper_bound; v += 1.0){
            cumsum += likelyhood.get_bin(-v);
            cdf[to!size_t(v - lower_bound)] *= cumsum;
        }
    }

    auto result = Likelyhood(lower_bound, upper_bound);
    double last = 0.0;
    foreach (index, c; cdf){
        c = c ^^ (likelyhoods.length ^^ (-codependence));
        result.bins[index] = c - last;
        last = c;
    }
    result.delta = 1.0 / 1000.0;  // TODO: Calculate confidence.

    lower_bound = int.min;
    foreach (likelyhood; likelyhoods){
        lower_bound = max(lower_bound, -likelyhood.upper_bound);
    }
    result.set_bounds(lower_bound, upper_bound);
    return result;
}

// Normalizes as a side effect.
Likelyhood negamax_root(ref Likelyhood likelyhood, double n, ulong confidence, double codependence=0.0)
{
    double cdf[];
    cdf.length = likelyhood.bins.length;
    likelyhood.normalize;
    n = 1.0 / n;
    double cumsum = 0.0;
    foreach (index, bin; likelyhood.bins){
        cumsum += bin;
        cdf[index] = (cumsum ^^ (n ^^ (1 - codependence)));
    }
    auto result = Likelyhood(-likelyhood.upper_bound, -likelyhood.lower_bound);
    double last = 0.0;
    foreach (index, c; cdf){
        result.bins[$ - 1 - index] = c - last;
        last = c;
    }
    result.confidence = confidence;
    result.delta = 1.0 / to!double(confidence);
    return result;
}


class LikelyhoodNode(T, S, C)
{
    C state;
    T player_secure;
    T opponent_secure;
    Likelyhood prior;
    ulong visits = 0;

    double[] desirabilities;
    LikelyhoodNode!(T, S, C)[] children;
    LikelyhoodNode!(T, S, C)[C] parents;
    LikelyhoodNode!(T, S, C)[C] *node_pool;

    private
    {
        T[] moves;
    }

    int lower_bound() @property
    {
        return prior.lower_bound;
    }

    int upper_bound() @property
    {
        return prior.upper_bound;
    }

    ulong confidence() @property
    {
        return prior.confidence;
    }

    bool is_final() @property
    {
        return lower_bound == upper_bound;
    }

    double value() @property
    {
        return prior.mean;
    }

    this (T playing_area, Likelyhood prior, LikelyhoodNode!(T, S, C)[C] *node_pool=null)
    {
        this(S(playing_area), prior, node_pool);
    }

    this (S state, Likelyhood prior, LikelyhoodNode!(T, S, C)[C] *node_pool=null)
    {
        this(C(state), prior, node_pool);
    }

    this (C state, Likelyhood prior, LikelyhoodNode!(T, S, C)[C] *node_pool=null)
    {
        state.analyze_unconditional(player_secure, opponent_secure);
        auto result = analyze_state_light!(T, C)(state, player_secure, opponent_secure);
        player_secure = result.player_secure;
        opponent_secure = result.opponent_secure;
        this.state = state;
        if (state.is_leaf){
            this.prior = Likelyhood(to!int(result.score), to!int(result.score));
            this.visits = ulong.max;
        }
        else{
            calculate_available_moves(result);
            this.prior = prior;
            this.prior.set_bounds(to!int(result.lower_bound), to!int(result.upper_bound));
            this.node_pool = node_pool;
        }
    }

    void playout()
    {
        enum rounds = 100;
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
            if (visits < 4 || (history !is null && state in history)){
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

        this.prior = negamax(child_priors, 0.4 + 0.5 / (1.0 + log(0.1 * visits + 1)));
    }

    /*
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
        LikelyhoodNode!(T, S, C)[] queue;
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

    LikelyhoodNode!(T, S, C) choose_child()
    {
        if (!children.length){
            make_children;
        }

        double best_value = double.infinity;
        foreach (child; children){
            best_value = min(best_value, child.value);
        }

        enum exploration_constant = 2.0;

        double best_promise = -double.infinity;
        LikelyhoodNode!(T, S, C) promising_child;
        foreach (child, desirability; zip(children, desirabilities)){
            if (child.is_final){
                continue;
            }
            double promise = child.prior.less_than(best_value);
            promise += exploration_constant * sqrt(log(visits + 1) / (child.visits + 1));
            promise += desirability / log(visits + 1);
            if (promise > best_promise){
                best_promise = promise;
                promising_child = child;
            }
        }

        if (best_promise == -double.infinity){
            return children[0];
        }
        else{
            return promising_child;
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
        moves ~= T();
    }

    void make_children()
    {
        auto first_line = state.playing_area.inner_border;
        auto child_states = state.children(moves);
        desirabilities.length = 0;
        foreach (move, child_state; zip(moves, child_states)){
            if (child_state.passes == 1){
                desirabilities ~= -50;
            }
            else if (move & first_line){
                desirabilities ~= -10;
            }
            else {
                desirabilities ~= 0;
            }
            if (node_pool !is null && child_state in *node_pool){
                auto child = (*node_pool)[child_state];
                child.parents[state] = this;
                children ~= child;
            }
            else{
                Likelyhood child_prior = negamax_root(prior, child_states.length, 20, 0.8);
                if (child_state.passes == 1){
                    child_prior.adjust(2);
                }
                if (move & first_line){
                    child_prior.adjust(-1);
                }
                auto child = new LikelyhoodNode!(T, S, C)(child_state, child_prior, node_pool);
                child.parents[state] = this;
                children ~= child;
                if (node_pool !is null){
                    (*node_pool)[child_state] = child;
                }
            }
        }
    }

    LikelyhoodNode!(T, S, C) best_child()
    {
        if (!children.length){
            make_children;
        }

        LikelyhoodNode!(T, S, C) best_child;
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

    override string toString()
    {
        return format(
            "%s\nlower bound=%s, upper_bound=%s, value=%s, visits=%s, final=%s, number of children=%s",
            state._toString(T(), T(), player_secure, opponent_secure),
            lower_bound, upper_bound, value, visits, is_final, children.length
        );
    }
}

alias LikelyhoodNode8 = LikelyhoodNode!(Board8, State8, CanonicalState8);
