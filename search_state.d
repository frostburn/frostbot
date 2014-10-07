module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import utils;
import board8;
import state;

interface BaseSearchState(T)
{
    State!T state;
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;
    bool is_leaf;
    BaseSearchState!T[] children;
    BaseSearchState!T parent;

    private
    {
        T[] moves;
    }
}

class SearchState(T) : BaseSearchState!T
{
    T player_unconditional;
    T opponent_unconditional;
}
