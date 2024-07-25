uniform float4x4 ViewProj;
uniform float time;
uniform texture2d image;
uniform texture2d tex_interm;
uniform float upixel;
uniform float vpixel;
uniform float rand_seed;
uniform int current_step;
uniform int test1;

// Common parameters for all shaders, as reference. Do not uncomment this (but you can remove it safely).
/*
uniform float time;            // Time since the shader is running. Goes from 0 to 1 for transition effects; goes from 0 to infinity for filter effects
uniform texture2d image;       // Texture of the source (filters only)
uniform texture2d tex_interm;  // Intermediate texture where the previous step will be rendered (for multistep effects)
uniform float upixel;          // Width of a pixel in the UV space
uniform float vpixel;          // Height of a pixel in the UV space
uniform float rand_seed;       // Seed for random functions
uniform int current_step;      // index of current step (for multistep effects)
*/

// Specific parameters of the shader. They must be defined in the meta.json file next to this one.
uniform float font_size;
uniform int coord_mode;
uniform float pixel_u;
uniform float pixel_v;
uniform int pixel_x;
uniform int pixel_y;

//----------------------------------------------------------------------------------------------------------------------
#ifndef _INSIDE_BOX_HLSL
#define _INSIDE_BOX_HLSL
/**
 * Returns true if v is included in the rectangle defined by topLeft (inclusive) and bottomRight (exclusive)
 * Alternative definition : with topLeft.x <= bottomRight.x and topLeft.y <= bottomRight.y,
 *  it returns ( topLeft.x <= v.x < bottomRight.x && topLeft.y <= v.y < bottomRight.y )
 * Behavior on limits is messy if topLeft.x > bottomRight.x or topLeft.y > bottomRight.y
 * @param v coordinates of a point to test
 * @param topLeft coordinates of the top left corner of the rectangle
 * @param bottomRight coordinates of the bottom right corner of the rectangle
 */
bool insideBox(float2 v, float2 topLeft, float2 bottomRight) {
    float2 s = step(topLeft, v) - step(bottomRight, v);
    return s.x * s.y != 0.0;
}

#endif /* _INSIDE_BOX_HLSL */

#ifndef _PRINT_VALUE_HLSL
#define _PRINT_VALUE_HLSL
/* Inspired from https://www.shadertoy.com/view/3lGBDm ; Licensed under CC BY-NC-SA 3.0
    Font extracted with : zcat /usr/share/fonts/X11/misc/4x6.pcf.gz | pcf2bdf
    See : https://github.com/ludolpif/obs-shadertastic-effects/blob/main/utils/x11-bitmap-font-extractor.sh
*/
// int font_width = 4;
// int font_height = 6;
float printValue__digitBin(int x) {
    return (
        x==int('.')?32.0:
        x==int('0')?2454816.0:
        x==int('1')?2302576.0:
        x==int('2')?2441840.0:
        x==int('3')?7611440.0:
        x==int('4')?5600320.0:
        x==int('5')?7418928.0:
        x==int('6')?6370592.0:
        x==int('7')?7610640.0:
        x==int('8')?6628656.0:
        x==int('9')?2450480.0:
        x==int('?')?3416096.0:
        x==int('a')?415072.0:
        x==int('b')?1266992.0:
        x==int('c')?397664.0:
        x==int('d')?4609376.0:
        x==int('e')?152416.0:
        x==int('f')?4354592.0:
        x==int('g')?415299.0:
        x==int('h')?1267024.0:
        x==int('i')?2110064.0:
        x==int('j')?4211779.0:
        x==int('k')?1389904.0:
        x==int('l')?3285616.0:
        x==int('m')?357712.0:
        x==int('n')?218448.0:
        x==int('o')?152864.0:
        x==int('p')?217873.0:
        x==int('q')?415076.0:
        x==int('r')?340240.0:
        x==int('s')?406576.0:
        x==int('t')?2564672.0:
        x==int('u')?349536.0:
        x==int('v')?349472.0:
        x==int('w')?350032.0:
        x==int('x')?336464.0:
        x==int('y')?349763.0:
        x==int('z')?475760.0:
        x==int('-')?28672.0:
        3416096.0
    );
}
/*
    Each magic number represents all bits in a grid of size font_width*font_height
    HLSL functions mostly need floats. IEEE754 single precision floats have 24 bits for mantissa.
    So, maximum font size is 6x4 with this encoding. For more, use double (51 bits) or a proper texture.
    The chosen encoding use exponent = 0, so the mantissa and the standard int encoding are the same.
    Example with '7' : float 7610640.0. Take the int32 encoding of 7610640, as binary :
    7610640 <=> 0000 0000 0111 0100 0010 0001 0001 0000
    Each group of font_width bits is a line of the character, keep only the font_height last lines
    0111
    0100
    0010
    0001
    0001
    0000
    Mirror horizontally
    1110
    0010
    0100
    1000
    1000
    0000
*/

