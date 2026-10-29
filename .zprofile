# ~/.config/zsh/.zprofile
#
# Login shells only. On macOS, /etc/zprofile has just run path_helper, which
# reorders PATH with the system dirs first; put our entries back in front, then
# re-read local.zshenv so the entries it adds come first again too (it holds
# variables only, so reading it twice is safe).

if [[ $OSTYPE == darwin* ]] && (( $+functions[_zsh_setup_path] )); then
  _zsh_setup_path
  _zlocal=( "$ZDOTDIR"/local.zshenv(N.U^IW) ); (( $#_zlocal )) && source "$_zlocal[1]"; unset _zlocal
fi
