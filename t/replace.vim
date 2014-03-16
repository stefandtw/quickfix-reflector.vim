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