/**
 * Print a numerical value in the rectangle with it top-right at the coordinates uv
 * @param uv coordinates of the top right pixel of the debug area, in UV coordinates
 * @param value numerical value to print
 * @param nbDecimal number of decimals to print
 * @param fontSize size of the font, 1.0 meaning the full height of the image texture
 * @return true if the pixel located at uv is a debug pixel, false otherwise
 * @example
 * // float2(1.0, 0.0) is top right uv coordinate of the image
 * if (printValue(uv, 42.23, float2(1.0, 0.0), 3, 0.2)) {
 *     // current pixel is a debug one, print it as full red
 *     return float4(1.0, 0.0, 0.0, 1.0);
 * }
 * else {
 *     // actual shader code
 * }
 */
bool printValue(float2 uv, float value_to_debug, float2 area_topRight, int nbDecimal, float fontSize) {
    nbDecimal = max(0, nbDecimal);
    if ((uv.y < 0.0) || (uv.y >= 1.0) || (uv.x < 0.0) || (uv.x >= 1.0)) {
        return false;
    }
    int font_width = 4;
    int font_height = 6;

    bool isNegative = (value_to_debug < 0.0);
    bool hasDecimals = (nbDecimal > 0);
    value_to_debug = abs(value_to_debug);
    float log10Value = log2(abs(value_to_debug)) / log2(10.0);
    int biggestIndex = int(max(0.0, floor(max(log10Value, 0.0))));

    float square_height = fontSize / font_height;
    float square_width = square_height * upixel/vpixel;

    float area_height = font_height * square_height;
    float area_width = font_width * square_width * (nbDecimal + (hasDecimals ? 1 : 0) + (1 + biggestIndex) + (isNegative ? 1 : 0));
    float2 area_bottomLeft = area_topRight + float2(-area_width, area_height);

    if (insideBox(uv, area_topRight, area_bottomLeft)) {
        uv -= float2(area_bottomLeft.x, area_topRight.y);
        int square_u = int(uv.x / square_width);
        int square_v = int(uv.y / square_height);

        int digitIndex = square_u / font_width;
        int digit_u = square_u - digitIndex * font_width;

        float digitBin = 0.0;
        if (isNegative) {
            digitIndex--;
        }
        if (isNegative && digitIndex == -1) {
            digitBin = printValue__digitBin(int('-'));
        }
        else if (hasDecimals && digitIndex == biggestIndex + 1) {
            digitBin = printValue__digitBin(int('.'));
        }
        else {
            if (hasDecimals && digitIndex > biggestIndex) {
                digitIndex--;
                value_to_debug = frac( value_to_debug );
            }
            int currentDigitNegativeIndex = digitIndex-biggestIndex;
            float currentDigitFloat = fmod(value_to_debug * pow(10.0, currentDigitNegativeIndex), 10.0);
            int currentDigit;
            if ( (digitIndex == biggestIndex + nbDecimal) && (currentDigitFloat < 9.0) ) {
                currentDigit = int(round(currentDigitFloat));
            }
            else {
                currentDigit = int(currentDigitFloat);
            }
            digitBin = printValue__digitBin('0'+currentDigit);
        }

        return fmod(digitBin / pow(2.0, (font_height-square_v) * font_width + digit_u), 2.0) >= 1.0;
    }

    return false;
}

float4 printRGBA(float2 uv, float4 rgba_pixel_to_debug, float2 area_topRight, int nbDecimal, float fontSize) {
    float4 red  = float4(1.0, 0.0, 0.0, 1.0);
    float4 green= float4(0.0, 1.0, 0.0, 1.0);
    float4 blue = float4(0.0, 0.0, 1.0, 1.0);
    float4 grey = float4(0.5, 0.5, 0.5, 1.0);
    float4 none = float4(0.0, 0.0, 0.0, 0.0);

    float4 value_to_debug = rgba_pixel_to_debug * 255.0;
    float2 area_r = area_topRight;
    float2 area_g = float2(area_topRight.x, area_topRight.y + 1.0*fontSize);
    float2 area_b = float2(area_topRight.x, area_topRight.y + 2.0*fontSize);
    float2 area_a = float2(area_topRight.x, area_topRight.y + 3.0*fontSize);

    if ( printValue(uv, value_to_debug.r, area_r, nbDecimal, fontSize) ) return red;
    if ( printValue(uv, value_to_debug.g, area_g, nbDecimal, fontSize) ) return green;
    if ( printValue(uv, value_to_debug.b, area_b, nbDecimal, fontSize) ) return blue;
    if ( printValue(uv, value_to_debug.a, area_a, nbDecimal, fontSize) ) return grey;
    return none;
}

