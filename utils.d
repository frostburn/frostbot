module utils;

import std.container;

int popcount(ulong b) pure nothrow @nogc @safe
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
    int popcnt (ulong bits) pure nothrow @nogc @safe
    {
        return bits.popcount;
    }
}
else{
    int popcnt (ulong bits) pure nothrow @nogc @trusted
    {
        asm pure nothrow @nogc @trusted
        {
           mov RAX, bits ;
           popcnt RAX, RAX ;
        }
    }
}


ulong right_shift(ulong b, int amount) pure nothrow @nogc @safe
{
    if (amount <= -64 || amount >= 64){
        return 0;
    }
    else if (amount < 0){
        return b << (-amount);
    }
    return b >> amount;
}


immutable int index64[64] = [
    0,  1, 48,  2, 57, 49, 28,  3,
   61, 58, 50, 42, 38, 29, 17,  4,
   62, 55, 59, 36, 53, 51, 43, 22,
   45, 39, 33, 30, 24, 18, 12,  5,
   63, 47, 56, 27, 60, 41, 37, 16,
   54, 35, 52, 21, 44, 32, 23, 11,
   46, 26, 40, 15, 34, 20, 31, 10,
   25, 14, 19,  9, 13,  8,  7,  6
];

/**
 * bitScanForward
 * @author Martin Läuter (1997)
 *         Charles E. Leiserson
 *         Harald Prokop
 *         Keith H. Randall
 * "Using de Bruijn Sequences to Index a 1 in a Computer Word"
 * @param bb bitboard to scan
 * @precondition bb != 0
 * @return index (0..63) of least significant one bit
 */
int bitScanForward(ulong bb) pure nothrow @nogc @safe
{
   enum debruijn64 = 0x03f79d71b4cb0a89UL;
   assert(bb != 0);
   return index64[((bb & -bb) * debruijn64) >> 58];
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


int compare_sorted_lists(T)(in T[] a, in T[] b)
{
    auto a_length = a.length;
    auto b_length = b.length;
    if (a_length < b_length){
        return -1;
    }
    if (a_length > b_length){
        return 1;
    }

    foreach (index, a_element; a){
        T b_element = b[index];
        if (a_element < b_element){
            return -1;
        }
        if (a_element > b_element){
            return 1;
        }
    }
    return 0;
}


int compare_sets(T)(in bool[T] a, in bool[T] b)
{
    auto a_length = a.length;
    auto b_length = b.length;
    if (a_length < b_length){
        return -1;
    }
    if (a_length > b_length){
        return 1;
    }
    T[] a_keys = a.keys;
    T[] b_keys = b.keys;
    a_keys.sort;
    b_keys.sort;
    foreach (index, a_key; a_keys){
        T b_key = b_keys[index];
        if (a_key < b_key){
            return -1;
        }
        if (a_key > b_key){
            return 1;
        }
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


class HistoryNode(T)
{
    T value;
    HistoryNode!T *parent = null;

    this(T value){
        this.value = value;
    }

    this(T value, HistoryNode!T *parent){
        this.value = value;
        this.parent = parent;
    }

    bool opBinaryRight(string op)(in T lhs) const pure nothrow
        if (op == "in")
    {
        if (lhs == value){
            return true;
        }
        if (parent !is null){
            return (*parent).opBinaryRight!"in"(lhs);
        }
        return false;
    }

    size_t length()
    {
        if (parent is null){
            return 1;
        }
        else {
            return (*parent).length + 1;
        }
    }
}


struct SetQueue(T)
{
    DList!T queue;
    bool[T] members;

    size_t insert(T item)
    {
        if (item in members){
            return 0;
        }
        else {
            members[item] = true;
            return queue.insert(item);
        }
    }


    size_t insertBack(T item)
    {
        if (item in members){
            return 0;
        }
        else {
            members[item] = true;
            return queue.insertBack(item);
        }
    }

    T removeFront()
    {
        auto item = queue.front;
        queue.removeFront;
        members.remove(item);
        return item;
    }

    bool empty()
    {
        return queue.empty;
    }
}


unittest
{
    int s = 0;
    auto h = new HistoryNode!int(s);

    int child_s = 1;
    auto child_h = new HistoryNode!int(child_s, &h);

    assert(child_s !in h);
    assert(child_s in child_h);
    assert(s in child_h);
}
