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
    JUST_PLAYER(
        displayName = "Hardware Original (Default)",
        tagline = "100% Direct Hardware Decoder • True Natural Colors • Zero Filter",
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
        displayName = "Light Clarity",
        tagline = "Gentle Detail • Natural Skin • No Black Crush",
        useShader = true,
        brightness = 0.01f,
        contrast = 1.02f,
        saturation = 1.03f,
        vibrance = 0.08f,
        shadowLift = 0.02f,
        warmth = 0.00f,
        sharpness = 0.25f,
        gamma = 0.98f
    ),
    BRIGHT_SHADOW(
        displayName = "Bright Shadow Lift",
        tagline = "Lifts Dark Scenes Cleanly",
        useShader = true,
        brightness = 0.03f,
        contrast = 1.01f,
        saturation = 1.04f,
        vibrance = 0.10f,
        shadowLift = 0.045f,
        warmth = 0.00f,
        sharpness = 0.25f,
        gamma = 0.92f
    )
}

object CinemaPictureEngineState {
    @Volatile
    var currentPreset: PicturePreset = PicturePreset.JUST_PLAYER
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

                if (uSharpness > 0.01) {
                    float lC = getLuma(color);
                    float lN = getLuma(texture2D(uTexSampler, vTexSamplingCoord + vec2(0.0, uTexelSize.y)).rgb);
                    float lS = getLuma(texture2D(uTexSampler, vTexSamplingCoord - vec2(0.0, uTexelSize.y)).rgb);
                    float lE = getLuma(texture2D(uTexSampler, vTexSamplingCoord + vec2(uTexelSize.x, 0.0)).rgb);
                    float lW = getLuma(texture2D(uTexSampler, vTexSamplingCoord - vec2(uTexelSize.x, 0.0)).rgb);

                    float blurLuma = (lN + lS + lE + lW) * 0.25;
                    float edgeDetail = lC - blurLuma;
                    float sharpDelta = clamp(edgeDetail * (uSharpness * 1.1), -0.10, 0.10);
                    color = clamp(color + vec3(sharpDelta), 0.0, 1.0);
                }

                float lumaIn = getLuma(color);
                float shadowWeight = (1.0 - lumaIn) * (1.0 - lumaIn);
                color = clamp(color + vec3(uBrightness + uShadowLift * shadowWeight), 0.0, 1.0);

                color = clamp((color - 0.5) * uContrast + 0.5, 0.0, 1.0);
                color = pow(max(color, vec3(0.0001)), vec3(uGamma));

                float luma = getLuma(color);
                float maxC = max(color.r, max(color.g, color.b));
                float minC = min(color.r, min(color.g, color.b));
                float currentSat = maxC - minC;
                float vibBoost = 1.0 + uVibrance * (1.0 - clamp(currentSat, 0.0, 1.0));
                color = mix(vec3(luma), color, uSaturation * vibBoost);

                color.r += uWarmth * 0.05;
                color.b -= uWarmth * 0.05;

                gl_FragColor = vec4(clamp(color, 0.0, 1.0), center.a);
            }
        """
    }
}