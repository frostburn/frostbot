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
//import monte_carlo;
import heuristic;
import fast_math;
import ann;

/*
void print_state(SearchState!Board8 ss, int depth){
    //
    //writeln(ss.player_unconditional);
    //writeln(ss.opponent_unconditional);
    //Board8 b;
    //foreach (move; ss.moves){
    //    b |= move;
    //}
    //writeln(b);
    if (depth <= 0){
        return;
    }
    if (ss.is_leaf && ss.lower_bound != ss.upper_bound){
        writeln(ss.state);
        writeln(ss.lower_bound, ", ", ss.upper_bound);
        writeln("Num children:", ss.children.length);
        foreach (child; ss.children){
            writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
        }
        Thread.sleep(dur!("msecs")(1000));
        writeln;
    }
    foreach (child; ss.children){
        //if ((ss.state.black_to_play && child.lower_bound == ss.lower_bound) || (!ss.state.black_to_play && child.upper_bound == ss.upper_bound))
            print_state(cast(SearchState!Board8)child, depth - 1);
    }
}
*/

/*
void print_path(SearchState8 ss, int depth){
    if (depth <= 0){
        return;
    }
    writeln(ss);
    writeln(ss.player_useless | ss.opponent_useless);
    foreach (child; ss.children){
        writeln(" ", child.lower_bound, ", ", child.upper_bound, ", max=", child.state.black_to_play);
    }
    bool found_one = false;
    foreach (child; ss.children){
        if (-child.lower_bound == ss.upper_bound && -child.upper_bound == ss.lower_bound){
            print_path(cast(SearchState8)child, depth - 1);
            found_one = true;
            break;
        }
    }
    if (!found_one){
        foreach (child; ss.children){
            if (-child.upper_bound == ss.lower_bound){
                print_path(cast(SearchState8)child, depth - 1);
                break;
            }
        }
    }
}
*/

void main()
{
    writeln("main");

    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    Transposition[CanonicalState8] empty2;
    auto transposition_table = &empty2;

    auto s = State8(rectangle8(4, 4));

    auto ss = new SearchState8(s, transposition_table, defense_transposition_table);
    ss.iterative_deepening(1, 36);
    writeln(ss);

    /*
    File file = File("networks/4x4_network_5.txt", "r");
    auto line = file.readln;
    auto network = Network8.from_string(line);
    */
    //writeln(network);
    /*
    //auto state = DefenseState8(rectangle8(4, 4));
    //fight(state, network, network, 0.01, 40, true);

    auto playing_area = rectangle8(4, 4);

    tournament(playing_area, network, 12, 1000, 0.01, 40, 0.01, 4);
    */

    //auto playing_area = rectangle8(4, 4);
    //auto network = Network8(playing_area, 3);

    //tournament(playing_area, network, 12, 2 * 10 * 6 * 15, 0.01, 100, 0.02, 6);

    //Board8 playing_area = rectangle8(4, 4);
    /*
    auto network = Network8(playing_area);
    network.activate(Board8(1, 1), Board8(), 0.01);
    writeln(network.input_layer.layer);
    writeln(network);
    writeln(network.get_sum);
    */
    //tournament(playing_area, 2, 12, 2000, 0.01, 40);

    /*
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    Transposition[CanonicalState8] empty2;
    auto transposition_table = &empty2;

    auto s = State8(rectangle8(4, 4));
    s.make_move(Board8(1, 1));
    s.make_move(Board8(2, 2));
    s.make_move(Board8(1, 2));
    s.make_move(Board8(2, 1));

    auto ss = new SearchState8(s, transposition_table, defense_transposition_table);
    ss.iterative_deepening(1, 36);
    writeln(ss);
    */
    //ss.pc;
    //writeln(ss.children[0].children[0]);
    //ss.children[0].children[0].pc;

    /*
    print_constants;

    auto b = Board11(0, 4) | Board11(0, 5) | Board11(0, 6) | Board11(1, 5) | Board11(2, 5) | Board11(2, 6) | Board11(2, 7) | Board11(2, 8) | Board11(1, 8) | Board11(0, 8);
    auto c = b | Board11(3, 9);
    auto d = Board11(0, 4);
    d.flood_into(c);

    assert(d == b);

    writeln(b);
    writeln(c);
    writeln(d);
    */

    /*
    Board8 playing_area = rectangle8(8, 7) & ~ Board8(0, 0);
    Board8 player = Board8(3, 3) | Board8(3, 4) | Board8(3, 5);
    Board8 opponent = Board8(4, 3) | Board8(5, 4);

    auto g = Grid(playing_area, player, opponent);
    g.bouzy;
    writeln(g);
    writeln;
    g.divide_by_influence;

    writeln(g);
    writeln(g.score);
    writeln(heuristic_value(playing_area, player, opponent));
    */

    /*
    TreeNode8[CanonicalState8] empty;
    auto node_pool = &empty;

    auto t = new TreeNode8(rectangle8(5, 5), node_pool);

    //t.state.state.make_move(Board8(2, 2));
    //t.state.state.canonize;

    while (!t.is_leaf){
        //writeln(t.default_playout_statistics(6000));
        writeln(t.statistics);
        writeln(t);
        foreach (i; 0..30000){
            t.playout;
        }
        foreach (c; t.children){
            //writeln("Child:");
            //writeln(c);
            writeln(c.value, ", ", c.visits);
        }
        t = t.best_child;
    }
    */

    /*
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;


    auto ds = new DefenseSearchState8(rectangle8(4, 3), defense_transposition_table);
    //ss.state.opponent = Board8(1, 0);
    ds.calculate_minimax_value(20);

    ds.ppp;
    */

    /+
    Transposition[DefenseState8] defense_transposition_table;

    foreach (eyespace; eyespaces(4).byKey){
        if (eyespace.space.length == 4){
            auto s = from_eyespace8(eyespace, false, -float.infinity);
            if (s.opponent_targets.length){
                s.opponent_targets[0].outside_liberties = 1;
            }
            auto ds = new DefenseSearchState8(s);
            ds.calculate_minimax_value;
            if (ds.lower_bound == ds.upper_bound){
                //writeln(s);
                //writeln(ds.lower_bound);
            }
            else{
                //writeln(ds);
            }
            /*
            Board8[] creating_moves;
            auto cs = s.children_and_moves(creating_moves);
            foreach (index, c; cs){
                auto cds = new DefenseSearchState8(c);
                cds.calculate_minimax_value;
                writeln(creating_moves[index]);
                writeln(cds.upper_bound);
            }
            */
        }
    }
    +/
}
