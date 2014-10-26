import std.stdio;
import std.string;
import std.format;
import core.thread;

import utils;
import board8;
import board11;
import bit_matrix;
import state;
import polyomino;
import defense_state;
//import game_state;
//import search_state;
import defense_search_state;
import defense;
import eyeshape;
import monte_carlo;
import heuristic;
import fast_math;
import ann;


void main()
{
    writeln("main");

    File file = File("networks/6x5_network_6.txt", "r");
    auto line = file.readln;
    auto network = Network8.from_string(line);

    auto playing_area = rectangle8(6, 5);
    //auto network = Network8(playing_area, 2);

    tournament(playing_area, network, 9, 10 * 6 * 15 * 2, 0.01, 100, 0.025, 1);
}
