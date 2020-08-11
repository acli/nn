nn-6.7.3 with minimal changes to make it compilable
===================================================

This is a version of nn-6.7.3 with the fewest possible changes to make it compilable on a modern Linux.
Only four files have been patched:
Essentially getline() has been renamed
and single backslashes in xmakefile hve been replaced with double ones
(xmakefile is a cpp-based template,
so backslash-newlines expand to newlines;
to keep the backslashes the backslashes must themselves be escaped).

nn is completely unusable for all newsgroups that contain UTF-8.
In 2020 pretty much all newsgroups contain UTF-8,
so nn is now pretty much useless.
At one point –
maybe after I’ve gotten trn’s UTF-8 support in a reasonable enough shape –
I might start trying to figure out how to fix this.

The original README from 6.7.3 is in [README](README).
