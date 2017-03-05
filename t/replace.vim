source plugin/quickfix-reflector.vim

describe 'changing quickfix entries'
	before
	end

	after
		cclose
		bdelete!
	end

	it 'replaces a letter'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/Line 1/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'adds a word'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/line 1 word/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'replaces multiple lines'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1//
		2substitute/line 2/Completely different text/
		3snomagic/line 3/#"4m´@!§$%&漢\/=?`{[]}~#;.^\| (line 3)/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# ''
		Expect getline(2) ==# 'Completely different text'
		Expect getline(3) ==# '#"4m´@!§$%&漢/=?`{[]}~#;.^| (line 3)'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'keeps the changed version after a write'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/Line 1 word/
		write
		Expect getline(1) =~# '\v\| Line 1 word$'
		call delete(tmpFile)
	end

	it 'works with error messages from compilers'
		let tmpFile = CreateTmpFile('t/code.js')
		let qfEntry = CreateQfEntry(tmpFile, 1, "Missing '(' at Bla.prototype.foo = function) { // here is a comment ")
		call setqflist([qfEntry])
		copen
		1substitute/function/function(/
		1substitute/foo/bar/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# '	Bla.prototype.bar = function() { // here is a comment'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'works with special characters'
		let tmpFile = CreateTmpFile('t/special-characters.txt')
		let qfEntry = CreateQfEntry(tmpFile, 1, '|a|b|c|^	~|d|e|f|')
		call setqflist([qfEntry])
		copen
		1substitute/\V^/|line|1|with|more|pipes||^/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# '|line|1|with|more|pipes||^	~||#"4m´@!§$%&漢\/=?`[{]}~#;.^\|)(|$'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'marks changed lines that could not be replaced'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		let qfEntry = CreateQfEntry(tmpFile, 1, 'li')
		call setqflist([qfEntry])
		copen
		1substitute/li/ri/
		write
		Expect getline(1) =~# '\V[ERROR]\v.*li$'
		call delete(tmpFile)
	end

	it 'replaces using the location list'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'lvimgrep /^/j ' . tmpFile
		lopen
		1substitute/line 1/line 1 word/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
		lclose
	end

	it 'does not close buffers that were visible before'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/ ' . tmpFile
		copen
		1substitute/line 1/line 1 word/
		write
		wincmd p
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		call delete(tmpFile)
	end

	it 'replaces lines even if the qf buffer is written using wall from another buffer'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/ ' . tmpFile
		copen
		1substitute/line 1/line 1 word/
		execute "normal! \<CR>"
		wall
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'replaces the same line multiple times if there are multiple quickfix entries'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /\v(li|ne)\ze.* 1/jg ' . tmpFile
		copen
		1substitute/line 1/line 1 word/
		2substitute/line 1/line 1 another/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 another word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'replaces similar characters at the beginning'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /line 1/j ' . tmpFile
		copen
		1substitute/line/222line/
		write
		1substitute/222line/2line/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# '2line 1'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'replaces similar characters at the end'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /line 1/j ' . tmpFile
		copen
		1substitute/$/222/
		write
		1substitute/22$//
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 12'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'replaces similar characters at the beginning and end'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /line 1/j ' . tmpFile
		copen
		1substitute/line 1/222line 1222/
		write
		1substitute/222line 1222/2line 12/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# '2line 12'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'changes lower case letters to upper case even if ignorecase is set'
		set ignorecase
		set smartcase
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /line 1/j ' . tmpFile
		copen
		1substitute/line/LINE/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'LINE 1'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	it 'works if switchbuf is set and buffer is open'
		let &switchbuf = 'useopen'
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		split tmpFile
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/Line 1/
		write
		execute "normal! \<CR>"
		Expect getline(1) ==# 'Line 1'
		Expect &switchbuf == 'useopen'
		call delete(tmpFile)
	end

	it 'makes individually undoable changes'
		" Require 'undofile' so that changes may be undone after writing the file.
		set undofile
		let g:qf_join_changes = 0
		let tmpFile1 = CreateTmpFile('t/3-lines.txt')
		let tmpFile2 = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile1 . ' ' . tmpFile2
		copen
		%substitute/line/Line/
		write
		normal gg
		execute "normal! \<CR>"
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'Line 3'
		undo
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'line 3'
		cnfile!
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'Line 3'
		undo
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'line 3'
		call delete(tmpFile1)
		call delete(tmpFile2)
	end

	it 'joins changes'
		set undofile
		let g:qf_join_changes = 1
		let tmpFile1 = CreateTmpFile('t/3-lines.txt')
		let tmpFile2 = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile1 . ' ' . tmpFile2
		copen
		%substitute/line/Line/
		write
		normal gg
		execute "normal! \<CR>"
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'Line 3'
		undo
		Expect getline(1) ==# 'line 1'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		cnfile!
		Expect getline(1) ==# 'Line 1'
		Expect getline(2) ==# 'Line 2'
		Expect getline(3) ==# 'Line 3'
		undo
		Expect getline(1) ==# 'line 1'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		call delete(tmpFile1)
		call delete(tmpFile2)
	end

	it 'does not write their buffers if option is set'
		let g:qf_write_changes = 0
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/Line 1 word/
		write
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'Line 1 word'
		Expect &modified == 1
		bdelete!
		execute 'edit ' . tmpFile
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1'
		call delete(tmpFile)
		let g:qf_write_changes = 1
	end

  it 'works for problematic lines'
		let tmpFile = CreateTmpFile('t/problematic-lines.txt')
		execute 'vimgrep /^/ ' . tmpFile
		let originalLength1 = strchars(getline(1))
		let originalLength2 = strchars(getline(2))
		copen
		normal AHello
		normal jAHello
		write
		execute "normal! \<CR>"
		Expect getline(1) =~# '\v^.+Hello.+$'
		Expect getline(1) =~# '\v^.{' . (originalLength1 + len('Hello')) . '}$'
		Expect getline(2) =~# '\v^.+Hello$'
		Expect getline(2) =~# '\v^.{' . (originalLength2 + len('Hello')) . '}$'
	end 

  it 'does not remove space at the start of the line'
		let tmpFile = CreateTmpFile('t/lines-with-space.txt')
		execute 'vimgrep /^/ ' . tmpFile
		let original1 = getline(1)
		let original2 = getline(2)
		let original3 = getline(3)
		copen
		normal A:)
		normal jA:)
		normal jA:)
		write
		execute "normal! \<CR>"
		Expect getline(1) == original1 . ':)'
		Expect getline(2) == original2 . ':)'
		Expect getline(3) == original3 . ':)'
	end 


  it 'triggers QfReplacementBufWritePost'
		let tmpFile1 = CreateTmpFile('t/3-lines.txt')
		let tmpFile2 = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^line 1/ ' . tmpFile1 . ' ' . tmpFile2
		let g:triggered = 0
		autocmd User QfReplacementBufWritePost :let g:triggered += 1
		copen
		normal A:)
		normal jA:)
		write
		Expect g:triggered == 2
		call delete(tmpFile1)
		call delete(tmpFile2)
	end 

	it 'does not mind open tabs'
		tabnew
		tabnew
		tabprevious
		let tmpFile = CreateTmpFile('t/3-lines.txt')
		execute 'vimgrep /^/j ' . tmpFile
		copen
		1substitute/line 1/line 1 word/
		write
		Expect &modified == 0
		execute "normal! \<CR>"
		Expect expand('%:p') ==# tmpFile
		Expect getline(1) ==# 'line 1 word'
		Expect getline(2) ==# 'line 2'
		Expect getline(3) ==# 'line 3'
		Expect &modified == 0
		call delete(tmpFile)
	end

	function! CreateTmpFile(source)
		let tmpFile = tempname()
		execute 'edit ' . tmpFile
		execute 'read ' . a:source
		write
		bdelete
		return tmpFile
	endfunction

	function! CreateQfEntry(filename, lnum, text)
		return {
					\ 'filename': a:filename,
					\ 'lnum': a:lnum,
					\ 'text': a:text
					\	}
	endfunction

end

" vim:ts=2:sw=2:sts=2
