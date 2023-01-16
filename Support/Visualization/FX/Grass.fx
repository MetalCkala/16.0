float4x4 World;
float4x4 ViewProjection;

// Lighting parameters.
float3 DirLight0Direction;
float3 DirLight0DiffuseColor = 0.8;
float3 AmbientLightColor = 0.4;

float3 EyePosition;

// Parameters controlling the wind effect.
float3 WindDirection = float3(1, 0, 0);
float WindWaveSize = 0.1;
float WindRandomness = 1;
float WindSpeed = 1;
float WindAmount = 0.1;
float gTimer;

texture BasicTexture;

sampler BasicTextureSampler = sampler_state
{
    Texture = (BasicTexture);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    
    AddressU = Clamp;
    AddressV = Clamp;
};

texture SliceTexture;

sampler SliceTextureSampler = sampler_state
{
    Texture = (SliceTexture);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    
    AddressU = Wrap;
    AddressV = Wrap;
};

texture ThresholdTexture;

sampler ThresholdTextureSampler = sampler_state
{
    Texture = (ThresholdTexture);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    
    AddressU = Wrap;
    AddressV = Wrap;
};

texture NormalHeightTexture;

sampler NormalHeightTextureSampler = sampler_state
{
    Texture = (NormalHeightTexture);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    
    AddressU = Wrap;
    AddressV = Wrap;
};

float4x4 DensityMatrix;
float gAvgHeight = 0.1;
float gMinGeom = 20.0;
float gMaxGeom = 25.0;
float gTextureScale = 1.0;

texture DensityMap;

