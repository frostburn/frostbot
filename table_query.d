import std.json;
import std.stdio;
import std.string;
import std.format;

import board8;
import state;
import full_search;
static import settings;


string to_coord(int x, int y)
{
    auto xmap = [0: "A", 1: "B", 2: "C", 3: "D", 4: "E", 5: "F", 6: "G", 7: "H"];
    return format("%s%s", xmap[x], y);
}

string[] to_coord_list(T)(T b)
{
    string[] result;
    foreach (y; 0..T.HEIGHT){
        foreach (x; 0..T.WIDTH){
            auto p = T(x, y);
            if (b & p){
                result ~= to_coord(x, y);
            }
        }
    }
    return result;
}

size_t[string] moves(T)(State!T state)
{
    size_t[string] result;
    BoardType!T type;
    if (state.is_leaf){
        return result;
    }
    foreach (y; 0..T.HEIGHT){
        foreach (x; 0..T.WIDTH){
            auto p = T(x, y);
            auto child = state;
            if ((state.playing_area & p) && child.make_move(p)){
                auto endgame = child.endgame_state(type);
                result[to_coord(x, y)] = endgame;
            }
        }
    }
    state.make_move(T());
    auto endgame = state.endgame_state(type);
    result["pass"] = endgame;
    return result;
}

size_t[string] player_edits(T)(State!T state)
{
    size_t[string] result;
    BoardType!T type;
    if (state.is_leaf){
        return result;
    }
    foreach (y; 0..T.HEIGHT){
        foreach (x; 0..T.WIDTH){
            auto p = T(x, y);
            auto child = state;
            if ((state.playing_area & p) && child.make_move(p)){
                child.swap_turns;
                auto endgame = child.endgame_state(type);
                result[to_coord(x, y)] = endgame;
            }
        }
    }
    return result;
}

size_t[string] opponent_edits(T)(State!T state)
{
    size_t[string] result;
    BoardType!T type;
    if (state.is_leaf){
        return result;
    }
    foreach (y; 0..T.HEIGHT){
        foreach (x; 0..T.WIDTH){
            auto p = T(x, y);
            auto child = state;
            child.swap_turns;
            if ((state.playing_area & p) && child.make_move(p)){
                auto endgame = child.endgame_state(type);
                result[to_coord(x, y)] = endgame;
            }
        }
    }
    return result;
}

size_t[string] deletes(T)(State!T state){
    size_t[string] result;
    BoardType!T type;
    foreach (y; 0..T.HEIGHT){
        foreach (x; 0..T.WIDTH){
            auto p = T(x, y);
            if ((state.player | state.opponent) & p){
                auto edit = state;
                edit.ko.clear;
                edit.player &= ~p;
                edit.opponent &= ~p;
                auto endgame = edit.endgame_state(type);
                result[to_coord(x, y)] = endgame;
            }
        }
    }
    return result;
}


NodeValue get_node_value(string endgame_type, size_t e)
{
    string filename = settings.GO_TABLE_DIR ~ "go" ~ endgame_type;
    if (endgame_type == "4x4"){
        size_t cutoff = 400000000;
        if (e < cutoff){
            filename ~= "_part1.dat";
        }
        else {
            e -= cutoff;
            filename ~= "_part2.dat";
        }
    }
    else {
        filename ~= ".dat";
    }
    auto f = File(filename, "rb");
    f.seek(e * NodeValue.sizeof);
    NodeValue[] buf;
    buf.length = 1;
    f.rawRead(buf);
    return buf[0];
}


JSONValue process_go(string endgame_type, string endgame)
{
    auto go_endgame_types = [
        "3x2": BoardType8(rectangle8(3, 2)),
        "3x3": BoardType8(rectangle8(3, 3)),
        "4x1": BoardType8(rectangle8(4, 1)),
        "4x2": BoardType8(rectangle8(4, 2)),
        "4x3": BoardType8(rectangle8(4, 3)),
        "4x4": BoardType8(rectangle8(4, 4)),
        "5x3": BoardType8(rectangle8(5, 3)),
        "goplus": BoardType8(rectangle8(4, 2).south | rectangle8(2, 4).east)
    ];
    JSONValue result = ["status": "error"];
    if (endgame_type !in go_endgame_types){
        result.object["error_message"] = JSONValue("Unknown endgame type");
        return result;
    }
    BoardType8 t = go_endgame_types[endgame_type];
    size_t e;
    try {
        string temp = endgame;
        formattedRead(temp, "%s", &e);
    } catch (std.conv.ConvException) {
        result.object["error_message"] = JSONValue("Invalid endgame string");
        return result;
    }
    if (e >= t.size){
        result.object["error_message"] = JSONValue("Endgame too large");
        return result;
    }
    State8 s;
    if (!State8.from_endgame_state(e, t, s)){
        result["status"] = JSONValue("invalid");
        return result;
    }
    result.object["endgame_type"] = JSONValue(endgame_type);
    result.object["endgame"] = JSONValue(endgame);
    result.object["playing_area"] = JSONValue(to_coord_list(s.playing_area));
    result.object["player"] = JSONValue(to_coord_list(s.player));
    result.object["opponent"] = JSONValue(to_coord_list(s.opponent));
    result.object["ko"] = JSONValue(to_coord_list(s.ko));
    result.object["passes"] = s.passes;

    auto move_map = moves(s);
    result.object["moves"] = JSONValue(move_map);

    result.object["player_edits"] = JSONValue(player_edits(s));
    result.object["opponent_edits"] = JSONValue(opponent_edits(s));
    result.object["deletes"] = JSONValue(deletes(s));

    auto v = get_node_value(endgame_type, e);
    result.object["low"] = v.low;
    result.object["high"] = v.high;
    result.object["low_distance"] = v.low_distance;
    result.object["high_distance"] = v.high_distance;

    string[] strong_low_moves;
    string[] weak_low_moves;
    string[] strong_high_moves;
    string[] weak_high_moves;
    foreach (move, child_e; move_map){
        auto child_v = get_node_value(endgame_type, child_e);
        if (-child_v.high == v.low){
            if (child_v.high_distance == v.low_distance - 1){
                strong_low_moves ~= move;
            }
            else {
                weak_low_moves ~= move;
            }
        }
        if (-child_v.low == v.high){
            if (child_v.low_distance == v.high_distance - 1){
                strong_high_moves ~= move;
            }
            else {
                weak_high_moves ~= move;
            }
        }
    }
    result.object["strong_low_moves"] = JSONValue(strong_low_moves);
    result.object["weak_low_moves"] = JSONValue(weak_low_moves);
    result.object["strong_high_moves"] = JSONValue(strong_high_moves);
    result.object["weak_high_moves"] = JSONValue(weak_high_moves);

    result["status"] = JSONValue("OK");
    return result;
}


void main(string args[])
{
    if (args.length != 4){
        writeln("Incorrect args");
    }
    else {
        JSONValue result;
        auto game_type = args[1];
        auto endgame_type = args[2];
        auto endgame = args[3];
        if (game_type == "go"){
            result = process_go(endgame_type, endgame);
        }
        writeln(result.toString);
    }
}
