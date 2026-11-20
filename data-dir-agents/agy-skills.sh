# Shared deployment functions for the local and SSH rollout scripts.

agy_skill_is_managed() {
  local skill_dir="$1"
  local name="${skill_dir##*/}"
  local marker="$skill_dir/.data-dir-agents-managed"
  [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ] \
    && [ -f "$marker" ] && [ ! -L "$marker" ] \
    && grep -Fqx 'owner=data-dir-agents' "$marker" \
    && grep -Fqx 'deployment=gemini' "$marker" \
    && grep -Fqx "skill=$name" "$marker" \
    && grep -Fqx 'schema=1' "$marker"
}

agy_check_target() {
  local action="$1"
  shift
  local target="$HOME/.gemini/config/skills"
  local dir name

  if [ ! -d "$HOME/.gemini/antigravity-cli" ] || [ ! -d "$HOME/.gemini/config" ]; then
    echo 'ERROR: agy configuration has not been initialized' >&2
    return 1
  fi
  for dir in "$HOME/.gemini" "$HOME/.gemini/config" "$target"; do
    if [ -L "$dir" ] || { [ -e "$dir" ] && [ ! -d "$dir" ]; }; then
      echo "ERROR: expected a real directory at $dir" >&2
      return 1
    fi
  done

  for name in "$@"; do
    dir="$target/$name"
    if { [ -e "$dir" ] || [ -L "$dir" ]; } && ! agy_skill_is_managed "$dir"; then
      echo "ERROR: refusing to overwrite unmanaged agy skill: $dir" >&2
      return 1
    fi
  done

  [ "$action" != check ] || return 0
  for dir in "$target"/*; do
    agy_skill_is_managed "$dir" || continue
    name="${dir##*/}"
    case " $* " in *" $name "*) continue ;; esac
    if [ "$action" = prune ]; then
      rm -r -- "$dir" || return 1
      echo "Removed retired agy skill: $name"
    else
      echo "Would remove retired agy skill: $name"
    fi
  done
}

agy_check_deployment_target() {
  local host="$1" ssh_opts="$2"
  shift 2
  if [ -n "$host" ]; then
    # The function definitions and script travel over stdin. Skill names are
    # validated before they are passed as arguments to the remote shell.
    {
      declare -f agy_skill_is_managed agy_check_target
      printf 'agy_check_target "$@"\n'
    } | ssh $ssh_opts "$host" bash -s -- "$@"
  else
    agy_check_target "$@"
  fi
}

deploy_agy_skills() {
  local source="$1" apply="$2" delete="$3" host="${4:-}" ssh_opts="${5:-}"
  local skill name action changes
  local target="$HOME/.gemini/config/skills/"
  local -a skills=() names=() rsync_args=(-a --checksum)

  for skill in "$source"/*; do
    name="${skill##*/}"
    if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
      || [ ! -f "$skill/SKILL.md" ] || ! agy_skill_is_managed "$skill"; then
      echo "ERROR: invalid generated skill bundle: $skill" >&2
      return 1
    fi
    skills+=("$skill")
    names+=("$name")
  done

  if [ -n "$host" ]; then
    target="$host:.gemini/config/skills/"
    rsync_args+=(-e "ssh $ssh_opts")
  fi
  agy_check_deployment_target "$host" "$ssh_opts" check "${names[@]}" || return 1

  # Passing individual source directories scopes rsync deletion to their
  # contents. Other skill directories in the destination are kept.
  local -a transfer=("${rsync_args[@]}" --delete-delay)
  if [ "$apply" = false ]; then
    transfer+=(-ni)
  fi
  rsync "${transfer[@]}" "${skills[@]}" "$target" || return 1

  if [ "$apply" = true ]; then
    changes=$(rsync "${rsync_args[@]}" -ni --delete "${skills[@]}" "$target") || return 1
    if [ -n "$changes" ]; then
      printf 'ERROR: verification failed for %s\n%s\n' "$target" "$changes" >&2
      return 1
    fi
    printf 'Verified %s agy skills in %s\n' "${#names[@]}" "$target"
  fi

  if [ "$delete" = true ]; then
    action=plan-prune
    if [ "$apply" = true ]; then action=prune; fi
    agy_check_deployment_target "$host" "$ssh_opts" "$action" "${names[@]}" || return 1
  fi
}
