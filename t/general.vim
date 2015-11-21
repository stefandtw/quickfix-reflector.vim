source plugin/quickfix-reflector.vim

describe 'the quickfix window'
	before
		copen
	end

	after
		cclose
		bdelete!
	end

  it 'sets the modified flag'
		Expect &modified == 0
		put! ='i can insert lines'
		Expect &modified != 0
		write
		Expect &modified == 0
  end

  it 'links to the right places even after changing lines (and writing the buffer)'
		vimgrep /^/ t/3-lines.txt
		copen
		1delete
		1delete
		1put
		write
		Expect getline(1) ==# 't/3-lines.txt|3 col 1| line 3'
		Expect getline(2) ==# 't/3-lines.txt|2 col 1| line 2'

		1
		execute "normal! \<CR>"
		Expect bufname('%') ==# 't/3-lines.txt'
		Expect line('.') == 3

		copen
		2
		execute "normal! \<CR>"
		Expect bufname('%') ==# 't/3-lines.txt'
		Expect line('.') == 2
	end

  it 'works in parallel with location list windows'
		wincmd p
		lvimgrep /^/ t/3-lines.txt
		vsplit
		lopen
		wincmd l
		lopen

		" Just making sure there are no errors

		lclose
		quit
		lclose
	end 

  it 'can handle problematic lines'
		vimgrep /^/ t/problematic-lines.txt
		copen
		delete

		write
		" Just making sure there are no errors

	end 

  it 'ignores invalid lines'
		compiler msvc
		cgetfile t/invalid-qf-lines.c.out
		1delete
		1put

		write

		Expect getline(1) ==# '|| Project not selected to build for this solution configuration '
		Expect getline(2) ==# '|| ------ Skipped Build: Project: game_pc, Configuration: Release x64 ------'
		Expect getline(3) ==# '|| file1.cpp'
		Expect getline(7) ==# 'issue5/c.out|15| some text here'
	end 

	it 'opens without error if nowrite is used'
		set nowrite
		vimgrep /^/ t/problematic-lines.txt

		copen

		" no errors
		Expect &modifiable == 0
	end

end

" vim:ts=2:sw=2:sts=2
