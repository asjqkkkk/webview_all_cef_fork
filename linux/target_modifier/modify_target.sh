#!/bin/bash

# Will be something like /home/test/flutter_projects/example
program_path="${PWD%%/build/linux/*}"

# Will be the path of this script
scriptdir=$(cd $(dirname $0); pwd -P)

echo "Modifying target cc files..."

# Flutter 3.16+ moves runner sources into linux/runner. Fall back to linux/ for
# older templates so the plugin works across Flutter versions.
target_dir="$program_path/linux"
if [ -f "$program_path/linux/runner/my_application.cc" ]; then
  target_dir="$program_path/linux/runner"
fi

bash $scriptdir/tools/import_webview_cef_header_my_application.sh "$target_dir/my_application.cc"
bash $scriptdir/tools/add_key_release_event_to_my_application.sh "$target_dir/my_application.cc"
bash $scriptdir/tools/add_key_press_event_to_my_application.sh "$target_dir/my_application.cc"

bash $scriptdir/tools/import_webview_cef_header_main.sh "$target_dir/main.cc"
bash $scriptdir/tools/add_webview_init_to_main.sh "$target_dir/main.cc"
