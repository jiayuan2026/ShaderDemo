
Shader "Custom/Cube"
{
    Properties
    {
        [Header(Base Settings)]
        _Color ("Base Color", Color) = (0.1, 0.4, 1.0, 0.15)
        _Alpha ("Base Transparency", Range(0, 1)) = 1.0

        [Header(Edge Glow)]
        [HDR] _EdgeColor ("Edge Glow Color", Color) = (0.0, 1.0, 1.0, 1.0)
        _EdgePower ("Edge Glow Power", Range(0.1, 10)) = 2.5
        _EdgeIntensity ("Edge Intensity (HDR)", Range(0, 10)) = 3.0
        _EdgeOpacity ("Edge Opacity", Range(0, 1)) = 0.8

        [Header(Inner Structure)]
        [HDR] _InnerColor ("Inner Line Color", Color) = (0.2, 0.7, 1.0, 1.0)
        _LineThickness ("Inner Line Thickness", Range(0.005, 0.2)) = 0.05
        _InnerIntensity ("Inner Line Intensity", Range(0, 10)) = 1.5
        _InnerOpacity ("Inner Line Opacity", Range(0, 1)) = 0.8
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest LEqual
        Cull Off

        Pass
        {
            Name "ForwardUnlit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // =========================================
            // 1. Vertex Input
            // =========================================

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // =========================================
            // 2. Vertex Output
            // =========================================

            struct Varyings
            {
                float4 positionCS : SV_POSITION;

                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;

                float3 positionOS : TEXCOORD2;
                float3 normalOS : TEXCOORD3;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // =========================================
            // 3. Material Properties
            // SRP Batcher Compatible
            // =========================================

            CBUFFER_START(UnityPerMaterial)

                half4 _Color;
                float _Alpha;

                half4 _EdgeColor;
                float _EdgePower;
                float _EdgeIntensity;
                float _EdgeOpacity;

                half4 _InnerColor;
                float _LineThickness;
                float _InnerIntensity;
                float _InnerOpacity;

            CBUFFER_END

            // =========================================
            // 4. Vertex Shader
            // =========================================

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                output.positionCS = vertexInput.positionCS;

                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;

                output.positionOS = input.positionOS.xyz;
                output.normalOS = input.normalOS;

                return output;
            }

            // =========================================
            // 5. Fragment Shader
            // =========================================
            half4 frag(Varyings input, FRONT_FACE_TYPE facing : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                // -------------------------------------
                // A. Front / Back Face Detection
                // -------------------------------------
                bool isFrontFace = IS_FRONT_VFACE(facing, true, false);

                // -------------------------------------
                // B. Normal and View Direction
                // -------------------------------------
                
                float3 normalWS = normalize(input.normalWS);

                // Flip normal for back faces
                if (!isFrontFace)
                {
                    normalWS = -normalWS;
                }

                float3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                // -------------------------------------
                // C. Fresnel Edge Effect
                // -------------------------------------

                float NdotV = saturate(dot(normalWS, viewDirWS));

                float fresnel = pow(1.0 - NdotV, _EdgePower);

                // -------------------------------------
                // D. Geometric Edge Detection
                // Standard Unity Cube:
                // Local coordinates: -0.5 to +0.5
                // -------------------------------------

                float3 absPos = abs(input.positionOS);

                float3 absNormal = abs(normalize(input.normalOS));

                // Distance to each local-space boundary
                float distX = 0.5 - absPos.x;
                float distY = 0.5 - absPos.y;
                float distZ = 0.5 - absPos.z;

                // Screen-space anti-aliasing width
                float aaX = max(fwidth(distX), 0.0001);
                float aaY = max(fwidth(distY), 0.0001);
                float aaZ = max(fwidth(distZ), 0.0001);

                // Edge masks
                float edgeX = 1.0 - smoothstep( _LineThickness - aaX,  _LineThickness + aaX, distX);

                float edgeY = 1.0 - smoothstep( _LineThickness - aaY,  _LineThickness + aaY, distY);

                float edgeZ = 1.0 - smoothstep( _LineThickness - aaZ,  _LineThickness + aaZ, distZ);

                // Exclude the current face normal direction
                float lineX = edgeX * (1.0 - absNormal.x);
                float lineY = edgeY * (1.0 - absNormal.y);
                float lineZ = edgeZ * (1.0 - absNormal.z);

                // Combine edge masks
                float innerLines = max(lineX,max(lineY, lineZ));

                // -------------------------------------
                // E. Edge Emission
                // -------------------------------------

                half3 edgeGlow =  _EdgeColor.rgb * fresnel * _EdgeIntensity;

                // -------------------------------------
                // F. Inner Line Emission
                // -------------------------------------

                half3 innerGlow =  _InnerColor.rgb * innerLines * _InnerIntensity;

                // -------------------------------------
                // G. Base Color
                // -------------------------------------

                half3 baseColor = _Color.rgb;

                half3 finalRGB;

                if (isFrontFace)
                {
                    // Front surface
                    finalRGB = baseColor + edgeGlow + innerGlow;
                }
                else
                {
                    // Back surface
                    finalRGB = baseColor * 0.5 + edgeGlow + innerGlow * 0.7;
                }

                // -------------------------------------
                // H. Alpha Composition
                // -------------------------------------

                float baseAlpha = _Color.a * _Alpha;

                float edgeAlpha = fresnel * _EdgeOpacity;
                   

                float lineAlpha = innerLines * _InnerOpacity;
                    

                float finalAlpha = baseAlpha + edgeAlpha + lineAlpha;

                // Slightly reduce backface opacity
                if (!isFrontFace)
                {
                    finalAlpha *= 0.7;
                }

                finalAlpha = saturate(finalAlpha);

                // -------------------------------------
                // I. Final Output
                // -------------------------------------

                return half4(finalRGB, finalAlpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
