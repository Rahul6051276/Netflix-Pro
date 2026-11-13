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

data class PictureSettings(
    val enabled: Boolean = true,
    val brightness: Float = 0.02f,
    val contrast: Float = 1.20f,
    val saturation: Float = 1.32f,
    val vibrance: Float = 0.42f,
    val blackLevel: Float = -0.04f,
    val warmth: Float = 0.04f,
    val sharpness: Float = 0.28f,
    val gamma: Float = 0.95f
)

enum class PicturePreset(val label: String, val settings: PictureSettings) {
    VIVID_CINEMA(
        "Vivid Cinema",
        PictureSettings(true, 0.02f, 1.20f, 1.32f, 0.42f, -0.04f, 0.04f, 0.28f, 0.95f)
    ),
    HDR_BOOST(
        "HDR Boost",
        PictureSettings(true, 0.05f, 1.26f, 1.24f, 0.50f, -0.05f, 0.02f, 0.38f, 0.92f)
    ),
    FILMMAKER(
        "Filmmaker",
        PictureSettings(true, 0.00f, 1.14f, 1.12f, 0.18f, -0.02f, 0.10f, 0.12f, 0.98f)
    ),
    CRISP_SPORTS(
        "Crisp Sports",
        PictureSettings(true, 0.04f, 1.18f, 1.26f, 0.34f, -0.01f, -0.06f, 0.50f, 0.94f)
    ),
    NIGHT_THEATER(
        "Night Theater",
        PictureSettings(true, 0.03f, 1.08f, 1.15f, 0.22f, 0.03f, 0.16f, 0.18f, 1.04f)
    ),
    NATIVE_HDR(
        "Native HDR (Raw)",
        PictureSettings(false, 0f, 1f, 1f, 0f, 0f, 0f, 0f, 1f)
    )
}

object CinemaPictureState {
    @Volatile var settings: PictureSettings = PicturePreset.VIVID_CINEMA.settings
    @Volatile var splitCompareX: Float = 0f
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

    private val glProgram = GlProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    private var texWidth = 1920
    private var texHeight = 1080

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        texWidth = inputWidth.coerceAtLeast(1)
        texHeight = inputHeight.coerceAtLeast(1)
        return Size(texWidth, texHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            val s = CinemaPictureState.settings
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
            glProgram.setFloatUniform("uBlackLevel", s.blackLevel)
            glProgram.setFloatUniform("uWarmth", s.warmth)
            glProgram.setFloatUniform("uSharpness", s.sharpness)
            glProgram.setFloatUniform("uGamma", s.gamma.coerceIn(0.6f, 1.5f))
            glProgram.setFloatUniform("uSplitCompare", CinemaPictureState.splitCompareX)
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
            uniform float uBlackLevel;
            uniform float uWarmth;
            uniform float uSharpness;
            uniform float uGamma;
            uniform float uSplitCompare;
            varying vec2 vTexSamplingCoord;

            void main() {
                vec4 center = texture2D(uTexSampler, vTexSamplingCoord);
                if (uSplitCompare > 0.001 && vTexSamplingCoord.x < uSplitCompare) {
                    if (abs(vTexSamplingCoord.x - uSplitCompare) < 0.0025) {
                        gl_FragColor = vec4(0.90, 0.04, 0.08, 1.0);
                    } else {
                        gl_FragColor = center;
                    }
                    return;
                }

                vec3 color = center.rgb;

                if (uSharpness > 0.01) {
                    vec3 n = texture2D(uTexSampler, vTexSamplingCoord + vec2(0.0, uTexelSize.y)).rgb;
                    vec3 s = texture2D(uTexSampler, vTexSamplingCoord - vec2(0.0, uTexelSize.y)).rgb;
                    vec3 e = texture2D(uTexSampler, vTexSamplingCoord + vec2(uTexelSize.x, 0.0)).rgb;
                    vec3 w = texture2D(uTexSampler, vTexSamplingCoord - vec2(uTexelSize.x, 0.0)).rgb;
                    vec3 blur = (n + s + e + w) * 0.25;
                    color = clamp(color + (color - blur) * (uSharpness * 1.15), 0.0, 1.0);
                }

                color = clamp(color + vec3(uBrightness + uBlackLevel * (1.0 - color)), 0.0, 1.0);
                color = clamp((color - 0.5) * uContrast + 0.5, 0.0, 1.0);
                color = pow(max(color, vec3(0.0001)), vec3(uGamma));

                float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
                float maxC = max(color.r, max(color.g, color.b));
                float minC = min(color.r, min(color.g, color.b));
                float vibBoost = 1.0 + uVibrance * (1.0 - clamp(maxC - minC, 0.0, 1.0));
                color = mix(vec3(luma), color, uSaturation * vibBoost);

                color.r += uWarmth * 0.14;
                color.g += uWarmth * 0.03;
                color.b -= uWarmth * 0.14;

                gl_FragColor = vec4(clamp(color, 0.0, 1.0), center.a);
            }
        """
    }
}
