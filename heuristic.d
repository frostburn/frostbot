module heuristic;

import std.exception : assumeUnique;
import std.stdio;
import std.file;
import std.string;
import std.math;
import std.algorithm;
import std.range;
import std.random;

import utils;
import board8;
import board11;
import state;
//import ann;
import linalg;

struct Grid
{
    float[] values;

    size_t width;
    size_t height;

    this(size_t width, size_t height)
    {
        this.width = width;
        this.height = height;
        values.length = width * height;
        values[] = 0;
    }

    this(Board8 playing_area, Board8 player, Board8 opponent)
    {
        init!Board8(playing_area, player, opponent);
    }

    void init(T)(in T playing_area,in T player,in T opponent)
    {
        width = playing_area.horizontal_extent;
        height = playing_area.vertical_extent;
        values.length = width * height;
        foreach (y; 0..height){
            foreach(x; 0..width){
                T p = T(x, y);
                if (p & playing_area){
                    if (p & player){
                        values[x + y * width] = 1;
                    }
                    else if (p & opponent){
                        values[x + y * width] = -1;
                    }
                    else{
                        values[x + y * width] = 0;
                    }
                }
                else{
                    values[x + y * width] = float.nan;
                }
            }
        }
    }

    void neighbours(size_t index, out float north, out float west, out float south, out float east)
    {
            if (index >= width){
                north = values[index - width];
                if (north.isNaN){
                    north = 0;
                }
            }
            else{
                north = 0;
            }
            if (index % width > 0){
                west = values[index - 1];
                if (west.isNaN){
                    west = 0;
                }
            }
            else{
                west = 0;
            }
            if (index / width < height - 1){
                south = values[index + width];
                if (south.isNaN){
                    south = 0;
                }
            }
            else{
                south = 0;
            }
            if (index % width != width - 1){
                east = values[index + 1];
                if (east.isNaN){
                    east = 0;
                }
            }
            else{
                east = 0;
            }
    }

