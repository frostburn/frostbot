import std.stdio;

import board8;
import state;
import gamestate;

void main()
{
    //auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    //auto gs = new GameState!Board8(rectangle!Board8(2, 2));
    //gs.calculate_minimax_value(false);
    //writeln(gs);

    /*
    auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    gs.state.player = Board8(1, 0);
    gs.state.opponent = Board8(2, 0);
    */
    auto gs = new GameState!Board8(rectangle!Board8(3, 4));
    gs.calculate_minimax_value(true);
    
    /*
    foreach (p; gs.principal_path!"low"(20)){
        writeln(p);
    }
    */
    writeln(gs);

    /*
    foreach (child; 
        gs.children){
        writeln("Child: ", &child);
        writeln(child);
        foreach (grandchild; child.children){
            writeln("Grandchild: ", &grandchild);
            writeln(grandchild);
        }
    }
    assert(gs.children[0].state == gs.children[$ - 1].children[1].state);
    assert((gs.children[0]) is (gs.children[$ - 1].children[1]));
    */
}
