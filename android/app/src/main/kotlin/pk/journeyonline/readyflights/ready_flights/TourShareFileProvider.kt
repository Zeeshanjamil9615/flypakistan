package pk.journeyonline.readyflights.ready_flights

import androidx.core.content.FileProvider

/**
 * Exposes downloaded tour photos (cache/tour_shares/) to WhatsApp.
 * Its own subclass so it never clashes with a plugin's FileProvider entry
 * during manifest merging.
 */
class TourShareFileProvider : FileProvider()
