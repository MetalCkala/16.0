#undef USE_PARALLAX

#ifdef p_3_0
  #ifdef HAVE_BUMPMAP
    #define USE_PARALLAX
  #endif
#endif

// Light parameters:
float  SpecularPower = 100.0;
float  SpecularLevel = 1;
float3 DirLight0Direction = float3(0, -1, 0);
float3 DirLight0DiffuseColor = float3(0.5, 0.5, 0.5);
float3 DirLight0SpecularColor = float3(0.87, 0.87, 0.87);
float3 AmbientLightColor = float3(0.05333332, 0.09882354, 0.1819608);

float3 DiffuseColor;                // Fallback color

// Matrices:
float4x4 World;                      // World matrix for object
float4x4 ViewProjection;             // View * Projection matrix
float3   EyePosition;                // Camera's location

texture BasicTexture;                // Base color texture
texture BumpMap;                     // Normal map and height map texture pair
float2  BumpMapDims;                 // Specifies texture dimensions for computation of mip level at
                                     // render time (width, height)

float   BaseTextureRepeat = 25;      // The tiling factor for base and normal map textures
float   HeightMapScale = 0.02;       // Describes the useful range of values for the height field

int     LODThreshold = 3;            // The mip level id for transitioning between the full computation
                                     // for parallax occlusion mapping and the bump mapping computation
int     g_nMinSamples = 8;           // The minimum number of samples for sampling the height field profile
int     g_nMaxSamples = 50;          // The maximum number of samples for sampling the height field profile

float4x4 DensityMatrix;
texture DensityMap;

sampler DensityMapSampler = sampler_state
{
    Texture = (DensityMap);

    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = None;
    
    AddressU = Clamp;
    AddressV = Clamp;
};

