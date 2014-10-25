module fast_math;

import std.bitmanip;


float fast_erf(float value)
{
    auto fr = FloatRep(value);

    if (fr.exponent < FloatRep.bias - 4){
        return 1.1269116435581932f * value;
    }
    else if (fr.exponent < FloatRep.bias - 3){
        if (fr.sign){
            return 1.1181476332631481f * value - 0.00054775064344031454f;
        }
        return 0.00054775064344031454f + 1.1181476332631481f * value;
    }
    else if (fr.exponent < FloatRep.bias - 2){
        if (fr.sign){
            return 1.0880814829352246f * value - 0.0043060194344307634f;
        }
        return 0.0043060194344307634f + 1.0880814829352246f * value;
    }
    else if (fr.exponent < FloatRep.bias - 1){
        if (fr.sign){
            return 0.97669395057923847f * value - 0.032152902523427285f;
        }
        return 0.032152902523427285f + 0.97669395057923847f * value;
    }
    else if (fr.exponent < FloatRep.bias){
        uint f = (fr.fraction >> 12);
        fr.fraction = 343931 + (((1842940 - 240 * f) * f) >> 9);
        return fr.value;
    }
    else if (fr.exponent < FloatRep.bias + 1){
        fr.exponent = FloatRep.bias - 1;
        uint f = (fr.fraction >> 12);
        if (f & 1024){
            fr.fraction = 14918708 + (((844349 - 195 * f) * f) >> 9);
        }
        else{
            fr.fraction = 5749565 + (((1655852 - 606 * f) * f) >> 9);
        }
        return fr.value;
    }
    else if (fr.exponent < FloatRep.bias + 2){
        fr.exponent = FloatRep.bias - 1;
        uint f = fr.fraction;
        if (f < 2511360){
            fr.fraction = 8310128 + (f >> 5);
        }
        else{
            fr.fraction = 8388607;
        }
        return fr.value;
    }
    else{
        fr.exponent = FloatRep.bias;
        fr.fraction = 0;
        return fr.value;
    }
}


unittest
{
    import std.mathspecial;

    double max_error = 0.0;
    foreach (i; 0..100000){
        float value = i / 10000.0 - 5.0;
        double fast_value = fast_erf(value);
        double true_value = erf(value);
        double error = fabs(true_value - fast_value);
        if (error > max_error){
            max_error = error;
        }
    }
    assert(max_error < 0.0057129);
}

unittest
{
    uint max_fraction = (1 << FloatRep.fractionBits) - 1;

    FloatRep low_fr;
    low_fr.fraction = max_fraction;
    low_fr.exponent = FloatRep.bias - 5;

    FloatRep high_fr;
    high_fr.fraction = 0;
    high_fr.exponent = FloatRep.bias - 4;

    foreach (i;0..8){
        assert(fast_erf(low_fr.value) <= fast_erf(high_fr.value));
        low_fr.exponent = cast(ubyte)(low_fr.exponent + 1);
        high_fr.exponent = cast(ubyte)(high_fr.exponent + 1);
    }

    low_fr.exponent = FloatRep.bias;
    low_fr.fraction = 4194303;
    high_fr.exponent = FloatRep.bias;
    high_fr.fraction = 4194304;
    assert(fast_erf(low_fr.value) <= fast_erf(high_fr.value));

    low_fr.exponent = FloatRep.bias + 1;
    low_fr.fraction = 2511359;
    high_fr.exponent = FloatRep.bias + 1;
    high_fr.fraction = 2511360;
    assert(fast_erf(low_fr.value) <= fast_erf(high_fr.value));
}