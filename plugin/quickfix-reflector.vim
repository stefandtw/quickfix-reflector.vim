" necessary for using '\' line-continuation when starting vim -U NONE
let s:originalCpo = &cpo
set cpo&vim

if !exists("g:qf_modifiable")
  let g:qf_modifiable = 1
endif

if !exists("g:qf_join_changes")
  let g:qf_join_changes = 0
endif

if !exists("g:qf_write_changes")
  let g:qf_write_changes = 1
endif

let s:regexpEngine = '\%#=1'
if v:version < 704
	let s:regexpEngine = ''
endif

augroup quickfix_reflector
	autocmd!
	autocmd BufReadPost quickfix nested :call <SID>OnQuickfixInit()
augroup END

function! s:OnQuickfixInit()
	if &filetype !=# 'qf' || !&write
		return
	endif
	execute 'augroup quickfix_reflector_' . bufnr('%')
		autocmd!
		execute 'autocmd BufWriteCmd quickfix-' . bufnr('%') . ' :call <SID>OnWrite()'
	augroup END
	" Set a file name for the buffer. This makes it possible to write the
	" buffer using :w, :x and other built-in commands.
	execute 'write! quickfix-' .  bufnr('%')
	call s:PrepareBuffer()
endfunction

function! s:PrepareBuffer()
	if g:qf_modifiable == 1
	  setlocal modifiable
	endif
	let s:qfBufferLines = getline(1, '$')
endfunction

