//实现 URP版本 NvWaters.hlsl文件
#ifndef NVWATERS_INCLUDED
#define NVWATERS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

float4 _NvWatersMovement;

CBUFFER_START(UnityPerMaterial)
    sampler2D _AlbedoTex1;
    float4 _AlbedoTex1_ST;
    float4 _AlbedoColor;
    float _AlbedoIntensity;
    float _AlbedoContrast;
    float _SoftFactor;

    float _Shininess;
    float _Glossiness;
    float _Metallic;

    #ifdef EFFECT_ALBEDO2
        sampler2D _AlbedoTex2;
        float _Albedo2Tiling;
        float _Albedo2Flow;
    #endif

    sampler2D _NormalMap1;
    float4 _NormalMap1_ST;
    float _NormalMap1Strength;

    #ifdef EFFECT_NORMALMAP2
        sampler2D _NormalMap2;
        float _NormalMap2Tiling;
        float _NormalMap2Strength;
        float _NormalMap2Flow;
    #endif

    #ifdef EFFECT_MICROWAVE
        float _MicrowaveScale;
        float _MicrowaveStrength;
    #endif

    #ifdef EFFECT_PARALLAX
        float _ParallaxAmount;
        float _ParallaxFlow;
        float _ParallaxNormal2Offset;
        float _ParallaxNoiseGain;
        float _ParallaxNoiseAmplitude;
        float _ParallaxNoiseFrequency;
        float _ParallaxNoiseScale;
        float _ParallaxNoiseLacunarity;
    #endif

    #ifdef EFFECT_REFLECTION
        samplerCUBE _ReflectionCube;
        float4 _ReflectionColor;
        float _ReflectionStrength;
        float _ReflectionSaturation;
        float _ReflectionContrast;
    #endif

    #ifdef EFFECT_MIRROR
        sampler2D _GrabTexture;
        sampler2D _MirrorReflectionTex;
        float4 _MirrorColor;
        float4 _MirrorDepthColor;
        float _WeirdScale;
        float _MirrorFPOW;
        float _MirrorR0;
        float _MirrorSaturation;
        float _MirrorStrength;
        float _MirrorContrast;
        float _MirrorWavePow;
        float _MirrorWaveScale;
        float _MirrorWaveFlow;
        float4 _GrabTexture_TexelSize;
    #endif

    #ifdef EFFECT_FOAM
        float4 _FoamColor;
        float _FoamFlow;
        float _FoamGain;
        float _FoamAmplitude;
        float _FoamFrequency;
        float _FoamScale;
        float _FoamLacunarity;
        float4 _FoamSoft;
    #endif
CBUFFER_END

//定义 Attributes 结构体
struct Attributes
{
    float4 positionOS : POSITION;
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    float4 tangent : TANGENT;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv_AlbedoTex1 : TEXCOORD0;
    float2 uv_NormalMap1 : TEXCOORD1;
    float3 worldRefl : TEXCOORD2;
    float3 worldPos : TEXCOORD3;
    float4 screenPos : TEXCOORD4;
    float eyeDepth : TEXCOORD5;
    float3 viewDir : TEXCOORD6;
};

inline float3 UnityObjectToViewPos(in float3 pos)
{
    return mul(UNITY_MATRIX_V, mul(unity_ObjectToWorld, float4(pos, 1.0))).xyz;
}

Varyings WaterVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;
    output.eyeDepth = -UnityObjectToViewPos(input.vertex).z;
    return output;
}

float Noise(float2 uv, float gain, float amplitude, float frequency, float scale, float lacunarity, float octaves)
{
    float result;
    float frequencyL = frequency;
    float amplitudeL = amplitude;
    uv = uv * scale;
    for (int i = 0; i < octaves; i++)
    {
        float2 i = floor(uv * frequencyL);
        float2 f = frac(uv * frequencyL);
        float2 t = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
        float2 a = i + float2(0.0, 0.0);
        float2 b = i + float2(1.0, 0.0);
        float2 c = i + float2(0.0, 1.0);
        float2 d = i + float2(1.0, 1.0);
        a = -1.0 + 2.0 * frac(sin(float2(dot(a, float2(127.1, 311.7)), dot(a, float2(269.5, 183.3)))) * 43758.5453123);
        b = -1.0 + 2.0 * frac(sin(float2(dot(b, float2(127.1, 311.7)), dot(b, float2(269.5, 183.3)))) * 43758.5453123);
        c = -1.0 + 2.0 * frac(sin(float2(dot(c, float2(127.1, 311.7)), dot(c, float2(269.5, 183.3)))) * 43758.5453123);
        d = -1.0 + 2.0 * frac(sin(float2(dot(d, float2(127.1, 311.7)), dot(d, float2(269.5, 183.3)))) * 43758.5453123);
        float A = dot(a, f - float2(0.0, 0.0));
        float B = dot(b, f - float2(1.0, 0.0));
        float C = dot(c, f - float2(0.0, 1.0));
        float D = dot(d, f - float2(1.0, 1.0));
        float noise = (lerp(lerp(A, B, t.x), lerp(C, D, t.x), t.y));
        result = amplitudeL * noise;
        frequencyL *= lacunarity;
        amplitudeL *= gain;
    }
    return result * 0.5 + 0.5;
}

