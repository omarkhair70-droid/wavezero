package com.wavezero.player

import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.wavezero.player.playback.AudioPlayerManager
import com.wavezero.player.playback.PlaybackMetrics
import com.wavezero.player.playback.PlaybackState
import com.wavezero.player.playback.PlaybackStatus

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val appStartedAtMs = SystemClock.elapsedRealtime()
        super.onCreate(savedInstanceState)
        setContent {
            WaveZeroApp(appStartedAtMs = appStartedAtMs)
        }
    }
}

@Composable
fun WaveZeroApp(appStartedAtMs: Long) {
    val context = LocalContext.current.applicationContext
    val manager = remember {
        AudioPlayerManager(
            context = context,
            appStartedAtMs = appStartedAtMs,
        )
    }
    val playbackState by manager.playbackState.collectAsState()
    val metrics by manager.metrics.collectAsState()

    LaunchedEffect(manager) {
        manager.markScreenReady()
    }

    DisposableEffect(manager) {
        onDispose { manager.release() }
    }

    MaterialTheme {
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .background(Background),
            color = Background,
        ) {
            PlaybackProofScreen(
                playbackState = playbackState,
                metrics = metrics,
                onPlayPause = manager::togglePlayPause,
                onStop = manager::stop,
            )
        }
    }
}

@Composable
private fun PlaybackProofScreen(
    playbackState: PlaybackState,
    metrics: PlaybackMetrics,
    onPlayPause: () -> Unit,
    onStop: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.Start,
    ) {
        Text(
            text = "WaveZero",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Android Playback Proof",
            color = MutedText,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(modifier = Modifier.height(32.dp))
        Text(
            text = playbackState.trackTitle,
            color = Color.White,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = playbackState.artistName,
            color = MutedText,
            style = MaterialTheme.typography.titleMedium,
        )
        Spacer(modifier = Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = onPlayPause,
                colors = ButtonDefaults.buttonColors(containerColor = Accent),
            ) {
                Text(text = if (metrics.isPlaying) "Pause" else "Play")
            }
            Button(
                onClick = onStop,
                colors = ButtonDefaults.buttonColors(containerColor = ControlGray),
            ) {
                Text(text = "Stop")
            }
        }
        Spacer(modifier = Modifier.height(24.dp))
        StatusCard(playbackState = playbackState, metrics = metrics)
    }
}

@Composable
private fun StatusCard(playbackState: PlaybackState, metrics: PlaybackMetrics) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Panel),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "State: ${playbackState.status.label()}",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            MetricRow("app_screen_ready_ms", metrics.appScreenReadyMs.formatNullable())
            MetricRow("tap_to_first_audio_ms", metrics.tapToFirstAudioMs.formatNullable())
            MetricRow("manifest_load_ms", metrics.manifestLoadMs.formatNullable())
            MetricRow("buffer_count", metrics.bufferCount.toString())
            MetricRow("is_playing", metrics.isPlaying.toString())
            MetricRow("current_position_ms", metrics.currentPositionMs.toString())
            MetricRow("playback_error", metrics.playbackError ?: "none")
        }
    }
}

@Composable
private fun MetricRow(name: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = name, color = MutedText, style = MaterialTheme.typography.bodyMedium)
        Text(text = value, color = Color.White, style = MaterialTheme.typography.bodyMedium)
    }
}

private fun Long?.formatNullable(): String = this?.toString() ?: "pending"

private fun PlaybackStatus.label(): String = name.lowercase()

private val Background = Color(0xFF080A0F)
private val Panel = Color(0xFF141821)
private val Accent = Color(0xFF5E6AD2)
private val ControlGray = Color(0xFF2B313C)
private val MutedText = Color(0xFFAAB0C0)
