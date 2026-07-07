#!/usr/bin/env bash
# ============================================================
#  CLI_Assignment helper — Africahackon C1A
#  Runs each section with a banner, then pauses so you can
#  take the screenshot before moving on.
#
#  Usage:   bash run_assignment.sh
#  NOTE: Sections 3 & 5 need your real shell history — for
#  those, use the paste blocks in commands_to_paste.txt
#  instead (this script prints a reminder when it gets there).

banner() {
  echo
  echo "=============================================================="
  echo "  $1"
  echo "=============================================================="
}

pause_for_shot() {
  echo
  read -rp ">>> Take Screenshot $1 now, then press Enter to continue..."
}

run() {
  # print the command like a prompt line, then execute it
  echo
  echo "\$ $*"
  eval "$@"
}

#Section 1: File System Navigation
banner "SECTION 1: File System Navigation"
run pwd
run ls -la ~
run 'cd /etc && cd ~'
run pwd
pause_for_shot "1 (navigation commands + outputs)"

#Section 2: File & Directory Management
banner "SECTION 2: File & Directory Management"
run mkdir -p ~/cli_test
run mkdir -p ~/cli_test/project1 ~/cli_test/project2 ~/cli_test/project3
run touch ~/cli_test/project1/README.txt
run 'echo "This is a CLI test project" > ~/cli_test/project1/README.txt'
run cp ~/cli_test/project1/README.txt ~/cli_test/project2/
run cp ~/cli_test/project1/README.txt ~/cli_test/project3/
run mv ~/cli_test/project1/README.txt ~/cli_test/project1/PROJECT_INFO.txt
run ls -R ~/cli_test
pause_for_shot "2 (ls -R ~/cli_test)"
run cat ~/cli_test/project1/PROJECT_INFO.txt
pause_for_shot "3 (cat PROJECT_INFO.txt)"

#Section 3: Cleanup
banner "SECTION 3: Cleanup  —  IMPORTANT"
echo "Screenshot 4 must show mv and rm -r in YOUR command history."
echo "Commands run inside this script do NOT enter your history."
echo
echo "  ==> After this script finishes, paste the Section 3 block"
echo "      from commands_to_paste.txt directly into your terminal."
echo "      (The files are still in place — nothing was cleaned up here.)"

#Section 4: System Monitoring
banner "SECTION 4: System Monitoring"
run 'ps aux | head -15'
run free -h
run 'journalctl -n 10 --no-pager || sudo journalctl -n 10 --no-pager'
pause_for_shot "5 (ps aux, free -h, journalctl -n 10)"

#Section 5
banner "SECTION 5: Command History"
echo "Same as Section 3: 'history' only works in your interactive shell."
echo "  ==> Paste the Section 5 block from commands_to_paste.txt"
echo "      into your terminal for Screenshot 6."
echo
echo "All scripted sections done."
