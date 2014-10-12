module eyeshape;

import std.stdio;
import std.string;

import board8;


enum ThreeShape {unknown, straight_three, bent_three}


struct ThreeSpace(T)
{
    ThreeShape shape = ThreeShape.unknown;
    T middle;
    T wings;
}


ThreeSpace!T get_three_space(T)(T space)
in
{
    assert(space.popcount == 3);
}
body
{
    if (space.euler != 1){
        return ThreeSpace!T(ThreeShape.unknown, T(), T());
    }
    auto shape = ThreeShape.unknown;
    T temp = space & space.east;
    T middle = temp & temp.west;
    T wings;
    if (middle){  // Horizontal straight three
        shape = ThreeShape.straight_three;
    }
    else{
        if (temp){  // Bent three
            shape = ThreeShape.bent_three;
            if (space & temp.south){
                middle = temp;
            }
            else if(space & temp.north){
                middle = temp;
            }
            else{
                middle = temp.west;
            }
        }
        else{  // Vertical straight three
            shape = ThreeShape.straight_three;
            temp = space & space.north;
            middle = temp & temp.south;
        }
    }

    wings = space & ~middle;
    return ThreeSpace!T(shape, middle, wings);
}


alias ThreeSpace8 = ThreeSpace!Board8;
alias get_three_space8 = get_three_space!Board8;


unittest
{
    enum check_three_space = "
        three_space = get_three_space8(space);

        assert(three_space.shape == shape);
        assert(three_space.middle == middle);
        assert(three_space.wings == wings);
    ";

    enum check_all_transformations = "
        mixin(check_three_space);
        for (int i = 0; i < 3; i++){
            space.rotate;
            middle.rotate;
            wings.rotate;
            mixin(check_three_space);
        }
    ";

    ThreeSpace8 three_space;

    auto space = Board8(0, 0) | Board8(0, 1) | Board8(0, 2);
    auto middle = Board8(0, 1);
    auto wings = space & ~middle;
    auto shape = ThreeShape.straight_three;
    mixin(check_all_transformations);

    space = Board8(0, 0) | Board8(1, 0) | Board8(0, 1);
    middle = Board8(0, 0);
    wings = space & ~middle;
    shape = ThreeShape.bent_three;
    mixin(check_all_transformations);
}


enum FourShape {unknown, straight_four, bent_four, farmers_hat, twisted_four, square_four}


struct FourSpace(T)
{
    FourShape shape = FourShape.unknown;
    T middle;
    T wings;

    string toString(){
        return format("%s\nmiddle:\n%s\nwings\n%s", shape, middle, wings);
    }
}


FourSpace!T get_four_space(T)(T space)
in
{
    assert(space.popcount == 4);
}
body
{
    if (space.euler != 1){
        return FourSpace!T(FourShape.unknown, T(), T());
    }
    auto shape = FourShape.unknown;
    T temp = space & space.east;
    T middle;
    T wings;
    if (temp.popcount == 2){
        middle = temp & temp.west;
        if (space & middle.north){  // North pointing farmer's hat
            shape = FourShape.farmers_hat;
        }
        else if (space & middle.south){  // South pointing farmer's hat
            shape = FourShape.farmers_hat;
        }
        else if (middle){
            if (space & temp.north){
                // . . @
                // @ @ @
                middle = temp;
                shape = FourShape.bent_four;
            }
            else if (space & temp.south){
                // @ @ @
                // . . @
                middle = temp;
                shape = FourShape.bent_four;
            }
            else{
                // @ . .      @ @ @
                // @ @ @  or  @ . .
                middle = temp.west;
                shape = FourShape.bent_four;
            }
        }
        else{
            middle = space & space.south;
            middle |= middle.north;
            if (middle == space){
                shape = FourShape.square_four;
                return FourSpace!T(shape, T(), T());
            }
            shape = FourShape.twisted_four;
        }
    }
    else if(temp.popcount == 3){  // Horizontal straight four
        middle = temp & temp.west;
        shape = FourShape.straight_four;
    }

    temp = space & space.south;
    if (temp.popcount == 2){
        middle = temp & temp.north;
        if (space & middle.west){  // West pointing farmer's hat
            shape = FourShape.farmers_hat;
        }
        else if (space & middle.east){  // East pointing farmer's hat
            shape = FourShape.farmers_hat;
        }
        else if (middle){
            if (space & temp.east){
                // @ .
                // @ .
                // @ @
                middle = temp;
                shape = FourShape.bent_four;
            }
            else if (space & temp.west){
                // . @
                // . @
                // @ @
                middle = temp;
                shape = FourShape.bent_four;
            }
            else{
                // @ @      @ @
                // @ .  or  . @
                // @ .      . @
                middle = temp.north;
                shape = FourShape.bent_four;
            }
        }
        else{
            middle = space & space.east;
            middle |= middle.west;
            if (middle == space){
                shape = FourShape.square_four;
                return FourSpace!T(shape, T(), T());
            }
            shape = FourShape.twisted_four;
        }
    }
    else if(temp.popcount == 3){  // Vertical straight four
        middle = temp & temp.north;
        shape = FourShape.straight_four;
    }

    wings = space & ~middle;
    return FourSpace!T(shape, middle, wings);
}

alias FourSpace8 = FourSpace!Board8;
alias get_four_space8 = get_four_space!Board8;


unittest
{
    enum check_four_space = "
        four_space = get_four_space8(space);

        assert(four_space.shape == shape);
        assert(four_space.middle == middle);
        assert(four_space.wings == wings);
    ";

    enum check_all_transformations = "
        mixin(check_four_space);
        for (int i = 0; i < 3; i++){
            space.rotate;
            middle.rotate;
            wings.rotate;
            mixin(check_four_space);
        }
        space.mirror_v;
        middle.mirror_v;
        wings.mirror_v;
        mixin(check_four_space);
        for (int i = 0; i < 3; i++){
            space.rotate;
            middle.rotate;
            wings.rotate;
            mixin(check_four_space);
        }
    ";

    FourSpace8 four_space;

    auto space = Board8(0, 0) | Board8(0, 1) | Board8(0, 2) | Board8(1, 1);
    auto middle = Board8(0, 1);
    auto wings = space & ~middle;
    auto shape = FourShape.farmers_hat;
    mixin(check_all_transformations);

    space = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(3, 0);
    middle = Board8(1, 0) | Board8(2, 0);
    wings = space & ~middle;
    shape = FourShape.straight_four;
    mixin(check_all_transformations);

    space = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(0, 1);
    middle = Board8(0, 0) | Board8(1, 0);
    wings = space & ~middle;
    shape = FourShape.bent_four;
    mixin(check_all_transformations);

    space = Board8(0, 0) | Board8(1, 0) | Board8(1, 1) | Board8(2, 1);
    middle = Board8(1, 0) | Board8(1, 1);
    wings = space & ~middle;
    shape = FourShape.twisted_four;
    mixin(check_all_transformations);

    space = Board8(0, 0) | Board8(1, 0) | Board8(0, 1) | Board8(1, 1);
    middle = Board8();
    wings = Board8();
    shape = FourShape.square_four;
    mixin(check_all_transformations);
}