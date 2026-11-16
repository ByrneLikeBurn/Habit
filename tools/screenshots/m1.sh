#!/bin/zsh
# Milestone 1 screenshots. Deterministic: pinned simulator, fixture store, frozen clock
# (Saturday 14 November 2026, 09:41, London), animations off, fixed status bar.
# Usage: tools/screenshots/m1.sh   (run from the repo root)
set -e
DEVICE_NAME="iPhone 17 Pro"
RUNTIME="iOS 26.5"   # the screenshots in the repo were taken on this runtime
OUT=docs/screenshots/m1
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

for look in light:paper dark:ink; do
  appearance=${look%%:*}; tag=${look##*:}
  shot "today-$tag"          $appearance large disabled -fixture today
  shot "today-all-done-$tag" $appearance large disabled -fixture all-done
  shot "first-run-$tag"      $appearance large disabled -fixture empty
  shot "none-today-$tag"     $appearance large disabled -fixture none-today -screen notScheduled
  shot "not-scheduled-$tag"  $appearance large disabled -fixture today -screen notScheduled
  shot "undo-$tag"           $appearance large disabled -fixture today -screen undo
  shot "new-$tag"            $appearance large disabled -fixture today -screen new
  shot "new-count-$tag"      $appearance large disabled -fixture today -screen newCount
  shot "count-$tag"          $appearance large disabled -fixture today -screen count
  shot "edit-$tag"           $appearance large disabled -fixture today -screen edit
  shot "you-$tag"            $appearance large disabled -fixture today -screen you
  shot "appearance-$tag"     $appearance large disabled -fixture today -screen appearance
  shot "archived-$tag"       $appearance large disabled -fixture today -screen archived
  shot "marks-$tag"          $appearance large disabled -fixture today -screen marks
  shot "today-contrast-$tag" $appearance large enabled  -fixture today
done
for screen in today new count edit you appearance; do
  args=(-fixture today); [[ $screen != today ]] && args+=(-screen $screen)
  shot "ax5-$screen-paper" light accessibility-extra-extra-extra-large disabled $args
done
shot "ax5-undo-long-paper" light accessibility-extra-extra-extra-large disabled -fixture today -screen undoLong
shot "ax5-contrast-today-ink" dark accessibility-extra-extra-extra-large enabled -fixture today

xcrun simctl ui "$SIM" content_size large
xcrun simctl ui "$SIM" increase_contrast disabled
xcrun simctl ui "$SIM" appearance light
