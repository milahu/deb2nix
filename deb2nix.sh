#! /usr/bin/env bash

set -e
#set -x # trace



# note: currently, this path is hard-coded in apt-init-config
APT_CONFIG="$HOME/.config/apt/apt.conf"

if [ "$(id -u)" = 0 ]; then
  # if apt-init-config is run by root
  # then it writes the system-wide apt.conf
  APT_CONFIG="/etc/apt/apt.conf"
fi



# the dir_state_lists path is speciied in apt.conf
# but its non-trivial to parse apt.conf
# in a perl script like apt-file, i could use
#   use AptPkg::Config '$_config';
#   my $dir_state_lists = $_config->get_file('Dir::State::lists');

dir_state_lists="$HOME/.lib/apt/lists"

# TODO the filename can be different
# depending on APT::Default-Release in apt.conf
all_contents_path="$dir_state_lists/deb.debian.org_debian_dists_unstable_main_Contents-all.lz4"

nix_index_files_path="$HOME/.cache/nix-index/files"

update_max_age=$((60 * 60 * 24 * 10)) # 10 days



function file_needs_update() {
  # of not exists or is too old
  if
    ! [ -e "$1" ] ||
    (( ( $(date --utc +%s) - $(TZ=UTC stat -c%Y "$1") ) > update_max_age ))
  then
    echo "updating $1" >&2
    if [ -e "$1" ]; then
      echo "old version:" >&2
      stat "$1" >&2
    fi
    return 0 # true
  fi
  return 1 # false
}



# https://github.com/nix-community/nix-index-database
function download_nixpkgs_cache_index () {
  filename="index-$(uname -m | sed 's/^arm64$/aarch64/')-$(uname | tr A-Z a-z)"
  mkdir -p ~/.cache/nix-index
  pushd ~/.cache/nix-index >/dev/null
  # -N will only download a new version if there is an update.
  wget -q -N https://github.com/Mic92/nix-index-database/releases/latest/download/$filename
  ln -f $filename files
  popd >/dev/null
}



function sort_by_string_length() {
  while read line; do
    echo $(echo "$line" | wc -c) $line
  done |
  sort -n |
  cut -d' ' -f2-
}



# parse arguments

deb_pkg_list=""

args=("$@")