    void bouzy_dilate()
    {
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            float sgn_total = sgn(north) + sgn(west) + sgn(south) + sgn(east);
            if (value >= 0 && north >= 0 && west >= 0 && south >= 0 && east >= 0){
                new_values[index] = value + sgn_total;
            }
            else if (value <= 0 && north <= 0 && west <= 0 && south <= 0 && east <= 0){
                new_values[index] = value + sgn_total;
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
    }

    void bouzy_erode()
    {
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            if (value > 0){
                foreach (n; [north, west, south, east]){
                    if (n <= 0){
                        value -= 1;
                    }
                }
                if (value < 0){
                    value = 0;
                }
                new_values[index] = value;
            }
            else if (value < 0){
                foreach (n; [north, west, south, east]){
                    if (n >= 0){
                        value += 1;
                    }
                }
                if (value > 0){
                    value = 0;
                }
                new_values[index] = value;
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
    }

    bool radiate()
    {
        bool changed = false;
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            if (value == 0){
                if ((north > 0 || west > 0 || south > 0 || east > 0) && north >= 0 && west >= 0 && south >= 0 && east >= 0){
                    new_values[index] = 1;
                    changed = true;
                }
                else if ((north < 0 || west < 0 || south < 0 || east < 0) && north <= 0 && west <= 0 && south <= 0 && east <= 0){
                    new_values[index] = -1;
                    changed = true;
                }
                else{
                    new_values[index] = 0;
                }
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
        return changed;
    }

    void bouzy(size_t d=3, size_t e=4)
    {
        foreach (i; 0..d){
            bouzy_dilate;
        }
        foreach (i; 0..e){
            bouzy_erode;
        }
    }

    void divide_by_influence()
    {
        while (radiate) {
        }
    }

    string toString()
    {
        string r;
        foreach (y; 0..height){
            foreach (x; 0..width){
                auto value = values[x + y * width];
                if (value < 0){
                    r ~= "\x1b[34m";
                }
                else if (value > 0){
                    r ~= "\x1b[31m";
                }
                else{
                    r ~= "\x1b[0m";
                }
                if (value.isNaN){
                    r ~= "          ";
                }
                else{
                    r ~= format("%+#g  ", value);
                }
            }
            if (y < height - 1){
                r ~= "\n";
            }
        }
        r ~= "\x1b[0m";
        return r;
    }

    void to_boards(T)(out T player, out T opponent)
    {
        player = T.init;
        opponent = T.init;
        foreach (index, value; values){
            auto x = index % width;
            auto y = index / width;
            if (value > 0){
                player |= T(x, y);
            }
            else if(value < 0){
                opponent |= T(x, y);
            }
        }
    }

    float score()
    {
        float result = 0;
        foreach (value; values){
            if (!value.isNaN){
                result += sgn(value);
            }
        }
        return result;
    }
}

void divide_by_influence(T)(T playing_area, ref T player, ref T opponent)
{
    T temp_player;
    T temp_opponent;

    do{
        temp_player = player;
        temp_opponent = opponent;

        T player_cross = player.cross_unsafe;
        T opponent_cross = opponent.cross_unsafe;
        T territory = ~(player_cross & opponent_cross);

        player |= player_cross & playing_area & territory;
        opponent |= opponent_cross & playing_area & territory;
    } while (player != temp_player || opponent != temp_opponent);
}


/*
static Network8 network_4x4;
static playing_area_4x4 = rectangle8(4, 4);


float heuristic_value(T)(T playing_area, T player, T opponent)
{
    if (playing_area == playing_area_4x4){
        if (network_4x4.input_layer.width == 0){
            network_4x4 = Network8.from_file("networks/4x4_network_6.txt");
        }
        auto state = State!T(playing_area);
        state.player = player;
        state.opponent = opponent;
        return network_4x4.get_score!(State!T)(state);
    }
    float initial_score = (player | player.liberties(playing_area & ~opponent)).popcount - (opponent | opponent.liberties(playing_area & ~player)).popcount;
    T first_line = playing_area.inner_border;
    float first_line_penalty =  (player & first_line).popcount - (opponent & first_line).popcount;
    if (!player && !opponent){
        return 5.0;
    }
    if (!player && opponent.popcount == 1){
        return -5.0;
    }

    auto grid = Grid(playing_area, player, opponent);
    grid.bouzy;
    grid.to_boards(player, opponent);
    divide_by_influence(playing_area, player, opponent);
    return player.popcount - opponent.popcount + 0.4 * (opponent.euler - player.euler) + 0.25 * initial_score - 0.017 * first_line_penalty;
}
*/


static immutable int[Board11] move_to_index9;
static float[] likelyhood9_params;

static this()
{
    int[Board11] temp;
    temp[Board11.init] = 9 * 9;
    foreach (x; 0..9){
        foreach (y; 0..9){
            temp[Board11(x, y)] = x + 9 * y;
        }
    }
    temp.rehash;
    move_to_index9 = assumeUnique(temp);
    likelyhood9_params = cast(float[])read("networks/likelyhood9.dat");
}

void add_ataris9(S)(in S state, in Board11[] moves, ref float[] y)
{
    float point = 0.25;
    foreach (move; moves){
        auto index = move_to_index9[move];
        Board11 chain = move;
        chain.flood_into(state.player | move);
        auto num_libs = chain.liberties(state.playing_area & ~state.opponent).popcount;
        // Self atari.  // TODO: Nakade?
        if (num_libs == 1) {
            y[index] -= point;
        }
        // Escape from atari.
        if (num_libs >= 2){
            if ((chain ^ move).liberties(state.playing_area & ~state.opponent).popcount == 1){
                y[index] += point;
            }
        }
        Board11 o = state.opponent;
        foreach (o_chain; [move.north, move.east, move.west, move.south]){
            o_chain.flood_into(o);
            num_libs = o_chain.liberties(state.playing_area & ~(state.player | move)).popcount;
            // Kill
            if (num_libs == 0){
                y[index] += point;
            }
            // Giving atari
            else if (num_libs == 1){
                y[index] += point;
            }
            o ^= o_chain;
        }
    }
}

float[] move_likelyhoods9(S)(in S state, in Board11[] moves)
{
    float[] p_vec;
    float[] o_vec;
    Board11 p1, p2, p3, o1, o2, o3;
    foreach (chain; state.player.chains){
        auto num_libs = chain.liberties(state.playing_area & ~state.opponent).popcount;
        if (num_libs == 1){
            p1 |= chain;
        }
        else if (num_libs == 2){
            p2 |= chain;
        }
        else {
            p3 |= chain;
        }
    }
    foreach (chain; state.opponent.chains){
        auto num_libs = chain.liberties(state.playing_area & ~state.player).popcount;
        if (num_libs == 1){
            o1 |= chain;
        }
        else if (num_libs == 2){
            o2 |= chain;
        }
        else {
            o3 |= chain;
        }
    }
    foreach (y; 0..9){
        foreach (x; 0..9){
            auto p = Board11(x, y);
            if (p & p1){
                p_vec ~= 0.5;
            }
            else if (p & p2){
                p_vec ~= 0.75;
            }
            else if (p & p3){
                p_vec ~= 1;
            }
            else {
                p_vec ~= 0;
            }
            if (p & o1){
                o_vec ~= 0.5;
            }
            else if (p & o2){
                o_vec ~= 0.75;
            }
            else if (p & o3){
                o_vec ~= 1;
            }
            else {
                o_vec ~= 0;
            }
        }
    }
    auto stones = max(state.player.popcount, state.opponent.popcount);
    float[] w0, b0, w1, b1, w2, b2, w3, b3;
    if (state.ko){
        w0 = likelyhood9_params[0..97200];
        b0 = likelyhood9_params[97200..97800];
        w1 = likelyhood9_params[97800..277800];
        b1 = likelyhood9_params[277800..278100];
        w2 = likelyhood9_params[278100..308100];
        b2 = likelyhood9_params[308100..308200];
        w3 = likelyhood9_params[308200..316400];
        b3 = likelyhood9_params[316400..316482];
    }
    else if (stones < 12){
        w0 = likelyhood9_params[316482..413682];
        b0 = likelyhood9_params[413682..414282];
        w1 = likelyhood9_params[414282..594282];
        b1 = likelyhood9_params[594282..594582];
        w2 = likelyhood9_params[594582..624582];
        b2 = likelyhood9_params[624582..624682];
        w3 = likelyhood9_params[624682..632882];
        b3 = likelyhood9_params[632882..632964];
    }
    else if (stones < 20){
        w0 = likelyhood9_params[632964..730164];
        b0 = likelyhood9_params[730164..730764];
        w1 = likelyhood9_params[730764..910764];
        b1 = likelyhood9_params[910764..911064];
        w2 = likelyhood9_params[911064..941064];
        b2 = likelyhood9_params[941064..941164];
        w3 = likelyhood9_params[941164..949364];
        b3 = likelyhood9_params[949364..949446];
    }
    else {
        w0 = likelyhood9_params[949446..1046646];
        b0 = likelyhood9_params[1046646..1047246];
        w1 = likelyhood9_params[1047246..1227246];
        b1 = likelyhood9_params[1227246..1227546];
        w2 = likelyhood9_params[1227546..1257546];
        b2 = likelyhood9_params[1257546..1257646];
        w3 = likelyhood9_params[1257646..1265846];
        b3 = likelyhood9_params[1265846..1265928];
    }
    float[] x = p_vec ~ o_vec;
    float[] y;
    int n = cast(int)x.length;
    int m = cast(int)w0.length / n;
    y.length = m;
    gemv('N', m, n, 1.0f, w0.ptr, m, x.ptr, 1, 0.0f, y.ptr, 1);
    //y = dot(x, w0);
    y[] += b0[];
    foreach (ref v; y) v = tanh(v);
    n = m;
    m = cast(int)w1.length / n;
    x = y;
    y = new float[m];
    gemv('N', m, n, 1.0f, w1.ptr, m, x.ptr, 1, 0.0f, y.ptr, 1);
    //y = dot(y, w1);
    y[] += b1[];
    foreach (ref v; y) v = tanh(v);
    n = m;
    m = cast(int)w2.length / n;
    x = y;
    y = new float[m];
    gemv('N', m, n, 1.0f, w2.ptr, m, x.ptr, 1, 0.0f, y.ptr, 1);
    //y = dot(y, w2);
    y[] += b2[];
    foreach (ref v; y) v = tanh(v);
    n = m;
    m = cast(int)w3.length / n;
    x = y;
    y = new float[m];
    gemv('N', m, n, 1.0f, w3.ptr, m, x.ptr, 1, 0.0f, y.ptr, 1);
    //y = dot(y, w3);
    y[] += b3[];
    foreach (ref v; y) v = exp(v);

    //add_ataris9(state, moves, y);

    float[] result;
    float sum = 0;
    foreach (move; moves){
        result ~= y[move_to_index9[move]];
        sum += y[move_to_index9[move]];
    }
    result[] /= sum;
    return result;
}


float playout9(State11 state)
{
    while (!state.is_leaf){
        auto moves = state.moves;
        auto children = state.children(moves);
        auto likelyhoods = move_likelyhoods9(state, moves);
        sort!("a[0] > b[0]")(zip(likelyhoods, children));
        // Only pass if it is considered the best move.
        if (children[0].passes){
            // Make sure there are no obvious moves left.
            auto dames = state.player_unconditional.liberties(state.playing_area & ~state.opponent);
            Board11 atari_libs;
            foreach (chain; state.player.chains){
                auto libs = chain.liberties(state.playing_area & ~state.opponent);
                if (libs.popcount == 1){
                    atari_libs |= libs;
                }
            }
            bool found = false;
            auto num_opponent = state.opponent.popcount;
            foreach (child; children){
                bool killed = child.player.popcount < num_opponent;
                if (killed || child.opponent & (dames | atari_libs)){
                    state = child;
                    found = true;
                    break;
                }
            }
            if (!found) {
                state = children[0];
            }
        }
        else {
            float x = uniform01;
            size_t i = 0;
            while (x > likelyhoods[i]){
                x -= likelyhoods[i];
                i += 1;
            }
            if (children[i].passes){
                state = children[i-1];
            }
            else {
                state = children[i];
            }
        }
        state.analyze_unconditional;
    }
    return area_score9(state);
    //return state.liberty_score;
}


float area_score9(State11 state)
{
    auto empty = state.playing_area & ~(state.player, state.opponent);
    foreach (chain; (state.opponent & ~state.player_unconditional).chains){
        auto libs = chain.liberties(state.playing_area & ~state.player);
        if (libs.popcount == 1){
            
        }
    }

    bool[State11] seen;
    while (true){
        state.analyze_unconditional;
        seen[state] = true;
        Board11[] moves;
        foreach (move; state.moves[0..$-1]){
            // Skip self-ataris to preserve seki.
            if ((move | state.player).liberties(state.playing_area & ~state.opponent).popcount != 1){
                moves ~= move;
            }
        }
        auto children = state.children(moves);
        if (!children.length){
            break;
        }
        auto likelyhoods = move_likelyhoods9(state, moves);
        sort!("a[0] > b[0]")(zip(likelyhoods, children));
        bool found = false;
        foreach (child; children){
            if (child !in seen){
                state = child;
                found = true;
                break;
            }
        }
        if (!found){
            break;
        }
        //writeln(state);
    }
    /*
    auto dames = state.player_unconditional.liberties(state.opponent_unconditional);
    dames |= state.opponent_unconditional.liberties(state.player_unconditional);
    dames &= empty;
    float score = (state.player_unconditional & ~dames).popcount - (state.opponent_unconditional & ~dames).popcount;
    if (state.black_to_play){
        return state.value_shift + score;
    }
    else {
        return state.value_shift - score;
    }*/
    //writeln(state);
    return state.liberty_score;
}


class HeuristicNode(T, S)
{
    //TODO: Factor eliminated symmetries into likelyhoods.
    S state;
    float[] likelyhoods;
    float low = -float.infinity;
    float high = float.infinity;
    float low_confidence = 1;
    float high_confidence = 1;
    bool is_leaf = false;
    HeuristicNode!(T, S)[] children;
    HeuristicNode!(T, S)[] parents;

    ulong tag;

    this(S state)
    {
        assert(state.black_to_play);
        this.state = state;
        if (state.is_leaf){
            is_leaf = true;
            low = high = area_score9(state);
            low_confidence = high_confidence = 1;
        }
    }

    invariant
    {
        assert(state.passes <= 2);
        //assert(low <= high);
    }

    void make_children(ref HeuristicNode!(T, S)[S] node_pool)
    {
        assert(!is_leaf);
        if (children.length){
            return;
        }

        auto moves = state.moves;
        auto child_states = state.children(moves);  // Prunes moves
        likelyhoods = move_likelyhoods9(state, moves);
        size_t index = 0;
        size_t[S] seen;
        foreach (child_state; child_states){
            if (!child_state.black_to_play){
                child_state.flip_colors;
            }
            child_state.analyze_unconditional;
            //assert(child_state.black_to_play);
            auto key = child_state;
            key.canonize;
            if (key in seen){
                likelyhoods[seen[key]] += likelyhoods[index];
                likelyhoods[index] = 0;
            }
            else {
                seen[key] = index;
            }
            index += 1;
            if (key in node_pool){
                auto child = node_pool[key];
                children ~= child;
                child.parents ~= this;
            }
            else{
                auto child = new HeuristicNode!(T, S)(child_state);
                node_pool[key] = child;
                children ~= child;
                child.parents ~= this;
            }
        }
        assert(likelyhoods.length == children.length);
        sort!("a[0] > b[0]")(zip(likelyhoods, children));
    }

    bool update_value(float target)
    {
        if (!children.length){
            return false;
        }

        float new_low = -float.infinity;
        float new_high = -float.infinity;
        float new_score = -float.infinity;
        float new_low_confidence = 0;
        float new_high_confidence = 0;
        foreach (e; zip(children, likelyhoods)){
            auto child = e[0];
            auto likelyhood = e[1];
            if (-child.high > new_low){
                new_low = -child.high;
                new_low_confidence = child.high_confidence;
            }
            else if (-child.high == new_low && child.high_confidence > new_low_confidence){
                new_low_confidence = child.high_confidence;
            }
            if (child.low > -float.infinity){
                if (-child.low > new_high){
                    new_high = -child.low;
                }
                new_high_confidence += likelyhood * child.low_confidence;
            }
        }
        if (new_high == -float.infinity){
            new_high = float.infinity;
            new_high_confidence = 1;
        }

        //if (new_high > high){
        //    new_high = high;
        //}
        //assert(new_low <= new_high);

        bool changed = (new_low != low || new_high != high || new_low_confidence != low_confidence || new_high_confidence != high_confidence);
        low = new_low;
        high = new_high;
        low_confidence = new_low_confidence;
        high_confidence = new_high_confidence;

        return changed;
    }

    /*
    HeuristicNode!(T, S) promising_child()
    {
        auto best_promise = -float.infinity;
        HeuristicNode!(T, S) best_child = null;
        foreach (e; zip(likelyhoods, children)){
            auto likelyhood = e[0];
            auto child = e[1];
            if (child.tag == tag){
                continue;
            }
            auto promise = likelyhood * (1 - child.certainty);
            if (promise > best_promise){
                best_promise = promise;
                best_child = child;
            }
        }
        return best_child;
    }
    */

    override string toString()
    {
        return format(
            "%s\nlow=%s @ %s\nhigh=%s @ %s\nnumber of children=%s",
            state,
            low, low_confidence,
            high, high_confidence,
            children.length
        );
    }
}

alias HeuristicNode9 = HeuristicNode!(Board11, State11);


class HeuristicManager(T, S)
{
    HeuristicNode!(T, S) root;
    HeuristicNode!(T, S)[S] node_pool;

    private {
        SetQueue!(HeuristicNode!(T, S)) queue;
    }

    this(S state)
    {
        root = new HeuristicNode!(T, S)(state);
        auto key = state;
        key.canonize;
        node_pool[key] = root;
        queue.insert(root);
    }

    bool expand(float target)
    {
        auto tag = root.tag + 1;
        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.tag == tag){
                continue;
            }
            if (node.update_value(target)){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
            node.tag = tag;
        }
        root.tag = tag;

        root.tag += 1;
        auto node = root;
        bool done = false;
        while (!done){
            node.make_children(node_pool);
            auto best = -float.infinity;
            auto best_child = node;
            done = true;
            foreach (child; node.children){
                if (child.tag == root.tag){
                    continue;
                }
                if (child.is_leaf && node.low == -float.infinity){
                    done = true;
                    break;
                }
                if (child.is_leaf){
                    continue;
                }
                if (-child.low > best || uniform01 < 0.01){
                    done = false;
                    best = -child.low;
                    best_child = child;
                }
            }
            if (done || best_child.is_leaf){
                break;
            }
            node = best_child;
            node.tag = root.tag;
            //writeln(node);
        }
        queue.insertBack(node);
        return true;
    }

    /*
    bool expand_coverage(float target)
    {
        auto tag = root.tag + 1;
        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.tag == tag){
                continue;
            }
            if (node.update_value(target)){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
            node.tag = tag;
        }
        root.tag = tag;

        root.tag += 1;
        auto node = root;
        bool done = false;
        while (!done){
            done = true;
            node.make_children(node_pool);
            foreach (child; node.children){
                if (child.tag == root.tag){
                    continue;
                }
                if (child.coverage < target){
                    node = child;
                    node.tag = root.tag;
                    done = false;
                    break;
                }
            }
            //writeln(node);
        }
        queue.insertBack(node);
        return true;
    }
    */

    /*
    bool expand_certainty(float limit=float.infinity)
    {
        assert(limit >= 1);
        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.update_value){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
        }

        root.tag += 1;
        auto node = root;
        bool done = false;
        while (true){
            if (node.is_leaf){
                break;
            }
            if (!node.children){
                node.make_children(node_pool);
                foreach (child; node.children){
                    if (child.is_leaf){
                        done = true;
                    }
                }
                if (done){
                    break;
                }
            }
            node = node.promising_child;
            if (node is null){
                break;
            }
            node.tag = root.tag;
        }
        if (node is null){
            return false;
        }
        writeln(node);
        if (node.is_leaf){
            foreach (parent; node.parents){
                queue.insertBack(parent);
            }
        }
        else {
            queue.insertBack(node);
        }

        return true;
    }
    */
}


alias HeuristicManager9 = HeuristicManager!(Board11, State11);


/*
unittest
{
    Board8 playing_area = rectangle8(8, 7) & ~ Board8(0, 0);
    Board8 player = Board8(3, 3) | Board8(3, 4) | Board8(3, 5);
    Board8 opponent = Board8(4, 3) | Board8(5, 4);

    auto g = Grid(playing_area, player, opponent);
    g.bouzy;
    g.divide_by_influence;

    assert(g.score == heuristic_value(playing_area, player, opponent));
}
*/