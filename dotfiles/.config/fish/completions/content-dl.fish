# content-dl: its options and yt-dlp's browsers for --browser. As bash's in bashrc/35-completions.
complete -c content-dl --no-files
complete -c content-dl -l audio -d 'Audio only'
complete -c content-dl -l browser -x -a 'brave chrome chromium edge firefox opera safari vivaldi whale' -d "The browser's cookies"
