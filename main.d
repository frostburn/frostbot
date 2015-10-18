import std.stdio;
import std.string;
import std.format;
import std.math;
import std.algorithm;
import std.range;
import std.random;
import std.parallelism;
import std.uni;
static import std.file;
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
import full_search;
//import bounded_state;
//import defense_state;
//import search_state;
//import defense_search_state;
//import defense;
//import eyeshape;
//static import monte_carlo;
import heuristic;
//import fast_math;
//import ann;
import likelyhood;
//import wdl_node;
//import direct_mc;
//import monte_carlo;
import tsumego;

import chess;
import chess_endgame;

static import settings;

// Lol "makefile"
// dmd main.d utils.d board8.d board11.d bit_matrix.d state.d polyomino.d defense_state.d defense_search_state.d defense.d eyeshape.d monte_carlo.d heuristic.d fast_math.d ann.d likelyhood.d wdl_node.d direct_mc.d pattern3.d
// -O -release -inline -noboundscheck


void main()
{
    writeln("main");

    HeuristicNode9[State11] node_pool;
    auto n = new HeuristicNode9(State11(rectangle11(9, 9)));

    n.make_children(node_pool);
    ulong tag = 0;
    float vv = 0;
    foreach (ee; zip(n.children, n.likelyhoods)) {
        ee[0].make_children(node_pool);
        float v = 0;
        foreach (e; zip(ee[0].children, ee[0].likelyhoods)){
            tag += 1;
            auto c = e[0];
            c.tag = tag;
            auto sign = -e[1];
            while (!c.is_leaf) {
                c.make_children(node_pool);
                bool found = false;
                foreach (cc; c.children){
                    if (cc.tag != tag){
                        c = cc;
                        c.tag = tag;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    break;
                }
                sign = -sign;
            }
            v += sign * area_score(c.state);
        }
        writeln(ee[0]);
        writeln(v, " @ ", ee[1]);
        vv -= ee[1] * v;
    }
    writeln(vv);

    /*
    auto s = State11(rectangle11(9, 9));
    foreach (j; 0..100){
        auto children = s.children;
        float[] scores;
        foreach (child; children){
            scores ~= 0;
            foreach (i; 0..1000){
                scores[$-1] += playout(child);
            }
        }
        sort(zip(scores, children));
        if (s.black_to_play){
            s = children[$-1];
        }
        else {
            s = children[0];
        }
        writeln(s);
    }
    */

    /*
    HeuristicNode9[State11] node_pool;

    auto n = new HeuristicNode9(State11(rectangle11(9, 9)));
    while (!n.is_leaf){
        n.make_children(node_pool);
        n = n.children[0];
        writeln(n);
    }
    while (n.parents.length){
        n = n.parents[0];
        n.update_value;
        writeln(n);
        //Thread.sleep(dur!("msecs")(1000));
    }
    */

    /*
    HeuristicNode9[State11] node_pool;
    auto n = new HeuristicNode9(State11(rectangle11(9, 9)));
    while (!n.is_leaf){
        n.make_children(node_pool);
        n = n.children[0];
    }
    */

    /*
    writeln(n);
    writeln(area_score(n.state));
    return;
    */

    /*
    //auto m = new HeuristicManager9(State11(rectangle11(9, 9)));
    auto m = new HeuristicManager9(n.parents[0].state);
    foreach (i; 0..10000){
        m.expand(0.2);
        writeln(i);
        writeln(m.root);
    }

    foreach (child; m.root.children){
        writeln(child.low, ", ", child.high);
    }
    */


    /*
    foreach (k; 0..1){
        auto s = State11(rectangle11(9, 9));

        foreach (i; 0..100){
            auto m = s.moves;
            if (m.length > 1){
                m = m[0..$-1];
            }
            s.children(m);
            auto l = move_likelyhoods9(s, m);

            foreach (ref v; l) v += uniform01!float() * 0.0;

            sort(zip(l,m));

            s.make_move(m[$-1]);
            s.analyze_unconditional;
            //writeln(s);
        }
        writeln(s);
        writeln(s.liberty_score);
    }
    */

    return;

    /*
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;
    auto local_transpositions = &loc_trans;
    */

    // TODO: Japanese rules using graph arrow weights and area control game after two passes.

    /*
    ChessState s = chess_start;
    //writeln(chess_start.children(score));
    //writeln(s);
    while (true){
        examine_chess_playout(s);
    }
    */

    /*
    auto s = ChessState("r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq e6 1 2");
    writeln(s);
    writeln(s.fen);
    writeln(s.canonical_state);
    */


    /*
    auto et = EndgameType("kr_k");
    CanonicalChessState s;
    CanonicalChessState.from_endgame_state(28644, et, s);
    writeln(s);
    auto ee = s.endgame_state(et);
    writeln(ee);
    CanonicalChessState.from_endgame_state(ee, et, s);
    writeln(s);
    return;
    */

    // TODO: unittests for castling endgames

    //8/6p1/8/5P2/4K1k1/8/8/8 b - - 0 1


    //auto t = EndgameType("kpp_k");
    //auto fs = new FullSearch!(EndgameType, ChessNodeValue, CanonicalChessState);

    /*
    fs.initialize(t);
    foreach (st; t.subtypes){
        string filename = settings.CHESS_TABLE_DIR ~ "chess" ~ st.toString ~ ".dat";
        if (std.file.exists(filename)){
            writeln("Reading data for ", st);
            fs.tables[st] = cast(ChessNodeValue[]) std.file.read(filename);
        }
    }
    //fs.reinitialize;
    fs.calculate(true);
    fs.decanonize;
    */

    /*
    string[] fens;
    fens.length = 6;
    float[] ds;
    ds.length = 6;
    string[] hfens;
    hfens.length = 6;
    float[] hds;
    hds.length = 6;
    foreach (st; [EndgameType("kpp_k")]){
        string filename = settings.CHESS_TABLE_DIR ~ "chess" ~ st.toString ~ ".dat";
        if (std.file.exists(filename)){
            writeln("Reading data for ", st);
            fs.tables[st] = cast(ChessNodeValue[]) std.file.read(filename);
        }
        fens[] = "";
        hfens[] = "";
        ds[] = -1;
        hds[] = -1;
        foreach (e, v; fs.tables[st]){
            foreach (i; 0..6){
                if (i <= 4){
                    if (v.low == i - 2 && v.low_distance > ds[i]){
                        ds[i] = v.low_distance;
                        CanonicalChessState cs;
                        CanonicalChessState.from_endgame_state(e, st, cs);
                        fens[i] = ChessState(cs.state).fen;
                    }
                    if (v.high == i - 2 && v.high_distance > hds[i]){
                        hds[i] = v.high_distance;
                        CanonicalChessState cs;
                        CanonicalChessState.from_endgame_state(e, st, cs);
                        hfens[i] = ChessState(cs.state).fen;
                    }
                }
                else {
                    if (v.low == -float.infinity){
                        ds[i] = -2;
                        CanonicalChessState cs;
                        CanonicalChessState.from_endgame_state(e, st, cs);
                        fens[i] = ChessState(cs.state).fen;
                    }
                    if (v.high == float.infinity){
                        hds[i] = -2;
                        CanonicalChessState cs;
                        CanonicalChessState.from_endgame_state(e, st, cs);
                        hfens[i] = ChessState(cs.state).fen;
                    }
                }
            }
        }
        writeln(st);
        writeln(ds);
        writeln(fens);
        writeln(hds);
        writeln(hfens);
        if (st == t){
            foreach (state; fs.principal_path(st, es[4])){
                writeln(state);
            }
        }
        //std.file.write(settings.CHESS_TABLE_DIR ~ "chess" ~ st.toString ~ ".dat", fs.tables[st]);
    }
    */


    /*
    k_k
    [-1, -1, 0, -1, -1]
    ["", "", "3K4/8/8/8/8/8/8/7k w - - 0 1", "", ""]
    [-1, -1, 0, -1, -1]
    ["", "", "3K4/8/8/8/8/8/8/7k w - - 0 1", "", ""]
    kn_k
    [-1, -1, 14, 27, -1]
    ["", "", "k7/8/6N1/3K4/8/8/8/8 w - - 0 1", "8/k7/8/K5N1/8/8/8/8 w - - 0 1", ""]
    [-1, -1, 4, 1, -1]
    ["", "", "7N/8/5k2/8/K7/8/8/8 w - - 0 1", "k1K5/N7/8/8/8/8/8/8 w - - 0 1", ""]
    k_kn
    [-1, 0, 5, -1, -1]
    ["", "K1k5/8/8/1n6/8/8/8/8 w - - 0 1", "n4k2/8/8/3K4/8/8/8/8 w - - 0 1", "8/k7/8/K5N1/8/8/8/8 w - - 0 1", ""]
    [-1, 26, 13, -1, -1]
    ["", "1K1k4/8/8/8/2n5/8/8/8 w - - 0 1", "K7/3k4/1n6/8/8/8/8/8 w - - 0 1", "k1K5/N7/8/8/8/8/8/8 w - - 0 1", ""]
    kb_k
    [-1, -1, 34, 17, -1]
    ["", "K1k5/8/8/1n6/8/8/8/8 w - - 0 1", "K1B5/8/1k6/8/8/8/8/8 w - - 0 1", "4B3/8/8/3K4/8/k7/8/8 w - - 0 1", ""]
    [-1, -1, -1, 1, -1]
    ["", "1K1k4/8/8/8/2n5/8/8/8 w - - 0 1", "K7/3k4/1n6/8/8/8/8/8 w - - 0 1", "k1K5/B7/8/8/8/8/8/8 w - - 0 1", ""]
    k_kb
    [-1, 2, 1, -1, -1]
    ["", "1K6/b7/1k6/8/8/8/8/8 w - - 0 1", "Kb2k3/8/8/8/8/8/8/8 w - - 0 1", "4B3/8/8/3K4/8/k7/8/8 w - - 0 1", ""]
    [-1, 16, 35, -1, -1]
    ["", "1K1bk3/8/8/8/8/8/8/8 w - - 0 1", "k1b5/8/2K5/8/8/8/8/8 w - - 0 1", "k1K5/B7/8/8/8/8/8/8 w - - 0 1", ""]
    kr_k
    [-1, -1, -1, -1, 31]
    ["", "1K6/b7/1k6/8/8/8/8/8 w - - 0 1", "Kb2k3/8/8/8/8/8/8/8 w - - 0 1", "4B3/8/8/3K4/8/k7/8/8 w - - 0 1", "K7/1R6/2k5/8/8/8/8/8 w - - 0 1"]
    [-1, -1, -1, -1, -1]
    ["", "1K1bk3/8/8/8/8/8/8/8 w - - 0 1", "k1b5/8/2K5/8/8/8/8/8 w - - 0 1", "k1K5/B7/8/8/8/8/8/8 w - - 0 1", ""]
    k_kr
    [0, 0, 1, -1, -1]
    ["r1K5/8/2k5/8/8/8/8/8 w - - 0 1", "K1k5/1r6/8/8/8/8/8/8 w - - 0 1", "Kr2k3/8/8/8/8/8/8/8 w - - 0 1", "4B3/8/8/3K4/8/k7/8/8 w - - 0 1", "K7/1R6/2k5/8/8/8/8/8 w - - 0 1"]
    [32, 0, 1, -1, -1]
    ["r7/8/2K5/8/8/8/8/7k w - - 0 1", "K1k5/1r6/8/8/8/8/8/8 w - - 0 1", "Kr2k3/8/8/8/8/8/8/8 w - - 0 1", "k1K5/B7/8/8/8/8/8/8 w - - 0 1", ""]
    kq_k
    [-1, -1, -1, -1, 19]
    ["r1K5/8/2k5/8/8/8/8/8 w - - 0 1", "K1k5/1r6/8/8/8/8/8/8 w - - 0 1", "Kr2k3/8/8/8/8/8/8/8 w - - 0 1", "4B3/8/8/3K4/8/k7/8/8 w - - 0 1", "K7/1Q6/8/8/5k2/8/8/8 w - - 0 1"]
    [-1, -1, -1, -1, -1]
    ["r7/8/2K5/8/8/8/8/7k w - - 0 1", "K1k5/1r6/8/8/8/8/8/8 w - - 0 1", "Kr2k3/8/8/8/8/8/8/8 w - - 0 1", "k1K5/B7/8/8/8/8/8/8 w - - 0 1", ""]
    kp_k
    [-1, 4, 16, 41, 55]
    ["r1K5/8/2k5/8/8/8/8/8 w - - 0 1", "8/K1k5/P7/8/8/8/8/8 w - - 0 1", "1k5K/8/8/8/8/P7/8/8 w - - 0 1", "k7/7K/8/8/8/8/P7/8 w - - 0 1", "8/8/8/6k1/8/7K/1P6/8 w - - 0 1"]
    [-1, 0, 12, 3, -1]
    ["r7/8/2K5/8/8/8/8/7k w - - 0 1", "K1k5/P7/8/8/8/8/8/8 w - - 0 1", "5k1K/8/8/8/8/P7/8/8 w - - 0 1", "8/1Pk5/8/K7/8/8/8/8 w - - 0 1", ""]
    k_kp
    [-1, 4, 13, 1, -1]
    ["r1K5/8/2k5/8/8/8/8/8 w - - 0 1", "8/8/8/8/k7/3K4/1p6/8 w - - 0 1", "8/K5p1/8/8/8/8/k7/8 w - - 0 1", "8/8/8/8/8/1K6/p7/k7 w - - 0 1", "8/8/8/6k1/8/7K/1P6/8 w - - 0 1"]
    [56, 42, 17, 5, -1]
    ["8/6p1/k7/8/K7/8/8/8 w - - 0 1", "k7/7p/1K6/8/8/8/8/8 w - - 0 1", "8/p7/K7/8/8/8/8/7k w - - 0 1", "8/8/8/8/8/p1K5/k7/8 w - - 0 1", ""]
    k_kq
    [0, 0, 1, -1, -1]
    ["q1K5/8/2k5/8/8/8/8/8 w - - 0 1", "2K5/q3k3/8/8/8/8/8/8 w - - 0 1", "Kq2k3/8/8/8/8/8/8/8 w - - 0 1", "8/8/8/8/8/1K6/p7/k7 w - - 0 1", "8/8/8/6k1/8/7K/1P6/8 w - - 0 1"]
    [20, 0, 1, -1, -1]
    ["8/3K4/8/8/8/8/1q6/k7 w - - 0 1", "2K5/q3k3/8/8/8/8/8/8 w - - 0 1", "Kq2k3/8/8/8/8/8/8/8 w - - 0 1", "8/8/8/8/8/p1K5/k7/8 w - - 0 1", ""]
    */
    //get_kings_index_tables;

    /*
    bool[EndgameType] ets;
    foreach(et; EndgameType(2, 1, 0, 0, 0, 0, 0, 0, 0, 0).subtypes){
        ets[et] = true;
    }
    foreach(et; EndgameType(3, 0, 0, 0, 0, 0, 0, 0, 0, 0).subtypes){
        ets[et] = true;
    }
    foreach(et; ets.byKey){
        writeln(et);
    }
    writeln(ets.length);
    */

    /*
    foreach (kp; KingsPosition.KINGS_POSITION_TABLE){
        ulong k1, k2;
        kp.get_boards(k1, k2);
        int ox = kp.opponent & 7;
        int oy = kp.opponent >> 3;
        int px = kp.player & 7;
        int py = kp.player >> 3;
        if (px == 7 - py){
            writeln(on_board(k1, k2));
        }
    }
    */
    /*
    auto fs = new FullSearch!(BoardType8, NodeValue, State8)();

    auto type = BoardType8(rectangle8(4, 4));
    auto s = State8(type.playing_area);
    //s.opponent = Board8(0, 1) | Board8(1, 0);
    //s.player = Board8(2, 0) | Board8(1, 1);
    //s.ko = Board8(0, 0);
    //s.opponent = Board8(1, 0);
    //s.passes = 0;
    //writeln(s);
    auto e = s.endgame_state(type);

    writeln(e);
    writeln(type);
    writeln(State8.from_endgame_state(e, type, s));
    writeln(s);
    */

    /*
    fs.initialize(type);
    fs.calculate(true);

    //std.file.write("go3x3.dat", fs.tables[type]);
    writeln(fs.tables[type][e]);
    */

    /*
    size_t cutoff = 536869000;
    //fs.initialize(type);
    //fs.calculate(true);


    fs.tables[type] = cast(NodeValue[]) std.file.read("go4x4_part1.dat");
    fs.tables[type].length = cutoff;
    fs.tables[type].length = type.size;
    std.file.write("go4x4_part2.dat", fs.tables[type][cutoff..$]);
    //writeln(fs.tables[type].length);

    writeln(fs.tables[type][e]);
    */

    /*
    auto f = File("go3x2.dat", "rb");
    f.seek(e * NodeValue.sizeof);
    NodeValue[] buf;
    buf.length = 1;
    f.rawRead(buf);
    writeln(buf[0]);
    */

    /*
    foreach (ee; 0..fs.tables[type].length){
        if (fs.tables[type][ee].initialized){
            State8.from_endgame_state(ee, type, s);
            writeln(s);
            writeln(fs.tables[type][ee]);
        }
    }
    */

    //writeln(fs.tables[type][4 + 64 * (13 + 64 * (43 + 64 * ))]);

    /*
    NodeValue[][EndgameType] tables;
    size_t[EndgameType] valid;

    foreach (subtype; type.subtypes.byKey){
        writeln(subtype);
        writeln(subtype.size);
        tables[subtype] = [];
        tables[subtype].length = subtype.size;
        valid[subtype] = 0;
    }

    foreach (subtype, table; tables){
        foreach(e; 0..table.length){
            if (CanonicalChessState.from_endgame_state(e, subtype, s)){
                size_t ce = s.endgame_state(subtype);
                table[ce] = NodeValue(-float.infinity, float.infinity, float.infinity, float.infinity);
                valid[subtype] += 1;
            }
        }
    }

    writeln(valid);

    size_t i = 0;
    bool changed = true;
    while (changed) {
        i += 1;
        writeln("Iteration ", i);
        changed = false;
        foreach (subtype, table; tables){
            foreach(e; 0..table.length){
                auto v = table[e];
                if (v.initialized){
                    CanonicalChessState.from_endgame_state(e, subtype, s);
                    float score;
                    auto children = s.children(score);
                    float low = -float.infinity;
                    float high = -float.infinity;
                    float low_distance = float.infinity;
                    float high_distance = -float.infinity;
                    if (children.length){
                        foreach(child; children){
                            EndgameType ct;
                            auto ce = child.endgame_state(ct);
                            auto child_v = tables[ct][ce];
                            if (-child_v.high > low){
                                low = -child_v.high;
                                low_distance = child_v.high_distance;
                            }
                            else if (-child_v.high == low && child_v.high_distance < low_distance){
                                low_distance = child_v.high_distance;
                            }
                            if (-child_v.low > high){
                                high = -child_v.low;
                                high_distance = child_v.low_distance;
                            }
                            else if (-child_v.low == high && child_v.low_distance > high_distance){
                                high_distance = child_v.low_distance;
                            }
                        }
                        low_distance += 1;
                        high_distance += 1;
                    }
                    else {
                        low = high = score;
                        low_distance = high_distance = 0;
                    }
                    //writeln(low, high, low_distance, high_distance);
                    auto new_v = NodeValue(low, high, low_distance, high_distance);
                    if (new_v != v){
                        changed = true;
                    }
                    table[e] = new_v;
                }
            }
        }
    }


    float max_dist = 0;
    foreach(e; 0..tables[type].length){
        auto v = tables[type][e];
        if (v.initialized){
            if (v.low == 2 && v.low_distance > max_dist){
                max_dist = v.low_distance;
                CanonicalChessState.from_endgame_state(e, type, s);
                writeln(s);
                writeln(max_dist);
            }
        }
    }

    //writeln(max_dist);
    */

    /*
    auto e = s.endgame_state("knn_k");

    writeln(table[e]);

    writeln(CanonicalChessState.from_endgame_state("knn_k", e));

    float _;
    s = s.children(_)[0];
    writeln(s);
    writeln(CanonicalChessState.from_endgame_state("knn_k", s.endgame_state("knn_k")));
    */

    /*
    auto n = new GameNode!(ChessMove, CanonicalChessState)(s);

    n.calculate_minimax_values(&ts);
    writeln(n);
    writeln(ts.length);
    */

    /*
    foreach (k, t; ts){
        auto state = k.state;
        //writeln(state);
        //writeln(t);
        if (state.player & state.pawns){
            if (t.low_value != 1){
                writeln(state);
                writeln(t);
            }
            //assert(t.low_value == 1);
        }
    }
    */

    /*
    writeln(h_rays(RANK4 & HFILE, FULL).on_board);

    assert(h_rays(RANK4 & AFILE, FULL) == RANK4);
    assert(h_rays(RANK5 & HFILE, FULL) == RANK5);
    assert(h_rays(RANK5 & (BFILE | HFILE), FULL) == RANK5);
    assert(h_rays((RANK2 | RANK7) & CFILE, FULL) == (RANK2 | RANK7));
    assert(h_rays(RANK6 | RANK7, FULL) == (RANK6 | RANK7));
    assert(h_rays(CFILE, FULL) == FULL);
    */

    /*
    ulong b = 2392384789732987;
    writeln(b.on_board);
    writeln(b.mirror_d.on_board);
    */

    /*
    auto s = State8(rectangle8(7, 5));
    s.player = rectangle8(4, 1).south.east | Board8(1, 2);
    s.opponent = rectangle8(7, 5) ^ (rectangle8(7, 1) | rectangle8(5, 1).south | rectangle8(1, 5) | Board8(1, 2));
    s.opponent_unconditional = s.opponent;
    */
    /*
    auto s = State8(rectangle8(5, 5));
    s.opponent = Board8(2, 2);
    //s.player = Board8(1, 1) | Board8(2, 1);
    //s.opponent = Board8(1, 2) | Board8(2, 2);
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
