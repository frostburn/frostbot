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
    auto gs = new GameState!Board8(rectangle!Board8(3, 3));
    gs.calculate_minimax_value;
    /*
    foreach (p; gs.principal_path!"high"(20)){
        writeln(p);
        writeln("Dependencies:");
        foreach(dependency; p.dependencies.byKey){
            writeln(dependency);
        }
        writeln("****************");
    }
    */
    writeln(gs);
}
