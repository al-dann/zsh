# ~/.config/zsh/.zprofile
#
# Login shells only. On macOS, /etc/zprofile has just run path_helper, which
# reorders PATH with the system dirs first; put our entries back in front.

[[ $OSTYPE == darwin* ]] && (( $+functions[_zsh_setup_path] )) && _zsh_setup_path
