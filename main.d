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
//import polyomino;
//import defense_state;
//import game_state;
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

    auto s = State8(rectangle8(7, 7));

    writeln(s);

    examine_state_playout(s, true);
}