for (( arg_idx = 0; arg_idx < ${#args[@]}; arg_idx++ )); do

  arg="${args[$arg_idx]}"

  case "$arg" in

    -p|--packages)
      # next args are debian packages
      #: (( arg_idx++ ))
      arg_idx=$((arg_idx + 1))
      for (( ; arg_idx < ${#args[@]}; arg_idx++ )); do
        arg="${args[$arg_idx]}"
        if [ "${arg:0:1}" = "-" ]; then
          # end of package list
          #: (( arg_idx-- ))
          arg_idx=$((arg_idx - 1))
          break
        fi
        deb_pkg_list+="$arg"$'\n'
      done
      ;;

    *)
      echo "error: unrecognized argument: ${arg@Q}" >&2
      exit 1
      ;;

  esac

done



if [ -n "$deb_pkg_list" ]; then
  # filter by package names
  echo "filtering by debian package names:" $deb_pkg_list >&2
fi



if ! [ -e "$APT_CONFIG" ]; then
  echo "running apt-init-config to create $APT_CONFIG"
  apt-init-config
fi

# set env for all apt commands
export APT_CONFIG="$APT_CONFIG"



# update the debian files database

if file_needs_update "$all_contents_path"; then
  apt-file update
fi



# update the nixpkgs files database

if file_needs_update "$nix_index_files_path"; then
  download_nixpkgs_cache_index
fi



# loop the debian files database

for deb_db_path in "$dir_state_lists"/deb.debian.org_debian_dists_unstable_main_Contents-*.lz4; do

  deb_db_name=${deb_db_path##*/}
  deb_db_name=${deb_db_name%.lz4}
  deb_db_arch=${deb_db_name##*-} # all, amd64, ...

  # debug
  # first deb_pkg is bash
  # Contents-amd64.lz4 has only binaries /bin/*
  # Contents-all.lz4 has all other files
  #[[ "$deb_db_name" == "deb.debian.org_debian_dists_unstable_main_Contents-amd64.lz4" ]] || continue

  echo "reading debian files database: $deb_db_path" >&2

  # debian package name. example: bash
  deb_pkg=""

  # assuming that file paths have no spaces
  # otherwise we would need an array of strings

  # debian package files. example: "/bin/bash"
  deb_pkg_files=""

  while read line; do

    #echo "line: $line"

    # example: bin/bash

    deb_file_path=${line%% *}

    # examples:
    # shells/bash
    # misc/live-boot,admin/open-infrastructure-system-boot
    # misc/live-config,admin/open-infrastructure-system-config

    deb_file_pkg_full=${line##* }

    # example: bash
    #deb_file_pkg=${deb_file_pkg_full##*/}

    deb_file_pkg=$deb_file_pkg_full

    if [[ "$deb_file_pkg" != "$deb_pkg" ]] || [ -z "$line" ]; then

      if [ -n "$deb_pkg" ]; then

        # finish previous package

        echo "deb_pkg $deb_pkg" >&2
        #echo "deb_pkg_files $deb_pkg_files" >&2

        #echo
        #echo "# deb: $deb_pkg"

        for deb_file in $deb_pkg_files; do

          deb_file="/$deb_file"
          # /usr/ -> /
          deb_file=${deb_file/\/usr\//\/}
          echo "deb_file $deb_file" >&2

          # nix-locate --at-root
          # https://github.com/nix-community/nix-index/issues/233
          # There's a bunch of FHS packages in nixpkgs that essentially ship half a distro with them
          # and massively pollute the output when searching for packages that provides common command line tools.

          nix_pkg_list=$(nix-locate --top-level --whole-name --at-root --minimal "$deb_file" | sort_by_string_length)

          # TODO remove ".out" or generally, remove the default output suffix
          # is ".out" always the default output = first output?
          # no. see notes.txt and custom-default-output-packages.txt

          seen_first=false

          for nix_pkg in $nix_pkg_list; do
            if
              [[ "${nix_pkg##*.}" == "out" ]] ||
              grep -q -x -F "$nix_pkg" custom-default-output-packages.txt
            then
              # remove the default output suffix
              nix_pkg=${nix_pkg%.*}
            fi
            if $seen_first; then
              # print alternative results as nix comments
              echo "#$nix_pkg # $deb_pkg $deb_file"
            else
              echo "$nix_pkg # $deb_pkg $deb_file"
            fi
            seen_first=true
          done

        done

        break # debug: stop after first pkg

        if [ -z "$line" ]; then
          # end of input
          break
        fi
      fi

      # start new package
      deb_pkg="$deb_file_pkg"
      deb_pkg_files=""

    fi

    deb_pkg_files+="$deb_file_path"$'\n'

    #echo "arch $deb_db_arch   pkg $deb_pkg   file $deb_file_path"

  done < <(

    if [ -n "$deb_pkg_list" ]; then
      # filter by package names
      # one file can be in multiple packages
      # see also: deb_file_pkg_full
      grep_script="/("
      for deb_pkg in $deb_pkg_list; do
        grep_script+="$deb_pkg|"
      done
      # remove the last "|"
      grep_script="${grep_script:0: -1}"
      grep_script+=")($|,)"
      echo "grep script: $grep_script" >&2
      cat "$deb_db_path" | lz4 -d | grep -E "$grep_script"
    else
      cat "$deb_db_path" | lz4 -d
    fi

    #cat "$deb_db_path" | lz4 -d | head -n20
    #cat "$deb_db_path" | lz4 -d | grep '/bzip2$'

    # add empty line at the end
    echo
  )

done
