# Endless Sky Offline Backup

I maintain an offline backup of [endless sky][es], its associated repositories,
and plugin index.  As a "break glass" effort, in case the open source project is
vandalized.

## Prerequisites

Install `openjdk-11-jre` and `git`.

Create a GitHub personal access token with no permissions and save it to
`github-token` in the root of this repository.

Run `./setup-prereqs.sh` from the root of this repository.

## Backup

Run the backup periodically.

```bash
export backup_scripts="/mnt/fast/endless-sky-backup"
export backup_destination="/mnt/fast/endless-sky-mirror"
export intended_user=root
"$backup_scripts/backup.sh"
```

## Schedule

I set up a crontab.

```cron
0 3 * * * /mnt/fast/endless-sky-backup/backup.sh
```

## Inspecting history

Wherever you store `$backup_destination` it will contain multiple git
directories.  These are a mix of bare git mirrors and a normal repository named
`reflog`.

- `plugin--*.git` are endless-sky plugins.
- `*.git` without starting with `plugin--` are repositories at endless-sky org.
- `reflog` a git repository where each day a backup is performed, then the
  following command is run and stored in the reflog repo.  For each repository,
  backup runs:
  ```
  git show-ref > reflog/repo_name_without_dot_git
  ```

The `reflog` repository is meant to protect against force-pushes by potentially
malicious activity.  If there's a force-push then there will be a log of it
along with old refs for restoration.

[es]: https://github.com/endless-sky/endless-sky