sampler DensityMapSampler = sampler_state
{
    Texture = (DensityMap);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VS_INPUT
{
    float3 Position     : POSITION0;
    float3 Normal       : NORMAL0;
    float2 TexCoord     : TEXCOORD0;
    float  dth          : BLENDWEIGHT0;
};

struct VS_OUTPUT
{
    float4 Position     : POSITION0;
    float3 Color        : COLOR0;
    float  dth          : COLOR1;
    float2 TexCoord     : TEXCOORD0;
    float2 Density      : TEXCOORD1;
    float  Distance     : TEXCOORD2;
};

struct VSH_INPUT
{
    float3 Position     : POSITION0;
    float3 Normal       : NORMAL0;
};

struct VSH_OUTPUT
{
    float4 Position     : POSITION0;
    float2 TexCoord     : TEXCOORD0;
    float3 vLightTS     : TEXCOORD1;
    float2 Density      : TEXCOORD2;
    float3 vPositionWS  : TEXCOORD3;
};

struct VST_OUTPUT
{
    float4 Position     : POSITION0;
    float2 TexCoord     : TEXCOORD0;
    float  dth          : COLOR1;
};

VS_OUTPUT ComputeCommonVertexShader(VS_INPUT input, float4x4 world)
{
    VS_OUTPUT output;
    
    float4 vPositionWS = mul(float4(input.Position, 1), world);
    
    float2 tc = mul(vPositionWS, DensityMatrix).xy;
    output.Density = tc;
    
    float waveOffset = dot(vPositionWS, WindDirection) * WindWaveSize;
    float wind = sin(gTimer * WindSpeed + waveOffset) * WindAmount;
    wind *= input.Position.z;
    
    vPositionWS.xyz += WindDirection * wind;
    
    output.Position = mul(vPositionWS, ViewProjection);
    output.TexCoord = input.TexCoord;
    output.dth = input.dth;
    float3 vd = EyePosition - vPositionWS.xyz;
    output.Distance = length(vd);
    
    float3 N = normalize(mul(input.Normal, world));
    N *= sign(dot(N, normalize(vd)));
    float3 L = -DirLight0Direction;
    float3 Id = DirLight0DiffuseColor;
    float3 Ia = AmbientLightColor;
    float Ao = input.Position.z / gAvgHeight;

    output.Color = Ia * Ao + (saturate(dot(N, L)) + 0.3 * saturate(dot(-N, L))) * Id;
    
    return output;
}

VS_OUTPUT VertexShaderFunction(VS_INPUT input)
{
    return ComputeCommonVertexShader(input, World);
}

VSH_OUTPUT ComputeCommonVertexHorizontalShader(VSH_INPUT input)
{
    VSH_OUTPUT output;
    
    float4 vPositionWS = mul(float4(input.Position, 1), World);
    vPositionWS.z += gAvgHeight;

    output.Position = mul(vPositionWS, ViewProjection);
    output.vPositionWS = vPositionWS;

    float2 tc = mul(vPositionWS, DensityMatrix);
    output.Density = tc;
    output.TexCoord = input.Position.xy * gTextureScale;

    float3 vNormalWS = mul(input.Normal, (float3x3)World);
    float3 vTangentWS = mul(float3(1, 0, 0), (float3x3)World);
    float3 vBinormalWS = cross(vNormalWS, vTangentWS);

    vNormalWS = normalize(vNormalWS);
    vBinormalWS = normalize(vBinormalWS);
    vTangentWS = cross(vBinormalWS, vNormalWS);

    float3x3 mWorldToTangent = float3x3(vTangentWS, vBinormalWS, vNormalWS);

    float3 vLightWS = -DirLight0Direction;
    output.vLightTS = normalize(mul(mWorldToTangent, vLightWS));
    
    return output;
}

VST_OUTPUT RenderTextureVertexShader(VS_INPUT input)
{
    VST_OUTPUT output;
    
    float4 vPositionWS = mul(float4(input.Position, 1), World);
    output.Position = mul(vPositionWS, ViewProjection);
    output.TexCoord = input.TexCoord;
    output.dth = input.dth;
    
    return output;
}

float4 PixelShaderFunction(VS_OUTPUT input) : COLOR0
{
    float ld = tex2D(DensityMapSampler, input.Density).r;
    float dth = input.dth;
    clip(ld - dth - 0.01);

    float4 result = tex2D(BasicTextureSampler, input.TexCoord);
    clip(result.a - 0.666);

    float modulation = saturate(-dth + 0.1) * 10.0;

    result.rgb *= input.Color * float3(modulation * 1.5 + 1, modulation + 1, modulation + 1);
    
    float distance = input.Distance;
    float whs = saturate((distance - gMinGeom) / (gMaxGeom - gMinGeom));
    float wmax = 0.05;
    float w0 = 0.01;
    float w = wmax * (w0 + (1 - w0) * (1 - abs(2 * whs - 1)));
    float opacity = saturate((dth - (whs - w) * ld) / (2 * w * ld));
    result.a *= opacity;

    clip(result.a - 0.01);
    return result;
}

float4 PixelShaderHorizontalFunction(VSH_OUTPUT input) : COLOR0
{
    float ld = tex2D(DensityMapSampler, input.Density).r;
    float dth = tex2D(ThresholdTextureSampler, input.TexCoord).r;

    float4 result = tex2D(SliceTextureSampler, input.TexCoord);
 
    float distance = length(input.vPositionWS - EyePosition);
    float whs = saturate((distance - gMinGeom) / (gMaxGeom - gMinGeom));
    float wmax = 0.05;
    float w0 = 0.01;
    float w = wmax * (w0 + (1 - w0) * (1 - abs(2 * whs - 1)));
    float opacity = saturate(((whs + w) * ld - dth) / (2 * w * ld));
    result.a *= opacity;
    clip(result.a - 0.01);

    float3 vLightTS = normalize(input.vLightTS);
    float3 vNormalTS = float3(0, 0, 1);
    
    float3 Id = DirLight0DiffuseColor;
    float3 Ia = AmbientLightColor;
    float Ao = 1;

    result.rgb *= Ia * Ao + saturate(dot(vNormalTS, vLightTS)) * Id;
    
    return result;
}

float4 PixelShaderRenderTargetFunction(VST_OUTPUT input) : COLOR0
{
    float4 result = tex2D(BasicTextureSampler, input.TexCoord);
    float modulation = saturate(-input.dth + 0.1) * 10.0;
    result.rgb *= float3(modulation * 1.5 + 1, modulation + 1, modulation + 1);
    return result;
}

float4 PixelShaderRenderThresholdFunction(VST_OUTPUT input) : COLOR0
{
    float4 diffuse = tex2D(BasicTextureSampler, input.TexCoord);
    clip(diffuse.a - 0.1);
    return float4(input.dth, input.dth, input.dth, 1);
}

technique Main
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZEnable = true;
        ZWriteEnable = true;

        CullMode = None;
    }
}

technique HorizontalSlice
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 ComputeCommonVertexHorizontalShader();
        PixelShader = compile ps_2_0 PixelShaderHorizontalFunction();
        
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        AlphaFunc = Greater;        
        ZEnable = true;
        ZFunc = LessEqual;
        ZWriteEnable = true;
    }
}

technique RenderTexture
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 RenderTextureVertexShader();
        PixelShader = compile ps_2_0 PixelShaderRenderTargetFunction();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZEnable = true;
        ZWriteEnable = true;

        CullMode = None;
    }
}

technique RenderThresholdTexture
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 RenderTextureVertexShader();
        PixelShader = compile ps_2_0 PixelShaderRenderThresholdFunction();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZEnable = true;
        ZWriteEnable = true;

        CullMode = None;
    }
}