#define printMat_area(row,col) (area_topRight + float2((col-4.0),row)*nbDecimal*fontSize)
#define printMat_item(row,col) printValue(uv, mat_to_debug[row][col],printMat_area(row,col),nbDecimal,fontSize)
bool printFloat4x4(float2 uv, float4x4 mat_to_debug, float2 area_topRight, int nbDecimal, float fontSize) {
    return
       printMat_item(0,0) || printMat_item(0,1) || printMat_item(0,2) || printMat_item(0,3) ||
       printMat_item(1,0) || printMat_item(1,1) || printMat_item(1,2) || printMat_item(1,3) ||
       printMat_item(2,0) || printMat_item(2,1) || printMat_item(2,2) || printMat_item(2,3) ||
       printMat_item(3,0) || printMat_item(3,1) || printMat_item(3,2) || printMat_item(3,3);
}

#endif /* _PRINT_VALUE_HLSL */
//----------------------------------------------------------------------------------------------------------------------

// These are required objects for the shader to work.
// You don't need to change anything here, unless you know what you are doing
sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertData {
    float2 uv  : TEXCOORD0;
    float4 pos : POSITION;
};

struct FragData {
    float2 uv  : TEXCOORD0;
};

VertData VSDefault(VertData v_in)
{
    VertData vert_out;
    vert_out.uv  = v_in.uv;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    return vert_out;
}

float4 EffectLinear(float2 uv)
{
    float4 red  = float4(1.0,0.0,0.0,1.0);
    float4 cyan = float4(0.0,1.0,1.0,1.0);

    float2 uv_pixel_to_debug = (coord_mode==0)?float2(pixel_u,pixel_v):float2(pixel_x*upixel, pixel_y*vpixel);

    float4 rgba_pixel_to_debug = image.Sample(textureSampler, uv_pixel_to_debug);
    float4 rgba = image.Sample(textureSampler, uv);

    // First example : print a uniform variable with 3 decimals at top right corner of the image
    // (note : you can't print value that depends on pixel shader's uv)
    if ( printValue(uv, font_size, float2(1.0, 0.0), 3, font_size) ) {
        return cyan;
    }
    // Second example : print an RGBA value, note: this one returns a color, not a boolean
    float4 dbg = printRGBA(uv, rgba_pixel_to_debug, float2(1.0, 1.0*font_size), 1, font_size);
    rgba = lerp(rgba, dbg, dbg.a);

    // Display a red 3x3 pixel square around the pixel to debug, preserving the center pixel
    float2 uv_pixel = float2(upixel, vpixel);
    if ( insideBox(uv, uv_pixel_to_debug, uv_pixel_to_debug+uv_pixel ) ) {
        return rgba;
    }
    float2 uv_line_width = uv_pixel * 1.0;
    if ( insideBox(uv, uv_pixel_to_debug-uv_line_width, uv_pixel_to_debug+uv_pixel+uv_line_width) ) {
        return red;
    }

    // Display a zoomed area with a red border and filled with the color value of the pixel to debug
    float2 zoomed_center = (uv_pixel_to_debug - float2(0.5,0.5))/2.0 + float2(0.5, 0.5);
    float2 zoomed_topLeft = zoomed_center - 32.0*uv_pixel;
    float2 zoomed_bottomRight = zoomed_center + 32.0*uv_pixel;
    if ( insideBox(uv, zoomed_topLeft, zoomed_bottomRight) ) {
        return rgba_pixel_to_debug;
    }
    if ( insideBox(uv, zoomed_topLeft-uv_line_width, zoomed_bottomRight+uv_line_width) ) {
        return red;
    }

    return rgba;
}

//----------------------------------------------------------------------------------------------------------------------

// You probably don't want to change anything from this point.

float4 PSEffect(FragData f_in) : TARGET
{
    float4 rgba = EffectLinear(f_in.uv);
    return rgba;
}

technique Draw
{
    pass
    {
        vertex_shader = VSDefault(v_in);
        pixel_shader = PSEffect(f_in);
    }
}
