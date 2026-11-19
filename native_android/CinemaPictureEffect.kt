package com.netflixpro.netflix_pro

import android.content.Context
import android.opengl.GLES20
import androidx.annotation.OptIn
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

enum class PicturePreset(
    val displayName: String,
    val tagline: String,
    val useShader: Boolean,
    val brightness: Float,
    val contrast: Float,
    val saturation: Float,
    val vibrance: Float,
    val shadowLift: Float,
    val warmth: Float,
    val sharpness: Float,
    val gamma: Float
) {
    FHD_UPSCALER(
        displayName = "FHD 1080p Upscale",
        tagline = "720p → 1080p Crisp Detail • HW Rich Colors • Deep Blacks",
        useShader = true,
        brightness = 0.005f,
        contrast = 1.10f,
        saturation = 1.08f,
        vibrance = 0.22f,
        shadowLift = 0.012f,
        warmth = -0.01f,
        sharpness = 0.48f,
        gamma = 0.96f
    ),
    JUST_PLAYER(
        displayName = "Hardware Pure (Raw)",
        tagline = "Direct Hardware Surface • Unprocessed Native Colors",
        useShader = false,
        brightness = 0f,
        contrast = 1f,
        saturation = 1f,
        vibrance = 0f,
        shadowLift = 0f,
        warmth = 0f,
        sharpness = 0f,
        gamma = 1f
    ),
    CINEMA_NATURAL(
        displayName = "Cinema Natural",
        tagline = "Balanced Theater Tone • Natural Skin • Soft Clarity",
        useShader = true,
        brightness = 0.01f,
        contrast = 1.06f,
        saturation = 1.05f,
        vibrance = 0.14f,
        shadowLift = 0.018f,
        warmth = 0.00f,
        sharpness = 0.30f,
        gamma = 0.97f
    ),
    BRIGHT_SHADOW(
        displayName = "Dark Print Booster",
        tagline = "Lifts Dark Scenes Cleanly • Crisp Edges",
        useShader = true,
        brightness = 0.025f,
        contrast = 1.07f,
        saturation = 1.08f,
        vibrance = 0.20f,
        shadowLift = 0.040f,
        warmth = 0.00f,
        sharpness = 0.42f,
        gamma = 0.91f
    ),
    NIGHT_SOFT(
        displayName = "Night Eye-Comfort",
        tagline = "Gentle Brightness • Smooth Contrast",
        useShader = true,
        brightness = 0.00f,
        contrast = 1.03f,
        saturation = 1.02f,
        vibrance = 0.08f,
        shadowLift = 0.020f,
        warmth = 0.02f,
        sharpness = 0.22f,
        gamma = 0.96f
    )
}

object CinemaPictureEngineState {
    @Volatile
    var currentPreset: PicturePreset = PicturePreset.FHD_UPSCALER
}

@OptIn(UnstableApi::class)
class CinemaPictureEffect : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        return CinemaPictureShaderProgram(useHdr)
    }

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = false
}

