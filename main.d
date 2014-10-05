import std.stdio;

import board8;

void main()
{
    writeln(get_forage_table);
    auto b = Board8(2398472897889789273UL & Board8.FULL);
    writeln(b);
    b.mirror_v;
    writeln;
    writeln(b);
}
