float4x4 World;
float4x4 ViewProjection;
float4x4 View;

// Lighting parameters.
float3 DirLight0Direction;
float3 DirLight0DiffuseColor = 0.8;
float3 AmbientLightColor = 0.4;

float Magnitude = 0.01;
float gTimer;

texture BasicTexture;

sampler BasicTextureSampler = sampler_state
{
    Texture = (BasicTexture);

    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    
    AddressU = Wrap;
    AddressV = Wrap;
};

struct VS_INPUT
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 TexCoord : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float3 Color : COLOR0;
};

VS_OUTPUT ComputeCommonVertexShader(VS_INPUT input, float4x4 world)
{
    VS_OUTPUT output;

    float tScale = input.Position.z / 5.0;
    float amplitude = Magnitude * input.Position.z;
    float3 wave = amplitude * float3(sin(gTimer + input.Position.x / tScale),
                cos(gTimer + input.Position.y / tScale), 0);

    float4 pos_ws = mul(float4(input.Position + wave, 1), world);
    float4 pos_ps = mul(pos_ws, ViewProjection);
    output.Position = pos_ps;
    output.TexCoord = input.TexCoord;
    float3 normal = normalize(mul(input.Normal, world));
    float3 color = AmbientLightColor;
    color += DirLight0DiffuseColor * (max(dot(normal, -DirLight0Direction), 0.0));
    output.Color = color;

    return output;
}

VS_OUTPUT VertexShaderFunction(VS_INPUT input)
{
    return ComputeCommonVertexShader(input, World);
}

float4 PixelShaderFunction(VS_OUTPUT input) : COLOR0
{
    return tex2D(BasicTextureSampler, input.TexCoord) * float4(saturate(input.Color), 1);
}

technique Main
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}