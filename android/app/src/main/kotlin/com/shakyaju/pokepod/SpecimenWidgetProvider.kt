package com.shakyaju.pokepod

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * The home-screen Specimen widget.
 *
 * Every decision about *which* Pokémon is shown is made in Dart (the app, or
 * the short headless run started by the daily alarm) and stored through
 * home_widget; this class only draws what it reads and opens today's dossier
 * when tapped. Rendering is intentionally defensive: any missing piece falls
 * back to a placeholder instead of failing the whole update.
 *
 * The three published sizes grow progressively richer (see [Tier]): small is
 * the specimen's identity, medium adds its Pokédex field description, large
 * adds height and weight. Every layout answers to the same view ids so one
 * render path drives all of them, including the short banner used when a
 * launcher only leaves a single row of cells.
 */
class SpecimenWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      render(context, appWidgetManager, widgetId, widgetData)
    }
  }

  /// Resizing a widget can cross a layout threshold (banner -> small ->
  /// medium -> large), so the layout is re-evaluated whenever the launcher
  /// reports new sizes.
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, widgetId, newOptions)
    render(context, appWidgetManager, widgetId, HomeWidgetPlugin.getData(context))
  }

  private fun render(
      context: Context,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
      widgetData: SharedPreferences,
  ) {
    val options = appWidgetManager.getAppWidgetOptions(widgetId)
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
    val tier = tierFor(minWidth, minHeight)

    val name = widgetData.getString(KEY_NAME, null)?.trim().orEmpty()
    val dex = widgetData.getString(KEY_DEX, null)?.trim().orEmpty()
    val generation = widgetData.getString(KEY_GENERATION, null)?.trim().orEmpty()
    val typeLabel = widgetData.getString(KEY_TYPES, null)?.trim().orEmpty()
    val typeColorHex = widgetData.getString(KEY_TYPE_COLORS, null)?.trim().orEmpty()
    val description = widgetData.getString(KEY_DESCRIPTION, null)?.trim().orEmpty()
    val height = widgetData.getString(KEY_HEIGHT, null)?.trim().orEmpty()
    val weight = widgetData.getString(KEY_WEIGHT, null)?.trim().orEmpty()

    // The Dart side writes "Fire · Flying" plus a parallel "#AARRGGBB" list;
    // both are aligned segment by segment and may be empty.
    val typeNames = typeLabel.split(TYPE_SEPARATOR).filter { it.isNotBlank() }
    val typeColors = typeColorHex.split(',').filter { it.isNotBlank() }.mapNotNull { parseColor(it) }
    val chipFallback = context.getColor(R.color.widget_dim)

    val artwork = decodeArtwork(widgetData.getString(KEY_ART_PATH, null), MAX_ARTWORK_PX)
    val showDescription = tier >= Tier.MEDIUM && description.isNotEmpty()
    val showMeasures = tier == Tier.LARGE && (height.isNotEmpty() || weight.isNotEmpty())

    val views =
        RemoteViews(context.packageName, layoutFor(tier)).apply {
          setTextViewText(
              R.id.widget_name,
              when {
                name.isNotEmpty() -> name
                dex.isNotEmpty() -> dex
                // Nothing stored yet: the widget says where it comes from
                // rather than inventing a specimen.
                else -> context.getString(R.string.widget_brand)
              },
          )
          setTextViewText(R.id.widget_dex, dex)

          // Compact generation ("Gen I") sits beside the number in every tier.
          if (generation.isEmpty()) {
            setViewVisibility(R.id.widget_gen, View.GONE)
          } else {
            setTextViewText(R.id.widget_gen, generation)
            setViewVisibility(R.id.widget_gen, View.VISIBLE)
          }

          bindTypeChip(this, R.id.widget_type_1, R.id.widget_type_1_text,
              typeNames.getOrNull(0), typeColors.getOrNull(0), chipFallback)
          bindTypeChip(this, R.id.widget_type_2, R.id.widget_type_2_text,
              typeNames.getOrNull(1), typeColors.getOrNull(1), chipFallback)

          if (showDescription) {
            setTextViewText(R.id.widget_desc, description)
            setViewVisibility(R.id.widget_desc, View.VISIBLE)
          } else {
            setViewVisibility(R.id.widget_desc, View.GONE)
          }

          setViewVisibility(
              R.id.widget_measures,
              if (showMeasures) View.VISIBLE else View.GONE,
          )
          val showHeight = showMeasures && height.isNotEmpty()
          setViewVisibility(
              R.id.widget_height_block,
              if (showHeight) View.VISIBLE else View.GONE,
          )
          if (showHeight) {
            setTextViewText(R.id.widget_height, height)
          }
          val showWeight = showMeasures && weight.isNotEmpty()
          setViewVisibility(
              R.id.widget_weight_block,
              if (showWeight) View.VISIBLE else View.GONE,
          )
          if (showWeight) {
            setTextViewText(R.id.widget_weight, weight)
          }

          if (artwork != null) {
            setImageViewBitmap(R.id.widget_art, artwork)
          } else {
            setImageViewResource(R.id.widget_art, R.drawable.widget_pokeball)
          }

          setOnClickPendingIntent(R.id.widget_root, openSpecimenIntent(context, widgetId))
        }

    appWidgetManager.updateAppWidget(widgetId, views)
  }

  /**
   * One type badge, in the app's own type colour: a soft tint of the type
   * colour behind type-coloured text (the widget's compact take on the
   * in-app MetaBadge). The tint is applied as the text view's background and
   * clipped to the rounded mask behind it, so only stock RemoteViews calls
   * are used. An unknown type or colour hides the badge instead of guessing.
   */
  private fun bindTypeChip(
      views: RemoteViews,
      chipId: Int,
      textId: Int,
      label: String?,
      color: Int?,
      fallback: Int,
  ) {
    if (label.isNullOrEmpty()) {
      views.setViewVisibility(chipId, View.GONE)
      return
    }
    val accent = color ?: fallback
    views.setViewVisibility(chipId, View.VISIBLE)
    views.setTextViewText(textId, label)
    views.setInt(textId, "setBackgroundColor", (CHIP_FILL_ALPHA shl 24) or (accent and 0x00FFFFFF))
    views.setTextColor(textId, accent)
  }

  /**
   * Which of the published sizes to draw. A launcher that only leaves one
   * row of cells gets the compact banner (identity only, no description or
   * measurements) so nothing overlaps or is cut off; everything else follows
   * the small -> medium -> large progression the app documents.
   */
  private fun tierFor(minWidth: Int, minHeight: Int): Tier =
      when {
        minHeight < COMPACT_MAX_HEIGHT -> Tier.COMPACT
        minWidth >= LARGE_MIN_WIDTH && minHeight >= LARGE_MIN_HEIGHT -> Tier.LARGE
        minWidth >= MEDIUM_MIN_WIDTH -> Tier.MEDIUM
        else -> Tier.SMALL
      }

  private fun layoutFor(tier: Tier): Int =
      when (tier) {
        Tier.COMPACT -> R.layout.widget_specimen_compact
        Tier.SMALL -> R.layout.widget_specimen_small
        Tier.MEDIUM -> R.layout.widget_specimen_medium
        Tier.LARGE -> R.layout.widget_specimen_large
      }

  /// Opens the app on today's Specimen of the Day. `MainActivity` holds the
  /// extra until Dart asks for it, so both cold and warm taps land in the
  /// same place.
  private fun openSpecimenIntent(context: Context, widgetId: Int): PendingIntent {
    val intent =
        Intent(context, MainActivity::class.java).apply {
          putExtra(MainActivity.EXTRA_ROUTE, MainActivity.ROUTE_SPECIMEN)
          addFlags(
              Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_CLEAR_TOP or
                  Intent.FLAG_ACTIVITY_SINGLE_TOP
          )
        }
    return PendingIntent.getActivity(
        context,
        widgetId,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  /// Decodes the cached artwork down to roughly [maxPx] on its longest edge so
  /// three widget instances never inflate full-size official artwork.
  private fun decodeArtwork(path: String?, maxPx: Int): android.graphics.Bitmap? {
    if (path.isNullOrBlank()) {
      return null
    }
    val file = File(path)
    if (!file.exists()) {
      return null
    }
    return try {
      val bounds =
          BitmapFactory.Options().apply {
            inJustDecodeBounds = true
            inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
          }
      BitmapFactory.decodeFile(file.absolutePath, bounds)
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        return null
      }
      var sampleSize = 1
      while (bounds.outWidth / sampleSize > maxPx || bounds.outHeight / sampleSize > maxPx) {
        sampleSize *= 2
      }
      BitmapFactory.decodeFile(
          file.absolutePath,
          BitmapFactory.Options().apply { inSampleSize = sampleSize },
      )
    } catch (e: Exception) {
      // A corrupt or unreadable file must degrade to the placeholder.
      null
    }
  }

  private fun parseColor(value: String): Int? =
      try {
        android.graphics.Color.parseColor(value.trim())
      } catch (e: IllegalArgumentException) {
        null
      }

  enum class Tier { COMPACT, SMALL, MEDIUM, LARGE }

  companion object {
    /// Must stay in sync with `WidgetKeys` in `lib/features/widgets/specimen_widget_sync.dart`.
    private const val KEY_NAME = "pokepod.widget.name"
    private const val KEY_DEX = "pokepod.widget.dex"
    private const val KEY_TYPES = "pokepod.widget.types"
    private const val KEY_TYPE_COLORS = "pokepod.widget.typeColors"
    private const val KEY_GENERATION = "pokepod.widget.generation"
    private const val KEY_DESCRIPTION = "pokepod.widget.description"
    private const val KEY_HEIGHT = "pokepod.widget.height"
    private const val KEY_WEIGHT = "pokepod.widget.weight"
    private const val KEY_ART_PATH = "pokepod.widget.artPath"

    private const val MAX_ARTWORK_PX = 320

    /// How much of the card background shows through a type badge.
    private const val CHIP_FILL_ALPHA = 0x26

    private const val TYPE_SEPARATOR = " · "

    private const val COMPACT_MAX_HEIGHT = 96
    private const val MEDIUM_MIN_WIDTH = 220
    private const val LARGE_MIN_WIDTH = 300
    private const val LARGE_MIN_HEIGHT = 250
  }
}
