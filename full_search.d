import std.conv;
import std.stdio;
import std.string;
import std.math;

alias distance_t = ubyte;

struct NodeValue
{
    private
    {
        byte _low = 1;
        byte _high = -1;
        ubyte _low_distance = distance_t.max;
        ubyte _high_distance = distance_t.max;
    }

    this(float low, float high, float low_distance=float.infinity, float high_distance=float.infinity)
    {
        version (assert){
            assert(low <= high);
            if (low > -float.infinity){
                assert(low_distance < float.infinity);
            }
            if (high < float.infinity){
                assert(high_distance < float.infinity);
            }
        }
        this.low = low;
        this.high = high;
        this.low_distance = low_distance;
        this.high_distance = high_distance;
    }

    bool opEquals(in NodeValue rhs) const pure nothrow @nogc @safe
    {
        return _low == rhs._low && _high == rhs._high && _low_distance == rhs._low_distance && _high_distance == rhs._high_distance;
    }

    bool initialized()
    {
        return _low <= _high || _high == byte.min;
    }

    float low() const @property
    {
        if (_low == byte.min){
            return -float.infinity;
        }
        else {
            return _low;
        }
    }

    float low(float value) @property
    {
        if (value == -float.infinity){
            _low = byte.min;
            return value;
        }
        assert(value > byte.min && value <= byte.max);
        _low = to!byte(value);
        return value;
    }


    float high() const @property
    {
        if (_high == byte.min){
            return float.infinity;
        }
        else {
            return _high;
        }
    }

    float high(float value) @property
    {
        if (value == float.infinity){
            _high = byte.min;
            return value;
        }
        assert(value > byte.min && value <= byte.max);
        _high = to!byte(value);
        return value;
    }


    float low_distance() const @property
    {
        if (_low_distance == distance_t.max){
            return float.infinity;
        }
        return _low_distance;
    }

    float low_distance(float value) @property
    {
        if (value == float.infinity){
            _low_distance = distance_t.max;
            return value;
        }
        assert(value >= 0 && value < distance_t.max);
        _low_distance = to!distance_t(value);
        return value;
    }

    float high_distance() const @property
    {
        if (_high_distance == distance_t.max){
            return float.infinity;
        }
        return _high_distance;
    }

    float high_distance(float value) @property
    {
        if (value == float.infinity){
            _high_distance = distance_t.max;
            return value;
        }
        assert(value >= 0 && value < distance_t.max);
        _high_distance = to!distance_t(value);
        return value;
    }

    string toString()
    {
        return format("NodeValue(%s, %s, %s, %s)", low, high, low_distance, high_distance);
    }
}


class FullSearch(T, V, S)
{
    V[][T] tables;
    size_t valid[T];

    void initialize(T type)
    {
        S s;
        foreach (subtype; type.subtypes){
            tables[subtype] = [];
            tables[subtype].length = subtype.size;
            valid[subtype] = 0;
        }
        foreach (subtype, table; tables){
            foreach(e; 0..table.length){
                if (S.from_endgame_state(e, subtype, s)){
                    auto canonical_e = s.endgame_state(subtype);
                    table[canonical_e] = V(-float.infinity, float.infinity, float.infinity, float.infinity);
                    valid[subtype] += 1;
                }
            }
        }
    }

    void calculate(bool noisy=false)
    {
        S s;
        size_t i = 0;
        bool changed = true;
        while (changed) {
            i += 1;
            if (noisy){
                writeln("Iteration ", i);
            }
            changed = false;
            foreach (subtype, table; tables){
                foreach(e; 0..table.length){
                    auto v = table[e];
                    if (v.initialized){
                        S.from_endgame_state(e, subtype, s);
                        float score;
                        auto children = s.children(score);
                        float low = -float.infinity;
                        float high = -float.infinity;
                        float low_distance = float.infinity;
                        float high_distance = -float.infinity;
                        if (children.length){
                            foreach(child; children){
                                T ct;
                                auto ce = child.endgame_state(ct);
                                auto child_v = tables[ct][ce];
                                assert(child_v.initialized);
                                if (-child_v.high > low){
                                    low = -child_v.high;
                                    low_distance = child_v.high_distance;
                                }
                                else if (-child_v.high == low && child_v.high_distance < low_distance){
                                    low_distance = child_v.high_distance;
                                }
                                if (-child_v.low > high){
                                    high = -child_v.low;
                                    high_distance = child_v.low_distance;
                                }
                                else if (-child_v.low == high && child_v.low_distance > high_distance){
                                    high_distance = child_v.low_distance;
                                }
                            }
                            low_distance += 1;
                            high_distance += 1;
                        }
                        else {
                            low = high = score;
                            low_distance = high_distance = 0;
                        }
                        auto new_v = V(low, high, low_distance, high_distance);
                        assert(new_v.initialized);
                        if (new_v != v){
                            changed = true;
                        }
                        table[e] = new_v;
                    }
                }
            }
        }
    }

    void decanonize()
    {
        S s;
        foreach (subtype, table; tables){
            foreach(e; 0..table.length){
                if (S.from_endgame_state(e, subtype, s)){
                    auto canonical_e = s.endgame_state(subtype);
                    table[e] = table[canonical_e];
                }
            }
        }
    }
}
