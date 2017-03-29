" Author: Joshua Rubin <joshua@rubixconsulting.com>, Ryan Norris <rynorris@gmail.com>
" Description: go build for Go files

" inspired by work from dzhou121 <dzhou121@gmail.com>

function! s:ThisFile(buffer) abort
    return fnamemodify(bufname(a:buffer), ':p:t')
endfunction

function! s:ThisPackage(buffer) abort
    return fnamemodify(bufname(a:buffer), ':p:h')
endfunction

function! s:FilesToBuild(buffer) abort
    " Get absolute path to the directory containing the current file.
    " This directory by definition contains all the files for this go package.
    let l:this_package = s:ThisPackage(a:buffer)

    " Get a listing of all go files in the directory.
    let l:all_files = globpath(l:this_package, '*.go', 1, 1)

    return l:all_files
endfunction

function! ale_linters#go#gobuild#Install(buffer) abort
    let l:files_to_build = s:FilesToBuild(a:buffer)
    let l:file_args = join(map(l:files_to_build, 'fnameescape(v:val)'))
    return 'go test -i '
endfunction

function! ale_linters#go#gobuild#Build(buffer, any) abort
    let l:files_to_build = s:FilesToBuild(a:buffer)
    let l:file_args = join(map(l:files_to_build, 'fnameescape(v:val)'))
    return 'go test -c ' . ' -o /dev/null ' . l:file_args
endfunction

let s:path_pattern = '[a-zA-Z]\?\\\?:\?[[:alnum:]/\.\-_]\+'
let s:handler_pattern = '^\(' . s:path_pattern . '\):\(\d\+\):\?\(\d\+\)\?: \(.\+\)$'

function! s:FilterLines(buffer, lines) abort
    let l:this_file = s:ThisFile(a:buffer)

    let l:filtered_lines = []

    for l:line in a:lines
      " Get the filename from the line.
      let l:match = matchlist(l:line, s:handler_pattern)
      if len(l:match) == 0
        continue
      endif

      let l:line_file = get(l:match, 1)

      " Since we can only get errors for files in the package directory, just
      " compare basenames.
      if fnamemodify(l:this_file, ':p:t') == fnamemodify(l:line_file, ':p:t')
        call add(l:filtered_lines, l:line)
      endif
    endfor

    return l:filtered_lines
endfunction

function! ale_linters#go#gobuild#Handler(buffer, lines) abort
    " Just filter out any lines not for this buffer and then drop back to the
    " standard Unix format handler.
    return ale#handlers#HandleUnixFormatAsError(a:buffer, s:FilterLines(a:buffer, a:lines))
endfunction

call ale#linter#Define('go', {
\   'name': 'go build',
\   'executable': 'go',
\   'output_stream': 'stderr',
\   'read_buffer': 0,
\   'command_chain': [
\       {'callback': 'ale_linters#go#gobuild#Install'},
\       {'callback': 'ale_linters#go#gobuild#Build'}
\   ],
\   'callback': 'ale_linters#go#gobuild#Handler',
\})
