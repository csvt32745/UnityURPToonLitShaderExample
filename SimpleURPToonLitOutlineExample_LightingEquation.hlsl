// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to edit and experiment with different lighting equation.
// Add or edit whatever code you want here

// #pragma once is a safe guard best practice in almost every .hlsl (need Unity2020 or up), 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

half3 ShadeGI(ToonSurfaceData surfaceData, LightingData lightingData)
{
    // hide 3D feeling by ignoring all detail SH (leaving only the constant SH term)
    // we just want some average envi indirect color only
    half3 averageSH = SampleSH(0);

    // can prevent result becomes completely black if lightprobe was not baked 
    averageSH = max(_IndirectLightMinColor,averageSH);

    // occlusion (maximum 50% darken for indirect to prevent result becomes completely black)
    half indirectOcclusion = lerp(1, surfaceData.occlusion, 0.5);
    return averageSH * indirectOcclusion;
}

half ShadeAnisotropic(half3 T, half3 V, half3 L, half specularTerm)
{
    half3 H = normalize(V + L);
    float dotTH = dot(T, H);
    float sinTH = sqrt(1.0 - dotTH*dotTH);
    float dirAtten = smoothstep(-1.0, 0.0, dotTH);
    return specularTerm * dirAtten * pow(sinTH, _SpecularExponent) * _SpecularStrength;
}

half ShadeSpecular(half3 N, half3 V, half3 L, half specularTerm)
{
    half3 H = normalize(V + L);
    float dotNH = clamp(dot(N, H), 0.0, 1.0);
    float dirAtten = smoothstep(0.0, 1.0, dotNH);
    return specularTerm * dirAtten * pow(dotNH, _SpecularExponent) * _SpecularStrength;
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot)
half3 ShadeSingleLight(ToonSurfaceData surfaceData, LightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;

    half NoL = dot(N,L);

    half lightAttenuation = 1;

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method!
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

    // occlusion
    litOrShadowArea *= surfaceData.occlusion;

    // face ignore celshade since it is usually very ugly using NoL method
    litOrShadowArea = _IsFace? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // light's shadow map
    litOrShadowArea *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    half3 litOrShadowColor = lerp(_ShadowMapColor*surfaceData.shadowColor,1, litOrShadowArea);

    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation;

    half highlighColor = _UseAnisotropicHighlight?
        ShadeAnisotropic(lightingData.tangentWS, V, L, surfaceData.specular) : ShadeSpecular(N, V, L, surfaceData.specular);
    
    half rimLight = smoothstep(_RimLightThreshold, 1.0, 1-dot(N, V));

    highlighColor += rimLight * _RimLightStrength;

    // saturate() light.color to prevent over bright
    // additional light reduce intensity since it is additive
    return ((saturate(light.color)*(1.+highlighColor)) * lightAttenuationRGB) * (isAdditionalLight ? 0.25 : 1);
}

half3 ShadeEmission(ToonSurfaceData surfaceData, LightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo
    return emissionResult;
}

half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, LightingData lightingData)
{
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue
    half3 rawLightSum = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light
    return surfaceData.albedo * rawLightSum + emissionResult;
}
