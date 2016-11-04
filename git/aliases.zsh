alias git=hub
alias gitoneline="git log --graph --decorate --pretty=format:\"%C(auto)%h%d %Cblue%an%Creset: %C(auto)%s\""
alias gitonelineall="git log --graph --decorate --all --pretty=format:\"%C(auto)%h%d %Cblue%an%Creset: %C(auto)%s\""
alias gitpretty="git log --graph --decorate --name-status"
alias gitprettyall="git log --graph --decorate --name-status --all"
alias gitreset="git reset HEAD\^" # convenience function to go back one commit
alias gitpush="git push origin HEAD"
alias gitwip="git commit -a -m 'WIP DO NOT COMMIT'"

function gitmergecommit() { git log $1..HEAD --ancestry-path --merges --reverse }
function gitmerged() { git branch --merged $@ | sed -e '/^*/d' }
function gitshowsvn() { git show `git svn find-rev r$1` }
function gitsvnrebase() {
	if [[ $1 != "-l" ]]; then
		git svn fetch;
	fi
	git for-each-ref --shell --format='git co %(refname:short); git svn rebase -l;' refs/heads | \
		while read entry
		do
			eval "$entry"
		done
}

function gitupdatebases() {
	git fetch origin
    basis_branches=($(git for-each-ref --format='%(refname:short)' refs/heads/))
	rebaseBranch=$1
	# checkout a temporary branch in case we're currently on a basis branch
	git checkout -b updatebases_temp
	for branch in $basis_branches; do
	    echo "Checking $branch"
		# verify it exists
		git show-ref --verify --quiet refs/heads/"$branch"
		if [ $? -ne 0 ]; then
		    echo "Not found in refs"
			continue
		fi

		# verify it can be fast forwarded
		git merge-base --is-ancestor "$branch" origin/"$branch"
		if [ $? -ne 0 ]; then
			echo "$branch cannot be fast-forwarded to origin/$branch, you'll need to manually update your branch"
			continue
		fi

		# Change the branch ref to point to the new one
		echo "Updating $branch to origin/$branch"
		git update-ref refs/heads/"$branch" origin/"$branch"
	done
	git checkout -
	git branch -d updatebases_temp

	if [ ! -z "$rebaseBranch" ]; then
		git rebase $rebaseBranch
	fi
}

function gitcleanup() { 
  echo "=== Cleaning Remote Branch Caches ==="
  git remote prune origin

  echo "=== Cleaning Local Branches ========="
  except_branches=('"\*"' 'master' 'develop' 'rc')
  command="git branch --merged"
  for branch in $except_branches; do
	  command="$command | grep -v $branch"
  done
  command="$command | xargs -n 1 git branch -d"
  eval $command

  echo "=== Cleaning Local Branches With Empty Merges ==="
  command="git branch"
  for branch in $except_branches; do
	  command="$command | grep -v $branch"
  done
  localBranches=(`eval $command`)
  for branch in $localBranches; do
      mergeBase=`git merge-base HEAD $branch`
      git merge-tree "$mergeBase" HEAD "$branch" | grep -v "changed in both" | grep -v "  base" | grep -v "  our" | grep -v "  their" | read
      if [ $? -ne 0 ]; then
          git branch -D $branch
      fi
  done

  echo "=== Remaining Branches =============="
  git branch
}