@OptIn(UnstableApi::class)
private class CinemaPictureShaderProgram(useHdr: Boolean) :
    BaseGlShaderProgram(useHdr, 1) {

    private val glProgram: GlProgram = GlProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    private var texWidth = 1920
    private var texHeight = 1080

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        texWidth = inputWidth.coerceAtLeast(1)
        texHeight = inputHeight.coerceAtLeast(1)
        return Size(texWidth, texHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            val s = CinemaPictureEngineState.currentPreset

            glProgram.use()
            glProgram.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            glProgram.setBufferAttribute(
                "aFramePosition",
                GlUtil.getNormalizedCoordinateBounds(),
                GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE
            )
            glProgram.setFloatsUniform("uTransformationMatrix", GlUtil.create4x4IdentityMatrix())
            glProgram.setFloatsUniform("uTexTransformationMatrix", GlUtil.create4x4IdentityMatrix())
            glProgram.setFloatsUniform("uTexelSize", floatArrayOf(1f / texWidth, 1f / texHeight))
            glProgram.setFloatUniform("uBrightness", s.brightness)
            glProgram.setFloatUniform("uContrast", s.contrast)
            glProgram.setFloatUniform("uSaturation", s.saturation)
            glProgram.setFloatUniform("uVibrance", s.vibrance)
            glProgram.setFloatUniform("uShadowLift", s.shadowLift)
            glProgram.setFloatUniform("uWarmth", s.warmth)
            glProgram.setFloatUniform("uSharpness", s.sharpness)
            glProgram.setFloatUniform("uGamma", s.gamma.coerceIn(0.75f, 1.25f))
            glProgram.bindAttributesAndUniforms()

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            glProgram.delete()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    companion object {
        private const val VERTEX_SHADER = """
            attribute vec4 aFramePosition;
            uniform mat4 uTransformationMatrix;
            uniform mat4 uTexTransformationMatrix;
            varying vec2 vTexSamplingCoord;
            void main() {
                gl_Position = uTransformationMatrix * aFramePosition;
                vec4 texCoord = vec4(aFramePosition.xy * 0.5 + 0.5, 0.0, 1.0);
                vTexSamplingCoord = (uTexTransformationMatrix * texCoord).xy;
            }
        """

        private const val FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uTexSampler;
            uniform vec2 uTexelSize;
            uniform float uBrightness;
            uniform float uContrast;
            uniform float uSaturation;
            uniform float uVibrance;
            uniform float uShadowLift;
            uniform float uWarmth;
            uniform float uSharpness;
            uniform float uGamma;
            varying vec2 vTexSamplingCoord;

            float getLuma(vec3 c) {
                return dot(c, vec3(0.2126, 0.7152, 0.0722));
            }

            void main() {
                vec4 center = texture2D(uTexSampler, vTexSamplingCoord);
                vec3 color = center.rgb;

                // 1. Luma-Only 720p->1080p Smart Edge Sharpening (Zero Color Noise)
                if (uSharpness > 0.01) {
                    float lC = getLuma(color);
                    float lN = getLuma(texture2D(uTexSampler, vTexSamplingCoord + vec2(0.0, uTexelSize.y)).rgb);
                    float lS = getLuma(texture2D(uTexSampler, vTexSamplingCoord - vec2(0.0, uTexelSize.y)).rgb);
                    float lE = getLuma(texture2D(uTexSampler, vTexSamplingCoord + vec2(uTexelSize.x, 0.0)).rgb);
                    float lW = getLuma(texture2D(uTexSampler, vTexSamplingCoord - vec2(uTexelSize.x, 0.0)).rgb);

                    float blurLuma = (lN + lS + lE + lW) * 0.25;
                    float edgeDetail = lC - blurLuma;
                    float sharpDelta = clamp(edgeDetail * (uSharpness * 1.35), -0.14, 0.14);
                    color = clamp(color + vec3(sharpDelta), 0.0, 1.0);
                }

                // 2. Shadow detail recovery without washing out blacks
                float lumaIn = getLuma(color);
                float shadowWeight = (1.0 - lumaIn) * (1.0 - lumaIn) * smoothstep(0.02, 0.35, lumaIn);
                color = clamp(color + vec3(uBrightness + uShadowLift * shadowWeight), 0.0, 1.0);

                // 3. Hardware-like S-Curve Contrast & Gamma punch
                color = clamp((color - 0.5) * uContrast + 0.5, 0.0, 1.0);
                color = pow(max(color, vec3(0.0001)), vec3(uGamma));

                // 4. Skin-Safe Hardware Color Vibrance
                float luma = getLuma(color);
                float maxC = max(color.r, max(color.g, color.b));
                float minC = min(color.r, min(color.g, color.b));
                float currentSat = maxC - minC;
                float skinProtect = smoothstep(0.0, 0.25, max(0.0, color.r - color.g));
                float vibBoost = 1.0 + (uVibrance * (1.0 - skinProtect * 0.45)) * (1.0 - clamp(currentSat, 0.0, 1.0));
                color = mix(vec3(luma), color, uSaturation * vibBoost);

                // 5. Clean white balance
                color.r += uWarmth * 0.05;
                color.b -= uWarmth * 0.05;

                gl_FragColor = vec4(clamp(color, 0.0, 1.0), center.a);
            }
        """
    }
}