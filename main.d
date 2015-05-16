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
import game_state;
import bounded_state;
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


// Lol "makefile"
// dmd main.d utils.d board8.d board11.d bit_matrix.d state.d polyomino.d defense_state.d defense_search_state.d defense.d eyeshape.d monte_carlo.d heuristic.d fast_math.d ann.d likelyhood.d wdl_node.d direct_mc.d pattern3.d
// -O -release -inline -noboundscheck

void main()
{
    writeln("main");

    BoundedState8[CanonicalState8] empty;
    auto state_pool = &empty;

    auto s = State8(rectangle8(4, 3));
    //s.opponent = Board8(1, 0);
    //s.value_shift = 0.5;
    auto bs = new BoundedState8(CanonicalState8(s), state_pool);

    //bs.full_expand;
    //writeln(bs);
    /*
    bs.expand;
    bs.expand;
    bs.expand;
    bs.expand;
    bs.expand;
    bs.expand;
    bs.expand;
    bs.calculate_current_values;
    writeln(state_pool.length);
    //writeln(bs);

    foreach (b; state_pool.byValue){
        writeln;
        writeln(b);
    }
    */
    int i = 0;
    while(bs.expand){
        i++;
        //writeln(bs);
    }
    writeln(i);
    writeln(state_pool.length);
    writeln(bs);

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
    //s = State8(rectangle8(3, 2));
    //s.value_shift = 0.5;
    /*
    auto cs = CanonicalState8(s);
    //writeln(cs);
    auto gs = new GameState8(cs);
    gs.calculate_minimax_value;
    foreach (c; gs.principal_path!"low"){
        writeln(c);
    }
    */

    /*
    auto s = State8(rectangle8(7, 7));
    writeln(s);
    examine_state_playout(s, true);
    */
}
