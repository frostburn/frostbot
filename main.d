import std.stdio;
import std.string;
import std.format;
import std.math;
import std.algorithm;
import std.random;
import std.parallelism;
import core.thread;

import utils;
import board8;
import board11;
import bit_matrix;
import state;
import pattern3;
import polyomino;
import hl_node;
import game_node;
import local;
//import bounded_state;
//import defense_state;
//import search_state;
//import defense_search_state;
//import defense;
//import eyeshape;
//static import monte_carlo;
//import heuristic;
//import fast_math;
//import ann;
//import likelyhood;
//import wdl_node;
//import direct_mc;
import tsumego;


// Lol "makefile"
// dmd main.d utils.d board8.d board11.d bit_matrix.d state.d polyomino.d defense_state.d defense_search_state.d defense.d eyeshape.d monte_carlo.d heuristic.d fast_math.d ann.d likelyhood.d wdl_node.d direct_mc.d pattern3.d
// -O -release -inline -noboundscheck


void main()
{
    writeln("main");

    /*
    auto s = State8(rectangle8(4, 4));
    auto c = CompressedState8(s);
    writeln(c);
    */

    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;
    auto local_transpositions = &loc_trans;

    /*
    auto s = State8(rectangle8(7, 5));
    s.player = rectangle8(4, 1).south.east | Board8(1, 2);
    s.opponent = rectangle8(7, 5) ^ (rectangle8(7, 1) | rectangle8(5, 1).south | rectangle8(1, 5) | Board8(1, 2));
    s.opponent_unconditional = s.opponent;
    */
    auto s = State8(rectangle8(4, 4));
    s.player = Board8(1, 1) | Board8(2, 1);
    s.opponent = Board8(1, 2) | Board8(2, 2);
    //s.player = Board8(1, 1) | Board8(2, 2);
    //s.opponent = Board8(2, 1) | Board8(1, 2);

    auto m = new HLManager!(Board8, CompressedState8)(CompressedState8(s), local_transpositions);

    while(m.expand(2000)){
        writeln(m.root);
        writeln(m.node_pool.length);
    }
    writeln(m.root);
    //writeln(m.low_solution);
    //writeln(m.node_pool.length, " nodes explored");

    foreach (i, c; m.principal_path!("high", "high")(40)){
        if (i > 0){
            s = decanonize(s, c.state.state);
            s.analyze_unconditional;
        }
        writeln(s);
    }
    writeln(m.node_pool.length, " nodes explored");

    /*
    auto b = Board8(0, 0);
    b = b.cross(full8).cross(full8).cross(full8);
    auto o = b.liberties(full8) ^ Board8(4, 0) ^ Board8(1, 2);
    b = b.cross(full8);
    auto p = rectangle8(3, 2) ^ Board8(2, 0) ^ Board8(3, 0) ^ Board8(0, 1) ^ Board8(0, 2);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.opponent_unconditional = o;

    auto m = new HLManager8(CanonicalState8(s), transpositions);

    while (m.expand) {
    }
    assert(m.root.low == -15);
    assert(m.root.high == -15);
    */

    /*
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
    */

    /*
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;
    auto local_transpositions = &loc_trans;


    auto s = State8(rectangle8(5, 3));
    s.player = rectangle8(5, 1).south;
    s.opponent_unconditional = rectangle8(5, 1);
    s.opponent = s.opponent_unconditional | Board8(1, 2);

    auto cs = CanonicalState8(s);

    auto m = new HLManager8(cs, transpositions);
    while (m.expand) {
    }
    assert(m.root.low == 5);
    assert(m.root.high == 5);
    assert(m.node_pool.length <= 3);
    */


    /*
    auto s = State8(rectangle8(4, 3));

    auto cs = CanonicalState8(s);
    //auto cs = CanonicalState!Board8(State!Board8(Board8(0x1605UL), Board8(0x180800UL), Board8(0x3c1e0fUL), Board8(0x0UL), true, 1, Board8(0x0UL), Board8(0x0UL), 0));
    //cs = cs.children[$ - 1];
    //writeln(cs);
    auto m = new HLManager8(cs, transpositions);
    while (m.expand(1000)) {
        writeln(m.root.low, ", ", m.root.high);
    }
    foreach (c; m.principal_path!("low", "high")(m.root, 20)){
        writeln(c);
        Board8[] moves;
        float low, high;
        analyze_state(c.state, moves, low, high, transpositions);
        writeln(low, ", ", high);
        foreach (child; c.children){
            writeln(child.low, ", ", child.high, ": ", child.state.passes);
        }
        writeln(c.state.repr);
    }
    //assert(m.root.low == 4);
    //assert(m.root.high == 12);
    writeln(m.node_pool.length);
    /*

    //writeln(r);


    /*


    /*
    writeln("done");
    writeln(m.root);
    foreach(c; m.root.children){
        writeln("child");
        writeln(c);
    }
    writeln(m.node_pool.length);
    */

    /*
    auto s = State8(rectangle8(4, 1));
    auto n = new HLNode8(CanonicalState8(s), node_pool, transpositions);
    while (n.expand) {
    }
    assert(n.low == 4);
    assert(n.high == 4);

    s = State8(rectangle8(5, 1));
    n = new HLNode8(CanonicalState8(s), node_pool, transpositions);
    while (n.expand) {
    }
    assert(n.low == -5);
    assert(n.high == 5);

    s = State8(rectangle8(4, 2));
    n = new HLNode8(CanonicalState8(s), node_pool, transpositions);

    while (n.expand) {
    }
    assert(n.low == 8);
    assert(n.high == 8);

    s = State8(rectangle8(4, 3));
    n = new HLNode8(CanonicalState8(s), node_pool, transpositions);

    while (n.expand) {
    }
    assert(n.low == 4);
    assert(n.high == 12);
    */

    //n.full_expand;
    //writeln(n);

    /*
    foreach (i;0..9){
        auto b = Board11();
        foreach (j;0..5){
            int x = j;
            int y = i - j;
            if (x >= 0 && x < 5 && y >= 0 && y < 5){
                b |= Board11(x, y);
            }
        }
        b |= b.east(5);
        writeln(b);
        writeln(b.repr);
    }
    */

    /*
    auto b = rectangle11(5, 1).east(5);
    foreach (i; 0..5){
        writeln(b);
        writeln(b.repr);
        b |= b.south;
    }
    */

    /*
    auto b = Board11(123881237912738987, 2349237497823847897, true) & square11;
    foreach (i; 0..100000000){
        //b.mirror_d;
        //b.mirror_v;
        b.rotate;
    }
    writeln(b);
    */

    /*
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
    //writeln(n);

    bool[CanonicalState8] seen;
    void check(GameNode8 root)
    {
        if (root.state in seen){
            return;
        }
        seen[root.state] = true;
        Board8 moves;
        float low, high;
        root.state.get_score_bounds(low, high);
        assert(low <= root.low_value);
        assert(root.high_value <= high);
        analyze_state(root.state, moves, low, high, transpositions);
        assert(low <= root.low_value);
        assert(root.high_value <= high);
        foreach (child; root.children){
            check(child);
        }
    }
    check(n);
    writeln(seen.length);
    */

    /*
    auto b = Board8(0, 0);
    b = b.cross(full8).cross(full8).cross(full8);
    auto o = b.liberties(full8) ^ Board8(4, 0) ^ Board8(1, 2);
    b = b.cross(full8);
    auto p = rectangle8(3, 2) ^ Board8(2, 0) ^ Board8(3, 0) ^ Board8(0, 1) ^ Board8(0, 2);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.opponent_unconditional = o;

    auto n = new HLNode8(CanonicalState8(s), node_pool, transpositions);

    while (n.expand) {
    }
    assert(n.low == -15);
    assert(n.high == -15);
    */


    /*
    auto cs = new CornerShape([Piece(0, 0), Piece(0, 1)]);
    foreach (s; cs.shapes_plus_one.byKey){
        writeln(s);
    }
    */

    //writeln(polyominoes!EdgeShape(8).length);

    /*
    foreach (s; polyominoes!EdgeShape(5).byKey){
        writeln(s);
        writeln(s.liberties);
        writeln;
    }
    */

    /*
    auto l = LocalState8(s, 2);

    auto n = new GameNode!(Board8, LocalState8)(l);

    n.calculate_minimax_values;
    //writeln(n);
    foreach (c; n.principal_path!"low"){
        writeln(c);
    }
    */
    /*
    s.player = Board8(1, 1) | Board8(2, 1);
    s.opponent = Board8(1, 2) | Board8(2, 2);
    */

    /*
    auto opponent = rectangle8(5, 1).south;
    auto space = rectangle8(7, 2) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 4);
    auto player = playing_area & ~space;
    //player |= Board8(1, 0);
    auto s = State8(playing_area);
    s.player = player;
    s.player_unconditional = player;
    s.opponent = opponent;
    //s.swap_turns;
    writeln(s);
    */

    /*
    auto h = new HLNode8(CanonicalState8(s), node_pool);

    int i = 0;
    while(h.expand){
        i++;
        writeln(h);
        writeln(node_pool.length);
    }
    writeln(i);
    writeln(node_pool.length);
    writeln(h);
    foreach (c; h.children){
        writeln(c);
    }
    */
    /*
    writeln("Full expansion:");
    h.full_expand;
    writeln(node_pool.length);
    writeln(h);
    foreach (c; h.children){
        writeln(c);
    }
    */
    /*
    foreach (i; 0..4){
        HLNode8[] q;
        foreach (n; *node_pool){
            q ~= n;
        }
        foreach (n; q){
            if (!n.is_leaf){
                n.make_children;
            }
        }
    }
    h.calculate_current_values;
    writeln(node_pool.length);
    foreach (n; *node_pool){
        writeln(n);
    }
    */
    //writeln(h);
    /*
    foreach (b; bs.principal_path!"low"){
        writeln(b);
    }
    */

    /*
    foreach (c; h.children){
        writeln(c);
    }
    writeln;
    */
    //writeln(h.children[1]);
    /*
    foreach (c; h.children[1].children){
        writeln(c);
        writeln;
    }
    */

    /*
    bool[CanonicalState8] uniques;
    foreach (b; state_pool.byValue){
        auto key = b.state;
        key.value_shift = 0;
        uniques[key] = true;
    }
    writeln(uniques.length);
    */
    /*
    abs.make_children;
    auto a = abs.children[1];
    a.calculate_minimax_values;
    writeln(a);
    */

    /*
    abs.calculate_minimax_values;

    writeln(abs);
    foreach (child; abs.children){
        writeln;
        child.calculate_minimax_values;
        writeln(child);
        //ABState8[CanonicalState8] e;
        //auto np = &e;
        //auto c = new ABState8(child.state, np);
        //c.calculate_minimax_values;
        //writeln(c);
        //writeln(child.high_value);
    }
    */


    /*
    auto s = State8(rectangle8(4, 4));
    s.player = Board8(1, 1) | Board8(2, 1);
    s.opponent = Board8(1, 2) | Board8(2, 2);
    s.player_unconditional = s.player;
    s.opponent_unconditional = s.opponent;
    */

    /*
    //s = State8(rectangle8(3, 2));
    //s.value_shift = 0.5;
    auto cs = CanonicalState8(s);
    //cs.clear_ko = true;
    //writeln(cs);
    auto gs = new GameNode8(cs);
    gs.calculate_minimax_value;
    foreach (c; gs.principal_path!"low"){
        writeln(c);
    }
    */

    /*
    GameNode8[CanonicalState8] pool;
    void get_all(GameNode8 root){
        if (root.state !in pool){
            pool[root.state] = root;
            foreach (child; root.children){
                get_all(child);
            }
        }
    }

    get_all(gs);

    foreach (g; pool.byValue){
        float l, u;
        g.state.get_score_bounds(l, u);
        if (l > g.low_value || u < g.high_value){
            writeln(g);
            writeln(l, ", ", u);
            writeln;
        }
    }
    */

    /*
    auto s = State8(rectangle8(7, 7));
    writeln(s);
    examine_state_playout(s, true);
    */
}
