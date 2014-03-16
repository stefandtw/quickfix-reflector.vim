Usage
=====

In the quickfix window, simply edit any entry you like. Once you save the quickfix buffer, your changes will be made in the actual file an entry points to.

You can also delete lines in the quickfix window. This way, you can first review the quickfix list, remove all entries you don't care to change, and then use `%s/foo/bar` (or anything else) on the rest.


Details
=======

* Works in location list windows, too
* The quickfix buffer is now `modifiable`
* The usual write commands can be used (`:w`, `:x` etc.), but they won't save the buffer to a file. Instead they will trigger replacement for any changes you made.
* If you specifically want to save the quickfix buffer to a file, you can still do that the same way as before `:write my_qf_list`
* Adding and removing lines in the quickfix buffer breaks each line's link to Vim's internal quickfix entry. After making such changes, you need to write the quickfix buffer. This will rewrite Vim's internal quickfix list. Otherwise, pressing `<Enter>` may jump to the wrong entry.


Limits to text replacement
==========================

Whenever a replacement fails, you get an '[ERROR]' in the corresponding quickfix entry.

Replacement only works if the text that was modified actually exists in the corresponding text file and line number. So it may fail if the file was modified since the quickfix list was built.

If the quickfix entry contains only part of a line, replacement should work as long as there is a substring of that line with at least three characters.

Example: The quickfix entry `Missing ; at: xyz` can be used to replace in a line `a = xyz`. However, it cannot be used in a line `xyz = 1+xyz` because it is not clear which xyz would need to be replaced


Installation
============

Use [Pathogen](https://github.com/tpope/vim-pathogen), [Vundle](https://github.com/gmarik/Vundle.vim), or your own favorite method.


Development
===========

Run `rake test` for the [vspec](https://github.com/kana/vim-vspec) tests.

To get the test environment working you need to
* install ruby
* `gem install bundler`
* `bundle install`

More details [here](http://whileimautomaton.net/2013/02/08211255).
