#!/bin/zsh
# Milestone 3 screenshots. Deterministic: pinned simulator, fixture store, frozen clock
# (Saturday 14 November 2026, 09:41, London), animations off, fixed status bar.
# Usage: tools/screenshots/m3.sh [only-name-prefix]   (run from the repo root)
set -e
# Another device may be named for its own shots, but only into its own folder, so the iPhone shots
# are never overwritten: DEVICE_NAME="iPad Air 11-inch (M4)" OUT=/some/folder tools/screenshots/m3.sh
if [[ -n "${DEVICE_NAME:-}" && -z "${OUT:-}" ]]; then echo "Set OUT when DEVICE_NAME is set"; exit 1; fi
DEVICE_NAME=${DEVICE_NAME:-"iPhone 17 Pro"}
RUNTIME="iOS 26.5"   # the screenshots in the repo were taken on this runtime
OUT=${OUT:-docs/screenshots/m3}
ONLY=${1:-}
APP=DerivedData/Build/Products/Debug-iphonesimulator/Habit.app
SIM=$(xcrun simctl list devices available | sed -n "/-- $RUNTIME --/,/^--/p" | /usr/bin/grep -m1 "    $DEVICE_NAME (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$SIM" ]] || { echo "No $DEVICE_NAME on $RUNTIME"; exit 1; }

xcodebuild -scheme Habit -destination "id=$SIM" -derivedDataPath DerivedData build -quiet
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b > /dev/null
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install "$SIM" "$APP"
mkdir -p "$OUT"

shot() {   # name appearance size contrast args...
  local name=$1 appearance=$2 size=$3 contrast=$4; shift 4
  [[ -z "$ONLY" || $name == $ONLY* ]] || return 0
  xcrun simctl ui "$SIM" appearance "$appearance"
  xcrun simctl ui "$SIM" content_size "$size"
  xcrun simctl ui "$SIM" increase_contrast "$contrast"
  xcrun simctl terminate "$SIM" dev.byrnelikeburn.Habit 2>/dev/null || true
  # Language and region are pinned, so numbers and dates do not follow the Mac.
  xcrun simctl launch "$SIM" dev.byrnelikeburn.Habit -AppleLanguages "(en)" -AppleLocale en_GB "$@" > /dev/null
  sleep 4
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" > /dev/null 2>&1
  # JPEG at half size keeps the public repo small.
  sips -Z 1311 -s format jpeg -s formatOptions 70 "$OUT/$name.png" --out "$OUT/$name.jpg" > /dev/null
  rm "$OUT/$name.png"
  echo "$OUT/$name.jpg"
}

# Pausing: Today in each pause state, the row menu's pause, Edit, You, Pause for dates and its form, Bring back.
for look in light:paper dark:ink; do
  appearance=${look%%:*}; tag=${look##*:}
  shot "today-paused-$tag"        $appearance large disabled -fixture paused
  shot "today-paused-today-$tag"  $appearance large disabled -fixture paused-today
  shot "today-one-paused-$tag"    $appearance large disabled -fixture one-paused
  shot "today-all-archived-$tag"  $appearance large disabled -fixture all-archived
  shot "you-gentle-$tag"          $appearance large disabled -fixture paused -screen you
  shot "pause-dates-$tag"         $appearance large disabled -fixture paused -screen pauseDates
  shot "pause-form-new-$tag"      $appearance large disabled -fixture paused -screen pauseDatesNew
  shot "pause-form-$tag"          $appearance large disabled -fixture paused -screen pauseForm
  shot "edit-paused-$tag"         $appearance large disabled -fixture one-paused -screen editPaused
  shot "edit-pause-$tag"          $appearance large disabled -fixture today -screen edit
  shot "bring-back-$tag"          $appearance large disabled -fixture one-paused -screen bringBack
  shot "marks-$tag"               $appearance large disabled -fixture today -screen marks
  shot "detail-paused-$tag"       $appearance large disabled -fixture paused -screen detailMonth
done
for name in paused paused-today one-paused; do
  shot "ax5-today-$name-paper" light accessibility-extra-extra-extra-large disabled -fixture $name
done
shot "ax5-you-gentle-paper" light accessibility-extra-extra-extra-large disabled -fixture paused -screen you
shot "ax5-pause-form-paper" light accessibility-extra-extra-extra-large disabled -fixture paused -screen pauseForm
shot "ax5-edit-paused-paper" light accessibility-extra-extra-extra-large disabled -fixture one-paused -screen editPaused
shot "contrast-today-paused-paper" light large enabled -fixture paused
shot "contrast-today-paused-ink" dark large enabled -fixture paused

xcrun simctl ui "$SIM" content_size large
xcrun simctl ui "$SIM" increase_contrast disabled
xcrun simctl ui "$SIM" appearance light