//--------------------------------------------------------------------------------------
// Texture samplers
//--------------------------------------------------------------------------------------
sampler TextureSampler = sampler_state
{
    Texture = < BasicTexture >;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler BumpMapSampler = sampler_state
{
    Texture = < BumpMap >;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//--------------------------------------------------------------------------------------
// Vertex shader output structure
//--------------------------------------------------------------------------------------
struct VS_OUTPUT
{
    float4 position          : POSITION;
    float2 texCoord          : TEXCOORD0;
    float3 vLightTS          : TEXCOORD1;   // light vector in tangent space, denormalized
    float3 vViewTS           : TEXCOORD2;   // view vector in tangent space, denormalized
#ifdef USE_PARALLAX
    float3 vNormalWS         : TEXCOORD3;   // Normal vector in world space
    float3 vViewWS           : TEXCOORD4;   // View vector in world space
#endif
#ifdef HAVE_DENSITYMAP
    float2 Density           : TEXCOORD5;
#endif
};  


//--------------------------------------------------------------------------------------
// This shader computes standard transform and lighting
//--------------------------------------------------------------------------------------
VS_OUTPUT RenderSceneVS( float3 inPositionOS  : POSITION, 
                         float3 vInNormalOS   : NORMAL )
{
    VS_OUTPUT Out;

    // Compute position in world space:
    float4 pos_ws = mul( float4(inPositionOS, 1), World );
    float4 pos_ps = mul(pos_ws, ViewProjection);

    Out.position = pos_ps;

    // Propagate texture coordinate through:
    Out.texCoord = inPositionOS.xy / BaseTextureRepeat;

    // Transform the normal, tangent and binormal vectors from object space to homogeneous projection space:
    float3 vNormalWS   = mul( vInNormalOS,   (float3x3) World );
    float3 vTangentWS  = mul( float3(1, 0, 0),  (float3x3) World );
    float3 vBinormalWS = normalize( cross( vNormalWS, vTangentWS ));
    
    vNormalWS   = vNormalWS;
    vBinormalWS = vBinormalWS;
    vTangentWS = cross(vBinormalWS, vNormalWS);

    // Compute and output the world view vector (unnormalized):
    float3 vViewWS = EyePosition - pos_ws.xyz;
    
    // Compute denormalized light vector in world space:
    float3 vLightWS = -DirLight0Direction;

    // Normalize the light and view vectors and transform it to the tangent space:
    float3x3 mWorldToTangent = float3x3( vTangentWS, vBinormalWS, vNormalWS );

    // Propagate the view and the light vectors (in tangent space):
    Out.vLightTS = mul( mWorldToTangent, vLightWS );
    Out.vViewTS  = mul( mWorldToTangent, vViewWS );
    
#ifdef USE_PARALLAX
    Out.vViewWS = vViewWS;
    Out.vNormalWS = vNormalWS;
#endif

#ifdef HAVE_DENSITYMAP
    Out.Density = mul(pos_ws, DensityMatrix).xy;
#endif

    return Out;
}   

//--------------------------------------------------------------------------------------
// Pixel shader output structure
//--------------------------------------------------------------------------------------
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color
};

struct PS_INPUT
{
   float2 texCoord          : TEXCOORD0;
   float3 vLightTS          : TEXCOORD1;   // light vector in tangent space, denormalized
   float3 vViewTS           : TEXCOORD2;   // view vector in tangent space, denormalized
#ifdef USE_PARALLAX
   float3 vNormalWS         : TEXCOORD3;   // Normal vector in world space
   float3 vViewWS           : TEXCOORD4;   // View vector in world space
#endif
#ifdef HAVE_DENSITYMAP
    float2 Density          : TEXCOORD5;
#endif
};

//--------------------------------------------------------------------------------------
// Function:    ComputeIllumination
//--------------------------------------------------------------------------------------
float4 ComputeIllumination( float2 texCoord, float3 vLightTS, float3 vViewTS, float3 vNormalTS )
{
    // Sample base map:
#ifdef HAVE_BASICTEXTURE
    float4 cBaseColor = tex2D( TextureSampler, texCoord );
#else
    float4 cBaseColor = float4(1, 1, 1, 1);
#endif
    
    // Compute diffuse color component:
   float3 vLightTSAdj = vLightTS;
   
   float3 cDiffuse = saturate( dot( vNormalTS, vLightTSAdj )) * DirLight0DiffuseColor;
   
   float3 vReflectionTS = normalize( 2 * dot( vViewTS, vNormalTS ) * vNormalTS - vViewTS );
   float fRdotL = saturate( dot( vReflectionTS, vLightTSAdj ));
   float3 cSpecular = saturate( pow( fRdotL, SpecularPower )) * DirLight0SpecularColor * SpecularLevel;
   
   // Composite the final color:
   float3 cFinalColor = ( AmbientLightColor + cDiffuse ) * cBaseColor.rgb + cSpecular;
   
   return float4(cFinalColor, cBaseColor.a);
}

#ifdef USE_PARALLAX

//--------------------------------------------------------------------------------------
// Parallax occlusion mapping pixel shader
//--------------------------------------------------------------------------------------
float4 RenderScenePS( PS_INPUT i ) : COLOR0
{ 
    // Compute initial parallax displacement direction:
    float2 vParallaxDirection = normalize(  i.vViewTS.xy );

    // The length of this vector determines the furthest amount of displacement:
    float fLength         = length( i.vViewTS );
    float fParallaxLength = sqrt( fLength * fLength - i.vViewTS.z * i.vViewTS.z ) / i.vViewTS.z;

    // Compute the actual reverse parallax displacement vector:
    float2 vParallaxOffsetTS = vParallaxDirection * fParallaxLength;

    // Need to scale the amount of displacement to account for different height ranges
    // in height maps. This is controlled by an artist-editable parameter:
    vParallaxOffsetTS *= HeightMapScale;

   //  Normalize the interpolated vectors:
   float3 vViewTS   = normalize( i.vViewTS  );
   float3 vViewWS   = normalize( i.vViewWS  );
   float3 vLightTS  = normalize( i.vLightTS );
   float3 vNormalWS = normalize( i.vNormalWS );

   float4 cResultColor = float4( 0, 0, 0, 1 );

   // Compute the current gradients:
   float2 fTexCoordsPerSize = i.texCoord * BumpMapDims;

   // Compute all 4 derivatives in x and y in a single instruction to optimize:
   float2 dxSize, dySize;
   float2 dx, dy;

   float4( dxSize, dx ) = ddx( float4( fTexCoordsPerSize, i.texCoord ) );
   float4( dySize, dy ) = ddy( float4( fTexCoordsPerSize, i.texCoord ) );

   float  fMipLevel;
   float  fMipLevelInt;    // mip level integer portion
   float  fMipLevelFrac;   // mip level fractional amount for blending in between levels

   float  fMinTexCoordDelta;
   float2 dTexCoords;

   // Find min of change in u and v across quad: compute du and dv magnitude across quad
   dTexCoords = dxSize * dxSize + dySize * dySize;

   // Standard mipmapping uses max here
   fMinTexCoordDelta = max( dTexCoords.x, dTexCoords.y );

   // Compute the current mip level  (* 0.5 is effectively computing a square root before )
   fMipLevel = max( 0.5 * log2( fMinTexCoordDelta ), 0 );

   // Start the current sample located at the input texture coordinate, which would correspond
   // to computing a bump mapping result:
   float2 texSample = i.texCoord;
   
   if ( fMipLevel <= (float) LODThreshold )
   {
      int nNumSteps = (int) lerp( g_nMaxSamples, g_nMinSamples, dot( vViewWS, vNormalWS ) );

      float fCurrHeight = 0.0;
      float fStepSize   = 1.0 / (float) nNumSteps;
      float fPrevHeight = 1.0;
      float fNextHeight = 0.0;

      int    nStepIndex = 0;
      bool   bCondition = true;

      float2 vTexOffsetPerStep = fStepSize * vParallaxOffsetTS;
      float2 vTexCurrentOffset = i.texCoord;
      float  fCurrentBound     = 1.0;
      float  fParallaxAmount   = 0.0;

      float2 pt1 = 0;
      float2 pt2 = 0;

      float2 texOffset2 = 0;
      
      while ( nStepIndex < nNumSteps )
      {
         vTexCurrentOffset -= vTexOffsetPerStep;

         // Sample height map which in this case is stored in the alpha channel of the normal map:
         fCurrHeight = tex2Dgrad( BumpMapSampler, vTexCurrentOffset, dx, dy ).a;

         fCurrentBound -= fStepSize;

         if ( fCurrHeight > fCurrentBound )
         {
            pt1 = float2( fCurrentBound, fCurrHeight );
            pt2 = float2( fCurrentBound + fStepSize, fPrevHeight );

            texOffset2 = vTexCurrentOffset - vTexOffsetPerStep;

            nStepIndex = nNumSteps + 1;
            fPrevHeight = fCurrHeight;
         }
         else
         {
            nStepIndex++;
            fPrevHeight = fCurrHeight;
         }
      }

      float fDelta2 = pt2.x - pt2.y;
      float fDelta1 = pt1.x - pt1.y;

      float fDenominator = fDelta2 - fDelta1;

      // SM 3.0 requires a check for divide by zero, since that operation will generate
      // an 'Inf' number instead of 0, as previous models (conveniently) did:
      if ( fDenominator == 0.0f )
      {
         fParallaxAmount = 0.0f;
      }
      else
      {
         fParallaxAmount = (pt1.x * fDelta2 - pt2.x * fDelta1 ) / fDenominator;
      }

      float2 vParallaxOffset = vParallaxOffsetTS * (1 - fParallaxAmount );

      // The computed texture offset for the displaced point on the pseudo-extruded surface:
      float2 texSampleBase = i.texCoord - vParallaxOffset;
      texSample = texSampleBase;

      if ( fMipLevel > (float)(LODThreshold - 1) )
      {
         // Lerp based on the fractional part:
         fMipLevelFrac = modf( fMipLevel, fMipLevelInt );

         // Lerp the texture coordinate from parallax occlusion mapped coordinate to bump mapping
         // smoothly based on the current mip level:
         texSample = lerp( texSampleBase, i.texCoord, fMipLevelFrac );
      }
   }
   
    // Sample the normal from the normal map for the given texture sample:
    float3 vNormalTS = normalize( tex2D( BumpMapSampler, texSample ) * 2 - 1 );
    
    // Compute resulting color for the pixel:
    cResultColor = ComputeIllumination( texSample, vLightTS, vViewTS, vNormalTS );
    
#ifdef HAVE_DENSITYMAP
    cResultColor.a *= tex2D(DensityMapSampler, i.Density).r;
#endif
    
    return cResultColor;
}

#else

//--------------------------------------------------------------------------------------
// Bump mapping shader
//--------------------------------------------------------------------------------------
float4 RenderSceneBumpMapPS( PS_INPUT i ) : COLOR0
{ 
   //  Normalize the interpolated vectors:
   float3 vViewTS   = normalize( i.vViewTS  );
   float3 vLightTS  = normalize( i.vLightTS );
     
   float4 cResultColor = float4( 0, 0, 0, 1 );

   // Start the current sample located at the input texture coordinate, which would correspond
   // to computing a bump mapping result:
   float2 texSample = i.texCoord;

#ifdef HAVE_BUMPMAP
   // Sample the normal from the normal map for the given texture sample:
   float3 vNormalTS = normalize( tex2D( BumpMapSampler, texSample ) * 2 - 1 );
#else
   float3 vNormalTS = float3(0, 0, 1);
#endif
   // Compute resulting color for the pixel:
   cResultColor = ComputeIllumination( texSample, vLightTS, vViewTS, vNormalTS );

#ifdef HAVE_DENSITYMAP
    cResultColor.a *= tex2D(DensityMapSampler, i.Density).r;
#endif
   
   return cResultColor;
}

#endif

//--------------------------------------------------------------------------------------
// Renders scene to render target
//--------------------------------------------------------------------------------------

#ifdef USE_PARALLAX

technique Main
{
    pass P0
    {          
        VertexShader = compile vs_3_0 RenderSceneVS();
        PixelShader  = compile ps_3_0 RenderScenePS(); 
        
        
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        AlphaFunc = Greater;      
#ifdef HAVE_DENSITYMAP
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        AlphaFunc = Greater;        
        ZEnable = true;
        ZFunc = LessEqual;
        ZWriteEnable = true;
#endif
    }
}

#else

technique Main
{
    pass P0
    {          
        VertexShader = compile vs_2_0 RenderSceneVS();
        PixelShader  = compile ps_2_0 RenderSceneBumpMapPS();
        
#ifdef HAVE_DENSITYMAP
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        AlphaFunc = Greater;        
        ZEnable = true;
        ZFunc = LessEqual;
        ZWriteEnable = true;
#endif
    }
}

#endif