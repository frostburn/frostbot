module utils;


uint popcount(ulong b) pure nothrow @nogc @safe
{
     b = (b & 0x5555555555555555UL) + (b >> 1 & 0x5555555555555555UL);
     b = (b & 0x3333333333333333UL) + (b >> 2 & 0x3333333333333333UL);
     b = b + (b >> 4) & 0x0F0F0F0F0F0F0F0FUL;
     b = b + (b >> 8);
     b = b + (b >> 16);
     b = b + (b >> 32) & 0x0000007FUL;

     return cast(uint)b;
}


version(no_popcnt){
    uint popcnt (ulong bits) pure nothrow @nogc @safe
    {
        return bits.popcount;
    }
}
else{
    uint popcnt (ulong bits) pure nothrow @nogc @trusted
    {
        asm {
           mov RAX, bits ;
           popcnt RAX, RAX ;
        }
    }
}


int compare(in ulong a, in ulong b) pure nothrow @nogc @safe
{
    if (a < b){
        return -1;
    }
    if (a > b){
        return 1;
    }
    return 0;
}


bool member_in_list(T)(ref T member, ref T[] list){
    foreach (list_member; list){
        if (member is list_member){
            return true;
        }
    }
    return false;
}

/// PowerSet implementation by bearophile @ http://forum.dlang.org/
struct PowerSet(T) {
     T[] items;
     int opApply(int delegate(ref T[]) dg) {
         int result;
         T[] res;
         T[30] buf;
         if (!items.length) {
             result = dg(res);
         } else {
             outer:
             foreach (opt; [items[0..1], []]) {
                 buf[0 .. opt.length] = opt[];
                 foreach (r; PowerSet(items[1..$])) {
                     buf[opt.length .. opt.length + r.length] = r[];
                     res = buf[0 .. (opt.length + r.length)];
                     result = dg(res);
                     if (result) break outer;
                 }
             }
         }
         return result;
     }
}
