float4x4 World;
float4x4 View;
float4x4 Projection;

// Lighting parameters.
float3 DirLight0Direction = float3(0, -1, 0);
float3 DirLight0DiffuseColor = 0.8;
float3 AmbientLightColor = float3(0.05333332, 0.09882354, 0.1819608);

float3 Center = float3(0, 0, 0);
float3 Axis = float3(0, 1, 0);

float Magnitude = 0.01;
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

struct VertexShaderInput
{
    float3 Position     : POSITION0;
    float2 TexCoord     : TEXCOORD0;
    float2 Offset       : TEXCOORD1;
};

struct VertexShaderOutput
{
    float4 Position     : POSITION0;
    float2 TexCoord     : TEXCOORD0;
    float3 Color        : COLOR0;
};

VertexShaderOutput ComputeCommonVertexShader(VertexShaderInput input,
  float4x4 world,
  uniform float leafScale)
{
    VertexShaderOutput output;

    float4x4 WV = mul(world, View);

    float amplitude = Magnitude * input.Position.z;
    float3 wave = amplitude * float3(sin(gTimer + input.Position.x),
                cos(gTimer + input.Position.y), 0);

    float4 viewPosition = mul(float4(input.Position + wave, 1), WV);
    viewPosition.xyz += float3(input.Offset.x, input.Offset.y, 0) * leafScale;

    output.Position = mul(viewPosition, Projection);

    output.TexCoord = input.TexCoord;

    float3 normal = normalize(mul((input.Position - Center), world));
    float3 color = AmbientLightColor;
    color += DirLight0DiffuseColor * (0.75 * max(dot(normal, -DirLight0Direction), 0.3) + 0.25);
    output.Color = color;

    return output;
}

VertexShaderOutput ComputeCommonVertexShaderAligned(VertexShaderInput input, 
  float4x4 world,
  uniform float3 up,
  uniform float3 right,
  uniform float leafScale)
{
    VertexShaderOutput output;

    float4x4 WV = mul(world, View);
    float amplitude = Magnitude * input.Position.z;
    float3 wave = amplitude * float3(sin(gTimer + input.Position.x),
                cos(gTimer + input.Position.y), 0);

    float4 viewPosition = mul(float4(input.Position + wave, 1), WV);
    viewPosition.xyz += (input.Offset.x * right + input.Offset.y * up) * leafScale;
    output.Position = mul(viewPosition, Projection);

    output.TexCoord = input.TexCoord;

    float3 normal = normalize(mul((input.Position - Center), world));
    float3 color = AmbientLightColor;
    color += DirLight0DiffuseColor * (0.75 * max(dot(normal, -DirLight0Direction), 0.3) + 0.25);
    output.Color = color;

    return output;
}

VertexShaderOutput VertexShaderFunction(VertexShaderInput input,
  uniform float leafScale)
{
    return ComputeCommonVertexShader(input, World, leafScale);
}

VertexShaderOutput VertexShaderAlignedFunction(VertexShaderInput input,
  uniform float3 up,
  uniform float3 right,
  uniform float leafScale)
{
    return ComputeCommonVertexShaderAligned(input, World, up, right, leafScale);
}

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{
    float4 result = float4(input.Color, 1) * tex2D(BasicTextureSampler, input.TexCoord);
    clip(result.a - 0.666);
    return result;
}

technique Main
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction(length(World._m00_m01_m02));
        PixelShader = compile ps_2_0 PixelShaderFunction();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZEnable = true;
        ZWriteEnable = true;
    }
}

float3 ComputeUp(float4x4 view, float3 axis)
{
    return mul(axis, view);
}

float3 ComputeRight(float4x4 view, float3 axis)
{
    return mul(normalize(cross(view._m02_m12_m22, axis)), view);
}

technique AxisAligned
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 VertexShaderAlignedFunction(
          ComputeUp(View, Axis),
          ComputeRight(View, Axis),
          length(World._m00_m01_m02));

        PixelShader = compile ps_2_0 PixelShaderFunction();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZEnable = true;
        ZWriteEnable = true;
    }
}
