#!/bin/zsh
# Milestone 2 screenshots. Deterministic: pinned simulator, fixture store, frozen clock
# (Saturday 14 November 2026, 09:41, London), animations off, fixed status bar.
# Usage: tools/screenshots/m2.sh [only-name-prefix]   (run from the repo root)
set -e
# Another device may be named for its own shots, but only into its own folder, so the iPhone shots
# are never overwritten: DEVICE_NAME="iPad Air 11-inch (M4)" OUT=/some/folder tools/screenshots/m2.sh
if [[ -n "${DEVICE_NAME:-}" && -z "${OUT:-}" ]]; then echo "Set OUT when DEVICE_NAME is set"; exit 1; fi
DEVICE_NAME=${DEVICE_NAME:-"iPhone 17 Pro"}
RUNTIME="iOS 26.5"   # the screenshots in the repo were taken on this runtime
OUT=${OUT:-docs/screenshots/m2}
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

for look in light:paper dark:ink; do
  appearance=${look%%:*}; tag=${look##*:}
  shot "history-week-$tag"     $appearance large disabled -fixture today -screen history
  shot "history-month-$tag"    $appearance large disabled -fixture today -screen historyMonth
  shot "history-empty-$tag"    $appearance large disabled -fixture empty -screen history
  shot "detail-week-$tag"      $appearance large disabled -fixture today -screen detailWeek
  shot "detail-month-$tag"     $appearance large disabled -fixture today -screen detailMonth
  shot "detail-year-$tag"      $appearance large disabled -fixture today -screen detailYear
  shot "detail-runs-$tag"      $appearance large disabled -fixture today -screen detailRuns -showRuns
  shot "detail-empty-$tag"     $appearance large disabled -fixture today -screen detailEmpty
  shot "day-$tag"              $appearance large disabled -fixture today -screen day
  shot "day-done-$tag"         $appearance large disabled -fixture today -screen dayDone
  shot "day-off-$tag"          $appearance large disabled -fixture today -screen dayOff
  shot "day-count-$tag"        $appearance large disabled -fixture today -screen dayCount
  shot "you-$tag"              $appearance large disabled -fixture today -screen you
  shot "export-$tag"           $appearance large disabled -fixture today -screen export
  shot "import-preview-$tag"   $appearance large disabled -fixture today -screen importPreview
  shot "import-done-$tag"      $appearance large disabled -fixture today -screen importDone
  shot "import-nothing-$tag"   $appearance large disabled -fixture today -screen importNothing
  shot "import-not-habit-$tag" $appearance large disabled -fixture today -screen importNotHabit
  shot "import-newer-$tag"     $appearance large disabled -fixture today -screen importNewer
  shot "first-run-$tag"        $appearance large disabled -fixture empty
done

for screen in history historyMonth detailWeek detailMonth detailYear dayCount you; do
  shot "ax5-$screen-paper" light accessibility-extra-extra-extra-large disabled -fixture today -screen $screen
done
# Show days not logged on, in every view that draws the empty outline.
for screen in history historyMonth detailWeek detailMonth detailYear; do
  shot "notlogged-$screen-paper" light large disabled -fixture today -screen $screen -showDaysNotLogged
done
# A habit with no set days ("Practise guitar"), in Today, History month and Habit detail.
for appearance in light dark; do
  tag=$([ $appearance = light ] && echo paper || echo ink)
  shot "nodays-today-$tag"         $appearance large disabled -fixture no-days
  shot "nodays-history-month-$tag" $appearance large disabled -fixture no-days -screen historyMonth
  shot "nodays-detail-year-$tag"   $appearance large disabled -fixture no-days -screen detailYear
  shot "nodays-detail-week-$tag"   $appearance large disabled -fixture no-days -screen detailRuns -showRuns
  shot "ax5-nodays-today-$tag"     $appearance accessibility-extra-extra-extra-large disabled -fixture no-days
done
# New habit and Edit habit, at the standard size, the largest size and with Increase Contrast.
for appearance in light dark; do
  tag=$([ $appearance = light ] && echo paper || echo ink)
  shot "form-new-$tag"       $appearance large disabled -fixture today -screen new
  shot "form-new-count-$tag" $appearance large disabled -fixture today -screen newCount
  shot "form-edit-$tag"      $appearance large disabled -fixture today -screen edit
  shot "form-symbols-$tag"   $appearance large disabled -fixture no-days -screen symbols
  shot "form-symbols-new-$tag" $appearance large disabled -fixture today -screen symbolsNew
  shot "form-edit-nodays-$tag" $appearance large disabled -fixture no-days -screen edit
  shot "form-edit-waits-$tag"  $appearance large disabled -fixture today -screen editWaits
  shot "ax5-form-new-$tag"   $appearance accessibility-extra-extra-extra-large disabled -fixture today -screen new
  shot "ax5-form-edit-$tag"  $appearance accessibility-extra-extra-extra-large disabled -fixture today -screen edit
  shot "ax5-form-days-$tag"  $appearance accessibility-extra-extra-extra-large disabled -fixture today -screen editDays
  shot "contrast-form-edit-$tag" $appearance large enabled -fixture today -screen edit
done
shot "contrast-history-paper" light large enabled -fixture today -screen history
shot "contrast-detail-month-ink" dark large enabled -fixture today -screen detailMonth

xcrun simctl ui "$SIM" content_size large
xcrun simctl ui "$SIM" increase_contrast disabled
xcrun simctl ui "$SIM" appearance light