function! s:OnWrite()
	if !&modified
		return
	endif
	let qfBufferLines = copy(s:qfBufferLines)
	let isLocationList = len(getloclist(0)) > 0
	let qfWinNumber = winnr()

	" Get quickfix entries and create search patterns to find them again after
	" they have been changed in the quickfix buffer
	let qfList = s:getQfOrLocationList(isLocationList, qfWinNumber)
	let changes = []
	let entryIndex = 0
	for entry in qfList
		" Now find the line in the buffer using the quickfix description.
		" Then use that line to create a pattern without that text so we can find
		" the entry again after it has changed
		" 
		" Vim sometimes does not display the full line if it's very long
		if strchars(entry.text) > 180
			let qfDescription = matchstr(entry.text, '\v.{180}')
		else
			let qfDescription = entry.text
		endif
		let qfDescriptionTrimmed = substitute(qfDescription, '\v^\s*', '', '')
		let qfDescriptionEscaped = escape(qfDescriptionTrimmed, '/\')
		let patternForOriginalEntry = '\C\v^(.*)\V' . qfDescriptionEscaped . '\v(.*)$'
		let matchList = matchlist(qfBufferLines, patternForOriginalEntry)
		" If there are multiple entries with the same description text we only
		" want to use an entry once. So remove the matched line from the
		" bufferLines we search through.
		call remove(qfBufferLines, index(qfBufferLines, matchList[0]))
		" Make a search pattern that will find a changed version of the line
		let entry.markerPattern = '\C\V\^' . escape(matchList[1], '/\')
		if entry.valid == 0
			let entry.markerPattern = patternForOriginalEntry
		endif
		let entry.markerPatternForChanges = '\C\V\^' . escape(matchList[1], '/\') . '\(' . qfDescriptionEscaped . escape(matchList[2], '/\') . '\$' . '\)\@\!\(\.\*\)\$'

		" Now use the search patterns in the changed buffer
		let lineNumberForChange = search(entry.markerPatternForChanges, 'cnw')
		if lineNumberForChange && entry.valid == 1
			let change = {}
			let change.qfEntry = entry
			let changeMatchList = matchlist(getline(lineNumberForChange), entry.markerPatternForChanges)
			let change.originalFromQf = qfDescriptionTrimmed . matchList[2]
			let change.replacementFromQf = changeMatchList[2]
			call add(changes, change)
		endif

		" If we can't find the entry, its line was deleted. In that case, remove
		" the item from Vim's quickfix list so Vim won't get confused with the
		" rest of the lines.
		let lineNumber = search(entry.markerPattern, 'cnw')
		if !lineNumber
			call remove(qfList, entryIndex)
			continue
		endif
		let entry.lineNumber = lineNumber
		" Remove the error number so Vim will keep the new order of the entries.
		call remove(entry, 'nr')

		let entryIndex += 1
	endfor

	let qfWinView = winsaveview()
	call s:Replace(changes)
	call sort(qfList, 's:CompareEntryInBuffer')
	call s:setQfOrLocationList(qfList, isLocationList, qfWinNumber)
	setlocal nomodified
	call winrestview(qfWinView)
	call s:PrepareBuffer()
endfunction

function! s:getQfOrLocationList(isLocationList, winNumber)
	if a:isLocationList
		return getloclist(a:winNumber)
	else
		return getqflist()
	end
endfunction

function! s:setQfOrLocationList(entries, isLocationList, winNumber)
	if a:isLocationList
		call setloclist(a:winNumber, a:entries)
	else
		call setqflist(a:entries)
	end
endfunction

function! s:CompareEntryInBuffer(qfEntry1, qfEntry2)
	return a:qfEntry1.lineNumber - a:qfEntry2.lineNumber
endfunction

function! s:Replace(changes)
	let switchbufOriginal = &switchbuf
	let &switchbuf = ''
	let successfulChanges = 0
	let bufferHasChanged = {}
	let tabPageOriginal = tabpagenr()
	for change in a:changes
		let bufferWasListed = buflisted(change.qfEntry.bufnr)
		execute 'tab sbuffer ' . change.qfEntry.bufnr
		let originalFromQfEscaped = escape(change.originalFromQf, '/\')
		let replacementFromQfEscaped = escape(change.replacementFromQf, '/\')
		let lineInFileEscaped = escape(getline(change.qfEntry.lnum), '/\')
		let commonContext = s:FindCommonContext(originalFromQfEscaped, replacementFromQfEscaped, lineInFileEscaped)
		let commonInQfAndFile = commonContext.original
		let commonInQfAndFile_replacement = commonContext.replacement
		let isUniqueMatchInLine = s:HasSubstringOnce(getline(change.qfEntry.lnum), commonInQfAndFile)
		if strlen(commonInQfAndFile) >= 3 && isUniqueMatchInLine
			if g:qf_join_changes && has_key(bufferHasChanged, change.qfEntry.bufnr)
				undojoin
			endif
			execute change.qfEntry.lnum . 'snomagic/\V' . commonInQfAndFile . '/' . commonInQfAndFile_replacement . '/'
			if g:qf_write_changes == 1
				write
				silent doautocmd User QfReplacementBufWritePost
			endif
			let change.qfEntry.text = change.replacementFromQf
			let successfulChanges += 1
			let bufferHasChanged[change.qfEntry.bufnr] = 1
		else
			let change.qfEntry.text = substitute(change.qfEntry.text, '^\v(\[ERROR\])?', '[ERROR]', '')
		endif
		if !bufferWasListed && g:qf_write_changes == 0
			set buflisted
		endif
		tabclose!
		execute 'silent! tabn' . tabPageOriginal
		if !bufferWasListed && g:qf_write_changes == 1
			execute 'silent! bdelete ' . change.qfEntry.bufnr
		endif
	endfor
	let &switchbuf = switchbufOriginal
	if successfulChanges < len(a:changes)
		echohl WarningMsg
		echomsg successfulChanges . '/' . len(a:changes) . ' changes applied. See lines marked [ERROR].'
		" Echo another line. Without this, the previous warning is sometimes
		" overwritten when replacing something in an open buffer
		echo ''
		echohl None
	endif
endfunction

function! s:FindCommonContext(qfOriginal, qfChangedVersion, lineInFile)
	let startOfChange = 0
	let endOfChange = 0
	let endOfChangeInChangedVersion = 0
	let qfOriginalLength = strlen(a:qfOriginal)
	let qfChangedVersionLength = strlen(a:qfChangedVersion)
	let maxLength = max([qfOriginalLength, qfChangedVersionLength])
	for n in range(maxLength)
		if a:qfOriginal[n] !=# a:qfChangedVersion[n]
			let startOfChange = n
			break
		endif
	endfor
	let qfOriginalReversed = a:qfOriginal 
	let qfChangedVersionReversed = a:qfChangedVersion
	let changedVersionOffset = strlen(a:qfChangedVersion) - strlen(a:qfOriginal)
	for n in range(maxLength)
		if a:qfOriginal[qfOriginalLength - 1 - n] !=# a:qfChangedVersion[qfChangedVersionLength - 1 - n]
			let endOfChange = qfOriginalLength - 1 - n
			let endOfChangeInChangedVersion = qfChangedVersionLength - 1 - n
			break
		endif
	endfor
	let endOfChange = max([endOfChange, startOfChange - changedVersionOffset - 1])
	let minReplacement = s:StringRange(a:qfChangedVersion, startOfChange, endOfChangeInChangedVersion)

	let longest = ''
	let startOfCommonPart = -1
	let endOfCommonPart = -1
	for n in range(strlen(a:qfOriginal))
		" Find the largest common part between the qf entry and the line in the
		" file
		" We need the old regex engine, because the new one doesn't always find the
		" match in this case
		let commonResult = matchlist(strpart(a:qfOriginal, n) . "\n" . a:lineInFile,
			\ s:regexpEngine . '\C\v^(.+).*\n.*\1')
		if commonResult == []
			continue
		endif
		let common = commonResult[1]
		let startIndex = n
		let endIndex = startIndex + strlen(common) - 1
		if strlen(common) > strlen(longest) && startIndex <= startOfChange && endIndex >= endOfChange
			let longest = common
			let startOfCommonPart = startIndex
			let endOfCommonPart = endIndex
		endif
	endfor
	let longestReplacement =
		\ s:StringRange(a:qfOriginal, startOfCommonPart, startOfChange - 1)
		\ . minReplacement
		\ . s:StringRange(a:qfOriginal, endOfChange + 1, endOfCommonPart)
	return {
		\ 'original': longest, 
		\ 'replacement': longestReplacement
		\ }
endfunction

function! s:HasSubstringOnce(string, escapedSubstring)
	return a:string =~# '\V' . a:escapedSubstring . '\(\.\*' . a:escapedSubstring . '\)\@\!'
endfunction

function! s:StringRange(string, startIndex, endIndex)
	return strpart(a:string, a:startIndex, a:endIndex - a:startIndex + 1)
endfunction

let &cpo = s:originalCpo

" vim:ts=2:sw=2:sts=2
