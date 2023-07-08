# wtfos tests

Run monitor.sh to automatically monitor for reboots and log them during a long duration recording test

More specifically it:

- monitors for reboots
- dumps kmsg.log and fatal.log
- monitos for oomkills and the sort (kmsg.log_triggers.txt)
- periodically cleans the SD card to avoid SD Slow errors