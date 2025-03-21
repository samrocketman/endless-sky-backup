# Endless Sky Offline Backup

I maintain an offline backup of endless sky, its associated repositories, and
plugin index.

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