#ifdef EFFECT_PARALLAX
    inline float2 ParallaxOffset( half h, half height, half3 viewDir )
    {
        h = h * height - height/2.0;
        float3 v = normalize(viewDir);
        v.z += 0.42;
        return h * (v.xy / v.z);
    }

    float2 OffsetParallax(Varyings IN)
    {
        float2 uvnh = IN.worldPos.xz;
        uvnh += float2(_NvWatersMovement.z, _NvWatersMovement.w) * _ParallaxFlow;
        float nh = Noise(uvnh, _ParallaxNoiseGain, _ParallaxNoiseAmplitude, _ParallaxNoiseFrequency * 0.1, _ParallaxNoiseScale * 0.1, _ParallaxNoiseLacunarity, 3);
        return ParallaxOffset(nh, _ParallaxAmount, IN.viewDir);
    }
#endif

#ifdef EFFECT_REFLECTION
    float3 SpecularReflection(Varyings IN, float4 albedo, float3 normal)
    {
        float4 reflcol = texCUBE(_ReflectionCube, WorldReflectionVector(IN, normal));
        reflcol *= albedo.a;
        reflcol *= _ReflectionStrength;
        float LumRef = dot(reflcol, float3(0.2126, 0.7152, 0.0722));
        float3 reflcolL = lerp(LumRef.xxx, reflcol, _ReflectionSaturation);
        reflcolL = ((reflcolL - 0.5) * _ReflectionContrast + 0.5);
        return reflcolL * _ReflectionColor.rgb;
    }
#endif

#ifdef EFFECT_MIRROR
    float4 MirrorReflection(Varyings IN, float3 normal)
    {
        IN.screenPos.xy = normal * _GrabTexture_TexelSize.xy * IN.screenPos.z + IN.screenPos.xy;
        float nvwxz = _NvWatersMovement.z * _MirrorWaveFlow * 10;
        IN.screenPos.x += sin((nvwxz + IN.screenPos.y) * _MirrorWaveScale) * _MirrorWavePow * 0.1;
        half4 reflcol = tex2Dproj(_MirrorReflectionTex, IN.screenPos);
        reflcol *= _MirrorStrength;
        float LumRef = dot(reflcol, float3(0.2126, 0.7152, 0.0722));
        reflcol.rgb = lerp(LumRef.xxx, reflcol, _MirrorSaturation);
        reflcol.rgb = ((reflcol.rgb - 0.5) * _MirrorContrast + 0.5);
        reflcol *= _MirrorColor;
        float3 refrColor = tex2Dproj(_GrabTexture, IN.screenPos);
        refrColor = _MirrorDepthColor * refrColor;
        half fresnel = saturate(1.0 - dot(normal, normalize(IN.viewDir)));
        fresnel = pow(fresnel, _MirrorFPOW);
        fresnel = _MirrorR0 + (1.0 - _MirrorR0) * fresnel;
        return reflcol * fresnel + half4(refrColor.xyz, 1.0) * (1.0 - fresnel);
    }
#endif

float SoftFade(Varyings IN, float value, float softf)
{
    float rawZ = SampleSceneDepth(IN.screenPos + value);
    return saturate(softf * (LinearEyeDepth(rawZ, _ZBufferParams) - IN.eyeDepth));
}

float SoftFactor(Varyings IN)
{
    return _AlbedoColor.a * SoftFade(IN, 0.0001, _SoftFactor);
}

#ifdef EFFECT_FOAM
    float3 FoamFactor(Varyings IN, float3 albedo, float2 uv)
    {
        float2 foamuv = IN.worldPos.xz;
        foamuv += float2(_NvWatersMovement.z, _NvWatersMovement.w) * - _FoamFlow;
        float foamuvnoi = Noise(foamuv, _FoamGain, _FoamAmplitude, _FoamFrequency, _FoamScale, _FoamLacunarity, 3);
        float fade = pow(SoftFade(IN, foamuvnoi, _FoamSoft.x), _FoamSoft.z);
        float3 foam = tex2D(_AlbedoTex1, uv) * _FoamColor;
        if(fade > _FoamSoft.y)
        {
            albedo = lerp(foam, albedo, fade);
        }
        else
        {
            albedo = lerp(albedo, foam, fade);
        }
        return albedo;
    }
#endif

#endif