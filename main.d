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
//import game_state;
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
//import tsumego;


// Lol "makefile"
// dmd main.d utils.d board8.d board11.d bit_matrix.d state.d polyomino.d defense_state.d defense_search_state.d defense.d eyeshape.d monte_carlo.d heuristic.d fast_math.d ann.d likelyhood.d wdl_node.d direct_mc.d pattern3.d
// -O -release -inline -noboundscheck

void main()
{
    writeln("main");

    HLNode8[CanonicalState8] empty;
    auto node_pool = &empty;

    auto s = State8(rectangle8(4, 3));
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
    //writeln(cs);
    auto gs = new GameState8(cs);
    gs.calculate_minimax_value;
    foreach (c; gs.principal_path!"low"){
        writeln(c);
    }

    GameState8[CanonicalState8] pool;
    void get_all(GameState8 root){
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
